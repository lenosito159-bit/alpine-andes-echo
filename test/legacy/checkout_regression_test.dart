import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zivlo/core/error/failures.dart';
import 'package:zivlo/features/catalog/domain/entities/product.dart';
import 'package:zivlo/features/checkout/application/usecases/process_payment.dart';
import 'package:zivlo/features/checkout/domain/entities/sale.dart';
import 'package:zivlo/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:zivlo/features/checkout/domain/value_objects/payment.dart';
import 'package:zivlo/features/checkout/domain/value_objects/payment_method.dart';
import 'package:zivlo/features/checkout/infrastructure/repositories/in_memory_cart_repository.dart';

class SalesMock extends Mock implements ICheckoutRepository {}
class SaleFake extends Fake implements Sale {}
class FailingTotalsCart extends InMemoryCartRepository {
  @override
  Future<Either<Failure, double>> getTotal() async =>
      left(const CartOperationFailure('get_total', message: 'Lectura fallida'));
}

void main() {
  final product = Product(id: 'oil', name: 'Aceite', price: 9.5, stock: 4, createdAt: DateTime(2026));
  setUpAll(() => registerFallbackValue(SaleFake()));

  test('rejects zero quantities and cumulative stock overflow without mutation', () async {
    final cart = InMemoryCartRepository();
    expect((await cart.addProduct(product, quantity: 0)).isLeft(), isTrue);
    expect((await cart.addProduct(product, quantity: 3)).isRight(), isTrue);
    expect((await cart.addProduct(product, quantity: 2)).isLeft(), isTrue);
    expect((await cart.getItems()).getOrElse(() => []).single.quantity, 3);
  });

  test('refuses a stale screen total and retains the cart', () async {
    final cart = InMemoryCartRepository();
    await cart.addProduct(product);
    final sales = SalesMock();
    final result = await ProcessPayment(checkoutRepository: sales, cartRepository: cart)
        .execute(Payment.cash(totalAmount: 1, amountReceived: 1));
    expect(result.isLeft(), isTrue);
    verifyNever(() => sales.createSale(any()));
    expect((await cart.getItems()).getOrElse(() => []), hasLength(1));
  });

  test('propagates a total-read failure instead of recording a zero sale', () async {
    final cart = FailingTotalsCart();
    await cart.addProduct(product);
    final sales = SalesMock();
    final result = await ProcessPayment(checkoutRepository: sales, cartRepository: cart)
        .execute(Payment.cash(totalAmount: 9.5, amountReceived: 10));
    expect(result.getLeft().toNullable()?.message, 'Lectura fallida');
    verifyNever(() => sales.createSale(any()));
  });

  test('recalculates change and guards simultaneous checkout calls', () async {
    final cart = InMemoryCartRepository();
    await cart.addProduct(product);
    final sales = SalesMock();
    final saved = Completer<Either<Failure, Sale>>();
    final started = Completer<Sale>();
    when(() => sales.createSale(any())).thenAnswer((call) {
      started.complete(call.positionalArguments.single as Sale);
      return saved.future;
    });
    final process = ProcessPayment(checkoutRepository: sales, cartRepository: cart);
    const payment = Payment(method: PaymentMethod.cash, totalAmount: 9.5,
        amountReceived: 20, change: 999);
    final first = process.execute(payment);
    final sale = await started.future;
    expect((await process.execute(payment)).isLeft(), isTrue);
    expect(sale.change, 10.5);
    saved.complete(right(sale));
    expect((await first).isRight(), isTrue);
    verify(() => sales.createSale(any())).called(1);
    expect((await cart.getItems()).getOrElse(() => []), isEmpty);
  });

  test('keeps cart when durable sale storage fails', () async {
    final cart = InMemoryCartRepository();
    await cart.addProduct(product);
    final sales = SalesMock();
    when(() => sales.createSale(any())).thenAnswer((_) async => left(const SaleCreationFailure()));
    final result = await ProcessPayment(checkoutRepository: sales, cartRepository: cart)
        .execute(Payment.cash(totalAmount: 9.5, amountReceived: 20));
    expect(result.isLeft(), isTrue);
    expect((await cart.getItems()).getOrElse(() => []), hasLength(1));
  });
}
