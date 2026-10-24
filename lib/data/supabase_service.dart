// ration_safe_mobile_app/lib/data/supabase_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';
import '../models/beneficiary.dart';
import '../models/grain_lot.dart';
import '../models/distribution_node.dart';
import '../models/registration.dart';
import '../models/audit_log.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._init();
  bool _isInitialized = false;

  SupabaseService._init();

  bool get isReady => _isInitialized && !AppEnv.supabaseAnonKey.contains('dummy');

  Future<void> initialize() async {
    try {
      if (!AppEnv.supabaseAnonKey.contains('dummy')) {
        await Supabase.initialize(
          url: AppEnv.supabaseUrl,
          // ignore: deprecated_member_use
          anonKey: AppEnv.supabaseAnonKey,
        );
        _isInitialized = true;
        debugPrint('[Supabase] Initialized successfully with ${AppEnv.supabaseUrl}');
      } else {
        debugPrint('[Supabase] Dummy anon key detected; running with REST API fallback');
      }
    } catch (e) {
      debugPrint('[Supabase] Initialization failed: $e. Falling back to REST API.');
    }
  }

  SupabaseClient? get client => _isInitialized ? Supabase.instance.client : null;

  // --- Realtime Subscription ---
  RealtimeChannel? subscribeToUpdates(void Function() onTableChanged) {
    if (!isReady || client == null) return null;

    try {
      final channel = client!
          .channel('graintrust_mobile_realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'cards',
            callback: (_) => onTableChanged(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'grain_lots',
            callback: (_) => onTableChanged(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'registrations',
            callback: (_) => onTableChanged(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'audit_events',
            callback: (_) => onTableChanged(),
          )
          .subscribe();

      return channel;
    } catch (e) {
      debugPrint('[Supabase Realtime] Subscribe error: $e');
      return null;
    }
  }

  // --- Data Fetching ---
  Future<List<CardBeneficiary>> fetchCards(String? nodeId) async {
    // 1. Try Supabase direct join if ready
    if (isReady && client != null) {
      try {
        final res = await client!
            .from('cards')
            .select('''
              id, person_id, status, issued_at,
              persons (first_name, last_name, phone_number),
              household_profiles (family_count, address, city, state),
              quota_leases (allocated_qty, consumed_qty)
            ''');

        return (res as List).map((row) {
          final p = row['persons'] as Map<String, dynamic>? ?? {};
          final h = row['household_profiles'] as Map<String, dynamic>? ?? {};
          final qList = row['quota_leases'] as List? ?? [];
          final q = qList.isNotEmpty ? qList.first as Map<String, dynamic> : {};

          final alloc = (q['allocated_qty'] as num?)?.toDouble() ?? 0.0;
          final cons = (q['consumed_qty'] as num?)?.toDouble() ?? 0.0;

          return CardBeneficiary(
            id: row['id'] ?? '',
            personId: row['person_id'] ?? '',
            status: row['status'] ?? 'ACTIVE',
            issuedAt: row['issued_at'] ?? '',
            firstName: p['first_name'] ?? '',
            lastName: p['last_name'] ?? '',
            fullName: '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim(),
            phoneNumber: p['phone_number'] ?? '',
            familyCount: (h['family_count'] as num?)?.toInt() ?? 1,
            address: h['address'] ?? '',
            city: h['city'] ?? '',
            state: h['state'] ?? '',
            allocatedQty: alloc,
            consumedQty: cons,
            remainingQty: alloc - cons,
          );
        }).toList();
      } catch (e) {
        debugPrint('[Supabase] fetchCards error: $e. Falling back to HTTP.');
      }
    }

    // 2. HTTP Fallback to API server
    try {
      final url = Uri.parse('${AppEnv.backendApiUrl}/api/v1/cards${nodeId != null ? '?node_id=$nodeId' : ''}');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        return list.map((item) => CardBeneficiary.fromJson(item)).toList();
      }
    } catch (_) {}

    return [];
  }

  Future<List<GrainLotItem>> fetchLots() async {
    if (isReady && client != null) {
      try {
        final res = await client!.from('grain_lots').select();
        return (res as List).map((r) => GrainLotItem.fromJson(r)).toList();
      } catch (e) {
        debugPrint('[Supabase] fetchLots error: $e');
      }
    }

    try {
      final url = Uri.parse('${AppEnv.backendApiUrl}/api/v1/lots');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((i) => GrainLotItem.fromJson(i)).toList();
      }
    } catch (_) {}

    return [];
  }

  Future<List<NodeItem>> fetchNodes() async {
    if (isReady && client != null) {
      try {
        final res = await client!.from('distribution_nodes').select();
        return (res as List).map((r) => NodeItem.fromJson(r)).toList();
      } catch (e) {
        debugPrint('[Supabase] fetchNodes error: $e');
      }
    }

    try {
      final url = Uri.parse('${AppEnv.backendApiUrl}/api/v1/nodes');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((i) => NodeItem.fromJson(i)).toList();
      }
    } catch (_) {}

    return [];
  }

  Future<List<RegistrationItem>> fetchRegistrations() async {
    if (isReady && client != null) {
      try {
        final res = await client!.from('registrations').select().order('created_at', ascending: false);
        return (res as List).map((r) => RegistrationItem.fromJson(r)).toList();
      } catch (e) {
        debugPrint('[Supabase] fetchRegistrations error: $e');
      }
    }

    try {
      final url = Uri.parse('${AppEnv.backendApiUrl}/api/v1/registrations');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((i) => RegistrationItem.fromJson(i)).toList();
      }
    } catch (_) {}

    return [];
  }

  Future<List<AuditLogItem>> fetchAuditLogs() async {
    if (isReady && client != null) {
      try {
        final res = await client!.from('audit_events').select().order('timestamp', ascending: false).limit(20);
        return (res as List).map((r) => AuditLogItem.fromJson(r)).toList();
      } catch (e) {
        debugPrint('[Supabase] fetchAuditLogs error: $e');
      }
    }

    try {
      final url = Uri.parse('${AppEnv.backendApiUrl}/api/v1/audit');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((i) => AuditLogItem.fromJson(i)).toList();
      }
    } catch (_) {}

    return [];
  }

  // --- Mutations & RPCs ---

  /// Online Grain Dispense
  Future<Map<String, dynamic>> onlineDispense({
    required String idempotencyKey,
    required String cardId,
    required String lotId,
    required String nodeId,
    required double quantity,
    String actorId = 'distribution-operator',
  }) async {
    // 1. Supabase RPC if ready
    if (isReady && client != null) {
      try {
        final res = await client!.rpc('fn_online_dispense', params: {
          'p_idempotency_key': idempotencyKey,
          'p_card_id': cardId,
          'p_lot_id': lotId,
          'p_node_id': nodeId,
          'p_quantity': quantity,
          'p_actor_id': actorId,
        });
        return Map<String, dynamic>.from(res);
      } catch (e) {
        debugPrint('[Supabase RPC] fn_online_dispense error: $e. Falling back to HTTP.');
      }
    }

    // 2. HTTP Fallback
    try {
      final url = Uri.parse('${AppEnv.backendApiUrl}/api/v1/transactions');
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey,
          'x-user-id': actorId,
        },
        body: jsonEncode({
          'card_id': cardId,
          'lot_id': lotId,
          'node_id': nodeId,
          'quantity': quantity,
        }),
      );

      final body = jsonDecode(res.body);
      if (res.statusCode == 201) {
        return {
          'success': true,
          'state': 'RECONCILED',
          'data': body,
        };
      } else {
        return {
          'success': false,
          'code': body['code'] ?? 'ERR_201',
          'state': 'FAIL_REASON',
          'message': body['message'] ?? 'Transaction failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'code': 'ERR_500',
        'state': 'FAIL_REASON',
        'message': 'Network or server error: $e',
      };
    }
  }

  /// Submit Citizen Registration
  Future<Map<String, dynamic>> submitRegistration(Map<String, dynamic> data, String nodeId) async {
    final payload = Map<String, dynamic>.from(data);
    payload['node_id'] = nodeId;

    try {
      final url = Uri.parse('${AppEnv.backendApiUrl}/api/v1/registrations');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (res.statusCode == 201) {
        return {'success': true, 'data': jsonDecode(res.body)};
      } else {
        return {'success': false, 'message': jsonDecode(res.body)['message'] ?? 'Registration rejected'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Verify Registration
  Future<bool> verifyRegistration(String regId) async {
    try {
      final url = Uri.parse('${AppEnv.backendApiUrl}/api/v1/registrations/$regId/verify');
      final res = await http.post(url);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Approve Registration & Issue Card
  Future<Map<String, dynamic>> approveRegistration(String regId) async {
    if (isReady && client != null) {
      try {
        final res = await client!.rpc('fn_approve_registration', params: {
          'p_reg_id': regId,
          'p_actor_id': 'admin',
        });
        return {'success': true, 'data': res};
      } catch (e) {
        debugPrint('[Supabase RPC] fn_approve_registration error: $e');
      }
    }

    try {
      final url = Uri.parse('${AppEnv.backendApiUrl}/api/v1/registrations/$regId/approve');
      final res = await http.post(url);
      if (res.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(res.body)};
      }
    } catch (_) {}

    return {'success': false};
  }

  /// Reconcile Batch Sync
  Future<Map<String, dynamic>> reconcileSyncBatch(
    String nodeId,
    String batchId,
    List<Map<String, dynamic>> tokens,
  ) async {
    if (isReady && client != null) {
      try {
        final res = await client!.rpc('fn_reconcile_sync_batch', params: {
          'p_node_id': nodeId,
          'p_batch_id': batchId,
          'p_tokens': tokens,
        });
        return Map<String, dynamic>.from(res);
      } catch (e) {
        debugPrint('[Supabase RPC] fn_reconcile_sync_batch error: $e');
      }
    }

    try {
      final url = Uri.parse('${AppEnv.backendApiUrl}/api/v1/nodes/$nodeId/sync');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'batch_id': batchId,
          'tokens': tokens,
        }),
      );

      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(res.body));
      }
    } catch (_) {}

    return {
      'accepted': 0,
      'duplicate': 0,
      'rejected': tokens.length,
      'conflict': 0,
    };
  }

  /// Reset Database (Demo Reset)
  Future<bool> resetDatabase() async {
    try {
      final url = Uri.parse('${AppEnv.backendApiUrl}/api/v1/admin/reset');
      final res = await http.post(url);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
