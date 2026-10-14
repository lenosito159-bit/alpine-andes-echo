import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';

import '../application/pos_cubit.dart';
import '../domain/pos_engine.dart';
import 'receipt_service.dart';

const _green = Color(0xFF123C35);
const _lime = Color(0xFFE4F4A5);
const _paper = Color(0xFFF7F8F3);
const _muted = Color(0xFF66766C);
const _border = Color(0xFFE3E8DF);

/// All money and quantity arithmetic is performed by the domain engine.
class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  int _destination = 0;
  String _query = '';
  String _category = 'Todos';
  bool _showArchived = false;
  final _search = TextEditingController();
  PosCubit get _cubit => context.read<PosCubit>();

  static const _labels = ['Vender', 'Productos', 'Ventas', 'Caja', 'Fiado', 'Mi negocio'];
  static const _icons = [
    Icons.storefront_outlined,
    Icons.inventory_2_outlined,
    Icons.receipt_long_outlined,
    Icons.point_of_sale_outlined,
    Icons.people_outline,
    Icons.tune_outlined,
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFF8C342B) : _green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<bool> _run(Map<String, dynamic> action, {String? message}) async {
    final success = await _cubit.run(action);
    if (success && message != null) _message(message);
    return success;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _green).copyWith(
          primary: _green,
          secondary: _green,
          secondaryContainer: _lime,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: _paper,
        appBarTheme: const AppBarTheme(backgroundColor: _paper, foregroundColor: _green),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _paper,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
        ),
      ),
      child: BlocConsumer<PosCubit, PosViewState>(
        listener: (context, view) {
          if (view.error != null) _message(view.error!, error: true);
        },
        builder: (context, view) {
          final data = view.data;
          if (data == null) {
            return Scaffold(body: Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: view.error == null
                  ? const CircularProgressIndicator()
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.storage_outlined, size: 48),
                      const SizedBox(height: 16),
                      Text(view.error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: () => _cubit.load(), child: const Text('Volver a intentar')),
                    ]),
            )));
          }
          return LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return Scaffold(
              appBar: AppBar(
                title: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.storefront, color: _lime, size: 23)),
                  const SizedBox(width: 9),
                  const Text('zivlo', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1, fontSize: 29)),
                  const Text(' · Perú', style: TextStyle(color: _muted, fontSize: 13)),
                ]),
                actions: [
                  const Tooltip(message: 'Tus operaciones se guardan en este dispositivo, incluso sin internet.', child: Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.offline_bolt_outlined, color: _green))),
                  if (wide) Padding(padding: const EdgeInsets.only(right: 20), child: Text(data.settings['storeName']?.toString() ?? 'Mi negocio')),
                ],
                bottom: view.busy ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3)) : null,
              ),
              body: SafeArea(child: Row(children: [
                if (wide) NavigationRail(
                  selectedIndex: _destination,
                  extended: constraints.maxWidth >= 1200,
                  backgroundColor: Colors.white,
                  indicatorColor: _lime,
                  labelType: constraints.maxWidth >= 1200 ? null : NavigationRailLabelType.all,
                  onDestinationSelected: (index) => setState(() => _destination = index),
                  destinations: List.generate(_labels.length, (i) => NavigationRailDestination(
                    icon: Icon(_icons[i], key: ValueKey(i == 2 ? 'nav-sales' : 'nav-$i')),
                    label: Text(_labels[i]),
                  )),
                ),
                Expanded(child: AbsorbPointer(absorbing: view.busy, child: _screen(data))),
              ])),
              bottomNavigationBar: wide ? null : NavigationBar(
                height: 72,
                selectedIndex: _destination,
                indicatorColor: _lime,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (index) => setState(() => _destination = index),
                destinations: List.generate(_labels.length, (i) => NavigationDestination(
                  icon: Icon(_icons[i], key: ValueKey(i == 2 ? 'nav-sales' : 'nav-$i')),
                  label: _labels[i],
                )),
              ),
              floatingActionButton: !wide && _destination == 0 && data.cart.isNotEmpty
                  ? FloatingActionButton.extended(
                      key: const ValueKey('mobile-checkout'),
                      onPressed: view.busy ? null : data.session == null ? _openSession : () => _checkout(data),
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: Text(data.session == null ? 'Abrir caja para cobrar' : 'Cobrar ${soles(data.total)}'),
                    )
                  : null,
            );
          });
        },
      ),
    );
  }

  Widget _screen(PosState state) => switch (_destination) {
    0 => _sell(state),
    1 => _products(state),
    2 => _sales(state),
    3 => _cash(state),
    4 => _customers(state),
    _ => _business(state),
  };

  Widget _heading(String title, String subtitle, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 16, runSpacing: 12, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: _green, letterSpacing: -0.7)),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: _muted)),
      ]),
      if (action != null) action,
    ]),
  );

  Widget _panel(Widget child, {EdgeInsets padding = const EdgeInsets.all(20)}) => Container(
    padding: padding,
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _border), borderRadius: BorderRadius.circular(20)),
    child: child,
  );

  Widget _empty(IconData icon, String title, String detail, {Widget? action}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(18), decoration: const BoxDecoration(color: _paper, shape: BoxShape.circle), child: Icon(icon, color: _green, size: 34)),
      const SizedBox(height: 16),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: _green)),
      const SizedBox(height: 8),
      Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
      if (action != null) ...[const SizedBox(height: 20), action],
    ]),
  );

  Widget _sell(PosState state) {
    final products = state.products.where((p) => p['active'] != false).toList();
    final categories = <String>{'Todos', ...products.map((p) => p['category']?.toString() ?? 'Otros')};
    final query = _query.toLowerCase();
    final visible = products.where((p) => (_category == 'Todos' || p['category'] == _category) && '${p['name']} ${p['barcode']}'.toLowerCase().contains(query)).toList();
    return LayoutBuilder(builder: (context, constraints) {
      final sideCart = constraints.maxWidth >= 920;
      final catalog = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _heading('Tu próxima venta', 'Rápido, sencillo y siempre a la mano.'),
        if (state.session == null) Padding(padding: const EdgeInsets.only(bottom: 16), child: _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Empieza abriendo tu caja', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(height: 6),
          const Text('Registra el efectivo inicial para llevar las cuentas del día.'),
          const SizedBox(height: 12),
          FilledButton.icon(key: const ValueKey('open-register'), onPressed: _openSession, icon: const Icon(Icons.lock_open), label: const Text('Abrir caja')),
        ]))),
        Row(children: [
          Expanded(child: TextField(controller: _search, decoration: const InputDecoration(hintText: 'Buscar producto o código', prefixIcon: Icon(Icons.search)), onChanged: (value) => setState(() => _query = value), onSubmitted: (_) { if (visible.length == 1) _addProduct(visible.single); })),
          const SizedBox(width: 10),
          IconButton.filledTonal(tooltip: 'Escanear código de barras', onPressed: _scan, icon: const Icon(Icons.qr_code_scanner), padding: const EdgeInsets.all(15)),
        ]),
        const SizedBox(height: 14),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: categories.map((category) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(category), selected: _category == category, onSelected: (_) => setState(() => _category = category)))).toList())),
        const SizedBox(height: 18),
        if (products.isEmpty) _panel(_empty(Icons.inventory_2_outlined, 'Bienvenido a tu negocio', 'Agrega tus productos para empezar. También puedes explorar con un catálogo de ejemplo.', action: Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
          FilledButton.icon(onPressed: () => _productForm(state), icon: const Icon(Icons.add), label: const Text('Agregar producto')),
          OutlinedButton(onPressed: () => _run({'type': 'load-demo'}, message: 'Catálogo de ejemplo guardado.'), child: const Text('Cargar catálogo de ejemplo')),
        ]))),
        if (products.isNotEmpty && visible.isEmpty) _empty(Icons.search_off, 'No encontramos ese producto', 'Busca por otro nombre o código.'),
        if (visible.isNotEmpty) LayoutBuilder(builder: (context, grid) {
          final columns = grid.maxWidth >= 740 ? 4 : grid.maxWidth >= 510 ? 3 : 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12, mainAxisExtent: 208),
            itemCount: visible.length,
            itemBuilder: (context, i) => _productCard(visible[i]),
          );
        }),
      ]);
      return SingleChildScrollView(padding: const EdgeInsets.all(20), child: sideCart
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: catalog), const SizedBox(width: 24), SizedBox(width: 350, child: _cart(state))])
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [catalog, const SizedBox(height: 24), _cart(state)]));
    });
  }

  IconData _productIcon(Map<String, dynamic> product) {
    final text = '${product['name']} ${product['category']}'.toLowerCase();
    if (text.contains('leche') || text.contains('yogurt') || text.contains('lácteo')) return Icons.breakfast_dining_outlined;
    if (text.contains('agua') || text.contains('kola') || text.contains('bebida')) return Icons.local_drink_outlined;
    if (text.contains('arroz') || text.contains('granel') || text.contains('azúcar')) return Icons.grass;
    if (text.contains('pan') || text.contains('galleta')) return Icons.bakery_dining_outlined;
    if (text.contains('aceite')) return Icons.oil_barrel_outlined;
    return Icons.shopping_basket_outlined;
  }

  Widget _productCard(Map<String, dynamic> product) {
    final stock = product['stock'] as int;
    final available = stock > 0;
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(18), child: InkWell(
      key: ValueKey('product-${product['id']}'),
      borderRadius: BorderRadius.circular(18),
      onTap: available ? () => _addProduct(product) : null,
      child: Container(decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(18)), padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFEFF2E7), borderRadius: BorderRadius.circular(14)), child: Icon(_productIcon(product), size: 30, color: _green)),
          Icon(available ? Icons.add_circle_outline : Icons.block, color: available ? _green : _muted),
        ]),
        const SizedBox(height: 12),
        Text(product['name'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const Spacer(),
        Text(soles(product['price'] as int), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _green)),
        const SizedBox(height: 4),
        Text(available ? '${displayQuantity(stock, product['unit'].toString())} disponibles' : 'Sin stock', style: TextStyle(fontSize: 11, color: available ? _muted : Colors.red.shade800)),
      ])),
    ));
  }

  Future<void> _addProduct(Map<String, dynamic> product) async {
    if (product['unit'] == 'und') {
      await _run({'type': 'cart-add', 'productId': product['id'], 'quantity': 1000});
      return;
    }
    final quantity = TextEditingController(text: '1');
    await _dialog(title: product['name'].toString(), confirm: 'Agregar al carrito', content: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
      Text('${soles(product['price'] as int)} por ${product['unit']} · disponible: ${displayQuantity(product['stock'] as int, product['unit'].toString())}'),
      const SizedBox(height: 20),
      _number(quantity, 'Cantidad en ${product['unit']}', decimals: true),
    ]), submit: () => _run({'type': 'cart-add', 'productId': product['id'], 'quantity': parseAmount(quantity.text, decimals: 3)}));
    quantity.dispose();
  }

  Widget _cart(PosState state) => _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [const Expanded(child: Text('Tu carrito', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _green))), Text('${state.cart.length} productos', style: const TextStyle(color: _muted, fontSize: 12))]),
    if (state.cart.isEmpty) _empty(Icons.shopping_bag_outlined, 'Listo para una nueva venta', 'Toca un producto para agregarlo aquí.'),
    ...state.cart.map((line) {
      final product = state.products.firstWhere((p) => p['id'] == line['productId']);
      return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(product['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w600))), Text(soles(lineAmount(line['price'] as int, line['quantity'] as int)), style: const TextStyle(fontWeight: FontWeight.w700))]),
        const SizedBox(height: 6),
        Row(children: [
          IconButton(tooltip: 'Quitar ${product['name']}', onPressed: () => _run({'type': 'cart-quantity', 'productId': product['id'], 'quantity': 0}), icon: const Icon(Icons.delete_outline, size: 21)),
          TextButton(onPressed: () => _editQuantity(product, line), child: Text(displayQuantity(line['quantity'] as int, product['unit'].toString()))),
          const Spacer(),
          IconButton(tooltip: 'Agregar ${product['name']}', onPressed: () => _addProduct(product), icon: const Icon(Icons.add_circle_outline)),
        ]),
        const Divider(height: 1),
      ]));
    }),
    const SizedBox(height: 12),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total', style: TextStyle(fontSize: 18)), Text(soles(state.total), style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800, color: _green))]),
    const SizedBox(height: 18),
    FilledButton.icon(key: const ValueKey('checkout'), onPressed: state.cart.isEmpty ? null : state.session == null ? _openSession : () => _checkout(state), icon: Icon(state.session == null ? Icons.lock_open : Icons.arrow_forward), label: Text(state.session == null ? 'Abrir caja para cobrar' : 'Cobrar ${soles(state.total)}')),
    if (state.cart.isNotEmpty) TextButton(onPressed: () async { if (await _confirm('Vaciar carrito', 'Se quitarán los productos de esta venta.')) await _run({'type': 'cart-clear'}); }, child: const Text('Vaciar carrito')),
    const SizedBox(height: 8),
    const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_outline, size: 14, color: _muted), SizedBox(width: 6), Flexible(child: Text('Carrito guardado en este dispositivo', style: TextStyle(fontSize: 11, color: _muted)))]),
  ]));

  Future<void> _editQuantity(Map<String, dynamic> product, Map<String, dynamic> line) async {
    final controller = TextEditingController(text: _decimal(line['quantity'] as int, 3));
    await _dialog(title: 'Cambiar cantidad', content: (_) => _number(controller, '${product['name']} (${product['unit']})'), submit: () => _run({'type': 'cart-quantity', 'productId': product['id'], 'quantity': parseAmount(controller.text, decimals: 3)}));
    controller.dispose();
  }

  Future<void> _checkout(PosState state) async {
    final amounts = <String, TextEditingController>{for (final method in ['cash', 'yape', 'plin', 'card']) method: TextEditingController(text: method == 'cash' ? _decimal(state.total, 2) : '')};
    var digitalConfirmed = false;
    var credit = false;
    var selectedMethod = 'cash';
    String? customerId;
    final priorIds = state.sales.map((sale) => sale['id']).toSet();
    final success = await _dialog(
      title: 'Cobrar venta', confirm: 'Confirmar venta', confirmKey: 'confirm-payment',
      content: (refresh) {
        int entered = 0;
        int digitalEntered = 0;
        for (final entry in amounts.entries) { try { if (entry.value.text.isNotEmpty) { final value = parseAmount(entry.value.text); entered += value; if (entry.key != 'cash') digitalEntered += value; } } catch (_) {} }
        final hasDigital = digitalEntered > 0;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Total a cobrar', style: TextStyle(color: Colors.white70)), const SizedBox(height: 4), Text(soles(state.total), style: const TextStyle(color: _lime, fontSize: 34, fontWeight: FontWeight.w800))])),
          const SizedBox(height: 18),
          Wrap(spacing: 6, runSpacing: 6, children: ['cash', 'yape', 'plin', 'card', 'mixed'].map((method) => ChoiceChip(label: Text(method == 'mixed' ? 'Mixto' : paymentLabel(method)), selected: selectedMethod == method, onSelected: (_) => refresh(() { selectedMethod = method; digitalConfirmed = false; for (final c in amounts.values) { c.clear(); } if (method != 'mixed') amounts[method]!.text = _decimal(state.total, 2); }))).toList()),
          const SizedBox(height: 12),
          Text(selectedMethod == 'mixed' ? 'Distribuye el importe entre los medios utilizados.' : 'Registra únicamente el medio de pago recibido.', style: const TextStyle(color: _muted)),
          const SizedBox(height: 14),
          ...amounts.entries.where((entry) => selectedMethod == 'mixed' || entry.key == selectedMethod).map((entry) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _number(entry.value, '${paymentLabel(entry.key)} (S/)', key: entry.key == 'cash' ? const ValueKey('cash-received') : null, onChanged: (_) => refresh(() { if (entry.key != 'cash') digitalConfirmed = false; })))),
          if (digitalEntered > state.total) const Text('Los pagos digitales no pueden superar el total.', style: TextStyle(color: Colors.red))
          else if (entered > state.total) Text('Vuelto: ${soles(entered - state.total)}', style: const TextStyle(fontSize: 21, color: _green, fontWeight: FontWeight.w700)),
          if (entered < state.total) Text('${credit ? 'Quedará fiado' : 'Falta completar'}: ${soles(state.total - entered)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Dejar saldo al fiado'), value: credit, onChanged: (value) => refresh(() => credit = value)),
          if (credit && state.customers.isEmpty) const Text('Primero registra al cliente desde la sección Fiado.'),
          if (credit && state.customers.isNotEmpty) DropdownButtonFormField<String>(value: customerId, decoration: const InputDecoration(labelText: 'Cliente responsable'), items: state.customers.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name'].toString()))).toList(), onChanged: (value) => refresh(() => customerId = value)),
          if (hasDigital) CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: const Text('Verifiqué que el pago digital llegó'), subtitle: const Text('Revisa tu cuenta o terminal. Zivlo registra tu confirmación manual.'), value: digitalConfirmed, onChanged: (value) => refresh(() => digitalConfirmed = value ?? false)),
          const SizedBox(height: 10),
          const Text('Se guardará un recibo comercial. No es boleta ni factura electrónica.', style: TextStyle(color: _muted, fontSize: 12)),
        ]);
      },
      submit: () {
        final payments = amounts.entries.where((e) => e.value.text.trim().isNotEmpty).map((e) => <String, dynamic>{'method': e.key, 'amount': parseAmount(e.value.text)}).where((e) => (e['amount'] as int) > 0).toList();
        return _run({'type': 'checkout', 'cartKey': state.cartKey, 'payments': payments, 'digitalConfirmed': digitalConfirmed, 'credit': credit, 'customerId': customerId});
      },
    );
    for (final controller in amounts.values) { controller.dispose(); }
    if (success && mounted) {
      final sale = _cubit.state.data!.sales.where((s) => !priorIds.contains(s['id'])).firstOrNull;
      if (sale != null) await _saleDetail(sale);
    }
  }

  Widget _products(PosState state) {
    final products = state.products.where((p) => _showArchived ? p['active'] == false : p['active'] == true).toList();
    return ListView(padding: const EdgeInsets.all(20), children: [
      _heading('Tus productos', 'Precios claros y movimientos de stock con motivo.', action: FilledButton.icon(onPressed: () => _productForm(state), icon: const Icon(Icons.add), label: const Text('Agregar producto'))),
      SwitchListTile(title: const Text('Mostrar productos archivados'), value: _showArchived, onChanged: (value) => setState(() => _showArchived = value)),
      if (products.isEmpty) _empty(Icons.inventory_2_outlined, 'Tu catálogo está vacío', 'Crea tu primer producto o carga ejemplos desde Vender.'),
      ...products.map((p) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(_productIcon(p), color: _green), const SizedBox(width: 12), Expanded(child: Text(p['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17))), Text(soles(p['price'] as int), style: const TextStyle(fontWeight: FontWeight.w700))]),
        const SizedBox(height: 10),
        Text('${p['category']} · ${displayQuantity(p['stock'] as int, p['unit'].toString())} en stock', style: const TextStyle(color: _muted)),
        if ((p['stock'] as int) <= (p['unit'] == 'und' ? 5000 : 2000)) const Padding(padding: EdgeInsets.only(top: 5), child: Text('Stock bajo: revisa tu próxima compra', style: TextStyle(color: Color(0xFF986029)))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [OutlinedButton(onPressed: () => _productForm(state, product: p), child: const Text('Editar')), OutlinedButton(onPressed: () => _stockForm(p), child: const Text('Mover stock')), TextButton(onPressed: () => _stockHistory(state, p), child: const Text('Historial de stock')), if (p['active'] == false) TextButton(onPressed: () => _run({'type': 'unarchive-product', 'productId': p['id']}, message: 'Producto reactivado.'), child: const Text('Reactivar'))]),
      ])))),
    ]);
  }

  Future<void> _productForm(PosState state, {Map<String, dynamic>? product, String? barcode}) async {
    final name = TextEditingController(text: product?['name']?.toString() ?? '');
    final category = TextEditingController(text: product?['category']?.toString() ?? 'Abarrotes');
    final price = TextEditingController(text: product == null ? '' : _decimal(product['price'] as int, 2));
    final stock = TextEditingController(text: product == null ? '0' : _decimal(product['stock'] as int, 3));
    final code = TextEditingController(text: barcode ?? product?['barcode']?.toString() ?? '');
    final reason = TextEditingController();
    String unit = product?['unit']?.toString() ?? 'und';
    await _dialog(title: product == null ? 'Agregar producto' : 'Editar producto', confirm: 'Guardar producto', content: (refresh) => Column(mainAxisSize: MainAxisSize.min, children: [
      _field(name, 'Nombre del producto', maxLength: 100), const SizedBox(height: 12),
      _field(category, 'Categoría', maxLength: 50), const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: unit, decoration: const InputDecoration(labelText: 'Unidad de venta'), items: const [DropdownMenuItem(value: 'und', child: Text('Unidad')), DropdownMenuItem(value: 'kg', child: Text('Kilogramo')), DropdownMenuItem(value: 'L', child: Text('Litro'))], onChanged: product == null ? (v) => refresh(() => unit = v ?? 'und') : null), const SizedBox(height: 12),
      _number(price, 'Precio por $unit (S/)'), const SizedBox(height: 12),
      _number(stock, 'Stock disponible ($unit)'), const SizedBox(height: 12),
      _field(code, 'Código de barras (opcional)', maxLength: 60),
      if (product != null) ...[const SizedBox(height: 12), _field(reason, 'Motivo si cambias el stock', maxLength: 120), const SizedBox(height: 8), const Text('El carrito conserva el precio acordado al agregar el producto.', style: TextStyle(color: _muted, fontSize: 12)), TextButton(onPressed: () async { if (await _confirm('Archivar producto', 'Se conservará el historial de ventas. Retira este producto del carrito antes de archivarlo.')) { if (await _run({'type': 'archive-product', 'productId': product['id']})) { if (mounted) Navigator.of(context).pop(false); } } }, child: const Text('Archivar producto'))],
    ]), submit: () => _run({'type': 'save-product', 'product': {'id': product?['id'], 'name': name.text, 'category': category.text, 'price': parseAmount(price.text), 'unit': unit, 'stock': parseAmount(stock.text, decimals: 3), 'barcode': code.text, 'stockReason': reason.text}}, message: 'Producto guardado.'));
    for (final controller in [name, category, price, stock, code, reason]) { controller.dispose(); }
  }

  Future<void> _stockForm(Map<String, dynamic> product) async {
    var kind = 'purchase';
    var subtract = false;
    final quantity = TextEditingController();
    final reason = TextEditingController();
    await _dialog(title: 'Mover stock de ${product['name']}', confirm: 'Guardar movimiento', content: (refresh) => Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Disponible: ${displayQuantity(product['stock'] as int, product['unit'].toString())}'), const SizedBox(height: 16),
      DropdownButtonFormField<String>(value: kind, decoration: const InputDecoration(labelText: 'Tipo de movimiento'), items: const [DropdownMenuItem(value: 'purchase', child: Text('Compra / entrada')), DropdownMenuItem(value: 'loss', child: Text('Merma / pérdida')), DropdownMenuItem(value: 'adjustment', child: Text('Ajuste de inventario'))], onChanged: (v) => refresh(() => kind = v ?? 'purchase')),
      if (kind == 'adjustment') SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Reducir stock'), value: subtract, onChanged: (v) => refresh(() => subtract = v)),
      const SizedBox(height: 16), _number(quantity, 'Cantidad (${product['unit']})'), const SizedBox(height: 16), _field(reason, 'Motivo del movimiento', maxLength: 120),
      const SizedBox(height: 12), const Text('Este movimiento actualiza cantidades. Si hubo un gasto en efectivo, regístralo también en Caja.', style: TextStyle(color: _muted, fontSize: 12)),
    ]), submit: () => _run({'type': 'stock-movement', 'productId': product['id'], 'quantity': parseAmount(quantity.text, decimals: 3) * (kind == 'adjustment' && subtract ? -1 : 1), 'kind': kind, 'reason': reason.text}, message: 'Movimiento de stock guardado.'));
    quantity.dispose(); reason.dispose();
  }

  Future<void> _stockHistory(PosState state, Map<String, dynamic> product) => showDialog<void>(context: context, builder: (context) {
    final rows = state.stockMovements.where((m) => m['productId'] == product['id']).toList().reversed;
    return AlertDialog(title: Text('Stock de ${product['name']}'), content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Saldo inicial: ${displayQuantity(product['openingStock'] as int, product['unit'].toString())}'), const SizedBox(height: 12),
      if (rows.isEmpty) const Text('Aún no hay movimientos después del saldo inicial.'),
      ...rows.map((m) => ListTile(contentPadding: EdgeInsets.zero, title: Text(m['reason'].toString()), subtitle: Text(peruDate(m['at'])), trailing: Text(displayQuantity(m['quantityDelta'] as int, product['unit'].toString())))),
    ]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Listo'))]);
  });

  Widget _sales(PosState state) {
    final sales = state.sales.reversed.toList();
    final completed = sales.where((s) => s['status'] == 'completed').toList();
    final sold = completed.fold<int>(0, (n, s) => n + (s['total'] as int));
    return ListView(padding: const EdgeInsets.all(20), children: [
      _heading('Cada venta cuenta', 'Historial local · fechas y horas de Perú.'),
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Total vendido · historial completo', style: TextStyle(color: _muted)), const SizedBox(height: 8), Text(soles(sold), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: _green)), Text('${completed.length} ventas · incluye ventas al fiado'), const Text('Los registros importados mantienen sus importes históricos.', style: TextStyle(color: _muted, fontSize: 12))])),
      const SizedBox(height: 18),
      if (sales.isEmpty) _empty(Icons.receipt_long_outlined, 'Tu primera venta te espera', 'Después de cobrar, consulta el recibo aquí.'),
      ...sales.map((sale) => Card(color: Colors.white, child: ListTile(contentPadding: const EdgeInsets.all(16), leading: Icon(sale['status'] == 'voided' ? Icons.undo : Icons.receipt_long, color: _green), title: Text('Venta #${sale['number']} · ${soles(sale['total'] as int)}'), subtitle: Text('${peruDate(sale['at'])}\n${sale['status'] == 'voided' ? 'Anulada' : (sale['credit'] as int) > 0 ? 'Con fiado' : 'Completada'}${sale['legacy'] == true ? ' · Importada de Hive' : ''}'), isThreeLine: true, trailing: const Icon(Icons.chevron_right), onTap: () => _saleDetail(sale)))),
    ]);
  }

  Future<void> _saleDetail(Map<String, dynamic> original) async {
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text('Recibo comercial #${original['number']}'),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text((original['store'] as Map)['storeName'].toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        Text(peruDate(original['at'])), const Divider(),
        ...(original['lines'] as List).cast<Map>().map((line) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Expanded(child: Text('${line['name']}\n${displayQuantity(line['quantity'] as int, line['unit'].toString())} × ${soles(line['price'] as int)}')), Text(soles(line['total'] as int))]))),
        if (original['legacy'] == true) ...[const Divider(), const Text('Registro histórico importado: los componentes de pago no fueron almacenados de forma completa. Consulta la copia de los datos originales antes de conciliarlo.', style: TextStyle(color: _muted, fontSize: 12)), if (original['discount'] is int && original['discount'] != 0) Text('Descuento histórico: ${soles(original['discount'] as int)}')],
        const Divider(), Text('Total: ${soles(original['total'] as int)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 23)),
        ...(original['payments'] as List).cast<Map>().map((p) => Text('${paymentLabel(p['method'].toString())}: ${soles(p['amount'] as int)}')),
        Text('Vuelto: ${soles(original['change'] as int)}'),
        if ((original['credit'] as int) > 0) Text('Fiado original: ${soles(original['credit'] as int)}'),
        if (original['status'] == 'voided') Text('VENTA ANULADA\nMotivo: ${original['voidReason']}', style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 16), const Text('Este recibo comercial no reemplaza una boleta ni una factura electrónica.', style: TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 16), Wrap(spacing: 8, runSpacing: 8, children: [OutlinedButton.icon(onPressed: () => _receiptAction(original, print: false), icon: const Icon(Icons.share_outlined), label: const Text('Compartir PDF')), OutlinedButton.icon(onPressed: () => _receiptAction(original, print: true), icon: const Icon(Icons.print_outlined), label: const Text('Imprimir'))]),
        if (original['status'] == 'completed' && original['legacy'] != true) ...[const SizedBox(height: 10), TextButton(onPressed: () async { Navigator.pop(dialogContext); await _voidSale(original); }, child: const Text('Anular y devolver venta completa'))],
      ]))),
      actions: [TextButton(key: const ValueKey('close-receipt'), onPressed: () => Navigator.pop(dialogContext), child: const Text('Nueva venta / Listo'))],
    ));
  }

  Future<void> _receiptAction(Map<String, dynamic> sale, {required bool print}) async {
    try { if (print) { await ReceiptService.print(sale); } else { await ReceiptService.share(sale); } }
    catch (_) { _message('No pudimos abrir el servicio de impresión o compartir el PDF. La venta sigue guardada.', error: true); }
  }

  Future<void> _voidSale(Map<String, dynamic> sale) async {
    final reason = TextEditingController();
    var returned = false;
    final collected = (sale['total'] as int) - (sale['credit'] as int) + _cubit.state.data!.repayments.where((r) => r['saleId'] == sale['id']).fold<int>(0, (sum, r) => sum + (r['amount'] as int));
    await _dialog(title: 'Anular venta #${sale['number']}', confirm: 'Confirmar anulación', content: (refresh) => Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('Esta operación devuelve todos los productos al stock, cancela el fiado pendiente y registra la devolución de los importes cobrados, incluidos los abonos. No se borrará la venta.'), const SizedBox(height: 16), _field(reason, 'Motivo de la devolución', maxLength: 120),
      if (collected > 0) CheckboxListTile(contentPadding: EdgeInsets.zero, title: Text('Confirmo la devolución de ${soles(collected)} al cliente'), subtitle: const Text('Realiza y verifica las devoluciones digitales en tu cuenta o terminal. Zivlo no las procesa.'), value: returned, onChanged: (v) => refresh(() => returned = v ?? false))
      else const Text('No hay dinero cobrado que devolver. Se cancelará el fiado pendiente y se repondrá el stock.'),
    ]), submit: () { if (collected > 0 && !returned) throw const PosException('Confirma la devolución antes de anular.'); return _run({'type': 'void-sale', 'saleId': sale['id'], 'reason': reason.text, 'refundConfirmed': returned || collected == 0}, message: 'Anulación y movimientos de devolución guardados.'); });
    reason.dispose();
  }

  Widget _cash(PosState state) {
    final session = state.session;
    final movements = state.movements.where((m) => m['sessionId'] == session?['id']).toList();
    int digital(String method) => movements.where((m) => m['method'] == method).fold<int>(0, (n, m) => n + (m['amount'] as int));
    return ListView(padding: const EdgeInsets.all(20), children: [
      _heading('Que tu caja cuadre', 'Los pagos digitales se muestran separados del efectivo.', action: FilledButton.icon(onPressed: session == null ? _openSession : _closeSession, icon: const Icon(Icons.point_of_sale), label: Text(session == null ? 'Abrir caja' : 'Cerrar caja'))),
      _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(session == null ? 'Caja cerrada' : 'Efectivo esperado', style: const TextStyle(color: _muted)), const SizedBox(height: 8), Text(soles(state.cashBalance), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 32, color: _green)), if (session != null) Text('Fondo inicial: ${soles(session['opening'] as int)} · ${peruDate(session['openedAt'])}'), const SizedBox(height: 14), Text('Yape: ${soles(digital('yape'))} · Plin: ${soles(digital('plin'))}'), Text('Tarjeta: ${soles(digital('card'))}'), if (session != null) ...[const SizedBox(height: 16), OutlinedButton(onPressed: _cashMovement, child: const Text('Registrar ingreso o gasto'))]])),
      const SizedBox(height: 20), const Text('Movimientos de la caja actual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      if (movements.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('Aún no hay movimientos en esta caja.')),
      ...movements.reversed.map((m) => ListTile(contentPadding: EdgeInsets.zero, title: Text(m['reason'].toString()), subtitle: Text('${peruDate(m['at'])} · ${paymentLabel(m['method']?.toString() ?? 'cash')}'), trailing: Text(soles(m['amount'] as int), style: TextStyle(color: (m['amount'] as int) < 0 ? Colors.red.shade800 : _green, fontWeight: FontWeight.w700)))),
      const SizedBox(height: 20), const Text('Cierres anteriores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ...state.sessions.reversed.map((s) => Card(child: ListTile(title: Text(peruDate(s['closedAt'])), subtitle: Text('Esperado ${soles(s['expected'] as int)} · Contado ${soles(s['counted'] as int)}'), trailing: Text('Diferencia\n${soles(s['difference'] as int)}', textAlign: TextAlign.right)))),
    ]);
  }

  Future<void> _openSession() async {
    final controller = TextEditingController(text: '0.00');
    await _dialog(title: 'Abrir caja', confirm: 'Confirmar apertura', content: (_) => Column(mainAxisSize: MainAxisSize.min, children: [const Text('¿Con cuánto efectivo empiezas la jornada?'), const SizedBox(height: 16), _number(controller, 'Monto inicial (S/)', key: const ValueKey('opening-amount'))]), submit: () => _run({'type': 'open-session', 'opening': parseAmount(controller.text)}, message: 'Caja abierta. Ya puedes vender.'));
    controller.dispose();
  }

  Future<void> _closeSession() async {
    final state = _cubit.state.data!;
    final controller = TextEditingController();
    await _dialog(title: 'Cerrar caja', confirm: 'Confirmar cierre', content: (_) => Column(mainAxisSize: MainAxisSize.min, children: [Text('Efectivo esperado: ${soles(state.cashBalance)}'), const SizedBox(height: 12), const Text('Cuenta billetes y monedas. No incluyas Yape, Plin ni tarjeta.'), const SizedBox(height: 16), _number(controller, 'Efectivo contado (S/)')]), submit: () => _run({'type': 'close-session', 'counted': parseAmount(controller.text)}, message: 'Caja cerrada. Puedes consultar la diferencia en el historial.'));
    controller.dispose();
  }

  Future<void> _cashMovement() async {
    final amount = TextEditingController(); final reason = TextEditingController(); var kind = 'expense';
    await _dialog(title: 'Movimiento de efectivo', confirm: 'Guardar movimiento', content: (refresh) => Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(value: kind, decoration: const InputDecoration(labelText: 'Tipo'), items: const [DropdownMenuItem(value: 'expense', child: Text('Salida / gasto')), DropdownMenuItem(value: 'income', child: Text('Ingreso'))], onChanged: (v) => refresh(() => kind = v ?? 'expense')), const SizedBox(height: 16), _number(amount, 'Importe (S/)'), const SizedBox(height: 16), _field(reason, 'Motivo', maxLength: 120)]), submit: () => _run({'type': 'cash-movement', 'amount': parseAmount(amount.text), 'kind': kind, 'reason': reason.text}, message: 'Movimiento de caja guardado.'));
    amount.dispose(); reason.dispose();
  }

  Widget _customers(PosState state) => ListView(padding: const EdgeInsets.all(20), children: [
    _heading('Fiado, con cuentas claras', 'Los abonos reducen deuda y no generan otra venta.', action: FilledButton.icon(onPressed: () => _customerForm(), icon: const Icon(Icons.person_add_outlined), label: const Text('Agregar cliente'))),
    if (state.customers.isEmpty) _empty(Icons.people_outline, 'Conoce a tus clientes', 'Registra un cliente para vender al fiado y llevar sus abonos.'),
    ...state.customers.map((customer) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.person_outline, color: _green), const SizedBox(width: 12), Expanded(child: Text(customer['name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))), Text(soles(state.debtFor(customer['id'].toString())), style: const TextStyle(fontWeight: FontWeight.w800, color: _green, fontSize: 20))]),
      if (customer['phone'].toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(customer['phone'].toString())),
      const SizedBox(height: 8), TextButton(onPressed: () => _customerForm(customer: customer), child: const Text('Editar cliente')),
      ...state.sales.where((sale) => sale['customerId'] == customer['id'] && (sale['credit'] as int) > 0).map((sale) {
        final repaid = state.repayments.where((r) => r['saleId'] == sale['id']).fold<int>(0, (n, r) => n + (r['amount'] as int));
        final debt = sale['status'] == 'voided' ? 0 : (sale['credit'] as int) - repaid;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Divider(), ListTile(contentPadding: EdgeInsets.zero, title: Text('Venta #${sale['number']} · Pendiente ${soles(debt)}'), subtitle: Text('${peruDate(sale['at'])}${sale['status'] == 'voided' ? ' · Anulada' : ''}'), trailing: debt > 0 ? OutlinedButton(onPressed: () => _repay(sale, debt), child: const Text('Abonar')) : const Icon(Icons.check_circle_outline, color: _green)), ...state.repayments.where((r) => r['saleId'] == sale['id']).map((r) => Padding(padding: const EdgeInsets.only(left: 10, bottom: 8), child: Text('Abono ${soles(r['amount'] as int)} · ${paymentLabel(r['method'].toString())} · ${peruDate(r['at'])}', style: const TextStyle(color: _muted, fontSize: 12))))]);
      }),
    ])))),
  ]);

  Future<void> _customerForm({Map<String, dynamic>? customer}) async {
    final name = TextEditingController(text: customer?['name']?.toString() ?? ''); final phone = TextEditingController(text: customer?['phone']?.toString() ?? '');
    await _dialog(title: customer == null ? 'Agregar cliente' : 'Editar cliente', confirm: 'Guardar cliente', content: (_) => Column(mainAxisSize: MainAxisSize.min, children: [_field(name, 'Nombre del cliente', maxLength: 100), const SizedBox(height: 16), _field(phone, 'Teléfono (opcional)', maxLength: 30, keyboard: TextInputType.phone)]), submit: () => _run({'type': 'save-customer', 'customer': {'id': customer?['id'], 'name': name.text, 'phone': phone.text}}, message: 'Cliente guardado.'));
    name.dispose(); phone.dispose();
  }

  Future<void> _repay(Map<String, dynamic> sale, int debt) async {
    final amount = TextEditingController(); var method = 'cash'; var confirmed = false;
    await _dialog(title: 'Abonar a venta #${sale['number']}', confirm: 'Guardar abono', content: (refresh) => Column(mainAxisSize: MainAxisSize.min, children: [Text('Saldo pendiente: ${soles(debt)}'), const SizedBox(height: 16), _number(amount, 'Abono (S/)'), const SizedBox(height: 16), DropdownButtonFormField<String>(value: method, decoration: const InputDecoration(labelText: 'Medio de pago'), items: ['cash', 'yape', 'plin', 'card'].map((m) => DropdownMenuItem(value: m, child: Text(paymentLabel(m)))).toList(), onChanged: (v) => refresh(() { method = v ?? 'cash'; confirmed = false; })), if (method != 'cash') CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Verifiqué el pago digital recibido'), value: confirmed, onChanged: (v) => refresh(() => confirmed = v ?? false)), const SizedBox(height: 10), const Text('No se descontará stock ni se registrará otra venta.', style: TextStyle(color: _muted, fontSize: 12))]), submit: () => _run({'type': 'repay', 'saleId': sale['id'], 'amount': parseAmount(amount.text), 'method': method, 'digitalConfirmed': confirmed}, message: 'Abono guardado.'));
    amount.dispose();
  }

  Widget _business(PosState state) => ListView(padding: const EdgeInsets.all(20), children: [
    _heading('Tu negocio, a tu ritmo', 'Configura tus recibos y protege la información local.'),
    _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(state.settings['storeName'].toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)), if (state.settings['owner'].toString().isNotEmpty) Text(state.settings['owner'].toString()), if (state.settings['address'].toString().isNotEmpty) Text(state.settings['address'].toString()), const SizedBox(height: 16), OutlinedButton(onPressed: () => _settingsForm(state), child: const Text('Editar datos del negocio'))])),
    const SizedBox(height: 18), _panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Icon(Icons.shield_outlined, size: 36, color: _green), const SizedBox(height: 12), const Text('Cuida tus datos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)), const SizedBox(height: 10), const Text('La información permanece en este dispositivo. Borrar los datos de la app o desinstalarla puede eliminarla. Guarda copias en un lugar privado.'), const SizedBox(height: 18), FilledButton.icon(onPressed: () => _exportBackup(), icon: const Icon(Icons.save_alt), label: const Text('Exportar copia de seguridad')), const SizedBox(height: 10), OutlinedButton.icon(onPressed: _restoreBackup, icon: const Icon(Icons.upload_file_outlined), label: const Text('Restaurar una copia')), TextButton(onPressed: () => _exportBackup(recovery: true), child: const Text('Exportar copia anterior a la última restauración'))])),
    const SizedBox(height: 18), _panel(const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Alcance de esta versión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), SizedBox(height: 10), Text('Pagos digitales confirmados manualmente. Los recibos son comerciales y no son comprobantes SUNAT. Impresión mediante el servicio del sistema; Bluetooth directo y sincronización entre dispositivos aún no están integrados.'), SizedBox(height: 10), Text('Una caja local y un responsable. No incluye permisos por cajero ni cifrado de las copias exportadas.', style: TextStyle(color: _muted, fontSize: 12))])),
  ]);

  Future<void> _settingsForm(PosState state) async {
    final controllers = {for (final key in ['storeName', 'owner', 'address', 'ruc']) key: TextEditingController(text: state.settings[key].toString())};
    await _dialog(title: 'Datos del negocio', confirm: 'Guardar datos', content: (_) => Column(mainAxisSize: MainAxisSize.min, children: [_field(controllers['storeName']!, 'Nombre del negocio', maxLength: 80), const SizedBox(height: 12), _field(controllers['owner']!, 'Responsable', maxLength: 80), const SizedBox(height: 12), _field(controllers['address']!, 'Dirección', maxLength: 160), const SizedBox(height: 12), _field(controllers['ruc']!, 'RUC de 11 dígitos (opcional)', maxLength: 11, keyboard: TextInputType.number)]), submit: () => _run({'type': 'settings', 'settings': controllers.map((key, value) => MapEntry(key, value.text))}, message: 'Datos del negocio guardados.'));
    for (final c in controllers.values) { c.dispose(); }
  }

  Future<void> _exportBackup({bool recovery = false}) async {
    try {
      final json = recovery ? await _cubit.exportRecoveryBackup() : await _cubit.exportBackup();
      if (json == null) { _message('Aún no hay una copia anterior a una restauración.'); return; }
      await Share.shareXFiles([XFile.fromData(utf8.encode(json), mimeType: 'application/json', name: 'zivlo-${recovery ? 'recuperacion' : 'copia'}-${DateTime.now().millisecondsSinceEpoch}.json')], text: 'Copia de seguridad Zivlo. Contiene datos privados del negocio.');
    } catch (_) { _message('No se pudo exportar la copia. Los datos del negocio siguen guardados.', error: true); }
  }

  Future<void> _restoreBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      if (result == null) return;
      final file = result.files.single;
      if (file.size > 20 * 1024 * 1024 || file.bytes == null) throw const PosException('La copia no es válida o supera 20 MB.');
      if (!await _confirm('Restaurar copia', 'Reemplazará los datos actuales. Exporta una copia antes de continuar. Zivlo guardará además una copia interna del estado anterior.')) return;
      if (await _cubit.restoreBackup(utf8.decode(file.bytes!))) _message('Copia restaurada correctamente.');
    } catch (error) { _message(error is PosException ? error.message : 'No se pudo leer la copia. No se modificaron los datos.', error: true); }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _BarcodePage()));
    if (!mounted || code == null) return;
    final state = _cubit.state.data!;
    final product = state.products.where((p) => p['active'] == true && p['barcode'] == code).firstOrNull;
    if (product != null) { await _addProduct(product); }
    else if (await _confirm('Producto no encontrado', 'No existe un producto con el código $code. ¿Quieres registrarlo?')) { await _productForm(state, barcode: code); }
  }

  Widget _field(TextEditingController controller, String label, {int maxLength = 160, TextInputType? keyboard}) => TextField(controller: controller, keyboardType: keyboard, maxLength: maxLength, decoration: InputDecoration(labelText: label, counterText: ''));
  Widget _number(TextEditingController controller, String label, {bool decimals = true, Key? key, ValueChanged<String>? onChanged}) => TextField(key: key, controller: controller, keyboardType: TextInputType.numberWithOptions(decimal: decimals), onChanged: onChanged, decoration: InputDecoration(labelText: label));
  String _decimal(int n, int places) { final scale = places == 3 ? 1000 : 100; return '${n ~/ scale}.${(n % scale).toString().padLeft(places, '0')}'; }

  Future<bool> _confirm(String title, String message) async => await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continuar'))])) ?? false;

  Future<bool> _dialog({required String title, required Widget Function(StateSetter) content, required Future<bool> Function() submit, String confirm = 'Guardar', String? confirmKey}) async {
    var saving = false;
    String? error;
    return await showDialog<bool>(context: context, barrierDismissible: false, builder: (dialogContext) => StatefulBuilder(builder: (context, refresh) => PopScope(canPop: !saving, child: AlertDialog(
      title: Text(title),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [AbsorbPointer(absorbing: saving, child: content(refresh)), if (error != null) ...[const SizedBox(height: 16), Text(error!, style: const TextStyle(color: Color(0xFF8C342B)))]]))),
      actions: [TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')), FilledButton(key: confirmKey == null ? null : ValueKey(confirmKey), onPressed: saving ? null : () async {
        refresh(() { saving = true; error = null; });
        bool success = false;
        try { success = await submit(); if (!success) error = _cubit.state.error ?? 'No se guardó la operación. Revisa los datos.'; }
        catch (e) { error = e is PosException ? e.message : 'Revisa los datos e intenta nuevamente.'; }
        if (!dialogContext.mounted) return;
        if (success) { Navigator.pop(dialogContext, true); } else { refresh(() => saving = false); }
      }, child: Text(saving ? 'Guardando…' : confirm))],
    )))) ?? false;
  }
}

class _BarcodePage extends StatefulWidget {
  const _BarcodePage();
  @override
  State<_BarcodePage> createState() => _BarcodePageState();
}
class _BarcodePageState extends State<_BarcodePage> {
  final controller = MobileScannerController();
  bool found = false;
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Escanear producto')), body: MobileScanner(controller: controller, onDetect: (capture) {
    if (found || !mounted) return;
    final codes = capture.barcodes.where((b) => b.rawValue?.isNotEmpty ?? false);
    if (codes.isEmpty) return;
    found = true; Navigator.pop(context, codes.first.rawValue);
  }, errorBuilder: (context, error, child) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.camera_alt_outlined, size: 48), const SizedBox(height: 16), const Text('No pudimos acceder a la cámara. Revisa el permiso de cámara en los ajustes del teléfono o busca el producto por nombre.'), const SizedBox(height: 16), FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Volver'))])))));
}
