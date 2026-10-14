import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';
import 'validate_payment.dart';

import 'package:zivlo/core/error/failures.dart';
import 'package:zivlo/features/checkout/domain/entities/sale.dart';
import 'package:zivlo/features/checkout/domain/entities/sale_item.dart';
import 'package:zivlo/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:zivlo/features/checkout/domain/repositories/cart_repository.dart';
import 'package:zivlo/features/checkout/domain/value_objects/payment.dart';
import 'package:zivlo/features/checkout/domain/value_objects/payment_method.dart';
/// Use Case: Process Payment
/// 
/// Handles the complete payment process:
/// 1. Validates payment amount >= total
/// 2. Creates Sale entity with all items
/// 3. Saves sale to repository
/// 4. Clears cart
/// 5. Returns Either<Failure, Sale>
/// 
/// This is the main use case for completing a transaction
class ProcessPayment {
  final ICheckoutRepository checkoutRepository;
  final ICartRepository cartRepository;
  final Uuid uuid;

  bool _processing = false;

  ProcessPayment({
    required this.checkoutRepository,
    required this.cartRepository,
    Uuid? uuid,
  }) : uuid = uuid ?? const Uuid();

  /// Executes the payment process
  /// 
  /// [payment] - Payment information with method and amounts
  /// 
  /// Returns [Sale] on success, [Failure] on error
  Future<Either<Failure, Sale>> execute(Payment payment) async {
    if (_processing) {
      return left(const PaymentValidationFailure('Ya hay un cobro en curso'));
    }
    _processing = true;
    try {
      // Get cart items
      final cartItemsResult = await cartRepository.getItems();
      if (cartItemsResult.isLeft()) {
        return left(cartItemsResult.getLeft().toNullable()!);
      }
      final cartItems = cartItemsResult.getOrElse(() => []);

      if (cartItems.isEmpty) {
        return left(const CartOperationFailure('empty_cart', 
          message: 'Cannot process payment with empty cart'));
      }

      // Get cart totals
      final subtotalResult = await cartRepository.getSubtotal();
      final discountResult = await cartRepository.getDiscount();
      final totalResult = await cartRepository.getTotal();

      for (final result in [subtotalResult, discountResult, totalResult]) {
        if (result.isLeft()) return left(result.getLeft().toNullable()!);
      }
      final subtotal = subtotalResult.getOrElse(() => throw StateError('Missing subtotal'));
      final discount = discountResult.getOrElse(() => throw StateError('Missing discount'));
      final total = totalResult.getOrElse(() => throw StateError('Missing total'));
      if (![subtotal, discount, total].every((value) => value.isFinite && value >= 0)) {
        return left(const PaymentValidationFailure('El carrito contiene importes inválidos'));
      }
      final validation = _validatePayment(payment, total);
      if (validation.isLeft()) return left(validation.getLeft().toNullable()!);

      // Create sale items from cart items
      final saleItems = cartItems.map((cartItem) {
        return SaleItem(
          id: uuid.v4(),
          productId: cartItem.product.id,
          productName: cartItem.product.name,
          barcode: cartItem.product.barcode,
          quantity: cartItem.quantity,
          unitPrice: cartItem.product.price,
          subtotal: cartItem.subtotal,
        );
      }).toList();

      // Calculate change for cash/mixed payments
      double? change;
      if (payment.method == PaymentMethod.cash || 
          payment.method == PaymentMethod.mixed) {
        change = ((payment.totalReceived * 100).round() - (total * 100).round()) / 100;
      }

      // Create Sale entity
      final sale = Sale(
        id: uuid.v4(),
        items: saleItems,
        subtotal: subtotal,
        discount: discount,
        total: total,
        paymentMethod: payment.method,
        amountReceived: payment.method == PaymentMethod.card ? null : payment.amountReceived,
        change: change,
        createdAt: DateTime.now(),
      );

      // Save sale to repository
      final saveResult = await checkoutRepository.createSale(sale);
      if (saveResult.isLeft()) {
        return saveResult;
      }

      // Clear cart
      final clearResult = await cartRepository.clear();
      if (clearResult.isLeft()) {
        // Sale was saved but cart couldn't be cleared
        // This is a recoverable error - log it but return the sale
        // The cart will be cleared on next app start or manually
      }

      // Return the created sale
      return right(sale);

    } catch (e) {
      return left(SaleCreationFailure(
        message: 'Failed to process payment: ${e.toString()}',
        exception: e is Exception ? e : Exception(e.toString()),
      ));
    } finally {
      _processing = false;
    }
  }

  /// Validates payment amount
  Either<Failure, Unit> _validatePayment(Payment payment, double cartTotal) {
    final amounts = [payment.totalAmount, payment.amountReceived, payment.cardAmount ?? 0];
    if (!amounts.every((value) => value.isFinite && value >= 0)) {
      return left(const PaymentValidationFailure('El pago contiene importes inválidos'));
    }
    final totalCents = (cartTotal * 100).round();
    if ((payment.totalAmount * 100).round() != totalCents) {
      return left(const PaymentValidationFailure('El total cambió. Revisa el carrito antes de cobrar'));
    }
    if ((payment.totalReceived * 100).round() < totalCents) {
      return left(const PaymentValidationFailure('El importe recibido es insuficiente'));
    }
    if (payment.method == PaymentMethod.cash && (payment.cardAmount ?? 0) != 0) {
      return left(const PaymentValidationFailure('Un pago en efectivo no admite importe de tarjeta'));
    }
    if (payment.method == PaymentMethod.card &&
        ((payment.cardAmount ?? 0) != 0 || (payment.amountReceived * 100).round() != totalCents)) {
      return left(const PaymentValidationFailure('El pago con tarjeta debe coincidir con el total'));
    }
    if (payment.method == PaymentMethod.mixed &&
        ((payment.cardAmount ?? 0) * 100).round() > totalCents) {
      return left(const PaymentValidationFailure('La parte de tarjeta no puede superar el total'));
    }
    return right(unit);
  }
}
