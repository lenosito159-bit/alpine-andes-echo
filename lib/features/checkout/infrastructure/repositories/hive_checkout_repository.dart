import 'package:fpdart/fpdart.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:zivlo/core/error/failures.dart';
import 'package:zivlo/features/checkout/domain/entities/sale.dart';
import 'package:zivlo/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:zivlo/features/checkout/infrastructure/models/sale_hive_model.dart';

/// Hive Implementation of ICheckoutRepository
/// 
/// Stores sales in a Hive box for offline-first persistence
/// 
/// Box name: 'sales'
/// Key: Sale ID (String)
/// Value: SaleHiveModel
class HiveCheckoutRepository implements ICheckoutRepository {
  static const String _boxName = 'sales';
  late Box<SaleHiveModel> _box;

  /// Opens the Hive box for sales
  /// Must be called before using the repository
  Future<void> initialize() async {
    if (Hive.isBoxOpen(_boxName)) {
      _box = Hive.box<SaleHiveModel>(_boxName);
    } else {
      _box = await Hive.openBox<SaleHiveModel>(_boxName);
    }
  }

  @override
  Future<Either<Failure, Sale>> createSale(Sale sale) async {
    try {
      final hiveModel = SaleHiveModel.fromEntity(sale);
      await _box.put(sale.id, hiveModel);
      return right(sale);
    } catch (e) {
      return left(SaleCreationFailure(
        message: 'Failed to save sale to Hive: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, Sale?>> getSaleById(String id) async {
    try {
      final hiveModel = _box.get(id);
      if (hiveModel == null) {
        return right(null);
      }
      return right(hiveModel.toEntity());
    } catch (e) {
      return left(SaleCreationFailure(
        message: 'Failed to get sale from Hive: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, List<Sale>>> getAllSales({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final sales = <Sale>[];

      for (final key in _box.keys) {
        final hiveModel = _box.get(key);
        if (hiveModel != null) {
          final sale = hiveModel.toEntity();

          // Filter by date range if provided
          if (startDate != null && sale.createdAt.isBefore(startDate)) {
            continue;
          }
          if (endDate != null && sale.createdAt.isAfter(endDate)) {
            continue;
          }

          sales.add(sale);
        }
      }

      // Sort by creation date (newest first)
      sales.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return right(sales);
    } catch (e) {
      return left(SaleCreationFailure(
        message: 'Failed to get sales from Hive: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, List<Sale>>> getTodaysSales() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      return getAllSales(startDate: startOfDay, endDate: endOfDay);
    } catch (e) {
      return left(SaleCreationFailure(
        message: 'Failed to get today\'s sales: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, int>> getSalesCount() async {
    try {
      return right(_box.length);
    } catch (e) {
      return left(SaleCreationFailure(
        message: 'Failed to get sales count: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, double>> getTotalRevenue() async {
    try {
      final salesResult = await getAllSales();
      return salesResult.fold(
        (failure) => left(failure) as Either<Failure, double>,
        (sales) {
          final total = sales.fold<double>(
            0.0,
            (sum, sale) => sum + sale.total,
          );
          return right(total);
        },
      );
    } catch (e) {
      return left(SaleCreationFailure(
        message: 'Failed to calculate total revenue: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, double>> getTodaysRevenue() async {
    try {
      final salesResult = await getTodaysSales();
      return salesResult.fold(
        (failure) => left(failure) as Either<Failure, double>,
        (sales) {
          final total = sales.fold<double>(
            0.0,
            (sum, sale) => sum + sale.total,
          );
          return right(total);
        },
      );
    } catch (e) {
      return left(SaleCreationFailure(
        message: 'Failed to calculate today\'s revenue: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteSale(String id) async {
    try {
      await _box.delete(id);
      return right(unit);
    } catch (e) {
      return left(SaleCreationFailure(
        message: 'Failed to delete sale: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  @override
  Future<Either<Failure, List<Sale>>> getSalesByPaymentMethod(
    String paymentMethod,
  ) async {
    try {
      final allSalesResult = await getAllSales();
      return allSalesResult.fold(
        (failure) => left(failure) as Either<Failure, List<Sale>>,
        (sales) {
          final filteredSales = sales.where((sale) {
            return sale.paymentMethod.name.toLowerCase() == 
                paymentMethod.toLowerCase();
          }).toList();
          return right(filteredSales);
        },
      );
    } catch (e) {
      return left(SaleCreationFailure(
        message: 'Failed to get sales by payment method: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }

  /// Closes the Hive box
  /// Should be called when the repository is no longer needed
  Future<void> dispose() async {
    await _box.close();
  }
}
