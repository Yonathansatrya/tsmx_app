import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class LocalAppDatabase {
  LocalAppDatabase._();

  static final LocalAppDatabase instance = LocalAppDatabase._();

  static const _databaseName = 'tmsx_app.db';
  static const _databaseVersion = 1;
  static const _cacheTable = 'app_kv_cache';

  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) return existing;

    final databasePath = await getDatabasesPath();
    final db = await openDatabase(
      path.join(databasePath, _databaseName),
      version: _databaseVersion,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE $_cacheTable (
            cache_key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL
          )
        ''');
        await database.execute(
          'CREATE INDEX idx_${_cacheTable}_expires_at '
          'ON $_cacheTable(expires_at)',
        );
      },
    );
    _database = db;
    return db;
  }

  Future<Map<String, dynamic>?> readJson(String key) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      _cacheTable,
      columns: const ['value', 'expires_at'],
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final expiresAt = (rows.first['expires_at'] as num?)?.toInt() ?? 0;
    if (expiresAt <= now) {
      await db.delete(_cacheTable, where: 'cache_key = ?', whereArgs: [key]);
      return null;
    }

    final raw = rows.first['value']?.toString() ?? '';
    if (raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  Future<void> writeJson(
    String key,
    Map<String, dynamic> value, {
    required Duration ttl,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    await db.insert(_cacheTable, {
      'cache_key': key,
      'value': jsonEncode(value),
      'updated_at': now.millisecondsSinceEpoch,
      'expires_at': now.add(ttl).millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteByPrefix(String prefix) async {
    final db = await _db;
    await db.delete(
      _cacheTable,
      where: 'cache_key LIKE ?',
      whereArgs: ['$prefix%'],
    );
  }

  Future<void> delete(String key) async {
    final db = await _db;
    await db.delete(_cacheTable, where: 'cache_key = ?', whereArgs: [key]);
  }

  Future<void> clear() async {
    final db = await _db;
    await db.delete(_cacheTable);
  }
}
