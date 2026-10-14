export const VERSION = 1;
export const METHODS = ['cash', 'yape', 'plin', 'card'];
export const money = (cents) => `S/ ${(cents / 100).toFixed(2)}`;
export const quantity = (q, unit = 'und') =>
  `${new Intl.NumberFormat('es-PE', { maximumFractionDigits: 3 }).format(q / 1000)} ${unit}`;
export function decimal(value, places = 2) {
  const raw = String(value).trim().replace(',', '.');
  const pattern = new RegExp(`^\\d+(?:\\.\\d{1,${places}})?$`);
  if (!pattern.test(raw))
    throw new Error(`Ingresa un número positivo con hasta ${places} decimales.`);
  const [whole, fraction = ''] = raw.split('.');
  const n = Number(whole) * 10 ** places + Number(fraction.padEnd(places, '0'));
  if (!Number.isSafeInteger(n) || n > 1_000_000_000)
    throw new Error('El importe excede el límite permitido.');
  return n;
}
const copy = (s) => structuredClone(s);
function requireValue(test, message) {
  if (!test) throw new Error(message);
}
const id = () => crypto.randomUUID();
function integer(n, min = 0, max = 1_000_000_000) {
  return Number.isSafeInteger(n) && n >= min && n <= max;
}
function text(t, max = 160) {
  return typeof t === 'string' && t.length <= max;
}
const units = ['und', 'kg', 'L'];
export function seed() {
  const products = [
    ['Arroz extra', 'Granel', 450, 'kg', 50000, 'rice', '7750000000011'],
    ['Aceite vegetal 1 L', 'Abarrotes', 950, 'und', 18000, 'oil', '7750000000028'],
    ['Leche evaporada', 'Lácteos', 420, 'und', 24000, 'milk', '7750000000035'],
    ['Huevos frescos', 'Frescos', 70, 'und', 60000, 'eggs', '7750000000042'],
    ['Azúcar rubia', 'Granel', 380, 'kg', 40000, 'sugar', '7750000000059'],
    ['Inca Kola 500 ml', 'Bebidas', 350, 'und', 20000, 'soda', '7750000000066'],
    ['Agua mineral 625 ml', 'Bebidas', 200, 'und', 30000, 'water', '7750000000073'],
    ['Fideos spaghetti', 'Abarrotes', 320, 'und', 16000, 'pasta', '7750000000080'],
    ['Pan francés', 'Frescos', 30, 'und', 80000, 'bread', '7750000000097'],
    ['Atún en conserva', 'Abarrotes', 650, 'und', 4000, 'tuna', '7750000000103'],
    ['Galletas de vainilla', 'Abarrotes', 150, 'und', 25000, 'cookies', '7750000000110'],
    ['Yogurt de fresa 1 L', 'Lácteos', 780, 'und', 8000, 'yogurt', '7750000000127'],
  ].map(([name, category, price, unit, stock, art, barcode], i) => ({
    id: `product-${i + 1}`,
    name,
    category,
    price,
    unit,
    stock,
    art,
    barcode,
    active: true,
  }));
  return {
    version: VERSION,
    revision: 0,
    settings: { storeName: 'Mi bodega', owner: '', address: '', ruc: '' },
    products,
    cart: [],
    sales: [],
    movements: [],
    sessions: [],
    session: null,
  };
}
export function totals(state) {
  const lines = state.cart.map((item) => {
    const product = state.products.find((p) => p.id === item.productId);
    requireValue(product, 'Uno de los productos ya no existe.');
    return {
      ...item,
      name: product.name,
      unit: product.unit,
      barcode: product.barcode,
      total: Math.round((item.price * item.quantity) / 1000),
    };
  });
  return { lines, total: lines.reduce((sum, line) => sum + line.total, 0), count: lines.length };
}
export function cartKey(state) {
  return JSON.stringify(state.cart);
}
export function cashBalance(state) {
  if (!state.session) return 0;
  return (
    state.session.opening +
    state.movements
      .filter((m) => m.sessionId === state.session.id)
      .reduce((sum, m) => sum + m.amount, 0)
  );
}
export function apply(state, action) {
  const s = copy(state);
  let result = null;
  switch (action.type) {
    case 'cart-add': {
      const p = s.products.find((p) => p.id === action.productId && p.active);
      requireValue(p, 'Producto no disponible.');
      const amount = action.quantity ?? 1000;
      requireValue(
        integer(amount, 1) && (p.unit !== 'und' || amount % 1000 === 0),
        'La cantidad no es válida para esta unidad.',
      );
      const item = s.cart.find((i) => i.productId === p.id);
      const q = (item?.quantity ?? 0) + amount;
      requireValue(q <= p.stock, `Stock disponible: ${quantity(p.stock, p.unit)}.`);
      if (item) item.quantity = q;
      else s.cart.push({ productId: p.id, price: p.price, quantity: amount });
      break;
    }
    case 'cart-quantity': {
      const item = s.cart.find((i) => i.productId === action.productId);
      const p = s.products.find((p) => p.id === action.productId);
      requireValue(item && p, 'Producto no encontrado en el carrito.');
      requireValue(
        integer(action.quantity) && (p.unit !== 'und' || action.quantity % 1000 === 0),
        'Cantidad inválida.',
      );
      requireValue(action.quantity <= p.stock, `Stock disponible: ${quantity(p.stock, p.unit)}.`);
      if (!action.quantity) s.cart = s.cart.filter((i) => i !== item);
      else item.quantity = action.quantity;
      break;
    }
    case 'cart-clear':
      s.cart = [];
      break;
    case 'open-session': {
      requireValue(!s.session, 'La caja ya está abierta.');
      requireValue(integer(action.opening), 'Monto inicial inválido.');
      s.session = { id: id(), opening: action.opening, openedAt: new Date().toISOString() };
      break;
    }
    case 'cash-movement': {
      requireValue(s.session, 'Abre la caja primero.');
      requireValue(
        integer(action.amount, 1) && text(action.reason, 120) && action.reason.trim(),
        'Indica un importe y un motivo.',
      );
      requireValue(['income', 'expense'].includes(action.kind), 'Tipo de movimiento inválido.');
      const amount = action.kind === 'income' ? action.amount : -action.amount;
      requireValue(cashBalance(s) + amount >= 0, 'El retiro supera el efectivo esperado.');
      s.movements.push({
        id: id(),
        sessionId: s.session.id,
        amount,
        reason: action.reason.trim(),
        kind: action.kind,
        at: new Date().toISOString(),
      });
      break;
    }
    case 'close-session': {
      requireValue(s.session, 'No hay caja abierta.');
      requireValue(integer(action.counted), 'Monto contado inválido.');
      const expected = cashBalance(s);
      result = {
        ...s.session,
        expected,
        counted: action.counted,
        difference: action.counted - expected,
        closedAt: new Date().toISOString(),
      };
      s.sessions.push(result);
      s.session = null;
      break;
    }
    case 'checkout': {
      requireValue(s.session, 'Abre tu caja antes de cobrar.');
      requireValue(
        action.cartKey === cartKey(s),
        'El carrito cambió. Revisa el total antes de cobrar.',
      );
      const { lines, total } = totals(s);
      requireValue(lines.length && total > 0, 'Agrega productos al carrito.');
      for (const line of lines) {
        const p = s.products.find((p) => p.id === line.productId);
        requireValue(p.active && p.stock >= line.quantity, `Stock insuficiente para ${line.name}.`);
      }
      const payments = action.payments;
      requireValue(
        Array.isArray(payments) && payments.length > 0 && payments.length <= 4,
        'Indica el medio de pago.',
      );
      requireValue(
        new Set(payments.map((p) => p.method)).size === payments.length,
        'Medio de pago repetido.',
      );
      for (const p of payments)
        requireValue(
          METHODS.includes(p.method) && integer(p.amount, 1),
          'Importe de pago inválido.',
        );
      const electronic = payments
        .filter((p) => p.method !== 'cash')
        .reduce((sum, p) => sum + p.amount, 0);
      const received = payments.find((p) => p.method === 'cash')?.amount ?? 0;
      requireValue(electronic <= total, 'Los pagos digitales no pueden superar el total.');
      requireValue(electronic + received >= total, 'El pago no cubre el total de la venta.');
      requireValue(
        !electronic || action.digitalConfirmed === true,
        'Confirma que recibiste el pago digital antes de registrar la venta.',
      );
      const change = received + electronic - total;
      const saleId = id();
      result = {
        id: saleId,
        number: s.sales.length + 1,
        at: new Date().toISOString(),
        sessionId: s.session.id,
        lines,
        total,
        payments: copy(payments),
        change,
        store: copy(s.settings),
      };
      s.sales.push(result);
      for (const line of lines)
        s.products.find((p) => p.id === line.productId).stock -= line.quantity;
      if (received)
        s.movements.push({
          id: id(),
          sessionId: s.session.id,
          amount: received - change,
          reason: `Venta #${result.number}`,
          kind: 'sale',
          saleId,
          at: result.at,
        });
      s.cart = [];
      break;
    }
    case 'save-product': {
      const p = action.product;
      requireValue(
        text(p.name, 100) && p.name.trim() && text(p.category, 50) && p.category.trim(),
        'Indica nombre y categoría.',
      );
      requireValue(
        integer(p.price, 1, 100_000_000) && units.includes(p.unit) && integer(p.stock),
        'Precio, stock o unidad inválidos.',
      );
      requireValue(
        p.unit !== 'und' || p.stock % 1000 === 0,
        'El stock por unidad debe ser entero.',
      );
      requireValue(text(p.barcode, 60), 'Código de barras inválido.');
      requireValue(
        !p.barcode || !s.products.some((x) => x.id !== p.id && x.barcode === p.barcode),
        'Ya existe un producto con ese código.',
      );
      const previous = s.products.find((x) => x.id === p.id);
      requireValue(
        !previous || previous.unit === p.unit || !s.cart.some((i) => i.productId === p.id),
        'Retira el producto del carrito antes de cambiar su unidad.',
      );
      requireValue(
        !s.cart.some((i) => i.productId === p.id && i.quantity > p.stock),
        'El stock no puede ser menor a la cantidad del carrito.',
      );
      const product = {
        id: previous?.id ?? id(),
        name: p.name.trim(),
        category: p.category.trim(),
        price: p.price,
        stock: p.stock,
        barcode: p.barcode.trim(),
        unit: p.unit,
        active: previous?.active ?? true,
        art: previous?.art ?? 'bag',
      };
      if (previous) s.products[s.products.indexOf(previous)] = product;
      else s.products.push(product);
      result = product;
      break;
    }
    case 'archive-product': {
      const p = s.products.find((p) => p.id === action.productId);
      requireValue(
        p && !s.cart.some((i) => i.productId === p.id),
        'Retira el producto del carrito antes de archivarlo.',
      );
      p.active = false;
      break;
    }
    case 'settings': {
      const v = action.settings;
      requireValue(
        text(v.storeName, 80) && v.storeName.trim() && text(v.owner, 80) && text(v.address, 160),
        'Datos del negocio inválidos.',
      );
      requireValue(v.ruc === '' || /^\d{11}$/.test(v.ruc), 'El RUC debe contener 11 dígitos.');
      s.settings = {
        storeName: v.storeName.trim(),
        owner: v.owner.trim(),
        address: v.address.trim(),
        ruc: v.ruc,
      };
      break;
    }
    default:
      throw new Error('Operación desconocida.');
  }
  s.revision++;
  return { state: s, result };
}
export function validateBackup(data) {
  requireValue(
    data && data.version === VERSION && integer(data.revision),
    'La copia no es compatible con esta versión.',
  );
  requireValue(
    data.settings &&
      text(data.settings.storeName, 80) &&
      data.settings.storeName.trim() &&
      text(data.settings.owner, 80) &&
      text(data.settings.address, 160) &&
      (data.settings.ruc === '' || /^\d{11}$/.test(data.settings.ruc)),
    'Datos de negocio inválidos.',
  );
  for (const key of ['products', 'cart', 'sales', 'movements', 'sessions'])
    requireValue(
      Array.isArray(data[key]) && data[key].length <= 50000,
      'Copia incompleta o demasiado grande.',
    );
  const ids = new Set();
  const codes = new Set();
  for (const p of data.products) {
    requireValue(
      text(p.id, 100) && p.id && !ids.has(p.id),
      'Identificadores de producto inválidos.',
    );
    ids.add(p.id);
    requireValue(
      text(p.name, 100) &&
        p.name.trim() &&
        text(p.category, 50) &&
        p.category.trim() &&
        text(p.barcode, 60) &&
        text(p.art, 40) &&
        typeof p.active === 'boolean',
      'Producto inválido.',
    );
    requireValue(!p.barcode || !codes.has(p.barcode), 'Código duplicado.');
    codes.add(p.barcode);
    requireValue(
      integer(p.price, 1, 100_000_000) &&
        integer(p.stock) &&
        units.includes(p.unit) &&
        (p.unit !== 'und' || p.stock % 1000 === 0),
      'Stock o precio inválido.',
    );
  }
  const cartIds = new Set();
  for (const line of data.cart) {
    const p = data.products.find((p) => p.id === line.productId);
    requireValue(
      p?.active &&
        !cartIds.has(p.id) &&
        integer(line.price, 1, 100_000_000) &&
        integer(line.quantity, 1) &&
        line.quantity <= p.stock &&
        (p.unit !== 'und' || line.quantity % 1000 === 0),
      'Carrito inválido.',
    );
    cartIds.add(p.id);
  }
  const validDate = (d) => typeof d === 'string' && Number.isFinite(Date.parse(d));
  const validSession = (s) =>
    s && text(s.id, 100) && s.id && integer(s.opening) && validDate(s.openedAt);
  requireValue(data.session === null || validSession(data.session), 'Caja inválida.');
  for (const session of data.sessions)
    requireValue(
      validSession(session) &&
        integer(session.expected) &&
        integer(session.counted) &&
        Number.isSafeInteger(session.difference) &&
        session.difference === session.counted - session.expected &&
        validDate(session.closedAt),
      'Cierre de caja inválido.',
    );
  const saleIds = new Set();
  const saleNumbers = new Set();
  for (const sale of data.sales) {
    requireValue(
      text(sale.id, 100) &&
        sale.id &&
        !saleIds.has(sale.id) &&
        integer(sale.number, 1) &&
        sale.number <= data.sales.length &&
        !saleNumbers.has(sale.number) &&
        validDate(sale.at) &&
        text(sale.sessionId, 100) &&
        integer(sale.total, 1) &&
        integer(sale.change),
      'Venta inválida.',
    );
    saleIds.add(sale.id);
    saleNumbers.add(sale.number);
    requireValue(
      Array.isArray(sale.lines) && sale.lines.length > 0 && sale.lines.length <= 10000,
      'Detalle de venta inválido.',
    );
    for (const l of sale.lines)
      requireValue(
        text(l.productId, 100) &&
          text(l.name, 100) &&
          text(l.barcode, 60) &&
          units.includes(l.unit) &&
          integer(l.quantity, 1) &&
          (l.unit !== 'und' || l.quantity % 1000 === 0) &&
          integer(l.price, 1) &&
          integer(l.total) &&
          l.total === Math.round((l.price * l.quantity) / 1000),
        'Importes de venta inválidos.',
      );
    requireValue(
      sale.lines.reduce((sum, l) => sum + l.total, 0) === sale.total,
      'Total de venta inconsistente.',
    );
    requireValue(
      Array.isArray(sale.payments) &&
        sale.payments.length > 0 &&
        sale.payments.length <= 4 &&
        new Set(sale.payments.map((p) => p.method)).size === sale.payments.length,
      'Pagos inválidos.',
    );
    for (const p of sale.payments)
      requireValue(METHODS.includes(p.method) && integer(p.amount, 1), 'Pago inválido.');
    const electronic = sale.payments
      .filter((p) => p.method !== 'cash')
      .reduce((sum, p) => sum + p.amount, 0);
    requireValue(
      electronic <= sale.total &&
        sale.payments.reduce((sum, p) => sum + p.amount, 0) - sale.change === sale.total &&
        sale.change <= (sale.payments.find((p) => p.method === 'cash')?.amount ?? 0),
      'Pagos no cuadran con la venta.',
    );
    requireValue(
      sale.store &&
        text(sale.store.storeName, 80) &&
        text(sale.store.address, 160) &&
        text(sale.store.ruc, 11),
      'Datos del recibo inválidos.',
    );
  }
  for (const m of data.movements)
    requireValue(
      text(m.id, 100) &&
        text(m.sessionId, 100) &&
        text(m.reason, 120) &&
        validDate(m.at) &&
        Number.isSafeInteger(m.amount) &&
        Math.abs(m.amount) <= 1_000_000_000 &&
        ['sale', 'income', 'expense'].includes(m.kind) &&
        (m.kind !== 'sale' || saleIds.has(m.saleId)),
      'Movimiento de caja inválido.',
    );
  return copy(data);
}
