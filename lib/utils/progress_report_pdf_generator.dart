import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ProgressReportPdfGenerator {
  static Future<pw.Document> _buildDocument({
    required String studentName,
    required String rollNumber,
    required String admissionNumber,
    required String grade,
    required String campusName,
    required String reportTitle,
    required String periodText,
    required List<String> headers,
    required List<List<String>> rows,
    required String overallPercentage,
    required String overallGrade,
    required String totalAssessments,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Institution Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ATOMUS TUITION CENTRE',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#4F46E5'), // Indigo
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Campus: ${campusName.isNotEmpty ? campusName : 'Atomus Main Campus'}',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'ACADEMIC RECORD',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Date: ${DateTime.now().toLocal().toString().split(' ').first}',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColor.fromHex('#4F46E5'), thickness: 1.5),
              pw.SizedBox(height: 14),

              // Title Section
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      reportTitle.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#1E293B'),
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      periodText,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#F59E0B'), // Accent/Amber
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Student Info Cards Layout
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildMetaRow('Student Name', studentName),
                        _buildMetaRow('Roll Number', rollNumber),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildMetaRow('Admission No', admissionNumber),
                        _buildMetaRow('Class / Grade', grade),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Tabular Data
              pw.Text(
                'PERFORMANCE BREAKDOWN',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 6),

              pw.Table(
                border: pw.TableBorder.symmetric(
                  inside: pw.BorderSide(
                    color: PdfColor.fromHex('#E2E8F0'),
                    width: 0.5,
                  ),
                  outside: pw.BorderSide(
                    color: PdfColor.fromHex('#CBD5E1'),
                    width: 1.0,
                  ),
                ),
                columnWidths: {
                  for (var i = 0; i < headers.length; i++)
                    i: i == 0
                        ? const pw.FlexColumnWidth(
                            2.5,
                          ) // Expand first column (Subject/Date/Exam)
                        : const pw.FlexColumnWidth(1.2),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#4F46E5'),
                    ),
                    children: headers.map((header) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: pw.Text(
                          header,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      );
                    }).toList(),
                  ),
                  // Table Rows
                  ...rows.map((row) {
                    final index = rows.indexOf(row);
                    final isEven = index % 2 == 0;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isEven
                            ? PdfColors.white
                            : PdfColor.fromHex('#F8FAFC'),
                      ),
                      children: row.map((cell) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: pw.Text(
                            cell,
                            style: const pw.TextStyle(fontSize: 8.5),
                            textAlign: pw.TextAlign.center,
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 24),

              // Summary & Statistics Cards
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F8FAFC'),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(8),
                      ),
                      border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildSummaryItem('Total Records', totalAssessments),
                        pw.SizedBox(height: 4),
                        _buildSummaryItem(
                          'Average Percentage',
                          overallPercentage,
                        ),
                        pw.SizedBox(height: 4),
                        _buildSummaryItem(
                          'Overall Grade',
                          overallGrade,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // Grading Legend
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey300,
                    style: pw.BorderStyle.dashed,
                  ),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'GRADING LEGEND: A+ (>=90%)  |  A (>=80%)  |  B+ (>=70%)  |  B (>=60%)  |  C (>=50%)  |  F (<50%)',
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 36),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 140,
                        height: 1,
                        color: PdfColors.grey400,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Class Teacher',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 140,
                        height: 1,
                        color: PdfColors.grey400,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Principal / Director',
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Confidentiality / System Footer
              pw.Center(
                child: pw.Text(
                  'CONFIDENTIAL ACADEMIC REPORT CARD. FOR OFFICIAL AND PERSONAL RECORD ONLY.',
                  style: const pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'Generated automatically via Atomus Academics Portal.',
                  style: const pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey400,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildMetaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.Text(
            value.isNotEmpty ? value : 'N/A',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColors.grey700,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: isBold ? PdfColor.fromHex('#4F46E5') : PdfColors.grey800,
          ),
        ),
      ],
    );
  }

  static Future<void> shareReport({
    required String studentName,
    required String rollNumber,
    required String admissionNumber,
    required String grade,
    required String campusName,
    required String reportTitle,
    required String periodText,
    required List<String> headers,
    required List<List<String>> rows,
    required String overallPercentage,
    required String overallGrade,
    required String totalAssessments,
  }) async {
    final pdf = await _buildDocument(
      studentName: studentName,
      rollNumber: rollNumber,
      admissionNumber: admissionNumber,
      grade: grade,
      campusName: campusName,
      reportTitle: reportTitle,
      periodText: periodText,
      headers: headers,
      rows: rows,
      overallPercentage: overallPercentage,
      overallGrade: overallGrade,
      totalAssessments: totalAssessments,
    );
    final bytes = await pdf.save();
    final cleanName = studentName.replaceAll(' ', '_');
    final cleanTitle = reportTitle.replaceAll(' ', '_');
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Atomus_Report_${cleanName}_$cleanTitle.pdf',
    );
  }

  static Future<void> printReport({
    required String studentName,
    required String rollNumber,
    required String admissionNumber,
    required String grade,
    required String campusName,
    required String reportTitle,
    required String periodText,
    required List<String> headers,
    required List<List<String>> rows,
    required String overallPercentage,
    required String overallGrade,
    required String totalAssessments,
  }) async {
    final pdf = await _buildDocument(
      studentName: studentName,
      rollNumber: rollNumber,
      admissionNumber: admissionNumber,
      grade: grade,
      campusName: campusName,
      reportTitle: reportTitle,
      periodText: periodText,
      headers: headers,
      rows: rows,
      overallPercentage: overallPercentage,
      overallGrade: overallGrade,
      totalAssessments: totalAssessments,
    );
    final cleanName = studentName.replaceAll(' ', '_');
    final cleanTitle = reportTitle.replaceAll(' ', '_');
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Atomus_Report_${cleanName}_$cleanTitle',
    );
  }
}
