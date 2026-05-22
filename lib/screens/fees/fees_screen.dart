import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../blocs/fee/fee_bloc.dart';
import '../../blocs/fee/fee_state.dart';
import '../../blocs/fee/fee_event.dart';
import '../../blocs/student/student_bloc.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/neu_box.dart';
import '../../models/dummy_data.dart';

class FeesScreen extends StatelessWidget {
  const FeesScreen({super.key});

  Future<void> _handleRefresh(BuildContext context) async {
    final feeBloc = context.read<FeeBloc>();
    feeBloc.add(LoadFeeData());
    await feeBloc.stream
        .firstWhere((s) => s.status != FeeStatus.loading)
        .timeout(const Duration(seconds: 4), onTimeout: () => feeBloc.state);
  }

  @override
  Widget build(BuildContext context) {
    // Get student details dynamically from StudentBloc context
    final studentState = context.read<StudentBloc>().state;
    final studentName = studentState.studentInfo?.fullName ?? 'Alexander Davis';
    final studentGrade =
        studentState.studentInfo?.grade ?? 'Grade 10 - Science';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Financial Services')),
      body: BlocBuilder<FeeBloc, FeeState>(
        builder: (context, state) {
          if (state.status == FeeStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.primary,
            onRefresh: () => _handleRefresh(context),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              children: [
                CustomCard(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const NeuBox(
                        width: 160,
                        height: 160,
                        borderRadius: 20,
                        isPressed: true,
                        child: Center(
                          child: Icon(
                            Icons.qr_code_2_rounded,
                            size: 100,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'SECURE CHECKOUT',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 2.0,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Scan the generated identifier using your authorized banking application.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 32),
                      CustomButton(
                        text: 'GENERATE RECEIPT',
                        onPressed: () {
                          final paidFees = state.fees
                              .where((f) => f.isPaid)
                              .toList();
                          if (paidFees.isNotEmpty) {
                            _showReceiptBottomSheet(
                              context,
                              paidFees.first,
                              studentName,
                              studentGrade,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No paid transactions found to generate receipts.',
                                ),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                          }
                        },
                        isOutline: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Transaction History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                ...state.fees.map(
                  (fee) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: fee.isPaid
                          ? () => _showReceiptBottomSheet(
                              context,
                              fee,
                              studentName,
                              studentGrade,
                            )
                          : null,
                      borderRadius: BorderRadius.circular(16),
                      child: CustomCard(
                        child: Row(
                          children: [
                            NeuBox(
                              width: 52,
                              height: 52,
                              borderRadius: 14,
                              isPressed: true,
                              padding: EdgeInsets.zero,
                              child: Icon(
                                fee.isPaid
                                    ? Icons.receipt_long_rounded
                                    : Icons.account_balance_wallet_rounded,
                                color: fee.isPaid
                                    ? AppColors.success
                                    : AppColors.warning,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          fee.title.toUpperCase(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      if (fee.isPaid)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.success
                                                .withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Text(
                                            'RECEIPT',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.success,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    fee.isPaid
                                        ? 'REF: ${fee.receiptId} • Tap to view'
                                        : 'MATURES: ${DateFormat('MMM d, yyyy').format(fee.dueDate)}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${fee.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fee.isPaid ? 'CLEARED' : 'PENDING',
                                  style: TextStyle(
                                    color: fee.isPaid
                                        ? AppColors.success
                                        : AppColors.warning,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showReceiptBottomSheet(
    BuildContext context,
    FeeRecord fee,
    String studentName,
    String studentGrade,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final paymentDateStr = fee.paymentDate != null
            ? DateFormat('MMMM d, yyyy - hh:mm a').format(fee.paymentDate!)
            : DateFormat(
                'MMMM d, yyyy',
              ).format(DateTime.now().subtract(const Duration(days: 1)));

        return Container(
          decoration: const BoxDecoration(
            color: Color(
              0xFF151521,
            ), // Luxurious dark backdrop matching deep slate theme
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 24,
                offset: Offset(0, -8),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),

              // Verification Circle Badge with ambient outer glow rings
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.success.withOpacity(0.3),
                    width: 2.0,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: AppColors.success,
                      size: 38,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'TRANSACTION RECEIPT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.success,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '\$${fee.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),

              // Ticket-style metadata box
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReceiptRow('Institution', 'Atomus ERP Academy'),
                    const SizedBox(height: 14),
                    _buildReceiptRow('Receipt / REF ID', fee.receiptId),
                    const SizedBox(height: 14),
                    _buildReceiptRow('Service Type', fee.title.toUpperCase()),
                    const SizedBox(height: 14),
                    _buildReceiptRow('Student Beneficiary', studentName),
                    const SizedBox(height: 14),
                    _buildReceiptRow('Academic Grade', studentGrade),

                    // Dashed ticket separator line
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        children: List.generate(
                          30,
                          (index) => Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 1.5,
                              color: Colors.white10,
                            ),
                          ),
                        ),
                      ),
                    ),

                    _buildReceiptRow('Settlement Date', paymentDateStr),
                    const SizedBox(height: 14),
                    _buildReceiptRow(
                      'Amount Settled',
                      '\$${fee.amount.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                    const SizedBox(height: 14),
                    _buildReceiptRow(
                      'Payment Status',
                      'CLEARED / SUCCESS',
                      valueColor: AppColors.success,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action triggers
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'SHARE RECEIPT',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Receipt reference link copied successfully!',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomButton(
                      text: 'DISMISS',
                      isOutline: true,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
