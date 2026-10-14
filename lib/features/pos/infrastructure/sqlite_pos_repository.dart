import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as paths;
import 'package:sqflite/sqflite.dart';
import '../domain/pos_engine.dart';
import '../domain/pos_repository.dart';

class LegacyImport {
  const LegacyImport(this.state, this.archive);
  final PosState state;
  final Map<String, dynamic> archive;
}

const _collections = <String, String>{
  'products': 'pos_products', 'cart': 'pos_cart', 'sales': 'pos_sales',
  'movements': 'pos_cash_movements', 'sessions': 'pos_sessions',
  'stockMovements': 'pos_stock_movements', 'customers': 'pos_customers',
  'repayments': 'pos_repayments',
};

/// Records are stored separately and updated by difference in a single SQLite
/// transaction. Domain payloads retain original receipt data and integer values.
class SqlitePosRepository implements PosRepository {
  SqlitePosRepository._(this._database, this.engine);
  final Database _database;
  final PosEngine engine;
  Database get databaseForTesting => _database;

  static Future<SqlitePosRepository> open({
    String? path,
    DatabaseFactory? factory,
    PosEngine? engine,
    Future<LegacyImport?> Function()? legacyLoader,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? paths.join(await dbFactory.getDatabasesPath(), 'zivlo_peru_v2.db');
    final db = await dbFactory.openDatabase(dbPath, options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.execute('PRAGMA synchronous = FULL');
      },
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE pos_metadata (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL)');
        for (final table in _collections.values) {
          await db.execute('CREATE TABLE $table (id TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL)');
        }
        await db.execute('CREATE TABLE pos_archives (name TEXT PRIMARY KEY NOT NULL, payload TEXT NOT NULL)');
      },
    ));
    final repository = SqlitePosRepository._(db, engine ?? PosEngine());
    try {
      final initialized = await db.query('pos_metadata', limit: 1);
      if (initialized.isEmpty) {
        // Read the old files before writing anything. A bad legacy import must
        // leave them intact and must not silently replace them with an empty shop.
        final imported = await legacyLoader?.call();
        await db.transaction((tx) async {
          if ((await tx.query('pos_metadata', limit: 1)).isNotEmpty) return;
          await repository._write(tx, null, imported?.state ?? PosState.empty());
          if (imported != null) await tx.insert('pos_archives', {
            'name': 'original_hive', 'payload': jsonEncode(imported.archive),
          });
        });
      }
      await repository.load();
      return repository;
    } catch (_) { await db.close(); rethrow; }
  }

  Future<PosState> _read(DatabaseExecutor tx) async {
    final rows = await tx.query('pos_metadata', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) throw const PosException('La base local no está inicializada.');
    final data = Map<String, dynamic>.from(jsonDecode(rows.single['payload'] as String) as Map);
    for (final entry in _collections.entries) {
      final records = await tx.query(entry.value, orderBy: 'rowid');
      data[entry.key] = records.map((r) => Map<String, dynamic>.from(jsonDecode(r['payload'] as String) as Map)).toList();
    }
    return PosState.fromJson(data);
  }

  Future<void> _write(DatabaseExecutor tx, PosState? previous, PosState next) async {
    final current = next.toJson();
    final old = previous?.toJson();
    for (final entry in _collections.entries) {
      String key(Map row) => (row[entry.key == 'cart' ? 'productId' : 'id']) as String;
      final oldRows = {for (final row in (old?[entry.key] as List? ?? [])) key(row as Map): jsonEncode(row)};
      final newRows = {for (final row in current[entry.key] as List) key(row as Map): jsonEncode(row)};
      for (final id in oldRows.keys.where((id) => !newRows.containsKey(id))) {
        await tx.delete(entry.value, where: 'id = ?', whereArgs: [id]);
      }
      for (final row in newRows.entries) {
        if (!oldRows.containsKey(row.key)) {
          await tx.insert(entry.value, {'id': row.key, 'payload': row.value});
        } else if (oldRows[row.key] != row.value) {
          await tx.update(entry.value, {'payload': row.value}, where: 'id = ?', whereArgs: [row.key]);
        }
      }
      current.remove(entry.key);
    }
    if (previous == null) {
      await tx.insert('pos_metadata', {'id': 1, 'payload': jsonEncode(current)});
    } else {
      await tx.update('pos_metadata', {'payload': jsonEncode(current)}, where: 'id = ?', whereArgs: [1]);
    }
  }

  @override
  Future<PosState> load() => _database.transaction((tx) => _read(tx));

  @override
  Future<PosState> dispatch(Map<String, dynamic> action, {required int expectedRevision}) => _database.transaction((tx) async {
    final current = await _read(tx);
    _checkRevision(current, expectedRevision);
    final next = engine.dispatch(current, action);
    await _write(tx, current, next);
    return next;
  });

  void _checkRevision(PosState state, int expected) {
    if (state.revision != expected) throw const PosException('Los datos cambiaron. Revisa la información actualizada y vuelve a intentar.');
  }

  Future<Map<String, dynamic>?> _archive(DatabaseExecutor tx, String name) async {
    final rows = await tx.query('pos_archives', where: 'name = ?', whereArgs: [name]);
    return rows.isEmpty ? null : Map<String, dynamic>.from(jsonDecode(rows.single['payload'] as String) as Map);
  }

  Map<String, dynamic> _envelope(PosState state, Map<String, dynamic>? legacy) {
    final payload = state.toJson();
    return {
      'format': 'zivlo-peru-backup', 'formatVersion': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'state': payload,
      // Detects accidental corruption; not a signature or authentication proof.
      'sha256': sha256.convert(utf8.encode(jsonEncode(payload))).toString(),
      if (legacy != null) 'originalHive': legacy,
    };
  }

  @override
  Future<String> exportBackup() => _database.transaction((tx) async => jsonEncode(_envelope(await _read(tx), await _archive(tx, 'original_hive'))));

  @override
  Future<String?> exportRecoveryBackup() => _database.transaction((tx) async {
    final archive = await _archive(tx, 'before_restore');
    return archive == null ? null : jsonEncode(archive);
  });

  @override
  Future<PosState> restoreBackup(String json, {required int expectedRevision}) async {
    if (utf8.encode(json).length > 20 * 1024 * 1024) throw const PosException('La copia supera el límite de 20 MB.');
    Map<String, dynamic> payload;
    Map<String, dynamic>? legacy;
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(json) as Map);
      if (decoded['format'] == 'zivlo-peru-backup') {
        if (decoded['formatVersion'] != 1) throw const PosException('Formato de copia no compatible.');
        payload = Map<String, dynamic>.from(decoded['state'] as Map);
        final digest = sha256.convert(utf8.encode(jsonEncode(payload))).toString();
        if (decoded['sha256'] != digest) throw const PosException('La copia está dañada o fue modificada.');
        if (decoded['originalHive'] != null) legacy = Map<String, dynamic>.from(decoded['originalHive'] as Map);
      } else {
        payload = decoded; // A raw pilot v1 export or a validated v2 snapshot.
      }
      PosState.fromJson(payload);
    } on PosException { rethrow; } catch (_) { throw const PosException('La copia no contiene datos válidos de Zivlo.'); }
    return _database.transaction((tx) async {
      final current = await _read(tx);
      _checkRevision(current, expectedRevision);
      await tx.insert('pos_archives', {
        'name': 'before_restore',
        'payload': jsonEncode(_envelope(current, await _archive(tx, 'original_hive'))),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      payload['revision'] = current.revision + 1;
      final next = PosState.fromJson(payload);
      await _write(tx, current, next);
      if (legacy != null) await tx.insert('pos_archives', {
        'name': 'original_hive', 'payload': jsonEncode(legacy),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      return next;
    });
  }

  @override
  Future<void> close() => _database.close();
}
