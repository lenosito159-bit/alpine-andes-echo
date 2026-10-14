import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zivlo/features/pos/application/pos_cubit.dart';
import 'test_repository.dart';

void main() {
  test('loading emits ready data and serializes in-flight mutations', () async {
    final repo = TestPosRepository(); final cubit = PosCubit(repo);
    await cubit.load(); expect(cubit.state.data!.products, hasLength(12));
    final gate = Completer<void>(); repo.barrier = gate.future;
    final first = cubit.run({'type': 'cart-add', 'productId': 'product-2'});
    expect(cubit.state.busy, isTrue);
    expect(await cubit.run({'type': 'cart-add', 'productId': 'product-2'}), isFalse);
    expect(repo.writes, 1); gate.complete(); expect(await first, isTrue);
    expect(cubit.state.data!.cart.single['quantity'], 1000);
    expect(cubit.state.busy, isFalse); await cubit.close();
  });
  test('failed persistence emits an error, never a success or mutated state', () async {
    final repo = TestPosRepository(); final cubit = PosCubit(repo); await cubit.load();
    repo.failWrites = true;
    expect(await cubit.run({'type': 'cart-add', 'productId': 'product-2'}), isFalse);
    expect(cubit.state.data!.cart, isEmpty); expect(cubit.state.error, contains('No se guardó'));
    expect(cubit.state.busy, isFalse); await cubit.close();
  });
  test('stale revision refreshes the screen before the next operation', () async {
    final repo = TestPosRepository(); final cubit = PosCubit(repo); await cubit.load();
    repo.data = repo.engine.dispatch(repo.data, {'type': 'cart-add', 'productId': 'product-3'});
    expect(await cubit.run({'type': 'cart-add', 'productId': 'product-2'}), isFalse);
    expect(cubit.state.data!.revision, repo.data.revision);
    expect(cubit.state.data!.cart.single['productId'], 'product-3');
    expect(await cubit.run({'type': 'cart-add', 'productId': 'product-2'}), isTrue);
    await cubit.close();
  });
}
