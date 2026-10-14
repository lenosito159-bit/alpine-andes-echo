import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:zivlo/features/pos/domain/pos_engine.dart';

void main() {
  late PosEngine engine;
  setUp(() {
    var id = 0;
    engine = PosEngine(clock: () => DateTime.utc(2026, 10, 14, 15), id: () => 'test-${++id}');
  });
  PosState ready() {
    var s = engine.dispatch(PosState.demo(), {'type': 'open-session', 'opening': 10000});
    return engine.dispatch(s, {'type': 'cart-add', 'productId': 'product-2'});
  }
  PosState pay(PosState s, List<Map<String, dynamic>> payments, {bool confirmed = false, bool credit = false, String? customer}) => engine.dispatch(s, {'type': 'checkout', 'cartKey': s.cartKey, 'payments': payments, 'digitalConfirmed': confirmed, 'credit': credit, 'customerId': customer});
  int stock(PosState s) => s.products.firstWhere((p) => p['id'] == 'product-2')['stock'] as int;

  test('exact céntimos, comma parsing, and half-up line rounding', () {
    expect(parseAmount('0.10') + parseAmount('0,20'), 30);
    expect(parseAmount('0.250', decimals: 3), 250);
    expect(lineAmount(450, 250), 113);
    expect(lineAmount(1, 500), 1);
    for (final invalid in ['-1', 'NaN', 'Infinity', '1e3', '1.001', '', '2abc']) {
      expect(() => parseAmount(invalid), throwsA(isA<PosException>()));
    }
  });
  test('snapshot and nested entities are immutable', () {
    final s = ready();
    expect(() => s.products.first['stock'] = 0, throwsUnsupportedError);
    expect(() => s.cart.add({}), throwsUnsupportedError);
    final external = s.toJson(); (external['products'] as List).first['stock'] = 0;
    expect(s.products.first['stock'], 50000);
  });
  test('demo is opt-in and never overwrites an existing shop', () {
    final s = engine.dispatch(PosState.empty(), {'type': 'load-demo'});
    expect(s.products, hasLength(12));
    expect(() => engine.dispatch(s, {'type': 'load-demo'}), throwsA(isA<PosException>()));
  });
  test('cash checkout uses the cart total, saves receipt, stock and net cash', () {
    final before = ready();
    final s = pay(before, [{'method': 'cash', 'amount': 2000}]);
    expect(s.sales.single['total'], 950); expect(s.sales.single['change'], 1050);
    expect(stock(s), 17000); expect(stock(before), 18000);
    expect(s.cashBalance, 10950); expect(s.cart, isEmpty);
    expect(s.stockMovements.single['quantityDelta'], -1000);
  });
  test('insufficient and malformed payments have no side effects', () {
    final s = ready(); final before = jsonEncode(s.toJson());
    expect(() => pay(s, [{'method': 'cash', 'amount': 949}]), throwsA(isA<PosException>()));
    expect(() => pay(s, [{'method': 'cash', 'amount': -1}]), throwsA(isA<PosException>()));
    expect(() => pay(s, [{'method': 'cash', 'amount': 950.0}]), throwsA(isA<PosException>()));
    expect(jsonEncode(s.toJson()), before);
  });
  test('digital confirmation is required and never increases cash', () {
    final s = ready();
    for (final method in ['yape', 'plin', 'card']) {
      expect(() => pay(s, [{'method': method, 'amount': 950}]), throwsA(isA<PosException>()));
      final next = pay(s, [{'method': method, 'amount': 950}], confirmed: true);
      expect(next.cashBalance, 10000); expect(next.sales.single['digitalConfirmed'], isTrue);
    }
  });
  test('mixed payment change only comes from cash', () {
    final s = pay(ready(), [{'method': 'yape', 'amount': 500}, {'method': 'cash', 'amount': 1000}], confirmed: true);
    expect(s.sales.single['change'], 550); expect(s.cashBalance, 10450);
    expect(() => pay(ready(), [{'method': 'plin', 'amount': 1000}], confirmed: true), throwsA(isA<PosException>()));
    expect(() => pay(ready(), [{'method': 'cash', 'amount': 500}, {'method': 'cash', 'amount': 500}]), throwsA(isA<PosException>()));
  });
  test('closed cash and stale carts cannot be checked out', () {
    final closed = engine.dispatch(PosState.demo(), {'type': 'cart-add', 'productId': 'product-2'});
    expect(() => pay(closed, [{'method': 'cash', 'amount': 950}]), throwsA(isA<PosException>()));
    final before = ready(); final after = engine.dispatch(before, {'type': 'cart-add', 'productId': 'product-3'});
    expect(() => engine.dispatch(after, {'type': 'checkout', 'cartKey': before.cartKey, 'payments': [{'method': 'cash', 'amount': 950}]}), throwsA(isA<PosException>()));
    final paid = pay(before, [{'method': 'cash', 'amount': 950}]);
    expect(() => engine.dispatch(paid, {'type': 'checkout', 'cartKey': before.cartKey, 'payments': [{'method': 'cash', 'amount': 950}]}), throwsA(isA<PosException>()));
  });
  test('unit quantities, stock caps and fractional inventory', () {
    final s = ready();
    expect(() => engine.dispatch(s, {'type': 'cart-add', 'productId': 'product-2', 'quantity': 500}), throwsA(isA<PosException>()));
    expect(() => engine.dispatch(s, {'type': 'cart-add', 'productId': 'product-2', 'quantity': 18000}), throwsA(isA<PosException>()));
    final granel = engine.dispatch(engine.dispatch(PosState.demo(), {'type': 'open-session', 'opening': 0}), {'type': 'cart-add', 'productId': 'product-1', 'quantity': 250});
    final next = pay(granel, [{'method': 'cash', 'amount': 200}]);
    expect(next.sales.single['total'], 113); expect(next.products.first['stock'], 49750);
  });
  test('price edits preserve the agreed cart and original receipt', () {
    var s = ready(); var p = Map<String, dynamic>.from(s.products[1]); p['price'] = 1500;
    s = engine.dispatch(s, {'type': 'save-product', 'product': p}); expect(s.total, 950);
    s = pay(s, [{'method': 'cash', 'amount': 950}]); p['name'] = 'Aceite renombrado';
    s = engine.dispatch(s, {'type': 'save-product', 'product': p});
    expect((s.sales.single['lines'] as List).single['name'], 'Aceite vegetal 1 L');
    expect(s.sales.single['total'], 950);
  });
  test('stock purchases, losses and adjustments keep an auditable balance', () {
    var s = PosState.demo();
    s = engine.dispatch(s, {'type': 'stock-movement', 'productId': 'product-2', 'quantity': 2000, 'kind': 'purchase', 'reason': 'Compra al proveedor'});
    s = engine.dispatch(s, {'type': 'stock-movement', 'productId': 'product-2', 'quantity': 1000, 'kind': 'loss', 'reason': 'Envase dañado'});
    expect(stock(s), 19000); expect(s.stockMovements, hasLength(2));
    expect(() => engine.dispatch(s, {'type': 'stock-movement', 'productId': 'product-2', 'quantity': -20000, 'kind': 'adjustment', 'reason': 'Conteo'}), throwsA(isA<PosException>()));
    expect(() => engine.dispatch(s, {'type': 'stock-movement', 'productId': 'product-2', 'quantity': 1000, 'kind': 'purchase', 'reason': ''}), throwsA(isA<PosException>()));
    final forged = s.toJson(); (forged['products'] as List)[1]['stock'] = 18000;
    expect(() => PosState.fromJson(forged), throwsA(isA<PosException>()));
  });
  test('stock price-form changes require a reason', () {
    final s = ready(); final p = {...s.products[1], 'stock': 19000};
    expect(() => engine.dispatch(s, {'type': 'save-product', 'product': p}), throwsA(isA<PosException>()));
    p['stockReason'] = 'Conteo físico';
    final next = engine.dispatch(s, {'type': 'save-product', 'product': p});
    expect(next.stockMovements.single['reason'], 'Conteo físico');
  });
  test('fiado and partial abonos affect debt and cash, never another sale or stock', () {
    var s = engine.dispatch(ready(), {'type': 'save-customer', 'customer': {'name': 'Rosa', 'phone': '999123456'}});
    final customer = s.customers.single['id'] as String;
    s = pay(s, [], credit: true, customer: customer);
    final sale = s.sales.single['id']; expect(s.debtFor(customer), 950); expect(stock(s), 17000);
    s = engine.dispatch(s, {'type': 'repay', 'saleId': sale, 'amount': 200, 'method': 'cash'});
    expect(s.debtFor(customer), 750); expect(s.cashBalance, 10200);
    expect(stock(s), 17000); expect(s.sales, hasLength(1));
    expect(() => engine.dispatch(s, {'type': 'repay', 'saleId': sale, 'amount': 751, 'method': 'cash'}), throwsA(isA<PosException>()));
    s = engine.dispatch(s, {'type': 'repay', 'saleId': sale, 'amount': 750, 'method': 'plin', 'digitalConfirmed': true});
    expect(s.debtFor(customer), 0); expect(s.cashBalance, 10200); expect(s.sales, hasLength(1));
  });
  test('full return reverses collected payments and abonos, preserves history', () {
    var s = engine.dispatch(ready(), {'type': 'save-customer', 'customer': {'name': 'Rosa', 'phone': ''}});
    final customer = s.customers.single['id'] as String;
    s = pay(s, [{'method': 'cash', 'amount': 200}], credit: true, customer: customer);
    final sale = s.sales.single['id'];
    s = engine.dispatch(s, {'type': 'repay', 'saleId': sale, 'amount': 300, 'method': 'yape', 'digitalConfirmed': true});
    s = engine.dispatch(s, {'type': 'void-sale', 'saleId': sale, 'refundConfirmed': true, 'reason': 'Devolución completa'});
    expect(stock(s), 18000); expect(s.cashBalance, 10000); expect(s.debtFor(customer), 0);
    expect(s.sales.single['status'], 'voided'); expect(s.repayments, hasLength(1));
    expect(s.sales.single['refunds'], [{'method': 'cash', 'amount': 200}, {'method': 'yape', 'amount': 300}]);
    expect(() => engine.dispatch(s, {'type': 'void-sale', 'saleId': sale, 'refundConfirmed': true, 'reason': 'Otra devolución'}), throwsA(isA<PosException>()));
  });
  test('return from another session requires enough cash and preserves prior close', () {
    var s = pay(ready(), [{'method': 'cash', 'amount': 950}]); final sale = s.sales.single['id'];
    s = engine.dispatch(s, {'type': 'close-session', 'counted': 10950});
    s = engine.dispatch(s, {'type': 'open-session', 'opening': 0});
    expect(() => engine.dispatch(s, {'type': 'void-sale', 'saleId': sale, 'refundConfirmed': true, 'reason': 'Devolución'}), throwsA(isA<PosException>()));
    s = engine.dispatch(s, {'type': 'cash-movement', 'kind': 'income', 'amount': 950, 'reason': 'Fondo para devolución'});
    s = engine.dispatch(s, {'type': 'void-sale', 'saleId': sale, 'refundConfirmed': true, 'reason': 'Devolución'});
    expect(s.cashBalance, 0); expect(s.sessions.single['expected'], 10950);
  });
  test('cash withdrawals and close difference are validated', () {
    var s = pay(ready(), [{'method': 'cash', 'amount': 950}]);
    s = engine.dispatch(s, {'type': 'cash-movement', 'kind': 'expense', 'amount': 200, 'reason': 'Bolsas'});
    expect(s.cashBalance, 10750);
    expect(() => engine.dispatch(s, {'type': 'cash-movement', 'kind': 'expense', 'amount': 11000, 'reason': 'Retiro'}), throwsA(isA<PosException>()));
    s = engine.dispatch(s, {'type': 'close-session', 'counted': 10700});
    expect(s.sessions.single['difference'], -50); expect(s.session, isNull);
  });
  test('backup round trip validates totals, foreign keys and supported versions', () {
    final s = pay(ready(), [{'method': 'cash', 'amount': 950}]);
    expect(PosState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>).toJson(), s.toJson());
    final corrupt = s.toJson(); (corrupt['sales'] as List).single['total'] = 1;
    expect(() => PosState.fromJson(corrupt), throwsA(isA<PosException>()));
    final wrongVersion = s.toJson()..['version'] = 99;
    expect(() => PosState.fromJson(wrongVersion), throwsA(isA<PosException>()));
  });
}
