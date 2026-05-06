import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../blocs/fee/fee_bloc.dart';
import '../../blocs/fee/fee_state.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/neu_box.dart';

class FeesScreen extends StatelessWidget {
  const FeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neuBase,
      appBar: AppBar(
        title: const Text('Financial Services'),
      ),
      body: BlocBuilder<FeeBloc, FeeState>(
        builder: (context, state) {
          if (state.status == FeeStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
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
                        child: Icon(Icons.qr_code_2_rounded, size: 100, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'SECURE CHECKOUT',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 2.0, color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Scan the generated identifier using your authorized banking application.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 32),
                    CustomButton(
                      text: 'GENERATE RECEIPT',
                      onPressed: () {},
                      isOutline: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Transaction History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              ...state.fees.map((fee) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
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
                              fee.isPaid ? Icons.verified_user_rounded : Icons.account_balance_wallet_rounded,
                              color: fee.isPaid ? AppColors.success : AppColors.warning,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fee.title.toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  fee.isPaid
                                      ? 'REF: ${fee.receiptId}'
                                      : 'MATURES: ${DateFormat('MMM d, yyyy').format(fee.dueDate)}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${fee.amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fee.isPaid ? 'CLEARED' : 'PENDING',
                                style: TextStyle(
                                  color: fee.isPaid ? AppColors.success : AppColors.warning,
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
                  )),
            ],
          );
        },
      ),
    );
  }
}
