import 'dart:convert';

import 'package:uuid/uuid.dart';

const _limit = 1000000000;
const _methods = ['cash', 'yape', 'plin', 'card'];
const _units = ['und', 'kg', 'L'];

class PosException implements Exception {
  const PosException(this.message);
  final String message;
  @override
  String toString() => message;
}

void _require(bool condition, String message) {
  if (!condition) throw PosException(message);
}

bool _integer(dynamic v, [int min = 0, int max = _limit]) =>
    v is int && v >= min && v <= max;
bool _text(dynamic v, [int max = 160]) => v is String && v.length <= max;
bool _name(dynamic v, [int max = 160]) => _text(v, max) && (v as String).trim().isNotEmpty;
bool _date(dynamic v) => v is String && DateTime.tryParse(v) != null;
Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
Map<String, dynamic> _map(dynamic value, String message) {
  _require(value is Map, message);
  try {
    return Map<String, dynamic>.from(value as Map);
  } on TypeError {
    throw PosException(message);
  }
}
List<Map<String, dynamic>> _rows(dynamic value, String message) {
  _require(value is List && value.length <= 50000, message);
  return (value as List).map((e) => _map(e, message)).toList();
}
dynamic _freeze(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(value.map((k, v) => MapEntry(k as String, _freeze(v))));
  }
  if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
  return value;
}
int _sum(Iterable<int> values) => values.fold(0, (a, b) => a + b);
int _lineTotal(int price, int quantity) {
  // Divide before multiplying to avoid lossy arithmetic on Dart web.
  final amount = price * (quantity ~/ 1000) + (price * (quantity % 1000) + 500) ~/ 1000;
  _require(_integer(amount), 'El importe excede el límite permitido.');
  return amount;
}
int lineAmount(int price, int quantity) => _lineTotal(price, quantity);

/// Parse an unsigned decimal exactly; no floating point conversion is involved.
int parseAmount(String value, {int decimals = 2}) {
  _require(decimals >= 0 && decimals <= 3, 'Precisión inválida.');
  final raw = value.trim().replaceAll(',', '.');
  final pattern = decimals == 0 ? r'^\d+$' : '^\\d+(?:\\.\\d{1,$decimals})?\$';
  _require(RegExp(pattern).hasMatch(raw), 'Ingresa un número positivo con hasta $decimals decimales.');
  final parts = raw.split('.');
  final fraction = parts.length == 2 ? parts[1] : '';
  final parsed = int.tryParse(parts[0] + fraction.padRight(decimals, '0'));
  _require(_integer(parsed), 'El importe excede el límite permitido.');
  return parsed!;
}

String soles(int cents) => '${cents < 0 ? '-' : ''}S/ ${cents.abs() ~/ 100}.${(cents.abs() % 100).toString().padLeft(2, '0')}';
String displayQuantity(int quantity, String unit) {
  final remainder = (quantity.abs() % 1000).toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '');
  return '${quantity < 0 ? '-' : ''}${quantity.abs() ~/ 1000}${remainder.isEmpty ? '' : '.$remainder'} $unit';
}

/// A validated, deeply immutable snapshot. Mutations go through [PosEngine].
class PosState {
  PosState._(Map<String, dynamic> data) : _data = _freeze(data) as Map<String, dynamic>;
  final Map<String, dynamic> _data;

  factory PosState.fromJson(Map<String, dynamic> json) {
    try {
      final data = _copy(json);
      _require(data['version'] == 1 || data['version'] == 2, 'La copia no es compatible con esta versión.');
      if (data['version'] == 1) {
        data['version'] = 2;
        data.putIfAbsent('stockMovements', () => <dynamic>[]);
        data.putIfAbsent('customers', () => <dynamic>[]);
        data.putIfAbsent('repayments', () => <dynamic>[]);
        for (final sale in _rows(data['sales'], 'Ventas inválidas.')) {
          // Update original maps after validating the collection shape.
          final original = (data['sales'] as List).firstWhere((e) => e['id'] == sale['id']) as Map;
          original.putIfAbsent('credit', () => 0);
          original.putIfAbsent('status', () => 'completed');
        }
      }
      for (final product in _rows(data['products'], 'Productos inválidos.')) {
        final original = (data['products'] as List).firstWhere((p) => p['id'] == product['id']) as Map;
        if (!original.containsKey('openingStock')) {
          final deltas = _rows(data['stockMovements'], 'Inventario inválido.').where((m) => m['productId'] == product['id']);
          original['openingStock'] = (product['stock'] as int) - _sum(deltas.map((m) => m['quantityDelta'] as int));
        }
      }
      _validate(data);
      return PosState._(data);
    } on PosException {
      rethrow;
    } catch (_) {
      throw const PosException('La copia contiene datos inválidos.');
    }
  }

  factory PosState.empty() => PosState.fromJson({
    'version': 2, 'revision': 0,
    'settings': {'storeName': 'Mi bodega', 'owner': '', 'address': '', 'ruc': ''},
    'products': [], 'cart': [], 'sales': [], 'movements': [], 'sessions': [],
    'stockMovements': [], 'customers': [], 'repayments': [], 'session': null,
  });

  factory PosState.demo() {
    final data = PosState.empty().toJson();
    const examples = [
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
    ];
    data['products'] = examples.asMap().entries.map((e) => {
      'id': 'product-${e.key + 1}', 'name': e.value[0], 'category': e.value[1],
      'price': e.value[2], 'unit': e.value[3], 'stock': e.value[4], 'art': e.value[5],
      'barcode': e.value[6], 'active': true,
    }).toList();
    return PosState.fromJson(data);
  }

  Map<String, dynamic> toJson() => _copy(_data);
  int get version => _data['version'] as int;
  int get revision => _data['revision'] as int;
  Map<String, dynamic> get settings => _data['settings'] as Map<String, dynamic>;
  List<Map<String, dynamic>> _list(String key) => List<Map<String, dynamic>>.unmodifiable((_data[key] as List).cast<Map<String, dynamic>>());
  List<Map<String, dynamic>> get products => _list('products');
  List<Map<String, dynamic>> get cart => _list('cart');
  List<Map<String, dynamic>> get sales => _list('sales');
  List<Map<String, dynamic>> get movements => _list('movements');
  List<Map<String, dynamic>> get sessions => _list('sessions');
  List<Map<String, dynamic>> get stockMovements => _list('stockMovements');
  List<Map<String, dynamic>> get customers => _list('customers');
  List<Map<String, dynamic>> get repayments => _list('repayments');
  Map<String, dynamic>? get session => _data['session'] as Map<String, dynamic>?;
  int get total => _sum(cart.map((line) => _lineTotal(line['price'] as int, line['quantity'] as int)));
  int get cashBalance => _cashBalance(_data);
  String get cartKey => jsonEncode(cart);
  int debtFor(String customerId) => _sum(sales.where((s) => s['customerId'] == customerId && s['status'] == 'completed').map((s) => (s['credit'] as int) - _sum(repayments.where((r) => r['saleId'] == s['id']).map((r) => r['amount'] as int))));
}

int _cashBalance(Map<String, dynamic> data) {
  final session = data['session'] as Map?;
  if (session == null) return 0;
  return (session['opening'] as int) + _sum((data['movements'] as List).where((m) => m['sessionId'] == session['id'] && (m['method'] == null || m['method'] == 'cash')).map((m) => m['amount'] as int));
}

class PosEngine {
  PosEngine({DateTime Function()? clock, String Function()? id})
      : _clock = clock ?? DateTime.now, _id = id ?? const Uuid().v4;
  final DateTime Function() _clock;
  final String Function() _id;

  PosState dispatch(PosState state, Map<String, dynamic> action) {
    final s = state.toJson();
    final at = _clock().toUtc().toIso8601String();
    final products = (s['products'] as List).cast<Map<String, dynamic>>();
    final cart = (s['cart'] as List).cast<Map<String, dynamic>>();
    Map<String, dynamic>? find(List<dynamic> list, dynamic id) {
      for (final item in list) { if (item['id'] == id) return item as Map<String, dynamic>; }
      return null;
    }
    Map<String, dynamic> requireSession() {
      _require(s['session'] != null, 'Abre la caja primero.');
      return s['session'] as Map<String, dynamic>;
    }
    void movement(int amount, String kind, String reason, {String method = 'cash', String? saleId}) {
      (s['movements'] as List).add({'id': _id(), 'sessionId': requireSession()['id'], 'amount': amount, 'reason': reason, 'kind': kind, 'method': method, 'at': at, if (saleId != null) 'saleId': saleId});
    }
    void stock(Map<String, dynamic> product, int delta, String kind, String reason, {String? saleId}) {
      final next = (product['stock'] as int) + delta;
      _require(_integer(next), 'Stock insuficiente o fuera del límite.');
      product['stock'] = next;
      (s['stockMovements'] as List).add({'id': _id(), 'productId': product['id'], 'quantityDelta': delta, 'kind': kind, 'reason': reason, 'at': at, if (saleId != null) 'saleId': saleId});
    }
    switch (action['type']) {
      case 'load-demo':
        _require(products.isEmpty && cart.isEmpty && (s['sales'] as List).isEmpty && (s['customers'] as List).isEmpty, 'El catálogo de ejemplo solo se puede cargar en un negocio vacío.');
        s['products'] = PosState.demo().toJson()['products'];
        break;
      case 'cart-add':
        final product = find(products, action['productId']);
        _require(product != null && product['active'] == true, 'Producto no disponible.');
        final amount = action['quantity'] ?? 1000;
        _validQuantity(amount, product!['unit'], min: 1);
        Map<String, dynamic>? line;
        for (final item in cart) { if (item['productId'] == product['id']) line = item; }
        final q = (line?['quantity'] as int? ?? 0) + (amount as int);
        _require(q <= (product['stock'] as int), 'Stock disponible: ${displayQuantity(product['stock'] as int, product['unit'] as String)}.');
        if (line == null) { cart.add({'productId': product['id'], 'price': product['price'], 'quantity': q}); }
        else { line['quantity'] = q; }
        s['cart'] = cart;
        break;
      case 'cart-quantity':
        final product = find(products, action['productId']);
        Map<String, dynamic>? line;
        for (final item in cart) { if (item['productId'] == action['productId']) line = item; }
        _require(product != null && line != null, 'Producto no encontrado en el carrito.');
        _validQuantity(action['quantity'], product!['unit']);
        _require((action['quantity'] as int) <= (product['stock'] as int), 'Stock insuficiente.');
        if (action['quantity'] == 0) { cart.remove(line); } else { line!['quantity'] = action['quantity']; }
        s['cart'] = cart;
        break;
      case 'cart-clear': s['cart'] = <dynamic>[]; break;
      case 'open-session':
        _require(s['session'] == null, 'La caja ya está abierta.');
        _require(_integer(action['opening']), 'Monto inicial inválido.');
        s['session'] = {'id': _id(), 'opening': action['opening'], 'openedAt': at};
        break;
      case 'close-session':
        final session = requireSession();
        _require(_integer(action['counted']), 'Monto contado inválido.');
        final expected = _cashBalance(s);
        (s['sessions'] as List).add({...session, 'expected': expected, 'counted': action['counted'], 'difference': (action['counted'] as int) - expected, 'closedAt': at});
        s['session'] = null;
        break;
      case 'cash-movement':
        requireSession();
        _require(_integer(action['amount'], 1) && _name(action['reason'], 120), 'Indica un importe y un motivo.');
        _require(['income', 'expense'].contains(action['kind']), 'Tipo de movimiento inválido.');
        final amount = (action['amount'] as int) * (action['kind'] == 'expense' ? -1 : 1);
        _require(_cashBalance(s) + amount >= 0, 'El retiro supera el efectivo esperado.');
        movement(amount, action['kind'] as String, (action['reason'] as String).trim());
        break;
      case 'save-product':
        final p = _map(action['product'], 'Producto inválido.');
        final previous = find(products, p['id']);
        _require(p['id'] == null || previous != null, 'El producto ya no existe.');
        final result = {...p, 'id': previous?['id'] ?? _id(), 'active': previous?['active'] ?? true, 'art': previous?['art'] ?? p['art'] ?? 'bag', 'openingStock': previous?['openingStock'] ?? 0};
        _validateProduct(result);
        result['name'] = (result['name'] as String).trim();
        result['category'] = (result['category'] as String).trim();
        result['barcode'] = (result['barcode'] as String).trim();
        _require(result['barcode'] == '' || !products.any((p) => p['id'] != result['id'] && p['barcode'] == result['barcode']), 'Ya existe un producto con ese código.');
        _require(previous == null || previous['unit'] == result['unit'], 'La unidad de un producto existente no se puede cambiar; crea otro producto.');
        _require(!cart.any((l) => l['productId'] == result['id'] && (l['quantity'] as int) > (result['stock'] as int)), 'El stock no puede ser menor a la cantidad del carrito.');
        if (previous != null) {
          final delta = (result['stock'] as int) - (previous['stock'] as int);
          if (delta != 0) {
            _require(_name(p['stockReason'], 120), 'Indica el motivo del ajuste de stock.');
            stock(previous, delta, 'adjustment', (p['stockReason'] as String).trim());
          }
          products[products.indexOf(previous)] = result;
        } else {
          final initialStock = result['stock'] as int;
          result['stock'] = 0;
          products.add(result);
          if (initialStock > 0) stock(result, initialStock, 'purchase', 'Inventario inicial');
        }
        s['products'] = products;
        break;
      case 'archive-product':
        final product = find(products, action['productId']);
        _require(product != null, 'Producto no encontrado.');
        _require(!cart.any((l) => l['productId'] == product!['id']), 'Retira el producto del carrito antes de archivarlo.');
        product!['active'] = false;
        break;
      case 'unarchive-product':
        final product = find(products, action['productId']);
        _require(product != null && _integer(product['price'], 1, 100000000), 'Corrige el precio del producto antes de reactivarlo.');
        product!['active'] = true;
        break;
      case 'stock-movement':
        final product = find(products, action['productId']);
        _require(product != null, 'Producto no encontrado.');
        _require(['purchase', 'loss', 'adjustment'].contains(action['kind']), 'Tipo de movimiento inválido.');
        _require(_name(action['reason'], 120), 'Indica el motivo del movimiento.');
        final q = action['quantity'];
        _require(_integer(q, action['kind'] == 'adjustment' ? -_limit : 1) && q != 0, 'Cantidad inválida.');
        _validQuantity((q as int).abs(), product!['unit'], min: 1);
        final delta = action['kind'] == 'loss' ? -q : q;
        final next = (product['stock'] as int) + delta;
        _require(!cart.any((l) => l['productId'] == product['id'] && (l['quantity'] as int) > next), 'Retira la cantidad reservada del carrito antes de reducir el stock.');
        stock(product, delta, action['kind'] as String, (action['reason'] as String).trim());
        break;
      case 'settings':
        final settings = _map(action['settings'], 'Datos del negocio inválidos.');
        _validateSettings(settings);
        s['settings'] = {for (final key in ['storeName', 'owner', 'address', 'ruc']) key: (settings[key] as String).trim()};
        break;
      case 'save-customer':
        final customer = _map(action['customer'], 'Cliente inválido.');
        _require(_name(customer['name'], 100) && _text(customer['phone'], 30), 'Indica nombre y teléfono válidos.');
        final customers = s['customers'] as List;
        final previous = find(customers, customer['id']);
        _require(customer['id'] == null || previous != null, 'Cliente no encontrado.');
        final result = {'id': previous?['id'] ?? _id(), 'name': (customer['name'] as String).trim(), 'phone': (customer['phone'] as String).trim()};
        if (previous == null) { customers.add(result); } else { customers[customers.indexOf(previous)] = result; }
        break;
      case 'checkout':
        final session = requireSession();
        _require(action['cartKey'] == state.cartKey, 'El carrito cambió. Revisa el total antes de cobrar.');
        _require(cart.isNotEmpty && state.total > 0, 'Agrega productos al carrito.');
        final lines = cart.map((line) {
          final p = find(products, line['productId']);
          _require(p != null && p['active'] == true && (p['stock'] as int) >= (line['quantity'] as int), 'Stock insuficiente.');
          final amount = _lineTotal(line['price'] as int, line['quantity'] as int);
          _require(amount > 0, 'Una cantidad es demasiado pequeña para cobrarla. Aumenta la cantidad o retírala del carrito.');
          return {...line, 'name': p!['name'], 'unit': p['unit'], 'barcode': p['barcode'], 'total': amount};
        }).toList();
        final payments = _rows(action['payments'], 'Indica los medios de pago.');
        _validatePayments(payments, allowEmpty: action['credit'] == true);
        final digital = _sum(payments.where((p) => p['method'] != 'cash').map((p) => p['amount'] as int));
        final cash = _sum(payments.where((p) => p['method'] == 'cash').map((p) => p['amount'] as int));
        _require(digital <= state.total, 'Los pagos digitales no pueden superar el total.');
        _require(digital == 0 || action['digitalConfirmed'] == true, 'Confirma que recibiste el pago digital.');
        final received = cash + digital;
        _require(action['credit'] == true || received >= state.total, 'El pago no cubre el total de la venta.');
        final credit = received < state.total ? state.total - received : 0;
        if (credit > 0) _require(find(s['customers'] as List, action['customerId']) != null, 'Selecciona un cliente para registrar el fiado.');
        if (action['customerId'] != null) _require(find(s['customers'] as List, action['customerId']) != null, 'Cliente no encontrado.');
        final change = received > state.total ? received - state.total : 0;
        final sales = s['sales'] as List;
        final number = sales.fold<int>(0, (max, sale) => (sale['number'] as int) > max ? sale['number'] as int : max) + 1;
        final sale = {'id': _id(), 'number': number, 'at': at, 'sessionId': session['id'], 'lines': lines, 'total': state.total, 'payments': payments, 'change': change, 'store': _copy(s['settings'] as Map<String, dynamic>), 'credit': credit, 'status': 'completed', 'digitalConfirmed': digital > 0, if (digital > 0) 'digitalConfirmedAt': at, if (action['customerId'] != null) 'customerId': action['customerId']};
        sales.add(sale);
        for (final line in lines) { stock(find(products, line['productId'])!, -(line['quantity'] as int), 'sale', 'Venta #$number', saleId: sale['id'] as String); }
        for (final payment in payments) {
          final amount = (payment['amount'] as int) - (payment['method'] == 'cash' ? change : 0);
          if (amount != 0) movement(amount, 'sale', 'Venta #$number', method: payment['method'] as String, saleId: sale['id'] as String);
        }
        s['cart'] = <dynamic>[];
        break;
      case 'repay':
        final session = requireSession();
        final sale = find(s['sales'] as List, action['saleId']);
        _require(sale != null && sale['status'] == 'completed' && sale['customerId'] != null, 'La venta no tiene una deuda pendiente.');
        final repaid = _sum((s['repayments'] as List).where((r) => r['saleId'] == sale!['id']).map((r) => r['amount'] as int));
        _require(_integer(action['amount'], 1) && (action['amount'] as int) <= (sale!['credit'] as int) - repaid, 'El abono supera la deuda o es inválido.');
        _require(_methods.contains(action['method']), 'Medio de pago inválido.');
        _require(action['method'] == 'cash' || action['digitalConfirmed'] == true, 'Confirma que recibiste el pago digital.');
        (s['repayments'] as List).add({'id': _id(), 'customerId': sale!['customerId'], 'saleId': sale['id'], 'amount': action['amount'], 'method': action['method'], 'at': at, 'sessionId': session['id']});
        movement(action['amount'] as int, 'repayment', 'Abono venta #${sale['number']}', method: action['method'] as String, saleId: sale['id'] as String);
        break;
      case 'void-sale':
        requireSession();
        final sale = find(s['sales'] as List, action['saleId']);
        _require(sale != null && sale['status'] == 'completed', 'La venta no existe o ya fue anulada.');
        _require(sale!['legacy'] != true, 'Esta venta importada requiere conciliación manual antes de anularla.');
        _require(_name(action['reason'], 120), 'Indica el motivo de la anulación.');
        final refunds = <String, int>{};
        for (final payment in sale['payments'] as List) {
          final method = payment['method'] as String;
          refunds[method] = (payment['amount'] as int) - (method == 'cash' ? sale['change'] as int : 0);
        }
        for (final repayment in (s['repayments'] as List).where((r) => r['saleId'] == sale['id'])) {
          final method = repayment['method'] as String;
          refunds[method] = (refunds[method] ?? 0) + (repayment['amount'] as int);
        }
        _require(!refunds.values.any((amount) => amount > 0) || action['refundConfirmed'] == true, 'Confirma la devolución del dinero antes de anular.');
        _require(_cashBalance(s) >= (refunds['cash'] ?? 0), 'Efectivo insuficiente para devolver el pago.');
        for (final line in sale['lines'] as List) {
          final product = find(products, line['productId']);
          _require(product != null, 'No se puede restituir un producto desconocido.');
          stock(product!, line['quantity'] as int, 'return', (action['reason'] as String).trim(), saleId: sale['id'] as String);
        }
        for (final refund in refunds.entries) {
          if (refund.value > 0) movement(-refund.value, 'refund', 'Anulación venta #${sale['number']}', method: refund.key, saleId: sale['id'] as String);
        }
        sale['refunds'] = refunds.entries.where((e) => e.value > 0).map((e) => {'method': e.key, 'amount': e.value}).toList();
        sale['status'] = 'voided'; sale['voidReason'] = (action['reason'] as String).trim(); sale['voidedAt'] = at; sale['refundConfirmed'] = true;
        break;
      default: throw const PosException('Operación desconocida.');
    }
    s['revision'] = state.revision + 1;
    return PosState.fromJson(s);
  }
}

void _validQuantity(dynamic quantity, dynamic unit, {int min = 0}) {
  _require(_integer(quantity, min) && _units.contains(unit) && (unit != 'und' || (quantity as int) % 1000 == 0), 'La cantidad no es válida para esta unidad.');
}
void _validateSettings(Map<String, dynamic> settings) {
  _require(_name(settings['storeName'], 80) && _text(settings['owner'], 80) && _text(settings['address'], 160) && (settings['ruc'] == '' || (settings['ruc'] is String && RegExp(r'^\d{11}$').hasMatch(settings['ruc'] as String))), 'Datos del negocio inválidos.');
}
void _validateProduct(Map<String, dynamic> p) {
  _require(_name(p['id'], 100) && _name(p['name'], 100) && _name(p['category'], 50) && _integer(p['price'], p['legacy'] == true ? 0 : 1, 100000000) && _text(p['barcode'], 60) && _text(p['art'], 40) && p['active'] is bool, 'Producto inválido.');
  _validQuantity(p['stock'], p['unit']);
}
void _validatePayments(List<Map<String, dynamic>> payments, {bool allowEmpty = false}) {
  _require(payments.length <= 4 && (allowEmpty || payments.isNotEmpty) && payments.map((p) => p['method']).toSet().length == payments.length, 'Medios de pago inválidos o repetidos.');
  for (final p in payments) { _require(_methods.contains(p['method']) && _integer(p['amount'], 1), 'Importe de pago inválido.'); }
}

void _validate(Map<String, dynamic> data) {
  _require(_integer(data['revision']), 'Revisión inválida.');
  _validateSettings(_map(data['settings'], 'Datos del negocio inválidos.'));
  final collections = <String, List<Map<String, dynamic>>>{};
  for (final key in ['products', 'cart', 'sales', 'movements', 'sessions', 'stockMovements', 'customers', 'repayments']) { collections[key] = _rows(data[key], 'Copia incompleta: $key.'); }
  final products = <String, Map<String, dynamic>>{};
  final codes = <String>{};
  for (final p in collections['products']!) {
    _validateProduct(p);
    _require(!products.containsKey(p['id']), 'Producto duplicado.');
    products[p['id'] as String] = p;
    final code = p['barcode'] as String;
    _require(code.isEmpty || codes.add(code), 'Código de barras duplicado.');
  }
  final cartIds = <String>{};
  var cartTotal = 0;
  for (final line in collections['cart']!) {
    final p = products[line['productId']];
    _require(p != null && p['active'] == true && cartIds.add(p['id'] as String), 'Producto del carrito inválido.');
    _validQuantity(line['quantity'], p!['unit'], min: 1);
    _require(_integer(line['price'], 1, 100000000) && (line['quantity'] as int) <= (p['stock'] as int), 'Precio o stock del carrito inválido.');
    cartTotal += _lineTotal(line['price'] as int, line['quantity'] as int);
  }
  _require(_integer(cartTotal), 'El carrito excede el límite permitido.');
  final sessionIds = <String>{};
  final allSessions = [...collections['sessions']!, if (data['session'] != null) _map(data['session'], 'Caja inválida.')];
  for (final session in allSessions) {
    _require(_name(session['id'], 100) && sessionIds.add(session['id'] as String) && _integer(session['opening']) && _date(session['openedAt']), 'Caja inválida o duplicada.');
    if (session != allSessions.last || data['session'] == null) {
      _require(_integer(session['expected']) && _integer(session['counted']) && session['difference'] == (session['counted'] as int) - (session['expected'] as int) && _date(session['closedAt']), 'Cierre de caja inválido.');
    }
  }
  final customerIds = <String>{};
  for (final c in collections['customers']!) {
    _require(_name(c['id'], 100) && customerIds.add(c['id'] as String) && _name(c['name'], 100) && _text(c['phone'], 30), 'Cliente inválido o duplicado.');
  }
  final sales = <String, Map<String, dynamic>>{};
  final numbers = <int>{};
  for (final sale in collections['sales']!) {
    final legacy = sale['legacy'] == true;
    _require(_name(sale['id'], 100) && !sales.containsKey(sale['id']) && _integer(sale['number'], 1) && numbers.add(sale['number'] as int) && _date(sale['at']) && _integer(sale['total'], legacy ? 0 : 1) && _integer(sale['change']) && _integer(sale['credit']) && ['completed', 'voided'].contains(sale['status']), 'Venta inválida o duplicada.');
    sales[sale['id'] as String] = sale;
    _require(legacy || sessionIds.contains(sale['sessionId']), 'La venta referencia una caja desconocida.');
    _require(sale['customerId'] == null || customerIds.contains(sale['customerId']), 'Cliente de venta desconocido.');
    _require(sale['credit'] == 0 || sale['customerId'] != null, 'Fiado sin cliente.');
    final lines = _rows(sale['lines'], 'Detalle de venta inválido.');
    _require(lines.isNotEmpty, 'Venta sin productos.');
    final seen = <String>{};
    for (final line in lines) {
      _require(_name(line['productId'], 100) && (legacy || seen.add(line['productId'] as String)) && (legacy || products.containsKey(line['productId'])) && _name(line['name'], 100) && _text(line['barcode'], 60) && _integer(line['price'], legacy ? 0 : 1, 100000000), 'Detalle de venta inválido.');
      _validQuantity(line['quantity'], line['unit'], min: 1);
      _require(_integer(line['total']) && (legacy || line['total'] == _lineTotal(line['price'] as int, line['quantity'] as int)), 'Importe de línea inconsistente.');
    }
    _require(legacy || _sum(lines.map((l) => l['total'] as int)) == sale['total'], 'Total de venta inconsistente.');
    final payments = _rows(sale['payments'], 'Pagos inválidos.');
    _validatePayments(payments, allowEmpty: (sale['credit'] as int) > 0 || (legacy && sale['paymentsComplete'] == false));
    final cash = _sum(payments.where((p) => p['method'] == 'cash').map((p) => p['amount'] as int));
    final electronic = _sum(payments.where((p) => p['method'] != 'cash').map((p) => p['amount'] as int));
    _require((legacy && sale['paymentsComplete'] == false) || (electronic <= (sale['total'] as int) && (sale['change'] as int) <= cash && cash + electronic - (sale['change'] as int) + (sale['credit'] as int) == sale['total'] && (sale['credit'] == 0 || sale['change'] == 0)), 'Los pagos no cuadran con la venta.');
    _validateSettings(_map(sale['store'], 'Datos del recibo inválidos.'));
    if (sale['status'] == 'voided') _require(_name(sale['voidReason'], 120) && _date(sale['voidedAt']) && sale['refundConfirmed'] == true, 'Anulación incompleta.');
  }
  final repaymentIds = <String>{};
  final repaidBySale = <String, int>{};
  for (final r in collections['repayments']!) {
    final sale = sales[r['saleId']];
    _require(_name(r['id'], 100) && repaymentIds.add(r['id'] as String) && sale != null && r['customerId'] == sale['customerId'] && customerIds.contains(r['customerId']) && sessionIds.contains(r['sessionId']) && _integer(r['amount'], 1) && _methods.contains(r['method']) && _date(r['at']), 'Abono inválido.');
    final id = r['saleId'] as String;
    repaidBySale[id] = (repaidBySale[id] ?? 0) + (r['amount'] as int);
    _require(repaidBySale[id]! <= (sale!['credit'] as int), 'Los abonos superan la deuda.');
  }
  final movementIds = <String>{};
  final balances = {for (final session in allSessions) session['id'] as String: session['opening'] as int};
  for (final m in collections['movements']!) {
    _require(_name(m['id'], 100) && movementIds.add(m['id'] as String) && sessionIds.contains(m['sessionId']) && _integer(m['amount'], -_limit) && m['amount'] != 0 && _name(m['reason'], 120) && _date(m['at']) && ['sale', 'income', 'expense', 'repayment', 'refund'].contains(m['kind']) && (m['method'] == null || _methods.contains(m['method'])), 'Movimiento de caja inválido.');
    final amount = m['amount'] as int;
    _require(['expense', 'refund'].contains(m['kind']) ? amount < 0 : amount > 0, 'Signo de movimiento inválido.');
    _require(!['sale', 'repayment', 'refund'].contains(m['kind']) || sales.containsKey(m['saleId']), 'Movimiento con venta desconocida.');
    _require(!['income', 'expense'].contains(m['kind']) || m['method'] == null || m['method'] == 'cash', 'Los ingresos y retiros de caja son en efectivo.');
    if (m['method'] == null || m['method'] == 'cash') balances[m['sessionId'] as String] = balances[m['sessionId']]! + amount;
  }
  for (final balance in balances.values) { _require(_integer(balance), 'Saldo de caja inválido.'); }
  for (final session in collections['sessions']!) { _require(session['expected'] == balances[session['id']], 'El cierre no coincide con los movimientos de caja.'); }
  final stockIds = <String>{};
  for (final m in collections['stockMovements']!) {
    final p = products[m['productId']];
    _require(_name(m['id'], 100) && stockIds.add(m['id'] as String) && p != null && _integer(m['quantityDelta'], -_limit) && m['quantityDelta'] != 0 && _name(m['reason'], 120) && _date(m['at']) && ['sale', 'purchase', 'loss', 'adjustment', 'return'].contains(m['kind']), 'Movimiento de inventario inválido.');
    _validQuantity((m['quantityDelta'] as int).abs(), p!['unit'], min: 1);
    _require(!['sale', 'return'].contains(m['kind']) || sales.containsKey(m['saleId']), 'Movimiento de stock con venta desconocida.');
    _require(!['sale', 'loss'].contains(m['kind']) || (m['quantityDelta'] as int) < 0, 'Salida de stock inválida.');
    _require(!['purchase', 'return'].contains(m['kind']) || (m['quantityDelta'] as int) > 0, 'Entrada de stock inválida.');
  }
  for (final p in products.values) {
    _require(_integer(p['openingStock']), 'Saldo inicial de inventario inválido.');
    final delta = _sum(collections['stockMovements']!.where((m) => m['productId'] == p['id']).map((m) => m['quantityDelta'] as int));
    _require((p['openingStock'] as int) + delta == p['stock'], 'El stock no coincide con sus movimientos.');
  }
  for (final sale in sales.values.where((s) => s['status'] == 'voided')) {
    final refunds = _rows(sale['refunds'], 'Devolución de pago incompleta.');
    _validatePayments(refunds, allowEmpty: true);
    final expected = <String, int>{};
    for (final p in sale['payments'] as List) { expected[p['method'] as String] = (p['amount'] as int) - (p['method'] == 'cash' ? sale['change'] as int : 0); }
    for (final r in collections['repayments']!.where((r) => r['saleId'] == sale['id'])) { expected[r['method'] as String] = (expected[r['method']] ?? 0) + (r['amount'] as int); }
    final actual = {for (final p in refunds) p['method'] as String: p['amount'] as int};
    for (final method in _methods) { _require((actual[method] ?? 0) == (expected[method] ?? 0), 'La devolución no cuadra con lo cobrado.'); }
  }
}
