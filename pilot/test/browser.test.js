import assert from 'node:assert/strict';
import { chromium } from 'playwright';
import { spawn } from 'node:child_process';
import { mkdir, mkdtemp, readFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const artifacts = process.env.BROWSER_ARTIFACTS || join(root, 'test-results');
const temp = await mkdtemp(join(tmpdir(), 'zivlo-browser-'));
const port = process.env.TEST_PORT || '4180';
const server = spawn(process.execPath, ['server.js'], {
  cwd: root,
  env: { ...process.env, PORT: port },
  stdio: ['ignore', 'pipe', 'pipe'],
});
await new Promise((resolve, reject) => {
  server.stdout.once('data', resolve);
  server.once('error', reject);
  server.once('exit', (code) => reject(new Error(`El servidor terminó: ${code}`)));
});
await mkdir(artifacts, { recursive: true });
let browser;
const errors = [];
const log = (name) => console.log(`✓ ${name}`);
try {
  browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium',
    headless: true,
    args: ['--no-sandbox'],
  });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
    acceptDownloads: true,
  });
  const page = await context.newPage();
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => {
    if (m.type() === 'error') errors.push(m.text());
  });
  page.on('dialog', (dialog) => dialog.accept());
  const state = () => page.evaluate(async () => (await import('/src/storage.js')).readState());
  const nav = (name) => page.locator(`.sidebar button[data-nav="${name}"]`).click();
  const add = (id) => page.locator(`[data-add="product-${id}"]`).click();
  const confirmPayment = () => page.locator('#confirm-payment').click();
  const close = () => page.locator('[data-action="close-modal"]').first().click();
  await page.goto(`http://127.0.0.1:${port}`);
  await page.waitForSelector('[data-add]');
  await page.waitForFunction(() =>
    document.querySelector('#offline-status')?.textContent.includes('Listo sin internet'),
  );
  await page.screenshot({ path: join(artifacts, 'desktop.png'), fullPage: true });
  assert.equal((await state()).products.length, 12);
  log('Catálogo inicial y aplicación cargados');

  await page.locator('[data-action="open-cash"]').click();
  await page.locator('[name="opening"]').fill('100.00');
  await page.locator('#open-cash-form button[type="submit"]').click();
  await page.waitForSelector('.cash-status:not(.closed)');
  assert.equal((await state()).session.opening, 10000);
  log('Apertura de caja con fondo de S/ 100.00');

  await add(2);
  await page.waitForSelector('[data-edit-qty="product-2"]');
  await add(3);
  await page.waitForSelector('[data-edit-qty="product-3"]');
  await page.locator('.checkout-button').click();
  await page.locator('#cash-received').fill('10');
  await confirmPayment();
  await page.waitForFunction(() =>
    document.querySelector('#toast').textContent.includes('no cubre'),
  );
  assert.equal((await state()).sales.length, 0);
  assert.equal((await state()).products[1].stock, 18000);
  log('Pago insuficiente rechazado sin modificar ventas ni stock');
  await page.locator('#cash-received').fill('20');
  await page.evaluate(() => {
    const f = document.querySelector('#checkout-form');
    f.requestSubmit();
    f.requestSubmit();
  });
  await page.waitForSelector('#receipt');
  let saved = await state();
  assert.equal(saved.sales.length, 1);
  assert.equal(saved.sales[0].total, 1370);
  assert.equal(saved.sales[0].change, 630);
  assert.equal(saved.products[1].stock, 17000);
  assert.equal(saved.cart.length, 0);
  log('Cobro, vuelto, stock, recibo y protección contra doble envío');
  await close();
  await nav('sales');
  await page.locator('[data-receipt]').click();
  assert.match(await page.locator('#receipt').textContent(), /13.70/);
  await close();
  await nav('sell');
  log('Historial y reapertura de recibo');

  for (const method of ['yape', 'plin']) {
    await add(7);
    await page.waitForSelector('[data-edit-qty="product-7"]');
    await page.locator('.checkout-button').click();
    await page.locator(`[data-method="${method}"]`).click();
    const before = (await state()).sales.length;
    await confirmPayment();
    assert.equal((await state()).sales.length, before);
    await page.locator('[name="digitalConfirmed"]').check();
    await confirmPayment();
    await page.waitForSelector('#receipt');
    saved = await state();
    assert.equal(saved.sales.at(-1).payments[0].method, method);
    await close();
    log(`${method}: confirmación obligatoria y cobro registrado`);
  }
  await add(2);
  await page.waitForSelector('[data-edit-qty="product-2"]');
  await page.locator('.checkout-button').click();
  await page.locator('[data-method="mixed"]').click();
  await page.locator('[name="digital"]').fill('5');
  await page.locator('[name="cash"]').fill('10');
  await page.locator('[name="digitalConfirmed"]').check();
  await confirmPayment();
  await page.waitForSelector('#receipt');
  saved = await state();
  assert.equal(saved.sales.at(-1).change, 550);
  assert.equal(saved.movements.at(-1).amount, 450);
  await close();
  log('Pago mixto separa efectivo y digital y calcula el vuelto');

  await add(1);
  await page.locator('#quantity-form [name="quantity"]').fill('0.250');
  await page.locator('#quantity-form button[type="submit"]').click();
  await page.waitForSelector('[data-edit-qty="product-1"]');
  assert.equal((await state()).cart[0].quantity, 250);
  await page.reload();
  await page.waitForSelector('[data-edit-qty="product-1"]');
  assert.equal((await state()).cart[0].quantity, 250);
  log('Venta a granel y recuperación del carrito tras recarga');
  await page.locator('[data-edit-qty="product-1"]').click();
  await page.locator('[name="quantity"]').fill('0');
  await page.locator('#quantity-form button[type="submit"]').click();
  await page.waitForSelector('.cart-empty');
  await page.locator('#product-search').fill('7750000000035');
  await page.locator('#product-search').press('Enter');
  await page.waitForSelector('[data-edit-qty="product-3"]');
  assert.equal((await state()).cart[0].productId, 'product-3');
  await page.locator('[data-action="clear-cart"]').click();
  await page.waitForSelector('.cart-empty');
  log('Búsqueda exacta por código de barras y vaciado de carrito');

  await nav('catalog');
  await page.locator('[data-action="new-product"]').click();
  await page.locator('[name="name"]').fill('Café de prueba');
  await page.locator('[name="price"]').fill('5,50');
  await page.locator('[name="stock"]').fill('10');
  await page.locator('[name="barcode"]').fill('CAFE-001');
  await page.locator('#product-form button[type="submit"]').click();
  await page.waitForSelector('td:has-text("Café de prueba")');
  saved = await state();
  const coffee = saved.products.find((p) => p.barcode === 'CAFE-001');
  assert.equal(coffee.price, 550);
  await page.locator(`[data-product="${coffee.id}"]`).click();
  await page.locator('[name="price"]').fill('6.20');
  await page.locator('#product-form button[type="submit"]').click();
  await page.waitForFunction(() => !document.querySelector('#product-form'));
  assert.equal((await state()).products.find((p) => p.id === coffee.id).price, 620);
  log('Creación y edición de catálogo con precio en soles');

  await nav('cash');
  await page.locator('[data-action="movement"]').click();
  await page.locator('[name="amount"]').fill('2');
  await page.locator('[name="reason"]').fill('Bolsas');
  await page.locator('#movement-form button[type="submit"]').click();
  await page.waitForSelector('td:has-text("Bolsas")');
  saved = await state();
  const expected =
    saved.session.opening +
    saved.movements
      .filter((m) => m.sessionId === saved.session.id)
      .reduce((n, m) => n + m.amount, 0);
  assert.equal(expected, 11620);
  await page.locator('[data-action="close-cash"]').click();
  await page.locator('[name="counted"]').fill('116.20');
  await page.locator('#close-cash-form button[type="submit"]').click();
  await page.waitForSelector('.cash-status.closed');
  assert.equal((await state()).sessions[0].difference, 0);
  log('Gasto, balance de efectivo y cierre de caja sin diferencia');

  await nav('settings');
  await page.locator('[name="storeName"]').fill('Bodega del barrio');
  await page.locator('#settings-form button[type="submit"]').click();
  await page.waitForFunction(
    () => document.querySelector('.store-mini strong')?.textContent === 'Bodega del barrio',
  );
  const downloadEvent = page.waitForEvent('download');
  await page.locator('[data-action="backup"]').click();
  const download = await downloadEvent;
  const backupPath = join(temp, 'backup.json');
  await download.saveAs(backupPath);
  const backup = JSON.parse(await readFile(backupPath, 'utf8'));
  assert.equal(backup.sales.length, 4);
  await page.locator('[name="storeName"]').fill('Temporal');
  await page.locator('#settings-form button[type="submit"]').click();
  await page.waitForFunction(
    () => document.querySelector('.store-mini strong')?.textContent === 'Temporal',
  );
  await page.locator('#backup-import').setInputFiles(backupPath);
  await page.waitForFunction(
    () => document.querySelector('.store-mini strong')?.textContent === 'Bodega del barrio',
  );
  assert.equal((await state()).sales.length, 4);
  log('Personalización, exportación y restauración de copia completa');

  const second = await context.newPage();
  await second.goto(`http://127.0.0.1:${port}`);
  await second.waitForSelector('[data-add]');
  await nav('sell');
  await add(7);
  await page.waitForSelector('[data-edit-qty="product-7"]');
  await second.waitForSelector('[data-edit-qty="product-7"]');
  assert.equal((await state()).cart.length, 1);
  await second.close();
  log('Actualización entre pestañas');

  await page.evaluate(async () => {
    await navigator.serviceWorker.ready;
    if (!navigator.serviceWorker.controller)
      await new Promise((resolve) =>
        navigator.serviceWorker.addEventListener('controllerchange', resolve, { once: true }),
      );
  });
  await context.setOffline(true);
  await page.reload();
  await page.waitForSelector('[data-add]');
  await page.locator('[data-action="open-cash"]').click();
  await page.locator('[name="opening"]').fill('0');
  await page.locator('#open-cash-form button[type="submit"]').click();
  await page.waitForSelector('.cash-status:not(.closed)');
  await page.locator('.checkout-button').click();
  await confirmPayment();
  await page.waitForSelector('#receipt');
  assert.equal((await state()).sales.length, 5);
  await close();
  log('Recarga y venta completa sin conexión');

  await page.setViewportSize({ width: 390, height: 844 });
  await add(3);
  await page.waitForSelector('.mobile-cart-bar');
  await page.locator('.mobile-cart-bar [data-action="checkout"]').click();
  await page.waitForSelector('#checkout-form');
  await close();
  await page.screenshot({ path: join(artifacts, 'mobile.png'), fullPage: false });
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false);
  await nav('sales');
  await page.locator('[data-receipt]').first().click();
  await page.emulateMedia({ media: 'print' });
  await page.pdf({ path: join(artifacts, 'receipt.pdf'), width: '80mm', printBackground: true });
  await page.emulateMedia({ media: 'screen' });
  log('Vista móvil sin desbordamiento y recibo imprimible');
  assert.deepEqual(errors, []);
  log('Sin errores de JavaScript ni de consola');

  const standaloneContext = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const standalone = await standaloneContext.newPage();
  const standaloneErrors = [],
    requests = [];
  standalone.on('pageerror', (e) => standaloneErrors.push(e.message));
  standalone.on('request', (r) => {
    if (r.url().startsWith('http')) requests.push(r.url());
  });
  await standalone.goto(`http://127.0.0.1:${port}/dist/Zivlo-Peru.html`);
  await standalone.waitForSelector('[data-add]');
  await standaloneContext.setOffline(true);
  await standalone.locator('[data-action="open-cash"]').click();
  await standalone.locator('[name="opening"]').fill('20');
  await standalone.locator('#open-cash-form button[type="submit"]').click();
  await standalone.waitForSelector('.cash-status:not(.closed)');
  await standalone.locator('[data-add="product-2"]').click();
  await standalone.waitForSelector('[data-edit-qty="product-2"]');
  await standalone.locator('.checkout-button').click();
  await standalone.locator('#cash-received').fill('10');
  await standalone.locator('#confirm-payment').click();
  await standalone.waitForSelector('#receipt');
  assert.match(await standalone.locator('#receipt').textContent(), /S\/ 0.50/);
  await standalone.locator('[data-action="close-modal"]').first().click();
  // The managed browser blocks file:// navigation. Exercise the exact
  // bundled document offline without changing that browser policy.
  const offlineDocument = await standaloneContext.newPage();
  offlineDocument.on('pageerror', (e) => standaloneErrors.push(e.message));
  await offlineDocument.route(`http://127.0.0.1:${port}/dist/Zivlo-Peru.html`, (route) =>
    route.fulfill({ contentType: 'text/html', path: join(root, 'dist/Zivlo-Peru.html') }),
  );
  await offlineDocument.goto(`http://127.0.0.1:${port}/dist/Zivlo-Peru.html`);
  await offlineDocument.waitForSelector('[data-add]');
  await offlineDocument.locator('.sidebar button[data-nav="sales"]').click();
  assert.equal(await offlineDocument.locator('[data-receipt]').count(), 1);
  assert.equal(requests.length, 1);
  assert.match(requests[0], /\/dist\/Zivlo-Peru.html$/);
  assert.deepEqual(standaloneErrors, []);
  log('HTML autónomo: apertura, cobro, vuelto y recuperación offline sin recursos externos');
  console.log('Todos los flujos de navegador pasaron.');
} finally {
  await browser?.close();
  server.kill();
}
