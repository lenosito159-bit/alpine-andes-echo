import test from 'node:test';
import assert from 'node:assert/strict';
import {
  seed,
  apply,
  totals,
  decimal,
  cartKey,
  cashBalance,
  validateBackup,
} from '../src/domain.js';

function ready() {
  let state = apply(seed(), { type: 'open-session', opening: 10000 }).state;
  return apply(state, { type: 'cart-add', productId: 'product-2' }).state;
}
function pay(state, payments, rest = {}) {
  return apply(state, { type: 'checkout', cartKey: cartKey(state), payments, ...rest });
}
test('los soles se convierten a céntimos sin errores binarios', () => {
  assert.equal(decimal('0.10') + decimal('0,20'), 30);
  assert.equal(decimal('1.05'), 105);
  for (const raw of ['NaN', '-2', 'Infinity', '1e3', '1.001', '', '3abc'])
    assert.throws(() => decimal(raw));
});
test('venta en efectivo guarda el total, reduce stock y vacía carrito sin mutar el original', () => {
  const state = ready();
  const { state: next, result: sale } = pay(state, [{ method: 'cash', amount: 2000 }]);
  assert.equal(sale.total, 950);
  assert.equal(sale.change, 1050);
  assert.equal(next.products.find((p) => p.id === 'product-2').stock, 17000);
  assert.equal(next.cart.length, 0);
  assert.equal(next.sales.length, 1);
  assert.equal(cashBalance(next), 10950);
  assert.equal(state.products.find((p) => p.id === 'product-2').stock, 18000);
  assert.equal(state.sales.length, 0);
});
test('pago insuficiente no guarda venta ni reduce stock', () => {
  const state = ready();
  const before = structuredClone(state);
  assert.throws(() => pay(state, [{ method: 'cash', amount: 949 }]), /no cubre/);
  assert.deepEqual(state, before);
});
test('doble cobro del mismo carrito se rechaza', () => {
  const state = ready();
  const key = cartKey(state);
  const next = pay(state, [{ method: 'cash', amount: 950 }]).state;
  assert.throws(
    () =>
      apply(next, { type: 'checkout', cartKey: key, payments: [{ method: 'cash', amount: 950 }] }),
    /carrito cambió/,
  );
  assert.equal(next.sales.length, 1);
});
test('Yape requiere confirmación y no aumenta el efectivo', () => {
  const state = ready();
  assert.throws(() => pay(state, [{ method: 'yape', amount: 950 }]), /Confirma/);
  const next = pay(state, [{ method: 'yape', amount: 950 }], { digitalConfirmed: true }).state;
  assert.equal(cashBalance(next), 10000);
  assert.equal(next.sales[0].change, 0);
});
test('pago mixto devuelve cambio solo del efectivo y registra aporte exacto', () => {
  const next = pay(
    ready(),
    [
      { method: 'plin', amount: 500 },
      { method: 'cash', amount: 1000 },
    ],
    { digitalConfirmed: true },
  ).state;
  assert.equal(next.sales[0].change, 550);
  assert.equal(cashBalance(next), 10450);
  assert.throws(
    () =>
      pay(
        ready(),
        [
          { method: 'yape', amount: 1000 },
          { method: 'cash', amount: 100 },
        ],
        { digitalConfirmed: true },
      ),
    /digitales/,
  );
});
test('no se permiten ventas con caja cerrada', () => {
  const state = apply(seed(), { type: 'cart-add', productId: 'product-2' }).state;
  assert.throws(() => pay(state, [{ method: 'cash', amount: 950 }]), /Abre tu caja/);
});
test('venta a granel redondea la línea a céntimos y descuenta 250 gramos', () => {
  let state = apply(seed(), { type: 'open-session', opening: 0 }).state;
  state = apply(state, { type: 'cart-add', productId: 'product-1', quantity: 250 }).state;
  assert.equal(totals(state).total, 113);
  const next = pay(state, [{ method: 'cash', amount: 200 }]).state;
  assert.equal(next.products[0].stock, 49750);
  assert.equal(next.sales[0].change, 87);
});
test('unidades enteras y stock se validan tanto al agregar como al cobrar', () => {
  assert.throws(
    () => apply(seed(), { type: 'cart-add', productId: 'product-2', quantity: 500 }),
    /cantidad/,
  );
  assert.throws(
    () => apply(seed(), { type: 'cart-add', productId: 'product-2', quantity: 19000 }),
    /Stock/,
  );
  const state = ready();
  state.products[1].stock = 0;
  assert.throws(() => pay(state, [{ method: 'cash', amount: 950 }]), /Stock insuficiente/);
});
test('cambiar el carrito invalida una pantalla de cobro antigua', () => {
  const state = ready();
  const key = cartKey(state);
  const next = apply(state, { type: 'cart-add', productId: 'product-3' }).state;
  assert.throws(
    () =>
      apply(next, { type: 'checkout', cartKey: key, payments: [{ method: 'cash', amount: 950 }] }),
    /carrito cambió/,
  );
});
test('editar precio de catálogo no altera el precio acordado en el carrito ni el historial', () => {
  let state = ready();
  const product = { ...state.products[1], price: 1500 };
  state = apply(state, { type: 'save-product', product }).state;
  assert.equal(totals(state).total, 950);
  state = pay(state, [{ method: 'cash', amount: 950 }]).state;
  state = apply(state, {
    type: 'save-product',
    product: { ...product, name: 'Aceite renombrado' },
  }).state;
  assert.equal(state.sales[0].lines[0].name, 'Aceite vegetal 1 L');
  assert.equal(state.sales[0].total, 950);
});
test('productos con código duplicado o stock menor al carrito son rechazados', () => {
  const state = ready();
  assert.throws(
    () =>
      apply(state, {
        type: 'save-product',
        product: { ...state.products[1], barcode: state.products[0].barcode },
      }),
    /código/,
  );
  assert.throws(
    () => apply(state, { type: 'save-product', product: { ...state.products[1], stock: 0 } }),
    /carrito/,
  );
  assert.throws(() => apply(state, { type: 'archive-product', productId: 'product-2' }), /Retira/);
});
test('caja separa ingresos, gastos y diferencia al cerrar', () => {
  let state = pay(ready(), [{ method: 'cash', amount: 950 }]).state;
  state = apply(state, {
    type: 'cash-movement',
    amount: 500,
    kind: 'expense',
    reason: 'Bolsas',
  }).state;
  assert.equal(cashBalance(state), 10450);
  assert.throws(
    () => apply(state, { type: 'cash-movement', amount: 11000, kind: 'expense', reason: 'Retiro' }),
    /supera/,
  );
  const { state: next, result } = apply(state, { type: 'close-session', counted: 10400 });
  assert.equal(result.difference, -50);
  assert.equal(next.session, null);
  assert.equal(next.sessions.length, 1);
  assert.equal(next.sales.length, 1);
});
test('copia completa valida ventas, caja y carrito; restaura sin compartir referencias', () => {
  let state = pay(ready(), [{ method: 'cash', amount: 1000 }]).state;
  state = apply(state, { type: 'cart-add', productId: 'product-3' }).state;
  const restored = validateBackup(JSON.parse(JSON.stringify(state)));
  assert.deepEqual(restored, state);
  restored.products[0].name = 'Otro';
  assert.notEqual(state.products[0].name, 'Otro');
});
test('copias corruptas, importes inconsistentes y stock negativo son rechazados', () => {
  assert.throws(() => validateBackup({ version: 1 }), /compatible/);
  const state = pay(ready(), [{ method: 'cash', amount: 950 }]).state;
  const negative = structuredClone(state);
  negative.products[0].stock = -1;
  assert.throws(() => validateBackup(negative), /Stock/);
  const wrongTotal = structuredClone(state);
  wrongTotal.sales[0].total = 1;
  assert.throws(() => validateBackup(wrongTotal), /inconsistente/);
  const wrongPayments = structuredClone(state);
  wrongPayments.sales[0].payments[0].amount = 100;
  assert.throws(() => validateBackup(wrongPayments), /no cuadran/);
});
