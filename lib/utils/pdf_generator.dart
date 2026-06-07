import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfGenerator {
  static Future<void> generateProductionReportPdf(Map<String, dynamic> details) async {
    final pdf = pw.Document();
    final report = details['report'] as Map<String, dynamic>;
    final entries = details['entries'] as List<Map<String, dynamic>>;
    final measurements = details['measurements'] as List<Map<String, dynamic>>;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('PRODUCTION REPORT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24)),
                  pw.Text(report['date'] ?? '', style: const pw.TextStyle(fontSize: 14)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            
            // Metadata
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Line'),
                      pw.Text(report['line'] ?? '-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 10),
                      _buildLabel('Shift'),
                      pw.Text(report['shift'] ?? '-', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Operators'),
                      pw.Text(report['operator_names'] ?? '-', style: pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Production Table
            pw.Text('REALIZED PRODUCTION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildHeaderCell('Fust Type'),
                    _buildHeaderCell('Start'),
                    _buildHeaderCell('End'),
                    _buildHeaderCell('Duration'),
                    _buildHeaderCell('Carts'),
                    _buildHeaderCell('Barrels'),
                  ],
                ),
                ...entries.map((e) {
                  return pw.TableRow(
                    children: [
                      _buildTableCell(e['fust_type'] ?? '-'),
                      _buildTableCell(e['start_time'] ?? '00:00'),
                      _buildTableCell(e['end_time'] ?? '00:00'),
                      _buildTableCell(_calculateDuration(e['start_time'], e['end_time'])),
                      _buildTableCell(e['cart_count']?.toString() ?? '0'),
                      _buildTableCell(e['barrel_count']?.toString() ?? '0'),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 30),

            // Chlorine
            pw.Text('CHLORINE MEASUREMENTS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    '23:00', '02:00', '05:00', '08:00', '11:00', '14:00', '15:00', '17:00', '20:00'
                  ].map((time) => _buildHeaderCell(time)).toList(),
                ),
                pw.TableRow(
                  children: [
                    '23:00', '02:00', '05:00', '08:00', '11:00', '14:00', '15:00', '17:00', '20:00'
                  ].map((time) {
                    final m = measurements.firstWhere((m) => m['measurement_time'] == time, orElse: () => {});
                    return _buildTableCell(m['chlorine_level']?.toString() ?? '');
                  }).toList(),
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Checklist
            pw.Text('CHECKLIST', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                _buildCheckItem('Barrels Empty', report['barrels_empty'] == 1),
                pw.SizedBox(width: 20),
                _buildCheckItem('Machine Clean', report['machine_clean'] == 1),
                pw.SizedBox(width: 20),
                _buildCheckItem('Nozzles Pierced', report['nozzles_pierced'] == 1),
              ],
            ),
            pw.SizedBox(height: 30),

            // Comments
            pw.Text('COMMENTS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
            pw.SizedBox(height: 10),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Text(report['comments'] ?? '-', style: const pw.TextStyle(fontSize: 12)),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Production_Report_${report['date']}_${report['line']}.pdf',
    );
  }

  static pw.Widget _buildLabel(String label) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(label.toUpperCase(), style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    );
  }

  static pw.Widget _buildHeaderCell(String label) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Center(child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
    );
  }

  static pw.Widget _buildTableCell(String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Center(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
    );
  }

  static pw.Widget _buildCheckItem(String label, bool isChecked) {
    return pw.Row(
      children: [
        pw.Container(
          width: 12,
          height: 12,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
          child: isChecked ? pw.Center(child: pw.Text('X', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))) : null,
        ),
        pw.SizedBox(width: 5),
        pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static String _calculateDuration(String? start, String? end) {
    if (start == null || end == null || start.isEmpty || end.isEmpty) return '0h 00min';
    try {
      final s = start.split(':');
      final e = end.split(':');
      final sMin = int.parse(s[0]) * 60 + int.parse(s[1]);
      var eMin = int.parse(e[0]) * 60 + int.parse(e[1]);
      if (eMin < sMin) eMin += 24 * 60;
      final diff = eMin - sMin;
      if (diff <= 0) return '0h 00min';
      final h = diff ~/ 60;
      final m = diff % 60;
      return '${h}h ${m.toString().padLeft(2, '0')}min';
    } catch (_) {
      return '0h 00min';
    }
  }
}
