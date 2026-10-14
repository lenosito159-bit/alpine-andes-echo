# Zivlo Perú · Cliente Android

## Estado de esta entrega

El cliente Flutter incluye un nuevo módulo POS conectado al arranque de la aplicación. Se implementaron reglas de venta, pagos en soles, inventario, caja, fiado, abonos, devolución completa de ventas, copias y migración de los datos originales.

**La compilación, el análisis de Flutter, las pruebas nativas y el APK están pendientes de ejecutar.** En el entorno de desarrollo, el proxy rechaza `storage.googleapis.com`, de donde se descarga el SDK Dart y el motor Flutter. El dominio ya está permitido en la configuración guardada, pero la instancia sigue usando una versión anterior de la política de red. Se necesita una instancia con la configuración actualizada; no hay que añadir el dominio de nuevo. Se prepararon los fuentes oficiales de Flutter 3.29.3 y Android SDK API 35 con build-tools 35.0.0. No se sustituyeron fuentes de descarga ni se desactivaron verificaciones para eludir el bloqueo.

Sí se comprobó la sintaxis de los archivos Dart mediante un parser, la sintaxis de los scripts Bash y la integridad de los cambios. Esas comprobaciones no sustituyen `flutter analyze`, `flutter test` o una compilación Android. El piloto web anterior mantiene sus 15 pruebas de dominio y sus recorridos de navegador verificados, incluida una venta offline. Es evidencia del piloto; no demuestra que el cliente Android funcione.

## Flujo implementado

1. Abre la caja e indica el fondo inicial.
2. Crea productos o carga expresamente el catálogo de ejemplo en un negocio vacío.
3. Busca por nombre/código o utiliza la cámara; agrega unidades o cantidades a granel.
4. Cobra usando efectivo, Yape, Plin, tarjeta o combinaciones. Los pagos digitales requieren confirmación manual.
5. Guarda venta, pagos, stock y caja en una transacción SQLite.
6. Consulta el historial y genera un recibo comercial PDF para compartir o imprimir mediante el sistema.
7. Registra compras/entradas, mermas y ajustes de stock con motivo; registra ingresos y gastos de caja.
8. Asigna fiado a un cliente y registra abonos parciales sin crear otra venta ni descontar stock nuevamente.
9. Devuelve una venta completa: conserva el historial, repone productos y registra las devoluciones de pagos y abonos, cancelando el saldo pendiente.
10. Cierra la caja indicando el efectivo contado y consulta la diferencia.
11. Exporta una copia y prueba su restauración en un entorno de prueba.

La tienda comienza vacía. El catálogo de ejemplo contiene códigos y precios ficticios y no representa precios actuales verificados. Las ventas al fiado forman parte del total vendido; el efectivo esperado incluye únicamente el dinero que corresponde a caja.

## Compilar y probar

Requisitos: Flutter **3.29.3** (Dart 3.7), Java 17 o compatible, Android SDK API 35, Bash y Python 3. En una máquina con acceso a las fuentes oficiales:

```bash
bash scripts/validate-pos.sh
```

El script prepara Android sin sobrescribir `lib`, resuelve dependencias, ejecuta análisis y todos los tests, y compila el APK debug. El resultado esperado, solo después de una compilación correcta, es:

```
build/app/outputs/flutter-apk/app-debug.apk
```

Para ejecutar en un dispositivo conectado:

```bash
flutter run
```

No se ha probado cámara, impresión, compartir archivos ni recuperación tras cierre forzado en un Android físico. Esas verificaciones deben completarse antes de utilizarlo para operaciones reales.

En una instancia que use la configuración actualizada, puede activarse el toolchain preparado con:

```bash
source /workspace/.tools/zivlo-env.sh
flutter --version
bash scripts/validate-pos.sh
```

No cambies el proxy ni desactives TLS para descargar el SDK. `pubspec.lock` debe generarse con una resolución correcta y conservarse en Git para fijar dependencias transitivas. No se inventó un lockfile durante el bloqueo del SDK.

## GitHub Actions

- `ci.yml`: Flutter 3.29.3, análisis de todo el código y `flutter test --coverage`. Incluye `test/pos` y `test/legacy`; ya no se limita a los tests triviales originales.
- `android-test-apk.yml`: analiza, ejecuta tests y compila un APK debug con checksum SHA-256, descargable como artefacto `zivlo-peru-debug-apk` si el workflow termina correctamente.

Ambos workflows están preparados en el código; **no fueron publicados ni ejecutados remotamente** en esta entrega. El artefacto APK todavía no existe. No se publica en Play Store ni se necesitan credenciales de producción para generar un APK de prueba.

La generación mantiene `com.example.zivlo`, la identidad que usaba el script original. Para actualizar una instalación existente y conservar sus datos, deben coincidir también el certificado de firma y el application ID. Un APK debug firmado con otra clave no constituye una actualización compatible. Conserva los datos y la instalación anterior; no desinstales la única copia para resolver una incompatibilidad de firma. Una publicación comercial requiere definir identidad y firma definitiva.

## Arquitectura

- `domain/pos_engine.dart`: estado validado e inmutable, importes, cantidades y reglas de negocio. No depende de Flutter, SQLite, cámara o impresión.
- `domain/pos_repository.dart`: puerto de almacenamiento.
- `application/pos_cubit.dart`: estados de pantalla y serialización de operaciones en curso; muestra éxito únicamente después del commit.
- `infrastructure/sqlite_pos_repository.dart`: SQLite, transacciones, comparación de revisión y copias.
- `infrastructure/legacy_hive_importer.dart`: conversión desde el esquema original, conservando archivos y valores históricos.
- `presentation/pos_page.dart`: interfaz adaptativa, formularios, catálogo, cobro, caja, fiado y copias.
- `presentation/receipt_service.dart`: recibo comercial PDF y servicios de impresión/compartir del sistema.
- `domain/fiscal_receipt_gateway.dart`: interfaz futura para un proveedor fiscal real. No tiene implementación activa ni envía documentos.

Se evaluó Drift y se eligió `sqflite` para esta etapa: permite transacciones SQLite sin generar código ni cambiar los modelos Hive usados para migrar. Cada colección tiene una tabla con registros identificados y payload JSON; los registros que cambiaron se escriben en una sola transacción. El dominio valida relaciones e importes. El estado completo se carga para aplicar reglas; esto simplifica una caja local pero requiere medir rendimiento y añadir consultas/paginación antes de escalar a historiales grandes o múltiples cajas. Las tablas de payload no reemplazan una normalización relacional completa.

## Dinero, cantidades y contabilidad

Los precios y pagos nuevos se almacenan en céntimos enteros. Las cantidades usan milésimas: 1000 representa una unidad, un kilo o un litro según el producto. Una unidad individual no admite fracciones.

Se redondea cada línea al céntimo más próximo, con medio céntimo hacia arriba. Ejemplo: 0.250 kg de arroz a S/ 4.50/kg produce S/ 1.13. Los precios del catálogo son precios finales; no se calcula ni desglosa IGV. Las cantidades demasiado pequeñas para producir un importe cobrable se rechazan al completar la venta.

El efectivo recibido puede exceder el total; el exceso se devuelve como vuelto. Los pagos digitales no pueden superar el total. Solo el aporte neto del efectivo modifica el saldo de caja.

Una venta al fiado guarda el saldo original pendiente. Los abonos se registran aparte y reducen deuda; no aumentan el total vendido ni afectan inventario. La devolución completa conserva venta y abonos originales, registra movimientos de devolución por medio de pago y cancela el saldo pendiente. Requiere caja abierta, suficiente efectivo y confirmación de que se devolvió el dinero. Las devoluciones digitales se realizan y verifican fuera de Zivlo.

No se borran ventas para corregirlas. Los cambios de stock tienen motivo y el stock actual se contrasta con su saldo inicial más movimientos. El carrito conserva el precio acordado al agregar un producto; el recibo conserva los nombres y precios vendidos aunque después cambie el catálogo.

## Migración desde Hive

La migración ocurre únicamente cuando se inicializa una base SQLite nueva:

1. Localiza las cajas originales `products` y `sales`.
2. Copia los bytes de los archivos en `zivlo_hive_archive`, dentro del directorio privado de documentos, usando nombres con su checksum. Verifica esas copias antes de abrir Hive.
3. Conserva los identificadores, las fechas, el stock actual y los importes históricos. Asigna números de recibo locales ordenados por fecha, ya que el esquema anterior no guardaba esa secuencia.
4. Convierte importes históricos a céntimos en la frontera de migración; conserva los valores `double` originales en un archivo lógico `originalHive` de la base y las copias exportadas.
5. Guarda todos los registros y el indicador de inicialización en una transacción. Una segunda apertura no vuelve a importar ni descuenta stock otra vez.

Los pagos mixtos originales no guardaban todos sus componentes. Se preservan como históricos sin inventar confirmaciones, deuda o movimientos de caja. Los descuentos y totales originales se conservan incluso cuando necesitan conciliación; no se recalculan para aparentar exactitud. Las ventas históricas no pueden anularse automáticamente.

Los productos históricos con precio cero se conservan archivados; se pueden corregir y reactivar. Datos incompatibles, como stock negativo o códigos duplicados, detienen la migración con un mensaje; no se sustituyen silenciosamente por una tienda vacía. Los archivos originales y sus copias permanecen disponibles.

## Copias y recuperación

La copia nativa contiene `format`, `formatVersion`, el estado y, cuando existe, el archivo lógico de datos Hive originales. El SHA-256 detecta cambios accidentales en el estado; no es una firma, prueba de autenticidad ni evidencia bancaria. Se aceptan también copias JSON del piloto web v1, con validación y conversión a v2.

La restauración reemplaza el estado actual y guarda, en la misma transacción, una copia interna previa. Se puede exportar desde **Mi negocio → Exportar copia anterior a la última restauración**. Si la escritura falla, no se aplica parcialmente el reemplazo. El límite actual de importación es 20 MB y cada colección está limitada a 50 000 registros; esto debe revisarse junto con el rendimiento antes de un uso de gran volumen.

Las copias contienen información privada del negocio y de clientes. No están cifradas. Guárdalas en un lugar privado y exporta regularmente. Eliminar los datos de la app, desinstalarla o perder el dispositivo puede eliminar los registros locales. No hay sincronización ni recuperación automática desde un servidor.

## Pruebas incorporadas y pendientes de ejecución nativa

- Céntimos exactos, cantidades fraccionarias y redondeo.
- Estado inmutable, pagos insuficientes, pagos digitales y combinaciones.
- Caja cerrada, carrito desactualizado y doble cobro.
- Stock, compras, mermas, ajuste con motivo y devolución completa.
- Fiado, abonos parciales y devolución de una venta que ya recibió abonos.
- Diferencias de caja y devolución desde otra sesión.
- SQLite real con fallo de escritura simulado: rollback de stock, carrito y movimientos.
- Persistencia al cerrar y reabrir el archivo SQLite.
- Exportación, copia corrupta, restauración atómica y recuperación previa.
- Migración de importes, descuentos, archivos originales y productos con precio cero.
- BLoC, arranque y flujo de venta en tamaños de 390 y 1200 píxeles.

No se describen estas pruebas como aprobadas: necesitan el SDK Flutter para ejecutarse.

## Límites funcionales

Esta implementación corresponde a una caja local con un responsable. No incluye autorización por cajero, sincronización entre dispositivos, cobro bancario automático, comprobantes SUNAT, impresión Bluetooth directa ni devoluciones parciales por línea. La cámara y los servicios del sistema se implementaron pero requieren validación en dispositivo. La interfaz fiscal futura no emite respuestas simuladas. El piloto web se mantiene como referencia; las funciones nativas nuevas no se duplicaron automáticamente en él.

## Acceso al repositorio y conservación del trabajo

La comprobación de escritura con `git push --dry-run` devolvió 403: GitHub niega permiso de escritura a la identidad `lenosito159-bit` en `ZIVLO-Team/zivlo-app`. Por eso no se publicó una rama ni se pudo utilizar el workflow remoto como alternativa de compilación. Se necesita acceso de escritura autorizado o un fork propio para publicar los cambios y ejecutar ese CI.

La revisión automática ASB rechazó guardar la lista de repositorios del entorno incluyendo Zivlo; no informó un motivo detallado y no confirmó guardar un borrador. El código está conservado localmente y en el paquete de fuentes. Antes de cambiar de instancia, descarga el ZIP; en la instancia nueva habrá que restaurar esos fuentes si no aparecen. No se ha verificado la restauración en una tarea nueva.
