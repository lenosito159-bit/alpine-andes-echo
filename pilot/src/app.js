import {
  money,
  quantity,
  decimal,
  totals,
  cartKey,
  cashBalance,
  validateBackup,
} from './domain.js';
import { openDatabase, readState, commit, onOtherTab } from './storage.js';

const $ = (selector) => document.querySelector(selector);
const standaloneMode = document.documentElement.dataset.standalone === 'true';
const esc = (value) =>
  String(value ?? '').replace(
    /[&<>"']/g,
    (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c],
  );
const icons = {
  sell: '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  box: '<path d="m12 3 9 5-9 5-9-5 9-5Z"/><path d="M3 8v9l9 5 9-5V8M12 13v9M7 5.8l9 5"/>',
  history: '<path d="M8 3h9l3 3v15H4V3h4ZM8 8h8M8 12h8M8 16h5"/>',
  cash: '<rect x="2" y="5" width="20" height="14" rx="3"/><circle cx="12" cy="12" r="3"/><path d="M5 9v6M19 9v6"/>',
  settings:
    '<path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1"/><circle cx="12" cy="12" r="4"/>',
  search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  arrow: '<path d="M4 12h16m-6-6 6 6-6 6"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  close: '<path d="m6 6 12 12M6 18 18 6"/>',
  trash: '<path d="M3 6h18M8 6V3h8v3M5 6l1 15h12l1-15M10 10v7M14 10v7"/>',
  download: '<path d="M12 3v12m-5-5 5 5 5-5M4 16v5h16v-5"/>',
  clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  shield: '<path d="m12 2 9 4v6c0 5-9 10-9 10S3 17 3 12V6l9-4Z"/><path d="m8 12 3 3 5-6"/>',
  barcode: '<path d="M3 3v18M6 3v18M10 3v18M12 3v18M16 3v18M19 3v18M21 3v18"/>',
  print: '<path d="M6 9V3h12v6M6 17H3V9h18v8h-3M6 14h12v7H6zM17 11h1"/>',
  person: '<circle cx="12" cy="7" r="4"/><path d="M4 21v-3a8 8 0 0 1 16 0v3"/>',
};
const icon = (name, cls = '') =>
  `<svg class="icon ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${icons[name] ?? icons.box}</svg>`;
const methods = { cash: 'Efectivo', yape: 'Yape', plin: 'Plin', card: 'Tarjeta' };
const date = (value) =>
  new Intl.DateTimeFormat('es-PE', {
    timeZone: 'America/Lima',
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
const day = (value) =>
  new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Lima',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date(value));
let state,
  view = 'sell',
  category = 'Todos',
  search = '',
  busy = false,
  paymentMethod = 'cash',
  saleFilter = 'today',
  offlineReady = false,
  modalKind = null,
  lastFocus;
let toastTimer, installPrompt;
const todaySales = () => state.sales.filter((s) => day(s.at) === day(Date.now()));

function toast(message, error = false) {
  $('#toast').textContent = message;
  $('#toast').className = `visible ${error ? 'error' : ''}`;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => ($('#toast').className = ''), 4500);
}
function productArt(p) {
  const palette = {
    rice: ['#efe6c8', '#d8c095'],
    oil: ['#f5e4a3', '#caae44'],
    milk: ['#e6edf0', '#aac0c8'],
    eggs: ['#f4e3d3', '#d5ac8a'],
    sugar: ['#e7ddd4', '#baa58f'],
    soda: ['#f8e9a2', '#d1b236'],
    water: ['#d9ecf0', '#81b6c2'],
    pasta: ['#f4dfc3', '#cf9a50'],
    bread: ['#f4e2bf', '#c99d55'],
    tuna: ['#dfebdf', '#91ab8d'],
    cookies: ['#eee2d2', '#c29d76'],
    yogurt: ['#f4dfe6', '#d19baa'],
    bag: ['#e4e9dc', '#9ea88c'],
  };
  const [bg, color] = palette[p.art] ?? palette.bag;
  let drawing;
  if (['oil', 'water', 'soda'].includes(p.art))
    drawing = `<rect x="47" y="17" width="26" height="13" rx="4" fill="${color}"/><path d="M48 30h24v13l11 15v55a9 9 0 0 1-9 9H46a9 9 0 0 1-9-9V58l11-15Z" fill="${color}"/><rect x="37" y="68" width="46" height="32" fill="#fff" opacity=".88"/><path d="M50 79h20M53 87h14" stroke="${color}" stroke-width="3"/>`;
  else if (['milk', 'yogurt'].includes(p.art))
    drawing = `<path d="m39 43 10-15h27l6 15v75H39Z" fill="${color}"/><path d="M39 43h43v18H39Z" fill="#fff" opacity=".85"/><path d="M49 28v15M49 82h23M52 92h17" stroke="#fff" stroke-width="3"/><circle cx="61" cy="78" r="9" fill="#fff" opacity=".75"/>`;
  else if (p.art === 'eggs')
    drawing = `<ellipse cx="42" cy="74" rx="17" ry="24" fill="#ddbea0"/><ellipse cx="66" cy="65" rx="17" ry="24" fill="#fff8ec"/><ellipse cx="86" cy="81" rx="17" ry="24" fill="#ecd3b6"/><path d="M22 91h85l-8 23H29Z" fill="${color}"/><path d="M32 100h64" stroke="#fff" opacity=".45" stroke-width="3"/>`;
  else if (p.art === 'bread')
    drawing = `<path d="M26 91c-5-14 20-48 35-48s39 29 34 45c-4 16-64 20-69 3Z" fill="${color}"/><path d="m45 59 9 14m6-23 8 15m7-8 8 13" stroke="#fae8ca" stroke-width="6" stroke-linecap="round"/>`;
  else if (p.art === 'tuna')
    drawing = `<ellipse cx="61" cy="95" rx="35" ry="11" fill="${color}"/><rect x="26" y="57" width="70" height="38" fill="${color}"/><ellipse cx="61" cy="57" rx="35" ry="11" fill="#d4dcd1"/><ellipse cx="61" cy="57" rx="27" ry="7" fill="none" stroke="#91ab8d"/><path d="M41 78h40" stroke="#fff" stroke-width="8"/>`;
  else
    drawing = `<path d="M37 31h47l-4 16 10 68a5 5 0 0 1-5 6H35a5 5 0 0 1-5-6l10-68Z" fill="${color}"/><path d="M37 31h47v9H37Z" fill="#fff" opacity=".4"/><rect x="38" y="60" width="44" height="37" rx="4" fill="#fff" opacity=".85"/><path d="M49 72h21M52 81h15" stroke="${color}" stroke-width="3"/><path d="m52 105 4 5m6-5 4 5" stroke="#fff" opacity=".4" stroke-width="3"/>`;
  return `<svg class="product-art" viewBox="0 0 120 140" aria-hidden="true"><rect width="120" height="140" rx="20" fill="${bg}"/><ellipse cx="61" cy="123" rx="32" ry="4" fill="#000" opacity=".06"/>${drawing}</svg>`;
}
function render() {
  const saleSum = todaySales().reduce((n, s) => n + s.total, 0);
  const nav = [
    ['sell', 'sell', 'Vender'],
    ['catalog', 'box', 'Productos'],
    ['sales', 'history', 'Ventas'],
    ['cash', 'cash', 'Caja'],
    ['settings', 'settings', 'Mi negocio'],
  ];
  $('#app').innerHTML = `<div class="layout">
    <aside class="sidebar"><a class="brand" href="#" data-nav="sell"><img src="./icon.svg" alt=""/><span>zivlo<span class="brand-dot">.</span></span></a>
      <div class="workspace-label">MI ESPACIO</div><nav aria-label="Principal">${nav.map(([key, glyph, label]) => `<button class="nav-item ${view === key ? 'active' : ''}" data-nav="${key}" ${view === key ? 'aria-current="page"' : ''}>${icon(glyph)}<span>${label}</span>${view === key ? '<i></i>' : ''}</button>`).join('')}</nav>
      <div class="sidebar-bottom"><div class="local-card">${icon('shield')}<strong>Tu negocio sigue.</strong><p>Tus datos se guardan<br>en este dispositivo.</p><span class="connection-dot"></span> Venta local</div><div class="store-mini"><div class="avatar">${esc(state.settings.storeName.charAt(0).toUpperCase())}</div><div><strong>${esc(state.settings.storeName)}</strong><span>Perú · PEN</span></div></div></div>
    </aside>
    <div class="main-shell"><header class="topbar"><div class="breadcrumb">Mi negocio <span>/</span> <strong>${nav.find((n) => n[0] === view)[2]}</strong></div><div class="topbar-actions"><span class="offline-status" id="offline-status">${offlineReady ? icon('check') : icon('shield')} ${offlineReady ? 'Listo sin internet' : 'Almacenamiento local'}</span><button class="cash-status ${state.session ? '' : 'closed'}" data-action="open-cash">${icon('cash')} ${state.session ? 'Caja abierta' : 'Abrir caja'}<span class="status-dot"></span></button><div class="avatar small">${esc((state.settings.owner || 'Tú').slice(0, 1).toUpperCase())}</div></div></header>
      <main>${view === 'sell' ? sellView(saleSum) : view === 'catalog' ? catalogView() : view === 'sales' ? salesView() : view === 'cash' ? cashView() : settingsView()}</main>
      ${view === 'sell' && state.cart.length ? `<div class="mobile-cart-bar"><button data-action="see-cart"><strong>Venta actual · ${state.cart.length}</strong><span>${money(totals(state).total)}</span></button><button class="button primary" data-action="checkout">Cobrar ${icon('arrow')}</button></div>` : ''}
      <footer class="app-footer"><span>Hecho para el comercio de todos los días.</span><span>Zivlo Perú <i>·</i> Piloto web 0.1</span></footer>
    </div>
  </div>`;
}
function header(eyebrow, title, description, action = '') {
  return `<div class="page-heading"><div><div class="eyebrow">${eyebrow}</div><h1>${title}</h1><p>${description}</p></div>${action}</div>`;
}
function sellView(saleSum) {
  return `${header('TU MOSTRADOR DIGITAL', 'Una buena venta empieza aquí.', 'Todo a mano. Cobra fácil, sigue con tu día.', `<div class="today-mini"><span>${icon('clock')} Ventas de hoy</span><strong>${money(saleSum)}</strong><small>${todaySales().length} ${todaySales().length === 1 ? 'venta registrada' : 'ventas registradas'}</small></div>`)}
  <div class="pos-layout"><section class="catalog-panel"><div class="search-toolbar"><label class="search-box">${icon('search')}<input id="product-search" type="search" value="${esc(search)}" placeholder="Buscar producto o escanear código…" aria-label="Buscar producto o código de barras" autocomplete="off"/> <kbd>↵</kbd></label><button class="button subtle" data-action="new-product">${icon('plus')}<span>Producto</span></button></div>
  <div class="category-tabs" role="group" aria-label="Categorías">${['Todos', ...new Set(state.products.filter((p) => p.active).map((p) => p.category))].map((c) => `<button class="category ${category === c ? 'selected' : ''}" data-category="${esc(c)}">${esc(c)}</button>`).join('')}</div>
  <div class="catalog-meta"><span>Productos disponibles <strong id="product-count"></strong></span><span>${icon('barcode')} Compatible con lector USB</span></div><div class="product-grid" id="product-grid">${productGrid()}</div>
  <div class="hint-strip">${icon('shield')}<div><strong>Tu venta no depende de una señal.</strong><span>El catálogo, la caja y tus ventas se guardan aquí.</span></div><span class="tiny-pill">OFFLINE FIRST</span></div>
  <div class="demo-note">Catálogo de ejemplo para probar. Puedes editarlo en Productos.</div></section>${cartView()}</div>`;
}
function visibleProducts() {
  const q = search.toLocaleLowerCase('es');
  return state.products.filter(
    (p) =>
      p.active &&
      (category === 'Todos' || p.category === category) &&
      (!q || p.name.toLocaleLowerCase('es').includes(q) || p.barcode.includes(q)),
  );
}
function productGrid() {
  const products = visibleProducts();
  return products.length
    ? products
        .map(
          (p) =>
            `<button class="product-card ${p.stock === 0 ? 'out-of-stock' : ''}" data-add="${esc(p.id)}" ${p.stock === 0 ? 'disabled' : ''} aria-label="Agregar ${esc(p.name)}"><div class="product-visual">${productArt(p)}<span class="product-add">${icon('plus')}</span>${p.stock < (p.unit === 'und' ? 5000 : 2000) ? '<span class="low-stock">Stock bajo</span>' : ''}</div><div class="product-info"><span class="product-category">${esc(p.category)}</span><h3>${esc(p.name)}</h3><div class="product-bottom"><strong>${money(p.price)}<small> / ${esc(p.unit)}</small></strong><span>${quantity(p.stock, p.unit)}</span></div></div></button>`,
        )
        .join('')
    : `<div class="empty-state">${icon('search')}<h3>No encontramos ese producto</h3><p>Prueba con otro nombre o agrégalo a tu catálogo.</p><button class="button secondary" data-action="new-product">Crear producto</button></div>`;
}
function cartView() {
  const { lines, total } = totals(state);
  return `<aside class="cart-panel"><div class="cart-heading"><div>${icon('sell')}<h2>Venta actual</h2><span class="count-badge">${lines.length}</span></div><button class="icon-button" data-action="clear-cart" aria-label="Vaciar carrito" title="Vaciar carrito" ${!lines.length ? 'disabled' : ''}>${icon('trash')}</button></div><div class="ticket-number"><span>NUEVA VENTA</span><span>#${String(state.sales.length + 1).padStart(4, '0')}</span></div><div class="cart-lines">${lines.length ? lines.map((l) => `<div class="cart-line"><div class="cart-line-top"><strong>${esc(l.name)}</strong><b>${money(l.total)}</b></div><div class="cart-line-bottom"><span>${money(l.price)} / ${esc(l.unit)}</span><div class="stepper"><button data-qty="${esc(l.productId)}" data-delta="-1" aria-label="Reducir ${esc(l.name)}">−</button><button class="quantity-button" data-edit-qty="${esc(l.productId)}" aria-label="Editar cantidad de ${esc(l.name)}">${quantity(l.quantity, l.unit)}</button><button data-qty="${esc(l.productId)}" data-delta="1" aria-label="Aumentar ${esc(l.name)}">+</button></div></div></div>`).join('') : `<div class="cart-empty"><div class="empty-bag">${icon('box')}</div><h3>Tu próxima venta<br>empieza con un producto</h3><p>Toca un producto del catálogo<br>para agregarlo aquí.</p></div>`}</div><div class="cart-summary"><div><span>Subtotal</span><strong>${money(total)}</strong></div><div><span>Productos</span><span>${lines.length}</span></div><div class="total-row"><span>Total a cobrar</span><strong>${money(total)}</strong></div><button class="button primary checkout-button" data-action="checkout" ${!lines.length ? 'disabled' : ''}>Cobrar ${money(total)} ${icon('arrow')}</button><div class="payment-logos"><span>Efectivo</span><span class="yape">yape</span><span class="plin">plin</span><span>Tarjeta</span></div></div><div class="cart-bottom-note">${icon('shield')} Guardado automático en este dispositivo</div></aside>`;
}
function catalogView() {
  const products = state.products.filter((p) => p.active);
  return `${header('UN CATÁLOGO A TU MEDIDA', 'Tus productos, en orden.', 'Precios claros y stock actualizado con cada venta.', `<button class="button primary" data-action="new-product">${icon('plus')} Nuevo producto</button>`)}<div class="stats-row"><div class="stat-card"><span>Productos activos</span><strong>${products.length}</strong><small>Listos para vender</small></div><div class="stat-card"><span>Con stock bajo</span><strong>${products.filter((p) => p.stock <= (p.unit === 'und' ? 5000 : 2000)).length}</strong><small>Revisa tu próxima compra</small></div><div class="stat-card"><span>Venta a granel</span><strong>${products.filter((p) => p.unit !== 'und').length}</strong><small>Por kilo o litro</small></div></div><div class="surface"><div class="section-heading"><h2>Catálogo del negocio</h2><span>${products.length} productos</span></div><div class="table-wrap"><table><thead><tr><th>Producto</th><th>Categoría</th><th>Precio</th><th>Stock disponible</th><th></th></tr></thead><tbody>${products.map((p) => `<tr><td><div class="table-product">${productArt(p)}<div><strong>${esc(p.name)}</strong><small>${esc(p.barcode || 'Sin código de barras')}</small></div></div></td><td>${esc(p.category)}</td><td><strong>${money(p.price)}</strong> / ${esc(p.unit)}</td><td><span class="stock-pill ${p.stock <= 5000 ? 'low' : ''}">${quantity(p.stock, p.unit)}</span></td><td><button class="button text-button" data-product="${esc(p.id)}">Editar</button></td></tr>`).join('')}</tbody></table></div></div>`;
}
function salesView() {
  const sales = saleFilter === 'today' ? todaySales() : state.sales;
  const total = sales.reduce((n, s) => n + s.total, 0);
  return `${header('CADA VENTA CUENTA', 'Así va tu negocio.', 'Consulta lo vendido y vuelve a imprimir tus recibos.')}<div class="stats-row"><div class="stat-card accent"><span>Total vendido ${saleFilter === 'today' ? 'hoy' : ''}</span><strong>${money(total)}</strong><small>Ventas registradas en este dispositivo</small></div><div class="stat-card"><span>Ventas completadas</span><strong>${sales.length}</strong><small>Sin pendientes de guardado</small></div><div class="stat-card"><span>Ticket promedio</span><strong>${money(sales.length ? Math.round(total / sales.length) : 0)}</strong><small>Importe promedio por venta</small></div></div><div class="surface"><div class="section-heading"><h2>Historial de ventas</h2><div class="segmented"><button data-sale-filter="today" class="${saleFilter === 'today' ? 'active' : ''}">Hoy</button><button data-sale-filter="all" class="${saleFilter === 'all' ? 'active' : ''}">Todas</button></div></div>${
    sales.length
      ? `<div class="table-wrap"><table><thead><tr><th>Venta</th><th>Fecha · hora de Perú</th><th>Pago</th><th>Total</th><th></th></tr></thead><tbody>${[
          ...sales,
        ]
          .reverse()
          .map(
            (s) =>
              `<tr><td><strong>#${String(s.number).padStart(4, '0')}</strong><small class="block">${s.lines.length} productos</small></td><td>${date(s.at)}</td><td>${s.payments.map((p) => `<span class="method-tag ${p.method}">${methods[p.method]}</span>`).join(' ')}</td><td><strong>${money(s.total)}</strong></td><td><button class="button text-button" data-receipt="${esc(s.id)}">Ver recibo ${icon('arrow')}</button></td></tr>`,
          )
          .join('')}</tbody></table></div>`
      : `<div class="empty-state">${icon('history')}<h3>Tu primera venta te espera</h3><p>Cuando cobres, la venta aparecerá aquí.</p><button class="button primary" data-nav="sell">Empezar a vender</button></div>`
  }</div>`;
}
function cashView() {
  const sessionSales = state.session
    ? state.sales.filter((s) => s.sessionId === state.session.id)
    : [];
  const digital = (method) =>
    sessionSales.reduce(
      (sum, sale) =>
        sum + sale.payments.filter((p) => p.method === method).reduce((n, p) => n + p.amount, 0),
      0,
    );
  const movements = state.session
    ? state.movements.filter((m) => m.sessionId === state.session.id)
    : [];
  return `${header('UNA CAJA QUE CUADRA', 'Controla cada sol.', 'Separa el efectivo de los pagos digitales y cierra con claridad.', `<button class="button ${state.session ? 'secondary' : 'primary'}" data-action="${state.session ? 'close-cash' : 'open-cash'}">${icon('cash')} ${state.session ? 'Cerrar caja' : 'Abrir caja'}</button>`)}<div class="stats-row"><div class="stat-card accent"><span>Efectivo esperado</span><strong>${money(cashBalance(state))}</strong><small>${state.session ? 'Incluye fondo inicial y movimientos' : 'Abre una caja para empezar'}</small></div><div class="stat-card"><span>Yape + Plin</span><strong>${money(digital('yape') + digital('plin'))}</strong><small>Confirmados manualmente por el cajero</small></div><div class="stat-card"><span>Tarjeta</span><strong>${money(digital('card'))}</strong><small>Pagos registrados en esta caja</small></div></div><div class="surface"><div class="section-heading"><div><h2>${state.session ? 'Movimientos de la caja actual' : 'Caja cerrada'}</h2>${state.session ? `<small>Abierta ${date(state.session.openedAt)} · Fondo ${money(state.session.opening)}</small>` : ''}</div>${state.session ? '<button class="button secondary" data-action="movement">Registrar movimiento</button>' : ''}</div>${
    movements.length
      ? `<div class="table-wrap"><table><thead><tr><th>Concepto</th><th>Hora</th><th>Tipo</th><th>Importe</th></tr></thead><tbody>${[
          ...movements,
        ]
          .reverse()
          .map(
            (m) =>
              `<tr><td>${esc(m.reason)}</td><td>${date(m.at)}</td><td>${{ sale: 'Venta en efectivo', income: 'Ingreso', expense: 'Salida' }[m.kind]}</td><td class="${m.amount < 0 ? 'negative' : 'positive'}"><strong>${m.amount < 0 ? '−' : '+'}${money(Math.abs(m.amount))}</strong></td></tr>`,
          )
          .join('')}</tbody></table></div>`
      : '<div class="empty-state compact"><p>Los ingresos y salidas de efectivo aparecerán aquí.</p></div>'
  }</div>${
    state.sessions.length
      ? `<div class="surface"><div class="section-heading"><h2>Cierres anteriores</h2></div><div class="table-wrap"><table><thead><tr><th>Cierre</th><th>Esperado</th><th>Contado</th><th>Diferencia</th></tr></thead><tbody>${[
          ...state.sessions,
        ]
          .reverse()
          .map(
            (s) =>
              `<tr><td>${date(s.closedAt)}</td><td>${money(s.expected)}</td><td>${money(s.counted)}</td><td class="${s.difference === 0 ? 'positive' : 'negative'}">${s.difference < 0 ? '−' : ''}${money(Math.abs(s.difference))}</td></tr>`,
          )
          .join('')}</tbody></table></div></div>`
      : ''
  }`;
}
function settingsView() {
  const v = state.settings;
  return `${header('HECHO PARA TU NEGOCIO', 'Dale tu nombre.', 'Personaliza tus recibos y cuida la información de tu tienda.')}<div class="settings-grid"><section class="surface"><div class="section-heading"><h2>Datos del negocio</h2></div><form id="settings-form" class="form-body"><label>Nombre del negocio<input name="storeName" value="${esc(v.storeName)}" maxlength="80" required/></label><label>Nombre del responsable<input name="owner" value="${esc(v.owner)}" maxlength="80"/></label><label>Dirección<input name="address" value="${esc(v.address)}" maxlength="160"/></label><label>RUC <span class="optional">opcional</span><input name="ruc" value="${esc(v.ruc)}" inputmode="numeric" pattern="[0-9]{11}" maxlength="11" placeholder="11 dígitos"/></label><button class="button primary" type="submit">Guardar datos ${icon('check')}</button></form></section><div><section class="surface backup-card"><div class="backup-icon">${icon('shield')}</div><h2>Tus datos merecen cuidado.</h2><p>Esta app guarda la información en este navegador. Exporta una copia periódicamente: borrar sus datos elimina el registro local.</p><button class="button primary" data-action="backup">${icon('download')} Descargar copia de seguridad</button><label class="button secondary import-button">Restaurar una copia<input id="backup-import" type="file" accept="application/json,.json" hidden/></label><button class="button text-button" data-action="persist">Solicitar almacenamiento persistente</button></section><section class="surface pilot-info"><span class="tiny-pill">ALCANCE DEL PILOTO</span><p>Ventas, stock, caja y recibos locales. Yape, Plin y tarjeta se confirman manualmente.</p><p>Los recibos son comerciales: no son boletas ni facturas electrónicas. Esta versión no incluye SUNAT, fiado, sincronización ni impresión Bluetooth.</p>${installPrompt ? '<button class="button secondary" data-action="install">Instalar en este dispositivo</button>' : ''}</section></div></div>`;
}
function updateGrid() {
  $('#product-grid').innerHTML = productGrid();
  $('#product-count').textContent = visibleProducts().length;
}
function afterRender() {
  if (view === 'sell') $('#product-count').textContent = visibleProducts().length;
}
function refresh() {
  render();
  afterRender();
}
function modal(title, subtitle, content, kind = '') {
  lastFocus = document.activeElement;
  modalKind = kind;
  $('#modal-root').innerHTML =
    `<div class="modal-backdrop"><section class="modal ${kind === 'receipt' ? 'receipt-modal' : ''}" role="dialog" aria-modal="true" aria-labelledby="modal-title"><div class="modal-heading"><div><h2 id="modal-title">${title}</h2><p>${subtitle}</p></div><button class="icon-button" data-action="close-modal" aria-label="Cerrar ventana">${icon('close')}</button></div>${content}</section></div>`;
  document.body.classList.add('modal-open');
  setTimeout(
    () =>
      $('#modal-root input:not([type=checkbox]), #modal-root select, #modal-root button')?.focus(),
    30,
  );
}
function closeModal() {
  $('#modal-root').innerHTML = '';
  document.body.classList.remove('modal-open');
  modalKind = null;
  lastFocus?.focus();
}
async function change(action) {
  if (busy) return null;
  busy = true;
  try {
    const outcome = await commit(action, state.revision);
    state = outcome.state;
    refresh();
    return outcome;
  } catch (error) {
    try {
      state = await readState();
      refresh();
    } catch {
      /* Keep visible state; the error remains explicit. */
    }
    toast(error.message, true);
    return null;
  } finally {
    busy = false;
  }
}
function productModal(product = null) {
  const p = product ?? {
    name: '',
    category: 'Abarrotes',
    price: 0,
    stock: 0,
    unit: 'und',
    barcode: '',
  };
  modal(
    product ? 'Editar producto' : 'Un nuevo producto para tu tienda',
    'El stock y el precio se guardan en este dispositivo.',
    `<form id="product-form" class="form-body" data-id="${esc(product?.id ?? '')}"><label>Nombre del producto<input name="name" value="${esc(p.name)}" maxlength="100" required placeholder="Ej. Café molido 250 g"/></label><div class="form-row"><label>Categoría<input name="category" value="${esc(p.category)}" maxlength="50" required list="categories"/><datalist id="categories">${[...new Set(state.products.map((p) => p.category))].map((c) => `<option value="${esc(c)}"></option>`).join('')}</datalist></label><label>Unidad de venta<select name="unit">${[
      ['und', 'Unidad'],
      ['kg', 'Kilogramo'],
      ['L', 'Litro'],
    ]
      .map(
        ([u, label]) => `<option value="${u}" ${p.unit === u ? 'selected' : ''}>${label}</option>`,
      )
      .join(
        '',
      )}</select></label></div><div class="form-row"><label>Precio por unidad (S/)<input name="price" value="${product ? (p.price / 100).toFixed(2) : ''}" inputmode="decimal" required placeholder="0.00"/></label><label>Stock disponible<input name="stock" value="${p.stock / 1000}" inputmode="decimal" required/></label></div><label>Código de barras <span class="optional">opcional</span><input name="barcode" value="${esc(p.barcode)}" maxlength="60" placeholder="Escanea o escribe el código"/></label><p class="form-note">En granel puedes usar hasta 3 decimales: 0.250 kg = 250 gramos. Editar stock es un ajuste manual en este piloto.</p><div class="modal-actions">${product ? `<button type="button" class="button danger-text" data-archive="${esc(p.id)}">Archivar</button>` : '<button type="button" class="button secondary" data-action="close-modal">Cancelar</button>'}<button class="button primary" type="submit">Guardar producto</button></div></form>`,
    'product',
  );
}
function openCashModal() {
  if (state.session) {
    view = 'cash';
    refresh();
    return;
  }
  modal(
    'Empecemos una buena jornada.',
    'Abre la caja e indica con cuánto efectivo empiezas.',
    `<form id="open-cash-form" class="form-body"><label>Fondo inicial en efectivo (S/)<input name="opening" inputmode="decimal" value="0.00" required/></label><p class="form-note">No es una venta. Este importe sirve para calcular cuánto efectivo debe quedar al cerrar.</p><button class="button primary full" type="submit">Abrir caja ${icon('arrow')}</button></form>`,
    'open-cash',
  );
}
function checkoutModal() {
  if (!state.cart.length) return;
  if (!state.session) {
    openCashModal();
    toast('Abre tu caja y luego pulsa Cobrar.');
    return;
  }
  paymentMethod = 'cash';
  const total = totals(state).total;
  modal(
    'Un paso más. Venta lista.',
    'Selecciona cómo te paga tu cliente.',
    `<form id="checkout-form" class="form-body" data-cart-key="${esc(cartKey(state))}"><div class="checkout-total"><span>Total a cobrar</span><strong>${money(total)}</strong><small>${state.cart.length} productos · Precio final</small></div><div class="payment-methods">${[
      ['cash', 'Efectivo'],
      ['yape', 'Yape'],
      ['plin', 'Plin'],
      ['card', 'Tarjeta'],
      ['mixed', 'Mixto'],
    ]
      .map(
        ([method, label]) =>
          `<button type="button" data-method="${method}" class="payment-method ${method === 'cash' ? 'selected' : ''}">${label}</button>`,
      )
      .join(
        '',
      )}</div><div id="payment-fields">${paymentFields(total)}</div><div class="non-fiscal">${icon('shield')} Se guardará un recibo comercial, sin envío a SUNAT.</div><button class="button primary full" type="submit" id="confirm-payment">Confirmar venta · ${money(total)} ${icon('check')}</button></form>`,
    'checkout',
  );
}
function paymentFields(total) {
  if (paymentMethod === 'cash')
    return `<label>Efectivo recibido (S/)<input id="cash-received" name="cash" inputmode="decimal" placeholder="${(total / 100).toFixed(2)}" value="${(total / 100).toFixed(2)}" required/></label><div class="quick-cash">${[
      1000, 2000, 5000, 10000,
    ]
      .filter((n) => n >= total)
      .map((n) => `<button type="button" data-cash="${n}">${money(n)}</button>`)
      .join(
        '',
      )}</div><div class="change-preview"><span>Vuelto para tu cliente</span><strong id="change-value">${money(0)}</strong></div>`;
  if (paymentMethod === 'mixed')
    return `<div class="form-row"><label>Medio digital<select name="digitalMethod"><option value="yape">Yape</option><option value="plin">Plin</option><option value="card">Tarjeta</option></select></label><label>Importe digital (S/)<input name="digital" id="digital-received" inputmode="decimal" placeholder="0.00" required/></label></div><label>Efectivo recibido (S/)<input id="cash-received" name="cash" inputmode="decimal" placeholder="0.00" required/></label><div class="change-preview"><span>Vuelto para tu cliente</span><strong id="change-value">${money(0)}</strong></div>${digitalConfirmation()}`;
  return `<div class="digital-info ${paymentMethod}"><strong>${methods[paymentMethod]} · ${money(total)}</strong><p>Verifica el abono en tu cuenta o terminal antes de continuar. Zivlo no verifica el pago automáticamente.</p></div>${digitalConfirmation()}`;
}
function digitalConfirmation() {
  return '<label class="checkbox-label"><input type="checkbox" name="digitalConfirmed" required/><span>Confirmo que recibí el pago digital.</span></label>';
}
function updateChange() {
  if (!$('#change-value')) return;
  try {
    const cash = decimal($('#cash-received').value || '0');
    const digital = $('#digital-received') ? decimal($('#digital-received').value || '0') : 0;
    const n = cash + digital - totals(state).total;
    $('#change-value').textContent = n < 0 ? `Faltan ${money(-n)}` : money(n);
  } catch {
    $('#change-value').textContent = 'Revisa los importes';
  }
}
function receiptModal(sale, success = false) {
  modal(
    success ? '¡Venta guardada!' : `Recibo #${String(sale.number).padStart(4, '0')}`,
    success
      ? 'El stock y la caja ya están actualizados.'
      : 'Una copia de lo que vendiste, tal como se registró.',
    `<div class="receipt-paper" id="receipt"><div class="receipt-brand">zivlo.</div><h3>${esc(sale.store.storeName)}</h3>${sale.store.address ? `<p>${esc(sale.store.address)}</p>` : ''}${sale.store.ruc ? `<p>RUC ${esc(sale.store.ruc)}</p>` : ''}<p>RECIBO COMERCIAL · #${String(sale.number).padStart(4, '0')}</p><p>${date(sale.at)} · Perú</p><hr/>${sale.lines.map((l) => `<div class="receipt-line"><div><strong>${esc(l.name)}</strong><small>${quantity(l.quantity, l.unit)} × ${money(l.price)}</small></div><strong>${money(l.total)}</strong></div>`).join('')}<hr/><div class="receipt-total"><span>TOTAL</span><strong>${money(sale.total)}</strong></div>${sale.payments.map((p) => `<div class="receipt-line"><span>${methods[p.method]}${p.method === 'cash' ? ' recibido' : ''}</span><span>${money(p.amount)}</span></div>`).join('')}<div class="receipt-line"><span>Vuelto</span><strong>${money(sale.change)}</strong></div><hr/><p class="receipt-thanks">Gracias por comprar en tu barrio.</p><p class="receipt-disclaimer">Este recibo no es un comprobante de pago tributario.<br>No reemplaza una boleta ni una factura.</p></div><div class="modal-actions receipt-actions"><button class="button secondary" data-action="print">${icon('print')} Imprimir recibo</button><button class="button primary" data-action="close-modal">${success ? 'Nueva venta' : 'Listo'} ${icon('arrow')}</button></div>`,
    'receipt',
  );
}
function downloadBackup() {
  const blob = new Blob([JSON.stringify(state, null, 2)], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `zivlo-copia-${day(Date.now())}.json`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  toast('Copia descargada. Guárdala en un lugar seguro.');
}

document.addEventListener('click', async (event) => {
  const target = event.target.closest('button, a, [data-category]');
  if (!target || busy || target.disabled) return;
  if (target.dataset.nav) {
    event.preventDefault();
    view = target.dataset.nav;
    search = '';
    refresh();
    return;
  }
  if (target.dataset.category) {
    category = target.dataset.category;
    refresh();
    return;
  }
  if (target.dataset.add) {
    const p = state.products.find((p) => p.id === target.dataset.add);
    if (p.unit !== 'und') {
      modal(
        `¿Cuánto de ${esc(p.name)}?`,
        `${money(p.price)} por ${esc(p.unit)} · Stock ${quantity(p.stock, p.unit)}`,
        `<form id="quantity-form" class="form-body" data-id="${esc(p.id)}" data-add="true"><label>Cantidad en ${esc(p.unit)}<input name="quantity" value="1" inputmode="decimal" required/></label><p class="form-note">Ejemplo: 0.250 kg para 250 gramos.</p><button class="button primary full" type="submit">Agregar al carrito</button></form>`,
        'quantity',
      );
    } else {
      await change({ type: 'cart-add', productId: p.id });
    }
    return;
  }
  if (target.dataset.qty) {
    const item = state.cart.find((i) => i.productId === target.dataset.qty);
    const p = state.products.find((p) => p.id === item.productId);
    const step = p.unit === 'und' ? 1000 : 250;
    await change({
      type: 'cart-quantity',
      productId: p.id,
      quantity: Math.max(0, item.quantity + Number(target.dataset.delta) * step),
    });
    return;
  }
  if (target.dataset.editQty) {
    const item = state.cart.find((i) => i.productId === target.dataset.editQty);
    const p = state.products.find((p) => p.id === item.productId);
    modal(
      'Ajustar cantidad',
      `${esc(p.name)} · ${money(item.price)} / ${esc(p.unit)}`,
      `<form id="quantity-form" class="form-body" data-id="${esc(p.id)}"><label>Cantidad en ${esc(p.unit)}<input name="quantity" value="${item.quantity / 1000}" inputmode="decimal" required/></label><p class="form-note">Usa 0 para retirar el producto.</p><button class="button primary full" type="submit">Actualizar cantidad</button></form>`,
      'quantity',
    );
    return;
  }
  if (target.dataset.product) {
    productModal(state.products.find((p) => p.id === target.dataset.product));
    return;
  }
  if (target.dataset.receipt) {
    receiptModal(state.sales.find((s) => s.id === target.dataset.receipt));
    return;
  }
  if (target.dataset.saleFilter) {
    saleFilter = target.dataset.saleFilter;
    refresh();
    return;
  }
  if (target.dataset.archive) {
    if (!confirm('¿Archivar este producto? Las ventas anteriores se conservarán.')) return;
    if (await change({ type: 'archive-product', productId: target.dataset.archive })) {
      closeModal();
      toast('Producto archivado.');
    }
    return;
  }
  if (target.dataset.method) {
    paymentMethod = target.dataset.method;
    document
      .querySelectorAll('[data-method]')
      .forEach((b) => b.classList.toggle('selected', b === target));
    $('#payment-fields').innerHTML = paymentFields(totals(state).total);
    updateChange();
    return;
  }
  if (target.dataset.cash) {
    $('#cash-received').value = (Number(target.dataset.cash) / 100).toFixed(2);
    updateChange();
    return;
  }
  switch (target.dataset.action) {
    case 'close-modal':
      closeModal();
      break;
    case 'new-product':
      productModal();
      break;
    case 'clear-cart':
      if (confirm('¿Vaciar los productos de esta venta?')) await change({ type: 'cart-clear' });
      break;
    case 'checkout':
      checkoutModal();
      break;
    case 'see-cart':
      $('.cart-panel')?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      break;
    case 'open-cash':
      openCashModal();
      break;
    case 'close-cash':
      modal(
        'Cerremos la jornada.',
        `Efectivo esperado: ${money(cashBalance(state))}`,
        `<form id="close-cash-form" class="form-body"><label>Efectivo contado en caja (S/)<input name="counted" inputmode="decimal" required placeholder="0.00"/></label><p class="form-note">Cuenta los billetes y monedas. Los pagos Yape, Plin y tarjeta no forman parte del efectivo.</p><button class="button primary full" type="submit">Confirmar cierre</button></form>`,
        'close-cash',
      );
      break;
    case 'movement':
      modal(
        'Registrar movimiento de caja',
        'Anota los ingresos y salidas que no son ventas.',
        `<form id="movement-form" class="form-body"><label>Tipo<select name="kind"><option value="expense">Salida / gasto</option><option value="income">Ingreso</option></select></label><label>Importe (S/)<input name="amount" inputmode="decimal" required/></label><label>Motivo<input name="reason" maxlength="120" required placeholder="Ej. Compra de bolsas"/></label><button class="button primary full" type="submit">Guardar movimiento</button></form>`,
        'movement',
      );
      break;
    case 'backup':
      downloadBackup();
      break;
    case 'persist': {
      const persisted = await navigator.storage?.persist?.();
      toast(
        persisted
          ? 'El navegador concedió almacenamiento persistente. Mantén tus copias de seguridad.'
          : 'El navegador no concedió almacenamiento persistente. Descarga copias regularmente.',
      );
      break;
    }
    case 'print':
      window.print();
      break;
    case 'install':
      if (installPrompt) {
        await installPrompt.prompt();
        installPrompt = null;
      }
      break;
  }
});
document.addEventListener('input', (event) => {
  if (event.target.id === 'product-search') {
    search = event.target.value;
    updateGrid();
  }
  if (['cash-received', 'digital-received'].includes(event.target.id)) updateChange();
});
document.addEventListener('keydown', async (event) => {
  if (event.key === 'Escape' && modalKind && !busy) closeModal();
  if (event.key === 'Tab' && modalKind) {
    const nodes = [
      ...document.querySelectorAll(
        '#modal-root button:not(:disabled), #modal-root input, #modal-root select',
      ),
    ].filter((n) => n.offsetParent !== null);
    const first = nodes[0],
      last = nodes.at(-1);
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last?.focus();
    }
    if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first?.focus();
    }
  }
  if (event.key === 'Enter' && event.target.id === 'product-search') {
    const p = state.products.find((p) => p.active && p.barcode === search.trim());
    if (p) {
      event.preventDefault();
      document.querySelector(`[data-add="${CSS.escape(p.id)}"]`)?.click();
      search = '';
      $('#product-search').value = '';
      updateGrid();
    }
  }
});
document.addEventListener('submit', async (event) => {
  event.preventDefault();
  if (busy) return;
  const form = event.target,
    v = Object.fromEntries(new FormData(form));
  try {
    if (form.id === 'settings-form') {
      if (await change({ type: 'settings', settings: v })) toast('Datos del negocio guardados.');
    }
    if (form.id === 'product-form') {
      const product = {
        ...v,
        id: form.dataset.id || undefined,
        price: decimal(v.price),
        stock: decimal(v.stock, 3),
      };
      if (await change({ type: 'save-product', product })) {
        closeModal();
        toast('Producto guardado.');
      }
    }
    if (form.id === 'quantity-form') {
      if (
        await change({
          type: form.dataset.add ? 'cart-add' : 'cart-quantity',
          productId: form.dataset.id,
          quantity: decimal(v.quantity, 3),
        })
      )
        closeModal();
    }
    if (form.id === 'open-cash-form') {
      if (await change({ type: 'open-session', opening: decimal(v.opening) })) {
        closeModal();
        toast('Caja abierta. Ya puedes vender.');
      }
    }
    if (form.id === 'movement-form') {
      if (
        await change({
          type: 'cash-movement',
          amount: decimal(v.amount),
          kind: v.kind,
          reason: v.reason,
        })
      ) {
        closeModal();
        toast('Movimiento guardado.');
      }
    }
    if (form.id === 'close-cash-form') {
      const outcome = await change({ type: 'close-session', counted: decimal(v.counted) });
      if (outcome) {
        closeModal();
        toast(
          `Caja cerrada. Diferencia: ${outcome.result.difference < 0 ? '−' : ''}${money(Math.abs(outcome.result.difference))}.`,
        );
      }
    }
    if (form.id === 'checkout-form') {
      const total = totals(state).total;
      let payments;
      if (paymentMethod === 'cash') payments = [{ method: 'cash', amount: decimal(v.cash) }];
      else if (paymentMethod === 'mixed')
        payments = [
          { method: v.digitalMethod, amount: decimal(v.digital) },
          { method: 'cash', amount: decimal(v.cash) },
        ].filter((p) => p.amount > 0);
      else payments = [{ method: paymentMethod, amount: total }];
      const button = $('#confirm-payment');
      button.disabled = true;
      button.textContent = 'Guardando venta…';
      const outcome = await change({
        type: 'checkout',
        cartKey: form.dataset.cartKey,
        payments,
        digitalConfirmed: v.digitalConfirmed === 'on',
      });
      if (outcome) {
        closeModal();
        receiptModal(outcome.result, true);
      } else {
        button.disabled = false;
        button.textContent = `Confirmar venta · ${money(total)}`;
      }
    }
  } catch (error) {
    toast(error.message, true);
  }
});
document.addEventListener('change', async (event) => {
  if (event.target.id !== 'backup-import') return;
  const file = event.target.files[0];
  if (!file) return;
  try {
    if (file.size > 10_000_000) throw new Error('La copia supera el límite de 10 MB del piloto.');
    const data = validateBackup(JSON.parse(await file.text()));
    if (
      !confirm(
        `Restaurar "${data.settings.storeName}" con ${data.sales.length} ventas reemplazará todos los datos actuales. Descarga una copia antes de continuar. ¿Restaurar?`,
      )
    )
      return;
    if (await change({ type: 'restore', state: data })) toast('Copia restaurada correctamente.');
  } catch (error) {
    toast(`No se restauró la copia: ${error.message}`, true);
  } finally {
    event.target.value = '';
  }
});
window.addEventListener('beforeinstallprompt', (event) => {
  event.preventDefault();
  installPrompt = event;
  if (view === 'settings') refresh();
});
onOtherTab(async () => {
  state = await readState();
  refresh();
  if (modalKind) closeModal();
  toast('Datos actualizados desde otra pestaña.');
});
async function start() {
  try {
    await openDatabase();
    state = await readState();
    refresh();
    if ('serviceWorker' in navigator && !standaloneMode && location.protocol !== 'file:') {
      try {
        await navigator.serviceWorker.register('./sw.js');
        await navigator.serviceWorker.ready;
        offlineReady = true;
        refresh();
      } catch {
        toast('La venta local funciona; la recarga sin internet todavía no está disponible.', true);
      }
    }
  } catch (error) {
    $('#app').innerHTML =
      `<div class="boot"><h1>No pudimos iniciar Zivlo</h1><p>${esc(error.message)}</p><p>Abre la aplicación desde su servidor local, no haciendo doble clic en el HTML.</p></div>`;
  }
}
start();
