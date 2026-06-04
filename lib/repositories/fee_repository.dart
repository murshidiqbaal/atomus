import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dummy_data.dart';
import '../services/parent_identity_service.dart';

class FeeRepository {
  final _supabase = Supabase.instance.client;
  final _parentIdentityService = ParentIdentityService();

  /// Returns true when the status string represents a completed payment.
  bool _statusIsPaid(String? status) {
    if (status == null) return false;
    final s = status.trim().toLowerCase();
    return s == 'paid' || s == 'success' || s == 'completed';
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  int? _parseStartMonth(String termName) {
    final clean = termName.toLowerCase();
    String startMonthStr = clean;
    if (clean.contains('-')) {
      startMonthStr = clean.split('-').first.trim();
    } else if (clean.contains(' to ')) {
      startMonthStr = clean.split(' to ').first.trim();
    }
    
    if (startMonthStr.startsWith('jan')) return 1;
    if (startMonthStr.startsWith('feb')) return 2;
    if (startMonthStr.startsWith('mar')) return 3;
    if (startMonthStr.startsWith('apr')) return 4;
    if (startMonthStr.startsWith('may')) return 5;
    if (startMonthStr.startsWith('jun')) return 6;
    if (startMonthStr.startsWith('jul')) return 7;
    if (startMonthStr.startsWith('aug')) return 8;
    if (startMonthStr.startsWith('sep')) return 9;
    if (startMonthStr.startsWith('oct')) return 10;
    if (startMonthStr.startsWith('nov')) return 11;
    if (startMonthStr.startsWith('dec')) return 12;
    return null;
  }

  DateTime _calculateDueDate(String termName, int dueDaysOffset, DateTime? updatedAt, int index, List<dynamic>? termDetailsList) {
    final startMonth = _parseStartMonth(termName);
    int year = DateTime.now().year;
    if (updatedAt != null) {
      year = updatedAt.year;
    }
    
    if (startMonth != null) {
      int? firstTermStartMonth;
      if (termDetailsList != null && termDetailsList.isNotEmpty) {
        final firstTerm = termDetailsList.first;
        if (firstTerm is Map<String, dynamic>) {
          final firstTermName = firstTerm['term_name']?.toString() ?? firstTerm['name']?.toString() ?? '';
          firstTermStartMonth = _parseStartMonth(firstTermName);
        }
      }
      
      int targetYear = year;
      if (firstTermStartMonth != null && startMonth < firstTermStartMonth) {
        targetYear = year + 1;
      }
      
      final termStart = DateTime(targetYear, startMonth, 1);
      return termStart.subtract(Duration(days: dueDaysOffset));
    }
    
    return DateTime(year, DateTime.now().month + index, 10);
  }

  Future<List<FeeRecord>> getFeeRecords() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print(
          'NOTICE [getFeeRecords]: No auth user session found. Returning dummy data fallback.',
        );
        return DummyData.fees;
      }

      final parent = await _parentIdentityService.resolveCurrentParent();
      final parentId = parent['id']?.toString();

      print(
        'Fetching linked student for Parent ID: $parentId in FeeRepository',
      );

      // 1. Fetch student info linked to this parent
      final studentData = await _supabase
          .from('students')
          .select('id, course_id, batch_id, full_name')
          .eq('parent_id', parentId!)
          .maybeSingle();

      if (studentData == null) {
        print(
          'NOTICE [getFeeRecords]: No student found linked to Parent ID $parentId. Returning dummy data.',
        );
        return DummyData.fees;
      }

      final studentId = studentData['id'];
      final courseId = studentData['course_id'];
      final batchId = studentData['batch_id'];

      print(
        'Found linked student: $studentId, course: $courseId, batch: $batchId',
      );

      // 2. Fetch active fee structures for the course
      List<dynamic> activeStructures = [];
      if (courseId != null) {
        try {
          activeStructures = await _supabase
              .from('fee_structures')
              .select()
              .eq('course_id', courseId)
              .eq('is_active', true);
          print('Found ${activeStructures.length} active fee structures for course: $courseId');
        } catch (e) {
          print('ERROR [getFeeRecords] fetching active fee structures: $e');
        }
      }

      // 3. Fetch from student_fees with nested fee_structures
      Map<String, dynamic>? studentFeeResponse;
      try {
        studentFeeResponse = await _supabase
            .from('student_fees')
            .select('*, fee_structures(*)')
            .eq('student_id', studentId)
            .maybeSingle();
      } catch (e) {
        print('ERROR [getFeeRecords] fetching student_fees: $e');
      }

      // Collect all relevant fee structures
      final Map<String, Map<String, dynamic>> structuresMap = {};

      if (studentFeeResponse != null && studentFeeResponse['fee_structures'] != null) {
        final struct = studentFeeResponse['fee_structures'] as Map<String, dynamic>;
        structuresMap[struct['id'].toString()] = struct;
      }

      for (var struct in activeStructures) {
        if (struct is Map<String, dynamic>) {
          structuresMap[struct['id'].toString()] = struct;
        }
      }

      final List<FeeRecord> records = [];
      final termStatusList = studentFeeResponse?['term_status'];

      if (structuresMap.isNotEmpty) {
        // Iterate over all relevant structures and build records
        for (var structure in structuresMap.values) {
          final termDetailsList = structure['term_details'];
          final structureId = structure['id'];
          final structureName = structure['name'] ?? 'Course Fee';

          if (termDetailsList is List && termDetailsList.isNotEmpty) {
            for (var i = 0; i < termDetailsList.length; i++) {
              final term = termDetailsList[i] as Map<String, dynamic>;
              final String termName = term['term_name']?.toString() ?? term['name']?.toString() ?? 'Term ${i + 1}';
              
              // Find matching status in student_fees term_status
              Map<String, dynamic>? matchedTermStatus;
              if (termStatusList is List) {
                // Try matching by term_name (case-insensitive)
                for (var ts in termStatusList) {
                  if (ts is Map<String, dynamic>) {
                    final tsName = (ts['term_name'] ?? ts['name'])?.toString().toLowerCase().trim();
                    final structTermName = termName.toLowerCase().trim();
                    if (tsName != null && tsName == structTermName) {
                      matchedTermStatus = ts;
                      break;
                    }
                  }
                }
                // If not found by name, and this structure is the primary one, try matching by index
                if (matchedTermStatus == null && 
                    studentFeeResponse != null && 
                    studentFeeResponse['fee_structure_id'] == structureId &&
                    i < termStatusList.length) {
                  final ts = termStatusList[i];
                  if (ts is Map<String, dynamic>) {
                    matchedTermStatus = ts;
                  }
                }
              }

              // Determine values
              double termAmount = _parseDouble(term['amount'] ?? term['total_amount']);
              double termPaidAmount = 0.0;
              String termStatus = 'Pending';
              DateTime? updatedAtDate;
              if (studentFeeResponse != null && studentFeeResponse['updated_at'] != null) {
                updatedAtDate = DateTime.tryParse(studentFeeResponse['updated_at'].toString());
              }
              final dueDaysOffset = _parseInt(structure['due_date_day'] ?? 10);
              DateTime dueDate = _calculateDueDate(termName, dueDaysOffset, updatedAtDate, i, termDetailsList);
              DateTime? paymentDate;

              if (matchedTermStatus != null) {
                termAmount = _parseDouble(matchedTermStatus['amount_due'] ?? matchedTermStatus['amount'] ?? termAmount);
                termPaidAmount = _parseDouble(matchedTermStatus['amount_paid'] ?? matchedTermStatus['paid_amount'] ?? 0.0);
                termStatus = matchedTermStatus['status']?.toString() ?? matchedTermStatus['payment_status']?.toString() ?? 'Pending';
                
                final paymentDateStr = matchedTermStatus['payment_date']?.toString() ?? matchedTermStatus['last_payment_date']?.toString();
                paymentDate = paymentDateStr != null ? DateTime.tryParse(paymentDateStr) : null;
              }

              final isPaid = _statusIsPaid(termStatus);
              final String recId = isPaid 
                  ? 'TXN-${(studentFeeResponse?['id'] ?? structureId).toString().substring(0, 8).toUpperCase()}-$i' 
                  : '';

              records.add(
                FeeRecord(
                  id: '${structureId}_term_$i',
                  title: '$structureName - $termName',
                  amount: termAmount,
                  dueDate: dueDate,
                  isPaid: isPaid,
                  receiptId: recId,
                  status: termStatus,
                  amountPaid: termPaidAmount,
                  paymentDate: paymentDate,
                ),
              );
            }
          } else {
            // Generate dynamic installments from structure config
            final totalAmount = _parseDouble(structure['total_amount']);
            final monthlyFee = _parseDouble(structure['monthly_fee']);
            final installmentCount = _parseInt(structure['installment_count'] ?? 1);
            final dueDateDay = _parseInt(structure['due_date_day'] ?? 10);

            final now = DateTime.now();
            for (int i = 0; i < installmentCount; i++) {
              final title = i == 0 ? 'Admission & First Term Tuition' : 'Tuition Fee Installment ${i + 1}';
              final amount = i == 0 ? (totalAmount - (monthlyFee * (installmentCount - 1))) : monthlyFee;
              final dueDate = DateTime(now.year, now.month + i, dueDateDay);

              // Check if we can find corresponding term status in student_fees
              Map<String, dynamic>? matchedTermStatus;
              if (termStatusList is List && 
                  studentFeeResponse != null && 
                  studentFeeResponse['fee_structure_id'] == structureId &&
                  i < termStatusList.length) {
                final ts = termStatusList[i];
                if (ts is Map<String, dynamic>) {
                  matchedTermStatus = ts;
                }
              }

              double termAmount = amount;
              double termPaidAmount = 0.0;
              String termStatus = 'Pending';
              DateTime? paymentDate;

              if (matchedTermStatus != null) {
                termAmount = _parseDouble(matchedTermStatus['amount_due'] ?? matchedTermStatus['amount'] ?? amount);
                termPaidAmount = _parseDouble(matchedTermStatus['amount_paid'] ?? matchedTermStatus['paid_amount'] ?? 0.0);
                termStatus = matchedTermStatus['status']?.toString() ?? matchedTermStatus['payment_status']?.toString() ?? 'Pending';
                final paymentDateStr = matchedTermStatus['payment_date']?.toString() ?? matchedTermStatus['last_payment_date']?.toString();
                paymentDate = paymentDateStr != null ? DateTime.tryParse(paymentDateStr) : null;
              }

              final isPaid = _statusIsPaid(termStatus);

              records.add(
                FeeRecord(
                  id: '${structureId}_inst_$i',
                  title: '$structureName - $title',
                  amount: termAmount,
                  dueDate: dueDate,
                  isPaid: isPaid,
                  receiptId: isPaid ? 'TXN-${(studentFeeResponse?['id'] ?? structureId).toString().substring(0, 8).toUpperCase()}-$i' : '',
                  status: termStatus,
                  amountPaid: termPaidAmount,
                  paymentDate: paymentDate,
                ),
              );
            }
          }
        }
      } else if (studentFeeResponse != null && termStatusList is List && termStatusList.isNotEmpty) {
        // Fallback: If no structures found, but student_fees term_status is present, use it directly
        for (var i = 0; i < termStatusList.length; i++) {
          final term = termStatusList[i] as Map<String, dynamic>;
          final String termName = term['term_name']?.toString() ?? term['name']?.toString() ?? 'Term ${i + 1}';
          final double termAmount = _parseDouble(term['amount_due'] ?? term['amount'] ?? term['total_amount'] ?? term['fee_amount']);
          final double termPaidAmount = _parseDouble(term['amount_paid'] ?? term['paid_amount'] ?? 0.0);
          final String termStatus = term['status']?.toString() ?? term['payment_status']?.toString() ?? 'Pending';
          
          DateTime? updatedAtDate;
          if (studentFeeResponse['updated_at'] != null) {
            updatedAtDate = DateTime.tryParse(studentFeeResponse['updated_at'].toString());
          }
          final dueDate = _calculateDueDate(termName, 10, updatedAtDate, i, termStatusList);

          final paymentDateStr = term['payment_date']?.toString() ?? term['last_payment_date']?.toString();
          final paymentDate = paymentDateStr != null ? DateTime.tryParse(paymentDateStr) : null;

          final isPaid = _statusIsPaid(termStatus);
          final receiptId = isPaid ? 'TXN-${studentFeeResponse['id'].toString().substring(0, 8).toUpperCase()}-$i' : '';

          records.add(
            FeeRecord(
              id: '${studentFeeResponse['id']}_term_$i',
              title: termName,
              amount: termAmount,
              dueDate: dueDate,
              isPaid: isPaid,
              receiptId: receiptId,
              status: termStatus,
              amountPaid: termPaidAmount,
              paymentDate: paymentDate,
            ),
          );
        }
      }

      // If nothing was parsed from the database tables, fallback to dummy data
      if (records.isEmpty) {
        print('NOTICE [getFeeRecords]: DB query yielded 0 records. Using dummy data fallback.');
        return DummyData.fees;
      }

      // Sort by due date (chronological so Term 1 is shown before Term 2, etc.)
      records.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      // Correct individual term statuses based on overall paid_amount from student_fees.
      // This ensures that if the individual term_status array elements are Pending/0
      // but the overall paid_amount reflects a payment (like Aswin Manoj who paid 1000.0),
      // we correctly display the corresponding term(s) as Paid.
      if (studentFeeResponse != null) {
        final double overallPaidAmount = _parseDouble(studentFeeResponse['paid_amount']);
        double remainingPaid = overallPaidAmount;

        for (var i = 0; i < records.length; i++) {
          final record = records[i];
          final double termAmount = record.amount;

          if (remainingPaid >= termAmount) {
            // This term is fully covered by the overall paid amount
            records[i] = FeeRecord(
              id: record.id,
              title: record.title,
              amount: record.amount,
              dueDate: record.dueDate,
              isPaid: true,
              receiptId: record.receiptId.isNotEmpty
                  ? record.receiptId
                  : 'TXN-${studentFeeResponse['id'].toString().substring(0, 8).toUpperCase()}-$i',
              status: 'Paid',
              amountPaid: termAmount,
              paymentDate: record.paymentDate ?? DateTime.tryParse(studentFeeResponse['last_payment_date']?.toString() ?? '') ?? DateTime.now(),
            );
            remainingPaid -= termAmount;
          } else if (remainingPaid > 0) {
            // This term is partially covered by the remaining paid amount
            records[i] = FeeRecord(
              id: record.id,
              title: record.title,
              amount: record.amount,
              dueDate: record.dueDate,
              isPaid: false,
              receiptId: record.receiptId,
              status: 'Partially Paid',
              amountPaid: remainingPaid,
              paymentDate: record.paymentDate ?? DateTime.tryParse(studentFeeResponse['last_payment_date']?.toString() ?? '') ?? DateTime.now(),
            );
            remainingPaid = 0.0;
          } else {
            // No remaining paid amount to allocate to this term.
            // If it was already marked as paid via other DB parsing paths, keep it, otherwise pending.
            if (!record.isPaid) {
              records[i] = FeeRecord(
                id: record.id,
                title: record.title,
                amount: record.amount,
                dueDate: record.dueDate,
                isPaid: false,
                receiptId: record.receiptId,
                status: 'Pending',
                amountPaid: 0.0,
                paymentDate: null,
              );
            }
          }
        }
      }
      return records;

    } catch (e) {
      print('CRITICAL ERROR [getFeeRecords]: $e. Returning dummy data fallback.');
      return DummyData.fees;
    }
  }

  Future<void> payFee(String feeTitle) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  /// Fetches payment transaction history for the student
  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final parent = await _parentIdentityService.resolveCurrentParent();
      final parentId = parent['id']?.toString();
      if (parentId == null) return [];

      final studentData = await _supabase
          .from('students')
          .select('id')
          .eq('parent_id', parentId)
          .maybeSingle();

      if (studentData == null) return [];

      final studentId = studentData['id'];

      final response = await _supabase
          .from('payment_transactions')
          .select()
          .eq('student_id', studentId)
          .order('payment_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('ERROR [getPaymentHistory]: $e');
      return [];
    }
  }

  /// Fetches the fee structure metadata for the student's course
  Future<Map<String, dynamic>?> getFeeStructureInfo() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final parent = await _parentIdentityService.resolveCurrentParent();
      final parentId = parent['id']?.toString();
      if (parentId == null) return null;

      final studentData = await _supabase
          .from('students')
          .select('id, course_id, full_name, courses(name)')
          .eq('parent_id', parentId)
          .maybeSingle();

      if (studentData == null) return null;

      final courseId = studentData['course_id'];
      if (courseId == null) return null;

      final studentFee = await _supabase
          .from('student_fees')
          .select('*, fee_structures(*)')
          .eq('student_id', studentData['id'])
          .maybeSingle();

      final courseName = studentData['courses']?['name'] ?? 'Course';

      double totalFee = 0.0;
      double paidAmount = 0.0;
      double discountAmount = 0.0;
      double balanceAmount = 0.0;
      String paymentStatus = 'Pending';
      String feeStructureName = courseName;

      if (studentFee != null) {
        totalFee = _parseDouble(studentFee['total_fee']);
        paidAmount = _parseDouble(studentFee['paid_amount']);
        discountAmount = _parseDouble(studentFee['discount_amount']);
        balanceAmount = _parseDouble(studentFee['balance_amount']);
        paymentStatus = studentFee['payment_status']?.toString() ?? 'Pending';
        feeStructureName = studentFee['fee_structures']?['name'] ?? courseName;
      } else {
        // Fallback to active structures for course
        final List<dynamic> structures = await _supabase
            .from('fee_structures')
            .select()
            .eq('course_id', courseId)
            .eq('is_active', true);
        if (structures.isNotEmpty) {
          totalFee = structures.fold<double>(0.0, (sum, fs) => sum + _parseDouble(fs['total_amount']));
          balanceAmount = totalFee;
          feeStructureName = structures.map((fs) => fs['name'] ?? '').join(', ');
        }
      }

      return {
        'student_name': studentData['full_name'],
        'course_name': courseName,
        'student_fee': studentFee,
        'total_fee': totalFee,
        'paid_amount': paidAmount,
        'discount_amount': discountAmount,
        'balance_amount': balanceAmount,
        'payment_status': paymentStatus,
        'fee_structure_name': feeStructureName,
      };
    } catch (e) {
      print('ERROR [getFeeStructureInfo]: $e');
      return null;
    }
  }
}
