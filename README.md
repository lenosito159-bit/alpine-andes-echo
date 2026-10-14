# Zivlo Perú · Punto de venta offline-first

Zivlo está orientado a bodegas, puestos de mercado y pequeños comercios peruanos: catálogo, ventas en soles, inventario, caja y fiado en un dispositivo, sin cuenta ni backend obligatorio.

Esta entrega incorpora un módulo POS Flutter con persistencia SQLite y una migración que conserva los archivos Hive originales. **El APK de prueba está generado: análisis sin errores, 43 pruebas aprobadas e instalación y arranque sin Wi-Fi ni datos móviles en un emulador Android 10.** [Ver la ejecución y descargar los artefactos](https://github.com/lenosito159-bit/alpine-andes-echo/actions/runs/38632367648#artifacts).

Inicia sesión en GitHub, descarga `zivlo-peru-debug-apk`, extrae el ZIP y abre `build/app/outputs/flutter-apk/app-debug.apk` en un teléfono Android de prueba. El paquete incluye el checksum y el lockfile de dependencias. Cámara e impresión requieren pruebas con hardware real.

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

El script prepara Android sin sobrescribir la lógica de la aplicación, ejecuta análisis y todas las pruebas y, si terminan correctamente, genera un APK debug. GitHub Actions ya generó y verificó el artefacto `zivlo-peru-debug-apk` en la [ejecución #10](https://github.com/lenosito159-bit/alpine-andes-echo/actions/runs/38632367648).

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
