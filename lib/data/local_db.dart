// ration_safe_mobile_app/lib/data/local_db.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/beneficiary.dart';
import '../models/grain_lot.dart';
import '../models/provisional_token.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

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
      version: 1,
      onCreate: _createDB,
    );
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

    // 3. Outbox for Signed Provisional Tokens
    await db.execute('''
      CREATE TABLE local_outbox (
        id TEXT PRIMARY KEY,
        txn_id TEXT NOT NULL,
        token_json TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        attempts INTEGER NOT NULL DEFAULT 0,
        reason TEXT,
        created_at TEXT NOT NULL
      )
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

  // --- Cards Cache ---
  Future<void> cacheCards(List<CardBeneficiary> cards) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('local_cards');
      final batch = txn.batch();
      for (final card in cards) {
        batch.insert(
          'local_cards',
          card.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<CardBeneficiary>> getLocalCards() async {
    final db = await database;
    final res = await db.query('local_cards');
    return res.map((m) => CardBeneficiary.fromJson(m)).toList();
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
    await db.transaction((txn) async {
      await txn.delete('local_lots');
      final batch = txn.batch();
      for (final lot in lots) {
        batch.insert(
          'local_lots',
          lot.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
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

  Future<List<SignedProvisionalToken>> getPendingOutboxTokens() async {
    final db = await database;
    final res = await db.query(
      'local_outbox',
      where: 'status = ?',
      whereArgs: ['PENDING'],
      limit: 100,
    );

    return res.map((row) {
      final json = jsonDecode(row['token_json'] as String);
      return SignedProvisionalToken.fromJson(json);
    }).toList();
  }

  Future<int> getOutboxDepth() async {
    final db = await database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM local_outbox WHERE status = ?',
      ['PENDING'],
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<void> markOutboxItemsSynced(List<String> tokenIds) async {
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

  Future<void> markOutboxItemFailed(String tokenId, String reason) async {
    final db = await database;
    await db.update(
      'local_outbox',
      {
        'status': 'FAILED',
        'reason': reason,
      },
      where: 'id = ?',
      whereArgs: [tokenId],
    );
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('local_cards');
    await db.delete('local_lots');
    await db.delete('local_outbox');
    await db.delete('local_transactions');
    await db.update('local_meta', {'value': 1000}, where: 'key = ?', whereArgs: ['counter']);
  }
}
