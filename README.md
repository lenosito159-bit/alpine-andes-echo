# Zivlo Perú · Punto de venta offline-first

Zivlo está orientado a bodegas, puestos de mercado y pequeños comercios peruanos: catálogo, ventas en soles, inventario, caja y fiado en un dispositivo, sin cuenta ni backend obligatorio.

Esta entrega incorpora un módulo POS Flutter con persistencia SQLite y una migración que conserva los archivos Hive originales. **La validación Flutter y el APK están pendientes por un bloqueo de descarga del SDK en el entorno de desarrollo.** El código y las pruebas están preparados; no se presenta el cliente Android como verificado ni se publica un APK inexistente.

## Probar el piloto web existente

El piloto de [`pilot/`](pilot/README.md) ya permite probar catálogo, carrito, cobro, stock, historial, caja y copias locales. Sus 15 pruebas de negocio y sus recorridos de navegador fueron ejecutados, incluida la operación offline.

```bash
cd pilot
npm start
```

Para generar un HTML autónomo:

```bash
npm run build
```

Las funciones Android nuevas, como fiado y devolución completa, no se incorporaron automáticamente al piloto web.

## Continuar con Android

Consulta [la documentación Android](docs/PERU_ANDROID.md) para el estado de implementación, arquitectura, migración, límites y pasos de instalación.

Con Flutter 3.29.3 y Android SDK disponibles:

```bash
bash scripts/validate-pos.sh
```

El script prepara Android sin sobrescribir la lógica de la aplicación, ejecuta análisis y todas las pruebas y, si terminan correctamente, genera un APK debug. GitHub Actions también tiene un workflow preparado para crear el artefacto `zivlo-peru-debug-apk`; no se ha ejecutado remotamente en esta entrega.

## Funciones implementadas en el módulo Flutter

- Venta por unidad, kilo y litro, con cantidades fraccionarias y dinero en céntimos.
- Efectivo, Yape, Plin, tarjeta y pagos combinados con confirmación digital manual.
- Carrito persistente y guardado transaccional de ventas, pagos, stock y caja.
- Catálogo, compras/entradas, mermas, ajustes con motivo y stock bajo.
- Apertura, ingresos, gastos, retiros, cierre y diferencia de caja.
- Clientes, fiado y abonos parciales sin duplicar ventas.
- Devolución completa mediante movimientos de reversión, conservando historial.
- Historial y recibos comerciales PDF para compartir o imprimir mediante el sistema.
- Copias, restauración validada y copia interna anterior a la restauración.
- Migración conservadora del esquema Hive original y puerto futuro de integración fiscal.

Estas funciones requieren la validación nativa descrita en la documentación. Los pagos digitales no se verifican automáticamente. Los recibos comerciales no reemplazan boletas ni facturas SUNAT. La información permanece en el dispositivo; se deben mantener copias privadas.

La arquitectura conserva dominio, aplicación, infraestructura y presentación, con BLoC y GetIt. Los módulos anteriores permanecen para compatibilidad y migración; el arranque utiliza el repositorio POS transaccional.

Repositorio: [ZIVLO-Team/zivlo-app](https://github.com/ZIVLO-Team/zivlo-app). Licencia: [MIT](LICENSE).
