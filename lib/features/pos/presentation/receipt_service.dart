import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/pos_engine.dart';

String peruDate(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return 'Fecha no disponible';
  final date = parsed.toUtc().subtract(const Duration(hours: 5));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

String paymentLabel(String method) => const {
      'cash': 'Efectivo',
      'yape': 'Yape',
      'plin': 'Plin',
      'card': 'Tarjeta',
    }[method] ?? method;

/// A commercial receipt. This document is never represented as a tax invoice.
class ReceiptService {
  static Future<Uint8List> build(Map<String, dynamic> sale) async {
    final document = pw.Document();
    final store = Map<String, dynamic>.from(sale['store'] as Map? ?? {});
    final lines = (sale['lines'] as List? ?? []).cast<Map>();
    final payments = (sale['payments'] as List? ?? []).cast<Map>();
    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => [
        pw.Text(store['storeName']?.toString() ?? 'Mi negocio',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        if ((store['address'] ?? '').toString().isNotEmpty)
          pw.Text(store['address'].toString()),
        if ((store['ruc'] ?? '').toString().isNotEmpty)
          pw.Text('RUC: ${store['ruc']}'),
        pw.SizedBox(height: 16),
        pw.Text('RECIBO COMERCIAL ${sale['number']}'),
        pw.Text('${peruDate(sale['at'])} (Perú)'),
        if (sale['status'] == 'voided')
          pw.Text('VENTA ANULADA',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Divider(),
        ...lines.map((line) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(line['name']?.toString() ?? 'Producto'),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${displayQuantity(line['quantity'] as int,
                          line['unit']?.toString() ?? 'und')} × ${soles(line['price'] as int)}'),
                      pw.Text(soles(line['total'] as int)),
                    ],
                  ),
                ],
              ),
            )),
        pw.Divider(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('TOTAL',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text(soles(sale['total'] as int),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.SizedBox(height: 12),
        ...payments.map((payment) => pw.Text(
            '${paymentLabel(payment['method'].toString())}: '
            '${soles(payment['amount'] as int)}')),
        if ((sale['change'] as int? ?? 0) > 0)
          pw.Text('Vuelto: ${soles(sale['change'] as int)}'),
        if ((sale['credit'] as int? ?? 0) > 0)
          pw.Text('Fiado al realizar la venta: ${soles(sale['credit'] as int)}'),
        pw.SizedBox(height: 20),
        pw.Text('Gracias por comprar en tu barrio.'),
        pw.SizedBox(height: 8),
        pw.Text('Este recibo no es una boleta ni factura electrónica. '
            'No constituye un comprobante de pago autorizado por SUNAT.',
            style: const pw.TextStyle(fontSize: 9)),
        if (sale['legacy'] == true)
          pw.Text('Registro histórico importado: pagos y datos del negocio requieren conciliación con el archivo original.',
              style: const pw.TextStyle(fontSize: 9))
        else if (payments.any((p) => p['method'] != 'cash'))
          pw.Text('Los pagos digitales fueron confirmados manualmente por el cajero.',
              style: const pw.TextStyle(fontSize: 9)),
      ],
    ));
    return document.save();
  }

  static Future<void> share(Map<String, dynamic> sale) async {
    await Printing.sharePdf(
      bytes: await build(sale),
      filename: 'zivlo-recibo-${sale['number']}.pdf',
    );
  }

  static Future<void> print(Map<String, dynamic> sale) async {
    await Printing.layoutPdf(
      name: 'Recibo comercial ${sale['number']}',
      onLayout: (_) => build(sale),
    );
  }
}
