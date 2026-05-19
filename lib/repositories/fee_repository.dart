import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dummy_data.dart';

class FeeRepository {
  final _supabase = Supabase.instance.client;

  Future<List<FeeRecord>> getFeeRecords() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('NOTICE [getFeeRecords]: No auth user session found. Returning dummy data fallback.');
        return DummyData.fees;
      }

      print('Fetching linked student for Parent Auth ID: ${user.id} in FeeRepository');

      // 1. Fetch student info linked to this parent
      final studentData = await _supabase
          .from('students')
          .select('id, course_id, batch_id, full_name')
          .eq('parent_id', user.id)
          .maybeSingle();

      if (studentData == null) {
        print('NOTICE [getFeeRecords]: No student found linked to Parent ID ${user.id}. Returning dummy data.');
        return DummyData.fees;
      }

      final studentId = studentData['id'];
      final courseId = studentData['course_id'];
      final batchId = studentData['batch_id'];

      print('Found linked student: $studentId, course: $courseId, batch: $batchId');

      // 2. Fetch actual student payments/due records from the 'fees' table
      final feesResponse = await _supabase
          .from('fees')
          .select()
          .eq('student_id', studentId)
          .order('due_date', ascending: false);

      final List<dynamic> feesList = feesResponse as List<dynamic>;
      print('Fetched ${feesList.length} fee records from DB');

      // 3. Fetch course fee structures from 'fee_structures'
      Map<String, dynamic>? feeStructure;
      if (courseId != null) {
        final structureResponse = await _supabase
            .from('fee_structures')
            .select()
            .eq('course_id', courseId)
            .maybeSingle();
        feeStructure = structureResponse;
        if (feeStructure != null) {
          print('Found course fee structure: Total Amount = ${feeStructure['total_amount']}, Monthly Fee = ${feeStructure['monthly_fee']}');
        }
      }

      // If both are completely empty in the DB, fallback to DummyData
      if (feesList.isEmpty && feeStructure == null) {
        print('NOTICE [getFeeRecords]: No fee records or structures in DB. Using dummy data fallback.');
        return DummyData.fees;
      }

      final List<FeeRecord> records = [];

      // 4. Map the database records to FeeRecord objects
      if (feesList.isEmpty && feeStructure != null) {
        // If we only have the course fee structure, generate pending installments dynamically!
        final totalAmount = (feeStructure['total_amount'] as num?)?.toDouble() ?? 0.0;
        final monthlyFee = (feeStructure['monthly_fee'] as num?)?.toDouble() ?? 0.0;
        final installmentCount = (feeStructure['installment_count'] as num?)?.toInt() ?? 1;
        final dueDateDay = (feeStructure['due_date_day'] as num?)?.toInt() ?? 10;

        print('Generating $installmentCount installments dynamically based on course fee structure.');
        final now = DateTime.now();
        for (int i = 0; i < installmentCount; i++) {
          final title = i == 0 ? 'Admission & First Term Tuition' : 'Tuition Fee Installment ${i + 1}';
          final amount = i == 0 ? (totalAmount - (monthlyFee * (installmentCount - 1))) : monthlyFee;
          final dueDate = DateTime(now.year, now.month + i, dueDateDay);
          
          records.add(
            FeeRecord(
              title: title,
              amount: amount,
              dueDate: dueDate,
              isPaid: false,
              receiptId: '',
              status: 'Pending',
              amountPaid: 0.0,
            ),
          );
        }
      } else {
        // Map actual 'fees' table rows!
        for (var item in feesList) {
          final id = item['id']?.toString() ?? '';
          final double amountDue = (item['amount_due'] as num?)?.toDouble() ?? 0.0;
          final double amountPaid = (item['amount_paid'] as num?)?.toDouble() ?? 0.0;
          final String status = item['payment_status'] ?? 'Pending';
          final bool isPaid = status == 'Paid';
          final String receiptId = isPaid ? (item['id']?.toString().substring(0, 8).toUpperCase() ?? 'TXN-REF') : '';
          
          final dueDateStr = item['due_date']?.toString();
          final createdAtStr = item['created_at']?.toString();
          
          final dueDate = dueDateStr != null ? DateTime.tryParse(dueDateStr) ?? DateTime.now() : DateTime.now();
          final paymentDate = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
          
          records.add(
            FeeRecord(
              id: id,
              title: item['fee_type']?.toString() ?? 'Tuition Fee Installment',
              amount: amountDue,
              dueDate: dueDate,
              isPaid: isPaid,
              receiptId: receiptId,
              status: status,
              amountPaid: amountPaid,
              paymentDate: paymentDate,
            ),
          );
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
}
