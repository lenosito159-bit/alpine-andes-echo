# Zivlo Perú · Piloto para probar hoy

Una aplicación web local añadida al repositorio Flutter existente. No reemplaza ni valida el cliente Android: permite probar hoy el flujo de negocio adaptado a una bodega peruana, con datos persistentes y operaciones reales en el navegador.

## Probar sin instalar herramientas

Abre `dist/Zivlo-Peru.html` en Chrome o Edge en una computadora. Es un archivo autónomo: no necesita servidor, internet, paquetes ni una cuenta. La compilación del archivo se hace con `node build.js`; la entrega empaquetada lo incluye ya generado.

1. Pulsa **Abrir caja** e ingresa un fondo inicial, por ejemplo S/ 100.00.
2. Agrega aceite y leche: el total será S/ 13.70.
3. Pulsa **Cobrar**, ingresa S/ 20.00 y confirma. El vuelto será S/ 6.30.
4. Abre **Ventas** para consultar el recibo y **Productos** para ver el stock actualizado.
5. En otra venta, elige Yape o Plin. Debes verificar el pago por tu cuenta y marcar la confirmación antes de registrar la venta.
6. Prueba arroz a granel: 0.250 kg cuesta S/ 1.13, redondeado al céntimo por línea.
7. En **Caja**, registra gastos y cierra indicando el efectivo contado.
8. En **Mi negocio**, descarga una copia de seguridad antes de terminar.

El catálogo inicial contiene 12 productos y códigos ficticios de ejemplo; no son precios de mercado verificados. Edita nombres, precios, códigos y stock en **Productos**. Cambiar un precio conserva el precio de los productos que ya estaban en el carrito y el historial de ventas.

Mantén el archivo en la misma ubicación y usa el mismo navegador para recuperar los datos. La persistencia de archivos locales depende del navegador. El documento autónomo se verificó en Chromium servido por HTTP y recreado sin conexión; la política del navegador de este entorno bloquea abrir archivos `file://`, así que esa apertura directa no se validó aquí. Si tu navegador bloquea archivos locales o su almacenamiento, usa el servidor de la sección siguiente. Los datos del archivo autónomo y de la versión servida pertenecen a orígenes diferentes: usa exportar/restaurar para trasladarlos.

## Usar la versión web / PWA

Se necesita Node.js 20 o superior. No hay dependencias de ejecución ni paso obligatorio de instalación:

```bash
cd pilot
npm start
```

El servidor usa el puerto 4173. Abre la app en el navegador del equipo que lo ejecuta. Para usar otro puerto: `PORT=5000 npm start` en macOS/Linux.

La PWA guarda los archivos necesarios mediante un service worker. Una vez que muestra **Listo sin internet**, puede recargarse sin conexión y seguir vendiendo. La PWA y el almacenamiento persistente requieren un origen seguro: HTTPS o localhost. Abrir desde un celular por HTTP a la IP de una computadora permite usar la interfaz, pero no garantiza la recarga offline. Para uso instalado en celular, sirve el directorio `pilot` por HTTPS. Este piloto no incluye alojamiento público ni un APK.

## Funciones comprobadas

- Catálogo: creación, edición, archivado, búsqueda por nombre/código y categorías.
- Carrito guardado automáticamente, cantidades enteras o fraccionarias y validación de stock.
- Soles calculados en céntimos; cantidades almacenadas en milésimas de unidad.
- Efectivo, Yape, Plin, tarjeta y combinación de efectivo con un pago digital.
- Pago digital confirmado manualmente; vuelto solo del efectivo.
- Venta, pagos, reducción de stock y movimiento de caja guardados en una transacción IndexedDB.
- Prevención de doble envío y control de revisión para operaciones concurrentes entre pestañas.
- Historial con fechas de Perú y recibos que conservan los datos originales.
- Apertura, ingresos, gastos, cierre y diferencia de caja.
- Impresión de recibo comercial usando el diálogo del navegador.
- Exportación y restauración de copia JSON con validación de estructura e importes.
- Interfaz adaptable a celular, con acceso fijo al cobro cuando hay productos en el carrito.

## Límites de esta entrega

Es un piloto para validar el flujo, no un sistema tributario ni una integración bancaria. No emite comprobantes SUNAT, no verifica transferencias ni procesa tarjetas. No incluye fiado, anulaciones, autenticación de cajeros, trazabilidad de ajustes manuales de stock, sincronización entre dispositivos, escaneo por cámara, impresión Bluetooth ni cifrado de la base local. Un lector USB que escriba el código y Enter funciona con el buscador.

Los recibos comerciales no reemplazan boletas ni facturas. No se aplica una fórmula tributaria ni se desglosa IGV: se cobra el precio final del catálogo. El sistema no envía datos a servicios externos.

Los datos permanecen en **este navegador y origen**, no en el repositorio ni en un servidor. Borrar los datos del navegador, usar otro perfil o perder el dispositivo puede eliminar o dejar inaccesible el registro. Exporta copias regularmente y antes de restaurar: la restauración reemplaza el estado actual. Las copias contienen datos del negocio y ventas; guárdalas de forma privada.

## Arquitectura y siguientes pasos

- `src/domain.js`: reglas de negocio puras; operaciones sobre una copia del estado, importes y validación de copias.
- `src/storage.js`: adaptador IndexedDB; transacción atómica y control de revisiones.
- `src/app.js`: presentación y coordinación de eventos.
- `sw.js`: disponibilidad offline de los archivos de la aplicación.
- `build.js`: genera un HTML autónomo con estilos, ilustraciones y código incorporados.

La separación permite trasladar las reglas comprobadas al dominio y casos de uso de Flutter. Para una versión comercial: corregir primero los bloqueos del cliente Flutter, implementar persistencia relacional/migraciones, agregar devoluciones y movimientos de inventario auditables, validar en Android físico y tratar SUNAT/pagos como adaptadores con estados propios.

## Validación reproducible

```bash
npm test
npm run build
npm ci
# Chromium instalado, o indica su ruta con CHROMIUM_PATH
npm run test:browser
```

Los tests de dominio usan el runner de Node, sin dependencias. Los tests de navegador usan Playwright 1.58.2 y Chromium (`/usr/bin/chromium` por defecto). Inician un servidor separado en el puerto 4180; `TEST_PORT` permite cambiarlo. Comprueban cobros y errores, stock, caja, copias, varias pestañas, recarga/venta offline y el archivo autónomo. Los resultados visuales se guardan en `test-results/`, ignorado por Git. No publican ni alteran datos de un usuario real.
