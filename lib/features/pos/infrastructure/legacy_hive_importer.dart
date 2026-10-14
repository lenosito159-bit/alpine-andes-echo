import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import '../../catalog/infrastructure/models/product_hive_model.dart';
import '../../checkout/infrastructure/models/sale_hive_model.dart';
import '../../checkout/infrastructure/models/sale_item_hive_model.dart';
import '../domain/pos_engine.dart';
import 'sqlite_pos_repository.dart';

/// Copies legacy financial records without deleting or clearing their files.
class LegacyHiveImporter {
  static Future<LegacyImport?> read({String? directory}) async {
    final home = directory ?? (await getApplicationDocumentsDirectory()).path;
    Hive.init(home);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ProductHiveModelAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(SaleItemHiveModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(SaleHiveModelAdapter());
    final hasProducts = await Hive.boxExists('products');
    final hasSales = await Hive.boxExists('sales');
    if (!hasProducts && !hasSales) return null;
    // Take byte-for-byte snapshots before opening Hive: its recovery/compaction
    // may touch an old file even when the application only intends to read it.
    final archiveDirectory = Directory('$home/zivlo_hive_archive');
    await archiveDirectory.create(recursive: true);
    for (final name in ['products', 'sales']) {
      final file = File('$home/$name.hive');
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes).toString();
      final archiveFile = File('${archiveDirectory.path}/${digest}_$name.hive');
      if (!await archiveFile.exists()) await archiveFile.writeAsBytes(bytes, flush: true);
      if (sha256.convert(await archiveFile.readAsBytes()).toString() != digest) {
        throw const PosException('No se pudo verificar la copia de los archivos históricos. No se inició la migración.');
      }
    }
    final productsOwned = hasProducts && !Hive.isBoxOpen('products');
    final salesOwned = hasSales && !Hive.isBoxOpen('sales');
    Box<ProductHiveModel>? products;
    Box<SaleHiveModel>? sales;
    try {
      if (hasProducts) products = productsOwned ? await Hive.openBox<ProductHiveModel>('products') : Hive.box<ProductHiveModel>('products');
      if (hasSales) sales = salesOwned ? await Hive.openBox<SaleHiveModel>('sales') : Hive.box<SaleHiveModel>('sales');
      return convert(products?.values.toList() ?? [], sales?.values.toList() ?? []);
    } finally {
      if (productsOwned) await products?.close();
      if (salesOwned) await sales?.close();
    }
  }

  /// Rounds only at the boundary with the old floating point storage format.
  static int _cents(double value) {
    if (!value.isFinite || value < 0 || value > 10000000) throw const PosException('Los importes históricos necesitan revisión. Tus archivos Hive se conservaron.');
    return (value * 100).round();
  }

  static LegacyImport convert(List<ProductHiveModel> products, List<SaleHiveModel> sales) {
    final data = PosState.empty().toJson();
    final archive = <String, dynamic>{
      'format': 'zivlo-original-hive', 'archivedAt': DateTime.now().toUtc().toIso8601String(),
      'products': products.map((p) => {
        'id': p.id, 'name': p.name, 'price': p.price, 'barcode': p.barcode,
        'category': p.category, 'stock': p.stock, 'createdAt': p.createdAt.toUtc().toIso8601String(),
      }).toList(),
      'sales': sales.map((s) => {
        'id': s.id, 'items': s.items.map((i) => i.toJson()).toList(),
        'subtotal': s.subtotal, 'discount': s.discount, 'total': s.total,
        'paymentMethodIndex': s.paymentMethodIndex, 'amountReceived': s.amountReceived,
        'change': s.change, 'createdAt': s.createdAt.toUtc().toIso8601String(),
      }).toList(),
    };
    data['products'] = products.map((p) => {
      'id': p.id, 'name': p.name, 'price': _cents(p.price),
      'barcode': p.barcode ?? '', 'category': (p.category?.trim().isNotEmpty ?? false) ? p.category! : 'Otros',
      'stock': p.stock * 1000, 'openingStock': p.stock * 1000,
      'unit': 'und', 'active': _cents(p.price) > 0, 'art': 'bag', 'legacy': true,
    }).toList();
    final ordered = [...sales]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    data['sales'] = ordered.asMap().entries.map((entry) {
      final s = entry.value;
      return {
        'id': s.id, 'number': entry.key + 1, 'at': s.createdAt.toUtc().toIso8601String(),
        'sessionId': 'legacy', 'store': data['settings'], 'total': _cents(s.total),
        'subtotal': _cents(s.subtotal), 'discount': _cents(s.discount),
        'credit': 0, 'change': s.change == null ? 0 : _cents(s.change!),
        'status': 'completed', 'legacy': true, 'paymentsComplete': false,
        'paymentMethodIndex': s.paymentMethodIndex,
        'historicalAmountReceived': s.amountReceived == null ? null : _cents(s.amountReceived!),
        // Mixed payment components were not stored. Never invent confirmation,
        // new debt, or cash movements for unreconstructible historical records.
        'payments': <dynamic>[],
        'lines': s.items.map((i) => {
          'id': i.id, 'productId': i.productId, 'name': i.productName,
          'barcode': i.barcode ?? '', 'quantity': i.quantity * 1000,
          'unit': 'und', 'price': _cents(i.unitPrice), 'total': _cents(i.subtotal),
        }).toList(),
      };
    }).toList();
    try { return LegacyImport(PosState.fromJson(data), archive); }
    on PosException catch (error) { throw PosException('No se migraron los datos históricos: ${error.message} Los archivos Hive originales se conservaron.'); }
  }
}
