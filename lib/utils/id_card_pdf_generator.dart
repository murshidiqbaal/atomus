import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/profile_models.dart';

class IdCardPdfGenerator {
  static Future<pw.Document> _buildDocument({
    required LinkedStudentProfile student,
    required ParentProfile parent,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Academic Institution Header
                pw.Text(
                  'ATOMUS INSTITUTIONAL PORTAL',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#4B61DD'),
                    letterSpacing: 1.5,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'DIGITAL STUDENT ID CARD SOFTCOPY',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#1A222D'),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  width: 60,
                  height: 2,
                  color: PdfColor.fromHex('#4B61DD'),
                ),
                pw.SizedBox(height: 36),

                // Cards Row
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    // FRONT SIDE
                    pw.Column(
                      children: [
                        pw.Text(
                          'FRONT SIDE',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          width: 230,
                          height: 350, // standard ID card aspect ratio vertical layout in A4 printout
                          padding: const pw.EdgeInsets.all(16),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#F5F7FA'),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                            border: pw.Border.all(
                              color: PdfColor.fromHex('#D1D8E0'),
                              width: 1.5,
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              // Top Bar
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text(
                                    'ATOMUS ACADEMICS',
                                    style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColor.fromHex('#4B61DD'),
                                    ),
                                  ),
                                  pw.Text(
                                    'OFFICIAL ID',
                                    style: pw.TextStyle(
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.grey500,
                                    ),
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 16),

                              // Avatar
                              pw.Center(
                                child: pw.Container(
                                  width: 72,
                                  height: 72,
                                  decoration: pw.BoxDecoration(
                                    color: PdfColor.fromHex('#4B61DD'),
                                    shape: pw.BoxShape.circle,
                                  ),
                                  alignment: pw.Alignment.center,
                                  child: pw.Text(
                                    student.initials,
                                    style: pw.TextStyle(
                                      color: PdfColors.white,
                                      fontSize: 22,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              pw.SizedBox(height: 16),

                              // Name and Roll
                              pw.Center(
                                child: pw.Text(
                                  student.fullName.toUpperCase(),
                                  textAlign: pw.TextAlign.center,
                                  style: pw.TextStyle(
                                    fontSize: 13,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColor.fromHex('#1A222D'),
                                  ),
                                ),
                              ),
                              pw.Center(
                                child: pw.Text(
                                  student.admissionNumber ?? student.rollNumber ?? 'Student ID',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    color: PdfColors.grey600,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                              ),
                              pw.SizedBox(height: 16),

                              // Metadata
                              pw.Column(
                                children: [
                                  _buildPdfMetaRow('COURSE', student.courseLabel),
                                  _buildPdfMetaRow('BATCH', student.batchLabel),
                                  _buildPdfMetaRow('CAMPUS', student.campusLabel),
                                  _buildPdfMetaRow('D.O.B', student.dob ?? 'Not provided'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // BACK SIDE
                    pw.Column(
                      children: [
                        pw.Text(
                          'BACK SIDE',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          width: 230,
                          height: 350,
                          padding: const pw.EdgeInsets.all(16),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#F5F7FA'),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(20)),
                            border: pw.Border.all(
                              color: PdfColor.fromHex('#D1D8E0'),
                              width: 1.5,
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              // Top header
                              pw.Text(
                                'EMERGENCY & MEDICAL INFO',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.red700,
                                ),
                              ),
                              pw.SizedBox(height: 16),

                              // Medical rows
                              pw.Column(
                                children: [
                                  _buildPdfMetaRow('BLOOD GROUP', student.bloodGroup ?? 'Not provided'),
                                  _buildPdfMetaRow('ALLERGIES', student.allergies ?? 'None listed'),
                                  _buildPdfMetaRow('CONDITIONS', student.medicalConditions ?? 'No chronic conditions'),
                                  _buildPdfMetaRow('PARENT CONTACT', parent.phoneNumber ?? 'No contact'),
                                ],
                              ),
                              pw.SizedBox(height: 16),

                              // Bottom block with QR and disclaimer
                              pw.Spacer(),
                              pw.Divider(color: PdfColors.grey300),
                              pw.SizedBox(height: 8),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.Expanded(
                                    child: pw.Column(
                                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(
                                          'DIGITAL ID SECURITY',
                                          style: pw.TextStyle(
                                            fontSize: 7,
                                            color: PdfColors.grey500,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                        ),
                                        pw.SizedBox(height: 2),
                                        pw.Text(
                                          'Scan QR to verify student authenticity.',
                                          style: pw.TextStyle(
                                            fontSize: 6,
                                            color: PdfColors.grey500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  pw.SizedBox(width: 8),
                                  pw.Container(
                                    width: 44,
                                    height: 44,
                                    padding: const pw.EdgeInsets.all(2),
                                    decoration: const pw.BoxDecoration(
                                      color: PdfColors.white,
                                    ),
                                    child: pw.BarcodeWidget(
                                      barcode: pw.Barcode.qrCode(),
                                      data: 'student:${student.id}',
                                      width: 40,
                                      height: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 48),
                pw.Text(
                  'CONFIDENTIALITY NOTICE: This document is for official institutional use. Alteration of this card is strictly prohibited.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Generated automatically via Atomus Academics App on ${DateTime.now().toLocal().toString().split(' ').first}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey400,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildPdfMetaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 76,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> downloadIdCard({
    required LinkedStudentProfile student,
    required ParentProfile parent,
  }) async {
    final pdf = await _buildDocument(student: student, parent: parent);
    final bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Atomus_ID_Card_${student.fullName.replaceAll(' ', '_')}.pdf',
    );
  }

  static Future<void> printIdCard({
    required LinkedStudentProfile student,
    required ParentProfile parent,
  }) async {
    final pdf = await _buildDocument(student: student, parent: parent);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Atomus_ID_Card_${student.fullName.replaceAll(' ', '_')}',
    );
  }
}
