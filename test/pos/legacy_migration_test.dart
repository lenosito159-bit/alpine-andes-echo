import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zivlo/features/catalog/infrastructure/models/product_hive_model.dart';
import 'package:zivlo/features/checkout/infrastructure/models/sale_hive_model.dart';
import 'package:zivlo/features/checkout/infrastructure/models/sale_item_hive_model.dart';
import 'package:zivlo/features/pos/domain/pos_engine.dart';
import 'package:zivlo/features/pos/infrastructure/legacy_hive_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ProductHiveModel product() => ProductHiveModel()..id = 'legacy-oil'..name = 'Aceite'..price = 9.5..barcode = 'OLD-001'..category = 'Abarrotes'..stock = 3..createdAt = DateTime.utc(2026);
  SaleHiveModel sale() {
    final item = SaleItemHiveModel()..id = 'item-1'..productId = 'legacy-oil'..productName = 'Aceite original'..barcode = 'OLD-001'..quantity = 1..unitPrice = 9.5..subtotal = 9.5;
    return SaleHiveModel()..id = 'sale-1'..items = [item]..subtotal = 9.5..discount = 1..total = 8.5..paymentMethodIndex = 2..amountReceived = 2..change = null..createdAt = DateTime.utc(2026, 1, 2);
  }
  test('migration preserves IDs, current stock, discounts and original doubles', () {
    final migrated = LegacyHiveImporter.convert([product()], [sale()]);
    expect(migrated.state.products.single['id'], 'legacy-oil');
    expect(migrated.state.products.single['stock'], 3000);
    expect(migrated.state.sales.single['total'], 850);
    expect(migrated.state.sales.single['discount'], 100);
    expect(migrated.state.sales.single['paymentsComplete'], isFalse);
    expect(migrated.state.sales.single['payments'], isEmpty);
    expect(migrated.state.movements, isEmpty);
    expect((migrated.archive['sales'] as List).single['amountReceived'], 2.0);
    final encoded = jsonEncode(migrated.archive); expect(encoded, contains('Aceite original'));
  });
  test('invalid historical stock fails without modifying the source models', () {
    final p = product()..stock = -1;
    expect(() => LegacyHiveImporter.convert([p], [sale()]), throwsA(isA<PosException>()));
    expect(p.stock, -1); expect(p.price, 9.5);
  });
  test('historical zero-price products are retained and archived for correction', () {
    final migrated = LegacyHiveImporter.convert([product()..price = 0], [sale()]);
    expect(migrated.state.products.single['price'], 0);
    expect(migrated.state.products.single['active'], isFalse);
    expect(migrated.state.products.single['stock'], 3000);
  });
  test('original Hive files remain readable and unchanged after importing', () async {
    final directory = await Directory.systemTemp.createTemp('zivlo-hive-import-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ProductHiveModelAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(SaleItemHiveModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(SaleHiveModelAdapter());
    final products = await Hive.openBox<ProductHiveModel>('products');
    final sales = await Hive.openBox<SaleHiveModel>('sales');
    await products.put('legacy-oil', product()); await sales.put('sale-1', sale());
    await products.close(); await sales.close();
    final original = await File('${directory.path}/products.hive').readAsBytes();
    final imported = await LegacyHiveImporter.read(directory: directory.path);
    expect(imported!.state.sales.single['total'], 850);
    expect(await File('${directory.path}/products.hive').readAsBytes(), original);
    final reopened = await Hive.openBox<ProductHiveModel>('products');
    expect(reopened.get('legacy-oil')!.price, 9.5);
    await reopened.close(); await directory.delete(recursive: true);
  });
}
