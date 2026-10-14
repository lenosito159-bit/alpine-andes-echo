import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zivlo/features/pos/application/pos_cubit.dart';
import 'package:zivlo/features/pos/domain/pos_repository.dart';
import 'package:zivlo/features/pos/presentation/pos_page.dart';
import 'package:zivlo/main.dart';
import 'package:zivlo/injection_container.dart' as di;
import 'test_repository.dart';

void main() {
  for (final width in [390.0, 1200.0]) {
    testWidgets('sale flow and history at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final repo = TestPosRepository(); final cubit = PosCubit(repo); await cubit.load(); addTearDown(cubit.close);
      await tester.pumpWidget(MaterialApp(home: BlocProvider.value(value: cubit, child: const PosPage())));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-register'))); await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('opening-amount')), '100.00');
      await tester.tap(find.text('Confirmar apertura')); await tester.pumpAndSettle();
      final oil = find.byKey(const ValueKey('product-product-2'));
      await tester.ensureVisible(oil); await tester.tap(oil); await tester.pumpAndSettle();
      final checkout = find.byKey(const ValueKey('checkout'));
      await tester.ensureVisible(checkout); await tester.tap(checkout); await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('cash-received')), '20.00');
      await tester.tap(find.byKey(const ValueKey('confirm-payment'))); await tester.pumpAndSettle();
      expect(find.text('Recibo comercial #1'), findsOneWidget);
      expect(repo.data.sales.single['change'], 1050);
      expect(repo.data.products[1]['stock'], 17000);
      await tester.tap(find.byKey(const ValueKey('close-receipt'))); await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-sales'))); await tester.pumpAndSettle();
      expect(find.text('Venta #1 · S/ 9.50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('application starts with the registered POS repository', (tester) async {
    await di.sl.reset();
    final repo = TestPosRepository();
    di.sl.registerSingleton<PosRepository>(repo);
    addTearDown(() => di.sl.reset());
    await tester.pumpWidget(const ZivloApp()); await tester.pumpAndSettle();
    expect(find.text('Tu próxima venta'), findsOneWidget);
    expect(find.text('Abrir caja'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
