import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/format.dart';
import '../core/models.dart';

/// Builds and shares a PDF "bukti transaksi" (payment receipt) for a payment
/// on an invoice. Uses the `printing` plugin so it can be saved / shared /
/// printed on Android, web and desktop.
class Receipt {
  static const _navy = PdfColor.fromInt(0xFF0B1F4D);
  static const _red = PdfColor.fromInt(0xFFE11B22);
  static const _green = PdfColor.fromInt(0xFF17A54A);
  static const _dim = PdfColor.fromInt(0xFF6B7590);
  static const _line = PdfColor.fromInt(0xFFE3E8F1);

  static Future<void> share(Invoice inv, Payment p) async {
    final doc = _build(inv, p);
    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: 'BuktiTransaksi_${p.ref}.pdf');
  }

  static Future<void> preview(Invoice inv, Payment p) async {
    await Printing.layoutPdf(onLayout: (_) async => _build(inv, p).save());
  }

  static pw.Document _build(Invoice inv, Payment p) {
    final o = inv.order;
    final c = o.charges;
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: const pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.all(pw.Radius.circular(10))),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Row(children: [
                    pw.Text('AIR', style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('CREW', style: pw.TextStyle(color: PdfColor.fromInt(0xFFF4B740), fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text('BUKTI TRANSAKSI', style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
                    pw.Text('Payment Receipt', style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('PEMBAYARAN BERHASIL', style: pw.TextStyle(color: _green, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text(fDateTime(p.at), style: const pw.TextStyle(color: _dim, fontSize: 9)),
                ]),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFE6F6EC), borderRadius: pw.BorderRadius.circular(20)),
                  child: pw.Text('LUNAS SEBAGIAN', style: pw.TextStyle(color: _green, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            _kv('No. Referensi', p.ref),
            _kv('No. Invoice', inv.id),
            _kv('No. Order', o.id),
            _kv('Metode Pembayaran', p.method.label),
            _kv('Crew', '${o.customer.name} • ${o.customer.airline}'),
            _kv('Driver', o.driver?.name ?? '-'),
            _kv('Rute', '${o.pickup}  →  ${o.destination}'),
            pw.SizedBox(height: 10),
            pw.Divider(color: _line),
            pw.Text('Rincian Tagihan', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _navy)),
            pw.SizedBox(height: 6),
            _kv('Argo', rp(c.argo)),
            _kv('Tol', rp(c.tol)),
            _kv('Parkir', rp(c.parkir)),
            _kv('Lainnya', rp(c.lainnya)),
            pw.Divider(color: _line),
            _kv('Total Tagihan', rp(inv.total), bold: true),
            _kv('Dibayar (transaksi ini)', rp(p.amount), bold: true, color: _green),
            _kv('Total Dibayar', rp(inv.paid)),
            _kv('Sisa Tagihan', rp(inv.remaining), bold: true, color: inv.remaining > 0 ? _red : _green),
            pw.Spacer(),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F6FB), borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Text(
                'Bukti transaksi ini sah dan diterbitkan otomatis oleh sistem AirCrew. '
                'Simpan sebagai bukti pembayaran yang valid.',
                style: const pw.TextStyle(color: _dim, fontSize: 8),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Center(child: pw.Text('AirCrew — Mobility Platform for Airline Crew', style: const pw.TextStyle(color: _dim, fontSize: 8))),
          ],
        ),
      ),
    );
    return doc;
  }

  static pw.Widget _kv(String k, String v, {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(k, style: const pw.TextStyle(color: _dim, fontSize: 9.5)),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Text(
              v,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color ?? PdfColor.fromInt(0xFF17213B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
