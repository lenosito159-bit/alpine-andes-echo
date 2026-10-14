import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import 'package:zivlo/core/error/failures.dart';
import 'package:zivlo/features/checkout/domain/repositories/cart_repository.dart';
/// Checkout Summary DTO
/// Contains all the information needed to display checkout summary
class CheckoutSummary extends Equatable {
  final int itemCount;
  final int totalQuantity;
  final double subtotal;
  final double discount;
  final double total;

  const CheckoutSummary({
    required this.itemCount,
    required this.totalQuantity,
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  /// Returns formatted subtotal for display
  String get formattedSubtotal {
    return '\$${subtotal.toStringAsFixed(2)}';
  }

  /// Returns formatted discount for display
  String get formattedDiscount {
    if (discount <= 0) return 'Sin descuento';
    return '-\$${discount.toStringAsFixed(2)}';
  }

  /// Returns formatted total for display
  String get formattedTotal {
    return '\$${total.toStringAsFixed(2)}';
  }

  /// Returns items summary text
  String get itemsSummary {
    if (itemCount == 1) {
      return '$totalQuantity producto';
    }
    return '$itemCount productos ($totalQuantity unidades)';
  }

  @override
  List<Object?> get props => [
        itemCount,
        totalQuantity,
        subtotal,
        discount,
        total,
      ];

  @override
  String toString() {
    return 'CheckoutSummary(items: $itemCount, total: $total)';
  }
}

/// Use Case: Get Checkout Summary
/// 
/// Retrieves the current cart summary for checkout display
/// 
/// This use case aggregates cart data into a summary DTO
/// Used by the checkout page to display order summary
class GetCheckoutSummary {
  final ICartRepository cartRepository;

  const GetCheckoutSummary(this.cartRepository);

  /// Executes the use case
  /// 
  /// Returns [CheckoutSummary] on success, [Failure] on error
  Future<Either<Failure, CheckoutSummary>> execute() async {
    try {
      // Get cart items
      final itemsResult = await cartRepository.getItems();
      if (itemsResult.isLeft()) {
        return left(CartOperationFailure('get_items',
          message: 'Failed to get cart items for summary'));
      }
      final items = itemsResult.getOrElse((_) => []);

      // Get totals
      final subtotalResult = await cartRepository.getSubtotal();
      final discountResult = await cartRepository.getDiscount();
      final totalResult = await cartRepository.getTotal();

      final subtotal = subtotalResult.getOrElse((_) => 0.0);
      final discount = discountResult.getOrElse((_) => 0.0);
      final total = totalResult.getOrElse((_) => 0.0);

      // Calculate total quantity
      final totalQuantity = items.fold<int>(
        0,
        (sum, item) => sum + item.quantity,
      );

      // Create summary
      final summary = CheckoutSummary(
        itemCount: items.length,
        totalQuantity: totalQuantity,
        subtotal: subtotal,
        discount: discount,
        total: total,
      );

      return right(summary);

    } catch (e) {
      return left(CartOperationFailure('get_summary',
        message: 'Failed to get checkout summary: ${e.toString()}',
        exception: e as Exception?,
      ));
    }
  }
}
