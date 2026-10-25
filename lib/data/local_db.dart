// ration_safe_mobile_app/lib/data/local_db.dart
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/beneficiary.dart';
import '../models/grain_lot.dart';
import '../models/provisional_token.dart';
import '../crypto/hash_utils.dart';

/// Secure AES-GCM 256 cryptographic vault for mobile SQLite field-level PII encryption.
class _LocalDbPiiCrypto {
  static final _aesGcm = AesGcm.with256bits();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  static const _dbKeyName = 'graintrust_db_aes_key_v1';
  static SecretKey? _cachedKey;

  static Future<SecretKey> _getKey() async {
    if (_cachedKey != null) return _cachedKey!;
    final hexKey = await _storage.read(key: _dbKeyName);
    if (hexKey != null) {
      final bytes = hexToBytes(hexKey);
      _cachedKey = SecretKey(bytes);
      return _cachedKey!;
    }
    final freshKey = await _aesGcm.newSecretKey();
    final bytes = await freshKey.extractBytes();
    await _storage.write(key: _dbKeyName, value: bytesToHex(bytes));
    _cachedKey = freshKey;
    return _cachedKey!;
  }

  static Future<String> encrypt(String plaintext) async {
    if (plaintext.isEmpty) return plaintext;
    try {
      final key = await _getKey();
      final secretBox = await _aesGcm.encrypt(
        utf8.encode(plaintext),
        secretKey: key,
      );
      final nonceHex = bytesToHex(secretBox.nonce);
      final macHex = bytesToHex(secretBox.mac.bytes);
      final cipherHex = bytesToHex(secretBox.cipherText);
      return 'enc:v1:$nonceHex:$macHex:$cipherHex';
    } catch (_) {
      return plaintext;
    }
  }

  static Future<String> decrypt(String ciphertext) async {
    if (!ciphertext.startsWith('enc:v1:')) return ciphertext;
    try {
      final parts = ciphertext.split(':');
      if (parts.length != 5) return ciphertext;
      final nonce = hexToBytes(parts[2]);
      final mac = Mac(hexToBytes(parts[3]));
      final cipherText = hexToBytes(parts[4]);
      final key = await _getKey();
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
      final clearBytes = await _aesGcm.decrypt(secretBox, secretKey: key);
      return utf8.decode(clearBytes);
    } catch (_) {
      return '[ENCRYPTED_PII]';
    }
  }
}

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;
  static final _random = Random();

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('graintrust_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE local_outbox ADD COLUMN last_error TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE local_outbox ADD COLUMN last_attempt_at TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE local_outbox ADD COLUMN next_retry_at TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE local_outbox ADD COLUMN quarantined_at TEXT');
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_outbox_sync ON local_outbox (status, next_retry_at, created_at)');
      } catch (_) {}
    }

    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS edge_ai_heuristics (
            token_id TEXT PRIMARY KEY,
            risk_score REAL NOT NULL,
            risk_level TEXT NOT NULL,
            heuristic_flags TEXT,
            recommended_action TEXT NOT NULL,
            analyzed_at INTEGER NOT NULL
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_grievances (
            id TEXT PRIMARY KEY,
            card_id TEXT NOT NULL,
            beneficiary_name TEXT,
            category TEXT NOT NULL,
            transcript TEXT NOT NULL,
            language TEXT NOT NULL,
            audio_timestamp TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'REGISTERED',
            created_at TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Cached Beneficiary Cards
    await db.execute('''
      CREATE TABLE local_cards (
        id TEXT PRIMARY KEY,
        person_id TEXT NOT NULL,
        status TEXT NOT NULL,
        issued_at TEXT NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        full_name TEXT NOT NULL,
        phone_number TEXT NOT NULL,
        family_count INTEGER NOT NULL,
        address TEXT NOT NULL,
        city TEXT NOT NULL,
        state TEXT NOT NULL,
        allocated_qty REAL NOT NULL,
        consumed_qty REAL NOT NULL,
        remaining_qty REAL NOT NULL
      )
    ''');

    // 2. Cached Grain Lots
    await db.execute('''
      CREATE TABLE local_lots (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        grain_type TEXT NOT NULL,
        total_quantity REAL NOT NULL,
        remaining_quantity REAL NOT NULL
      )
    ''');

    // 3. Outbox for Signed Provisional Tokens (Resilient DLQ & Backoff Schema)
    await db.execute('''
      CREATE TABLE local_outbox (
        id TEXT PRIMARY KEY,
        txn_id TEXT NOT NULL,
        token_json TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        attempts INTEGER NOT NULL DEFAULT 0,
        reason TEXT,
        last_error TEXT,
        last_attempt_at TEXT,
        next_retry_at TEXT,
        quarantined_at TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_outbox_sync ON local_outbox (status, next_retry_at, created_at)
    ''');

    // 4. Local Transactions
    await db.execute('''
      CREATE TABLE local_transactions (
        id TEXT PRIMARY KEY,
        card_id TEXT NOT NULL,
        lot_id TEXT NOT NULL,
        node_id TEXT NOT NULL,
        quantity REAL NOT NULL,
        state TEXT NOT NULL,
        fallback_used INTEGER NOT NULL DEFAULT 0,
        token_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 5. Node Monotonic Counter
    await db.execute('''
      CREATE TABLE local_meta (
        key TEXT PRIMARY KEY,
        value INTEGER NOT NULL
      )
    ''');

    await db.insert('local_meta', {'key': 'counter', 'value': 1000});

    // 6. Phase 4: Edge AI Anomaly Heuristics
    await db.execute('''
      CREATE TABLE edge_ai_heuristics (
        token_id TEXT PRIMARY KEY,
        risk_score REAL NOT NULL,
        risk_level TEXT NOT NULL,
        heuristic_flags TEXT,
        recommended_action TEXT NOT NULL,
        analyzed_at INTEGER NOT NULL
      )
    ''');

    // 7. Phase 4: Offline Vernacular Citizen Grievances
    await db.execute('''
      CREATE TABLE local_grievances (
        id TEXT PRIMARY KEY,
        card_id TEXT NOT NULL,
        beneficiary_name TEXT,
        category TEXT NOT NULL,
        transcript TEXT NOT NULL,
        language TEXT NOT NULL,
        audio_timestamp TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'REGISTERED',
        created_at TEXT NOT NULL
      )
    ''');
  }

  // --- Monotonic Counter ---
  Future<int> getNextCounter() async {
    final db = await database;
    return await db.transaction((txn) async {
      final res = await txn.query('local_meta', where: 'key = ?', whereArgs: ['counter']);
      int current = 1000;
      if (res.isNotEmpty) {
        current = (res.first['value'] as int?) ?? 1000;
      }
      final next = current + 1;
      await txn.update(
        'local_meta',
        {'value': next},
        where: 'key = ?',
        whereArgs: ['counter'],
      );
      return next;
    });
  }

  // --- Cards Cache (Encrypted PII at rest) ---
  Future<void> cacheCards(List<CardBeneficiary> cards) async {
    final db = await database;
    final batch = db.batch();
    for (final card in cards) {
      final encPhone = await _LocalDbPiiCrypto.encrypt(card.phoneNumber);
      final encAddress = await _LocalDbPiiCrypto.encrypt(card.address);
      final data = card.toJson();
      data['phone_number'] = encPhone;
      data['address'] = encAddress;

      batch.insert(
        'local_cards',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<CardBeneficiary>> getLocalCards() async {
    final db = await database;
    final res = await db.query('local_cards');
    final list = <CardBeneficiary>[];
    for (final row in res) {
      final mutable = Map<String, dynamic>.from(row);
      mutable['phone_number'] = await _LocalDbPiiCrypto.decrypt(mutable['phone_number']?.toString() ?? '');
      mutable['address'] = await _LocalDbPiiCrypto.decrypt(mutable['address']?.toString() ?? '');
      list.add(CardBeneficiary.fromJson(mutable));
    }
    return list;
  }

  Future<void> updateLocalCardConsumption(String cardId, double quantity) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE local_cards
      SET consumed_qty = consumed_qty + ?,
          remaining_qty = MAX(0, remaining_qty - ?)
      WHERE id = ?
    ''', [quantity, quantity, cardId]);
  }

  // --- Lots Cache ---
  Future<void> cacheLots(List<GrainLotItem> lots) async {
    final db = await database;
    final batch = db.batch();
    for (final lot in lots) {
      batch.insert(
        'local_lots',
        lot.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<GrainLotItem>> getLocalLots() async {
    final db = await database;
    final res = await db.query('local_lots');
    return res.map((m) => GrainLotItem.fromJson(m)).toList();
  }

  Future<void> updateLocalLotConsumption(String lotId, double quantity) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE local_lots
      SET remaining_quantity = MAX(0, remaining_quantity - ?)
      WHERE id = ?
    ''', [quantity, lotId]);
  }

  // --- Outbox Queue ---
  Future<void> queueOutboxToken(SignedProvisionalToken token) async {
    final db = await database;
    await db.insert(
      'local_outbox',
      {
        'id': token.id,
        'txn_id': token.txnId,
        'token_json': jsonEncode(token.toJson()),
        'status': 'PENDING',
        'attempts': 0,
        'created_at': token.createdAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Fetches pending outbox tokens in paginated chunks (default limit: 50) using cursor filtering.
  /// Prevents large memory allocations on low-spec Android POS hardware during deep queue syncs.
  Future<List<SignedProvisionalToken>> getPendingOutboxChunk({
    int limit = 50,
    String? afterCreatedAt,
    String? afterId,
  }) async {
    final db = await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    String whereClause = "(status = 'PENDING' OR status = 'RETRYING') AND (next_retry_at IS NULL OR next_retry_at <= ?)";
    final whereArgs = <dynamic>[nowIso];

    if (afterCreatedAt != null && afterId != null) {
      whereClause += " AND (created_at > ? OR (created_at = ? AND id > ?))";
      whereArgs.addAll([afterCreatedAt, afterCreatedAt, afterId]);
    }

    final res = await db.query(
      'local_outbox',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at ASC, id ASC',
      limit: limit,
    );

    return res.map((row) {
      final json = jsonDecode(row['token_json'] as String);
      return SignedProvisionalToken.fromJson(json);
    }).toList();
  }

  /// Backward-compatible fetcher returning first 50 pending records.
  Future<List<SignedProvisionalToken>> getPendingOutboxTokens() async {
    return await getPendingOutboxChunk(limit: 50);
  }

  /// Calculates exponential backoff with randomized full jitter.
  /// Formula: min(maxDelayMs, 2^attempt * baseDelayMs + random(0, 1000ms))
  static Duration calculateBackoffWithJitter(
    int attempt, {
    int baseDelayMs = 1000,
    int maxDelayMs = 60000,
  }) {
    final expMultiplier = 1 << (attempt > 6 ? 6 : attempt);
    final expMs = baseDelayMs * expMultiplier;
    final cappedExpMs = expMs > maxDelayMs ? maxDelayMs : expMs;
    final jitterMs = _random.nextInt(1000); // 0 to 999 ms randomized jitter
    return Duration(milliseconds: cappedExpMs + jitterMs);
  }

  /// Returns total active pending and retrying outbox records.
  Future<int> getOutboxDepth() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) as count FROM local_outbox WHERE status IN ('PENDING', 'RETRYING')",
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  /// Returns multi-status aggregate counts across outbox states.
  Future<Map<String, int>> getOutboxStats() async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT status, COUNT(*) as count 
      FROM local_outbox 
      GROUP BY status
    ''');

    final stats = <String, int>{
      'PENDING': 0,
      'RETRYING': 0,
      'DEAD_LETTER': 0,
      'FAILED': 0,
      'TOTAL': 0,
    };

    int total = 0;
    for (final row in res) {
      final status = row['status']?.toString() ?? 'PENDING';
      final count = (row['count'] as num?)?.toInt() ?? 0;
      stats[status] = count;
      total += count;
    }
    stats['TOTAL'] = total;
    return stats;
  }

  /// Atomically marks reconciled outbox tokens as synced (deleting confirmed entries).
  Future<void> markOutboxItemsSynced(List<String> tokenIds) async {
    if (tokenIds.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in tokenIds) {
      batch.delete(
        'local_outbox',
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Increments retry attempt with exponential jitter backoff, or moves to Dead-Letter Queue (DLQ) if attempt ceiling reached.
  Future<void> markOutboxAttemptFailed(
    String tokenId,
    String error, {
    int maxAttempts = 5,
  }) async {
    final db = await database;
    final now = DateTime.now().toUtc();

    final existing = await db.query('local_outbox', where: 'id = ?', whereArgs: [tokenId]);
    if (existing.isEmpty) return;

    final currentAttempts = (existing.first['attempts'] as num?)?.toInt() ?? 0;
    final nextAttempt = currentAttempts + 1;

    if (nextAttempt >= maxAttempts) {
      // Automatic Dead-Letter Queue (DLQ) Quarantine (prevents Head-of-Line blocking)
      await db.update(
        'local_outbox',
        {
          'status': 'DEAD_LETTER',
          'attempts': nextAttempt,
          'last_error': error,
          'reason': 'Exceeded maximum retry attempts ($maxAttempts)',
          'quarantined_at': now.toIso8601String(),
          'next_retry_at': null,
        },
        where: 'id = ?',
        whereArgs: [tokenId],
      );
    } else {
      final backoff = calculateBackoffWithJitter(nextAttempt);
      final nextRetryAt = now.add(backoff).toIso8601String();
      await db.update(
        'local_outbox',
        {
          'status': 'RETRYING',
          'attempts': nextAttempt,
          'last_error': error,
          'last_attempt_at': now.toIso8601String(),
          'next_retry_at': nextRetryAt,
        },
        where: 'id = ?',
        whereArgs: [tokenId],
      );
    }
  }

  /// Immediately quarantines an unrecoverable token (e.g. invalid cryptographic signature, terminal rejection)
  /// directly into the Dead-Letter Queue without burning retries, keeping healthy queue items unblocked.
  Future<void> quarantineDirectlyToDeadLetter(String tokenId, String errorReason) async {
    final db = await database;
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'local_outbox',
      {
        'status': 'DEAD_LETTER',
        'last_error': errorReason,
        'reason': errorReason,
        'quarantined_at': nowIso,
        'next_retry_at': null,
      },
      where: 'id = ?',
      whereArgs: [tokenId],
    );
  }

  /// Retrieves quarantined tokens from Dead-Letter Queue for audit and manual resolution.
  Future<List<Map<String, dynamic>>> getDeadLetterTokens({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'local_outbox',
      where: 'status = ?',
      whereArgs: ['DEAD_LETTER'],
      orderBy: 'quarantined_at DESC, created_at DESC',
      limit: limit,
    );
  }

  /// Re-queues a quarantined Dead-Letter Queue token back into PENDING state for retry.
  Future<bool> requeueDeadLetterToken(String tokenId) async {
    final db = await database;
    final rows = await db.update(
      'local_outbox',
      {
        'status': 'PENDING',
        'attempts': 0,
        'last_error': null,
        'next_retry_at': null,
        'quarantined_at': null,
      },
      where: 'id = ? AND status = ?',
      whereArgs: [tokenId, 'DEAD_LETTER'],
    );
    return rows > 0;
  }

  // --- Phase 4: AI Anomaly Heuristics & Citizen Grievance Storage ---
  Future<void> recordAiHeuristic({
    required String tokenId,
    required double riskScore,
    required String riskLevel,
    required List<String> flags,
    required String recommendedAction,
  }) async {
    final db = await database;
    await db.insert(
      'edge_ai_heuristics',
      {
        'token_id': tokenId,
        'risk_score': riskScore,
        'risk_level': riskLevel,
        'heuristic_flags': jsonEncode(flags),
        'recommended_action': recommendedAction,
        'analyzed_at': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getAiHeuristic(String tokenId) async {
    final db = await database;
    final res = await db.query(
      'edge_ai_heuristics',
      where: 'token_id = ?',
      whereArgs: [tokenId],
    );
    if (res.isEmpty) return null;
    final item = Map<String, dynamic>.from(res.first);
    if (item['heuristic_flags'] != null) {
      try {
        item['flags'] = jsonDecode(item['heuristic_flags'].toString());
      } catch (_) {
        item['flags'] = [];
      }
    }
    return item;
  }

  Future<void> recordGrievance({
    required String id,
    required String cardId,
    String? beneficiaryName,
    required String category,
    required String transcript,
    required String language,
    required String audioTimestamp,
  }) async {
    final db = await database;
    await db.insert(
      'local_grievances',
      {
        'id': id,
        'card_id': cardId,
        'beneficiary_name': beneficiaryName,
        'category': category,
        'transcript': transcript,
        'language': language,
        'audio_timestamp': audioTimestamp,
        'status': 'REGISTERED',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getLocalGrievances({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'local_grievances',
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('local_cards');
    await db.delete('local_lots');
    await db.delete('local_outbox');
    await db.delete('local_transactions');
    await db.delete('edge_ai_heuristics');
    await db.delete('local_grievances');
    await db.update('local_meta', {'value': 1000}, where: 'key = ?', whereArgs: ['counter']);
  }
}
