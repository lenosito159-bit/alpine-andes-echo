import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zivlo/features/pos/domain/pos_engine.dart';
import 'package:zivlo/features/pos/infrastructure/sqlite_pos_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late SqlitePosRepository repository;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('zivlo-sqlite-test-');
    repository = await SqlitePosRepository.open(path: '${directory.path}/shop.db', factory: databaseFactoryFfi);
  });
  tearDown(() async { await repository.close(); await directory.delete(recursive: true); });
  Future<PosState> command(Map<String, dynamic> action) async {
    final current = await repository.load();
    return repository.dispatch(action, expectedRevision: current.revision);
  }
  Future<PosState> ready() async {
    await command({'type': 'load-demo'});
    await command({'type': 'open-session', 'opening': 10000});
    return command({'type': 'cart-add', 'productId': 'product-2'});
  }

  test('cart and cash survive closing and reopening the real database file', () async {
    final before = await ready();
    await repository.close();
    repository = await SqlitePosRepository.open(path: '${directory.path}/shop.db', factory: databaseFactoryFfi);
    final after = await repository.load();
    expect(after.toJson(), before.toJson()); expect(after.total, 950);
  });
  test('failed durable sale insertion rolls back stock, cart and every ledger', () async {
    final before = await ready();
    await repository.databaseForTesting.execute("CREATE TRIGGER fail_sale BEFORE INSERT ON pos_sales BEGIN SELECT RAISE(ABORT, 'simulated disk write failure'); END");
    await expectLater(repository.dispatch({'type': 'checkout', 'cartKey': before.cartKey, 'payments': [{'method': 'cash', 'amount': 1000}]}, expectedRevision: before.revision), throwsA(anything));
    expect((await repository.load()).toJson(), before.toJson());
    await repository.databaseForTesting.execute('DROP TRIGGER fail_sale');
    final sale = await repository.dispatch({'type': 'checkout', 'cartKey': before.cartKey, 'payments': [{'method': 'cash', 'amount': 1000}]}, expectedRevision: before.revision);
    expect(sale.sales, hasLength(1)); expect(sale.cart, isEmpty);
  });
  test('concurrent checkout calls with the same revision commit exactly one sale', () async {
    final before = await ready();
    Future<bool> attempt() async {
      try { await repository.dispatch({'type': 'checkout', 'cartKey': before.cartKey, 'payments': [{'method': 'cash', 'amount': 950}]}, expectedRevision: before.revision); return true; }
      on PosException { return false; }
    }
    final results = await Future.wait([attempt(), attempt()]);
    expect(results.where((success) => success), hasLength(1));
    expect((await repository.load()).sales, hasLength(1));
  });
  test('backup restores all entities and preserves a recoverable previous state', () async {
    await ready(); final before = await repository.load(); final backup = await repository.exportBackup();
    await command({'type': 'cart-clear'});
    final current = await repository.load();
    final restored = await repository.restoreBackup(backup, expectedRevision: current.revision);
    expect(restored.cart, before.cart); expect(restored.revision, current.revision + 1);
    final recovery = jsonDecode((await repository.exportRecoveryBackup())!) as Map;
    expect((recovery['state'] as Map)['cart'], isEmpty);
  });
  test('corrupted backup is rejected before any data or recovery point changes', () async {
    final before = await ready();
    final corrupt = jsonDecode(await repository.exportBackup()) as Map<String, dynamic>;
    (corrupt['state'] as Map)['settings']['storeName'] = 'Modified';
    await expectLater(repository.restoreBackup(jsonEncode(corrupt), expectedRevision: before.revision), throwsA(isA<PosException>()));
    expect((await repository.load()).toJson(), before.toJson());
    expect(await repository.exportRecoveryBackup(), isNull);
  });
  test('restore failure is atomic, including its internal recovery copy', () async {
    final before = await ready();
    final alternate = PosState.demo().toJson(); (alternate['settings'] as Map)['storeName'] = 'Another shop';
    await repository.databaseForTesting.execute("CREATE TRIGGER fail_metadata BEFORE UPDATE ON pos_metadata BEGIN SELECT RAISE(ABORT, 'simulated metadata write failure'); END");
    await expectLater(repository.restoreBackup(jsonEncode(alternate), expectedRevision: before.revision), throwsA(anything));
    expect((await repository.load()).toJson(), before.toJson());
    expect(await repository.exportRecoveryBackup(), isNull);
  });
  test('legacy loader runs only on first initialization and retains its archive', () async {
    await repository.close();
    var calls = 0;
    Future<LegacyImport?> loader() async { calls++; return LegacyImport(PosState.demo(), {'products': [], 'sales': [], 'marker': 'original'}); }
    repository = await SqlitePosRepository.open(path: '${directory.path}/legacy.db', factory: databaseFactoryFfi, legacyLoader: loader);
    expect(calls, 1); await repository.close();
    repository = await SqlitePosRepository.open(path: '${directory.path}/legacy.db', factory: databaseFactoryFfi, legacyLoader: loader);
    expect(calls, 1);
    final backup = jsonDecode(await repository.exportBackup()) as Map;
    expect(backup['originalHive']['marker'], 'original');
  });
}
