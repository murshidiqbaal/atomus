import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/dummy_data.dart';

class ReceiptPdfGenerator {
  static Future<pw.Document> _buildDocument({
    required FeeRecord fee,
    required String studentName,
    required String studentGrade,
  }) async {
    final pdf = pw.Document();
    final currencyFmt = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 2);
    final paymentDateStr = fee.paymentDate != null
        ? DateFormat('MMMM dd, yyyy - hh:mm a').format(fee.paymentDate!)
        : DateFormat('MMMM dd, yyyy').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header banner
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#4B61DD'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'ATOMUS ACADEMICS',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Official Fee Payment Receipt',
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                      ),
                      child: pw.Text(
                        'PAID',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#2EC4B6'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Receipt Meta Info (Reference #, Date)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RECEIPT TO:',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        studentName,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Grade/Program: $studentGrade',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'RECEIPT DETAILS:',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey600,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      if (fee.receiptId.isNotEmpty)
                        pw.Text(
                          'Ref #: ${fee.receiptId}',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      pw.Text(
                        'Date: $paymentDateStr',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Itemized Table Header
              pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
                  ),
                ),
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        'Fee Item Description',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'Amount Due',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'Amount Paid',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),

              // Itemized Table Row
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 12),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            fee.title,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            fee.status ?? 'Fully Paid',
                            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                          ),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        currencyFmt.format(fee.amount),
                        style: const pw.TextStyle(fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        currencyFmt.format(fee.amountPaid ?? fee.amount),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Summary Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 220,
                    child: pw.Column(
                      children: [
                        _buildSummaryRow('Total Term Fee:', currencyFmt.format(fee.amount)),
                        pw.SizedBox(height: 6),
                        _buildSummaryRow('Total Amount Paid:', currencyFmt.format(fee.amountPaid ?? fee.amount), isBoldValue: true),
                        pw.Divider(color: PdfColors.grey400),
                        _buildSummaryRow(
                          'Balance Outstanding:',
                          currencyFmt.format(fee.amount - (fee.amountPaid ?? fee.amount)),
                          valueColor: PdfColor.fromHex('#4B61DD'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Column(
                children: [
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'This is a computer-generated official document. No physical signature is required.',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Thank you for your valuable support to Atomus Academics.',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#4B61DD')),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBoldValue = false,
    PdfColor? valueColor,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: isBoldValue ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: valueColor ?? PdfColors.black,
          ),
        ),
      ],
    );
  }

  static Future<void> shareReceipt({
    required FeeRecord fee,
    required String studentName,
    required String studentGrade,
  }) async {
    final pdf = await _buildDocument(fee: fee, studentName: studentName, studentGrade: studentGrade);
    final bytes = await pdf.save();
    final cleanTitle = fee.title.replaceAll(' ', '_').replaceAll('&', 'and');
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Receipt_${studentName.replaceAll(' ', '_')}_$cleanTitle.pdf',
    );
  }

  static Future<void> printReceipt({
    required FeeRecord fee,
    required String studentName,
    required String studentGrade,
  }) async {
    final pdf = await _buildDocument(fee: fee, studentName: studentName, studentGrade: studentGrade);
    final cleanTitle = fee.title.replaceAll(' ', '_').replaceAll('&', 'and');
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_${studentName.replaceAll(' ', '_')}_$cleanTitle',
    );
  }
}
