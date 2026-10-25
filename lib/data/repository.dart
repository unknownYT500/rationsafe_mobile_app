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
import '../ai/edge_guardian.dart';
import '../ai/blueprint_compliance.dart';

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

      // 1. Blueprint Statutory Rule Enforcement (NFSA 2013)
      final compliance = await BlueprintComplianceEngine.validateDispense(
        card: card,
        requestedQuantityKg: quantity,
      );
      if (!compliance.isCompliant && !allowFallback) {
        return {
          'mode': 'OFFLINE_EDGE_SIGNED',
          'success': false,
          'code': 'ERR_NFSA_STATUTORY_VIOLATION',
          'state': 'FAIL_REASON',
          'message': compliance.violations.first,
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

      // 2. Prepare Offline Token Metadata
      final counter = await _localDb.getNextCounter();
      final txnId = 'txn_off_${generateUuidV7()}';
      final tokenId = 'tok_off_${generateUuidV7()}';

      // 3. On-Device Edge Guardian AI Risk Assessment
      final aiAssessment = await EdgeGuardianService.evaluateTransaction(
        tokenId: tokenId,
        card: card,
        requestedQuantityKg: quantity,
        currentCounter: counter,
      );

      if (aiAssessment.recommendedAction == GuardianAction.block && !allowFallback) {
        return {
          'mode': 'OFFLINE_EDGE_SIGNED',
          'success': false,
          'code': 'ERR_AI_FRAUD_PREVENTED',
          'state': 'FAIL_REASON',
          'message': aiAssessment.explanation,
          'ai_assessment': aiAssessment.toJson(),
        };
      }

      // Offline Fallback or Valid Quota: Sign Provisional Token
      final keyPair = await _signer.getOrCreateNodeKeyPair();
      final subHash = await hashCardId(cardId);
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
        'ai_risk_score': aiAssessment.riskScore,
        'ai_risk_level': aiAssessment.riskLevel.name.toUpperCase(),
        'ai_flags': aiAssessment.flags,
        'ai_action': aiAssessment.recommendedAction.name.toUpperCase(),
        'message': allowFallback
            ? 'Offline fallback authorization approved. Provisional signed token queued.'
            : 'Provisional grain issuance signed with Ed25519. Queued in terminal outbox.',
      };
    }
  }

  // --- Resilient Chunked Batch Sync & Dead-Letter Queue Management ---

  Future<Map<String, dynamic>> triggerBatchSync(String nodeId, {int chunkSize = 50}) async {
    int totalSynced = 0;
    int totalQuarantined = 0;
    int totalRetrying = 0;
    int batchCount = 0;
    String? lastError;

    // Stream outbox in paginated chunks (50 items) to keep RAM usage bounded on low-spec POS terminals
    while (true) {
      final chunk = await _localDb.getPendingOutboxChunk(limit: chunkSize);
      if (chunk.isEmpty) break;

      batchCount++;
      final batchId = 'batch_${generateUuidV7()}';
      final tokenJsonList = chunk.map((t) => t.toJson()).toList();

      try {
        final result = await _supabase.reconcileSyncBatch(nodeId, batchId, tokenJsonList);
        final items = result['items'] as List<dynamic>?;

        if (items != null && items.isNotEmpty) {
          // Process per-item ACK outcomes
          final acceptedIds = <String>[];
          for (final item in items) {
            final tokenId = (item['token_id'] ?? item['id'])?.toString() ?? '';
            final outcome = item['outcome']?.toString().toUpperCase() ?? 'REJECTED';
            final reason = item['reason']?.toString() ?? 'Sync rejection';

            if (outcome == 'ACCEPTED' || outcome == 'DUPLICATE') {
              if (tokenId.isNotEmpty) acceptedIds.add(tokenId);
              totalSynced++;
            } else {
              // Quarantine permanently rejected token to Dead-Letter Queue without blocking subsequent items
              if (tokenId.isNotEmpty) {
                await _localDb.quarantineDirectlyToDeadLetter(tokenId, reason);
                totalQuarantined++;
              }
            }
          }
          if (acceptedIds.isNotEmpty) {
            await _localDb.markOutboxItemsSynced(acceptedIds);
          }
        } else {
          // Fallback blanket acknowledgment
          final acceptedCount = (result['accepted'] as num?)?.toInt() ?? 0;
          final duplicateCount = (result['duplicate'] as num?)?.toInt() ?? 0;
          if (acceptedCount > 0 || duplicateCount > 0) {
            final allIds = chunk.map((t) => t.id).toList();
            await _localDb.markOutboxItemsSynced(allIds);
            totalSynced += allIds.length;
          } else {
            // Apply exponential backoff with jitter on rejection
            for (final token in chunk) {
              await _localDb.markOutboxAttemptFailed(token.id, 'Sync batch rejected by central authority');
              totalRetrying++;
            }
            break;
          }
        }
      } catch (e) {
        lastError = e.toString();
        // Record failure and increment exponential jitter backoff for the chunk
        for (final token in chunk) {
          await _localDb.markOutboxAttemptFailed(token.id, 'Network error: $lastError');
          totalRetrying++;
        }
        break; // Stop loop on network error to allow backoff timer to elapse
      }
    }

    final stats = await _localDb.getOutboxStats();
    return {
      'synced': totalSynced,
      'quarantined_to_dlq': totalQuarantined,
      'retrying': totalRetrying,
      'batches_processed': batchCount,
      'remaining_depth': await _localDb.getOutboxDepth(),
      'outbox_stats': stats,
      'last_error': lastError,
      'message': totalSynced > 0
          ? 'Synchronized $totalSynced provisional transactions across $batchCount batches.'
          : (lastError != null ? 'Sync deferred: $lastError' : 'No outbox records ready for sync.'),
    };
  }

  Future<List<Map<String, dynamic>>> getDeadLetterTokens() async {
    return await _localDb.getDeadLetterTokens();
  }

  Future<bool> requeueDeadLetterToken(String tokenId) async {
    return await _localDb.requeueDeadLetterToken(tokenId);
  }

  Future<Map<String, int>> getOutboxStats() async {
    return await _localDb.getOutboxStats();
  }

  // --- Registrations ---

  Future<Map<String, dynamic>> submitRegistration(Map<String, dynamic> data, String nodeId) async {
    return await _supabase.submitRegistration(data, nodeId);
  }

  Future<bool> verifyRegistration(String regId) async {
    return await _supabase.verifyRegistration(regId);
  }

  Future<Map<String, dynamic>> approveRegistration(String regId) async {
    return await _supabase.approveRegistration(regId);
  }

  Future<bool> resetDatabase() async {
    await _localDb.clearAllData();
    return await _supabase.resetDatabase();
  }
}
