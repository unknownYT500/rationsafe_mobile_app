// ration_safe_mobile_app/lib/data/repository.dart
import 'local_db.dart';
import 'supabase_service.dart';
import '../crypto/ed25519_signer.dart';
import '../crypto/hash_utils.dart';
import '../models/beneficiary.dart';
import '../models/grain_lot.dart';
import '../models/distribution_node.dart';
import '../models/registration.dart';
import '../models/audit_log.dart';
import '../models/provisional_token.dart';

class GrainTrustRepository {
  static final GrainTrustRepository instance = GrainTrustRepository._init();

  final LocalDatabase _localDb = LocalDatabase.instance;
  final SupabaseService _supabase = SupabaseService.instance;
  final Ed25519Service _signer = Ed25519Service();

  GrainTrustRepository._init();

  // --- Fetching Data ---
  Future<List<CardBeneficiary>> getCards(String? nodeId, {required bool isOnline}) async {
    if (isOnline) {
      final remoteCards = await _supabase.fetchCards(nodeId);
      if (remoteCards.isNotEmpty) {
        await _localDb.cacheCards(remoteCards);
        return remoteCards;
      }
    }
    // Fallback to local SQLite cache
    return await _localDb.getLocalCards();
  }

  Future<List<GrainLotItem>> getLots({required bool isOnline}) async {
    if (isOnline) {
      final remoteLots = await _supabase.fetchLots();
      if (remoteLots.isNotEmpty) {
        await _localDb.cacheLots(remoteLots);
        return remoteLots;
      }
    }
    return await _localDb.getLocalLots();
  }

  Future<List<NodeItem>> getNodes({required bool isOnline}) async {
    if (isOnline) {
      final nodes = await _supabase.fetchNodes();
      if (nodes.isNotEmpty) return nodes;
    }

    // Default static nodes
    return [
      const NodeItem(
        id: 'node-alpha-001',
        name: 'Sector 4 Community Depot',
        publicKey: 'd41d8cd98f00b204e9800998ecf8427e00000000000000000000000000000001',
        status: 'ONLINE',
        lastHeartbeat: '',
        outboxDepth: 0,
        location: 'Kanpur Urban Sector 4',
      ),
      const NodeItem(
        id: 'node-beta-002',
        name: 'Rural Outpost Station 9',
        publicKey: 'd41d8cd98f00b204e9800998ecf8427e00000000000000000000000000000002',
        status: 'ONLINE',
        lastHeartbeat: '',
        outboxDepth: 0,
        location: 'Bithoor Rural Block 9',
      ),
    ];
  }

  Future<List<RegistrationItem>> getRegistrations({required bool isOnline}) async {
    if (isOnline) {
      return await _supabase.fetchRegistrations();
    }
    return [];
  }

  Future<List<AuditLogItem>> getAuditLogs({required bool isOnline}) async {
    if (isOnline) {
      return await _supabase.fetchAuditLogs();
    }
    return [];
  }

  Future<int> getOutboxDepth() async {
    return await _localDb.getOutboxDepth();
  }

  // --- Grain Issuance (Online vs Offline Signed) ---

  Future<Map<String, dynamic>> issueGrain({
    required bool isOnline,
    required String cardId,
    required String lotId,
    required String nodeId,
    required double quantity,
    required bool allowFallback,
    required String actorId,
  }) async {
    final idempotencyKey = 'mob_idem_${generateUuidV7()}';

    if (isOnline) {
      // 1. Online Central Dispense via Supabase RPC / API
      final res = await _supabase.onlineDispense(
        idempotencyKey: idempotencyKey,
        cardId: cardId,
        lotId: lotId,
        nodeId: nodeId,
        quantity: quantity,
        actorId: actorId,
      );

      return {
        'mode': 'ONLINE_CENTRAL',
        ...res,
      };
    } else {
      // 2. Autonomous Offline Edge Issuance
      final localCards = await _localDb.getLocalCards();
      final card = localCards.firstWhere(
        (c) => c.id == cardId,
        orElse: () => throw Exception('Card not found in offline terminal cache'),
      );

      final localLots = await _localDb.getLocalLots();
      final lot = localLots.firstWhere(
        (l) => l.id == lotId,
        orElse: () => throw Exception('Lot not found in offline terminal cache'),
      );

      // Check remaining quota
      final hasQuota = card.remainingQty >= quantity;
      final hasLotStock = lot.remainingQuantity >= quantity;

      if (!hasLotStock) {
        return {
          'mode': 'OFFLINE_EDGE_SIGNED',
          'success': false,
          'code': 'ERR_202',
          'state': 'FAIL_REASON',
          'message': 'Emergency Grain Lot Depleted in offline terminal cache.',
        };
      }

      if (!hasQuota && !allowFallback) {
        return {
          'mode': 'OFFLINE_EDGE_SIGNED',
          'success': false,
          'code': 'ERR_201',
          'state': 'FAIL_REASON',
          'message': 'Beneficiary Quota Limit Exceeded. Quota balance insufficient.',
        };
      }

      // Offline Fallback or Valid Quota: Sign Provisional Token
      final keyPair = await _signer.getOrCreateNodeKeyPair();
      final counter = await _localDb.getNextCounter();
      final subHash = await hashCardId(cardId);
      final txnId = 'txn_off_${generateUuidV7()}';
      final tokenId = 'tok_off_${generateUuidV7()}';
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expSec = nowSec + 3600; // 1-hour validity window

      final payload = ProvisionalTokenPayload(
        tid: txnId,
        nid: nodeId,
        lid: lotId,
        gid: 'grant_${nodeId}_lot',
        qid: 'quota_$cardId',
        sub: subHash,
        n: 'nonce_${generateUuidV7()}',
        c: counter,
        qty: quantity,
        iat: nowSec,
        exp: expSec,
        kid: nodeId,
      );

      final signatureHex = await _signer.signCanonicalPayload(
        payload.toJson(),
        keyPair['privateKeyHex']!,
      );

      final signedToken = SignedProvisionalToken(
        id: tokenId,
        txnId: txnId,
        payload: payload,
        signature: signatureHex,
        keyId: nodeId,
        createdAt: DateTime.now().toIso8601String(),
      );

      // Deduct locally and queue in outbox
      await _localDb.updateLocalCardConsumption(cardId, quantity);
      await _localDb.updateLocalLotConsumption(lotId, quantity);
      await _localDb.queueOutboxToken(signedToken);

      return {
        'mode': 'OFFLINE_EDGE_SIGNED',
        'success': true,
        'state': 'PROVISIONAL_ISSUE',
        'transaction_id': txnId,
        'token': signedToken,
        'quantity': quantity,
        'lot_id': lotId,
        'card_id': cardId,
        'counter': counter,
        'message': allowFallback
            ? 'Offline fallback authorization approved. Provisional signed token queued.'
            : 'Provisional grain issuance signed with Ed25519. Queued in terminal outbox.',
      };
    }
  }

  // --- Batch Sync ---

  Future<Map<String, dynamic>> triggerBatchSync(String nodeId) async {
    final pendingTokens = await _localDb.getPendingOutboxTokens();
    if (pendingTokens.isEmpty) {
      return {
        'synced': 0,
        'message': 'No pending provisional tokens in terminal outbox.',
      };
    }

    final batchId = 'batch_${generateUuidV7()}';
    final tokenJsonList = pendingTokens.map((t) => t.toJson()).toList();

    final result = await _supabase.reconcileSyncBatch(nodeId, batchId, tokenJsonList);

    // On accepted or duplicate, mark items synced locally
    final acceptedTokenIds = pendingTokens.map((t) => t.id).toList();
    await _localDb.markOutboxItemsSynced(acceptedTokenIds);

    return {
      'synced': pendingTokens.length,
      'batch_id': batchId,
      ...result,
    };
  }

  // --- Registrations ---

  Future<Map<String, dynamic>> submitRegistration(Map<String, dynamic> data, String nodeId) async {
    return await _supabase.submitRegistration(data, nodeId);
  }

  Future<bool> verifyRegistration(String regId) async {
    return await _supabase.verifyRegistration(regId);
  }

  Future<bool> deleteRegistration(String regId) async {
    return await _supabase.deleteRegistration(regId);
  }

  Future<bool> clearUnapprovedRegistrations() async {
    return await _supabase.clearUnapprovedRegistrations();
  }

  Future<Map<String, dynamic>> approveRegistration(String regId) async {
    return await _supabase.approveRegistration(regId);
  }

  Future<bool> resetDatabase() async {
    await _localDb.clearAllData();
    return await _supabase.resetDatabase();
  }
}
