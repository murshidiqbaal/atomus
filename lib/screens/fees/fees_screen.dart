import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../blocs/fee/fee_bloc.dart';
import '../../blocs/fee/fee_state.dart';
import '../../blocs/fee/fee_event.dart';
import '../../blocs/student/student_bloc.dart';
import '../../widgets/neu_box.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/drive_network_image.dart';
import '../../utils/drive_image_helper.dart';
import '../../models/dummy_data.dart';
import '../../repositories/fee_repository.dart';

class FeesScreen extends StatelessWidget {
  const FeesScreen({super.key});

  Future<void> _handleRefresh(BuildContext context) async {
    final feeBloc = context.read<FeeBloc>();
    feeBloc.add(LoadFeeData());
    await feeBloc.stream
        .firstWhere((s) => s.status != FeeStatus.loading)
        .timeout(const Duration(seconds: 6), onTimeout: () => feeBloc.state);
  }

  @override
  Widget build(BuildContext context) {
    final studentState = context.read<StudentBloc>().state;
    final studentInfo = studentState.studentInfo;
    final studentName = studentInfo?.fullName ?? 'Student';
    final studentGrade =
        studentInfo?.grade ?? 'Academic Program';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Fee Management'),
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Center(
              child: NeuBox(
                width: 40,
                height: 40,
                borderRadius: 10,
                padding: EdgeInsets.zero,
                onTap: () => Scaffold.of(context).openDrawer(),
                child: Center(
                  child: Icon(
                    Icons.menu_rounded,
                    color: isDark ? AppColors.accent : AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Center(
                child: NeuBox(
                  width: 40,
                  height: 40,
                  borderRadius: 10,
                  padding: EdgeInsets.zero,
                  onTap: () => _handleRefresh(context),
                  child: Center(
                    child: Icon(
                      Icons.refresh_rounded,
                      color: isDark ? AppColors.accent : AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: BlocBuilder<FeeBloc, FeeState>(
          builder: (context, state) {
            if (state.status == FeeStatus.loading && state.fees.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading fee details...',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (state.status == FeeStatus.failure && state.fees.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 56,
                        color: AppColors.error.withOpacity(0.7)),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load fee data',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      state.errorMessage ?? 'Please try again',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _handleRefresh(context),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.accent,
              backgroundColor: isDark ? AppColors.neuBaseDark : AppColors.neuBase,
              onRefresh: () => _handleRefresh(context),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  // ─── Campus Payment QR Code ────────────────────────
                  if (studentInfo != null) ...[
                    _buildCampusQrCard(context, studentInfo, isDark),
                    const SizedBox(height: 20),
                  ],

                  // ─── Overview Summary Card ─────────────────────────
                  _buildOverviewCard(context, state, isDark),
                  const SizedBox(height: 20),

                  // ─── Quick Stats Row ───────────────────────────────
                  _buildQuickStats(context, state, isDark),
                  const SizedBox(height: 24),

                  // ─── Overdue Alert ─────────────────────────────────
                  if (state.overdueFees.isNotEmpty) ...[
                    _buildOverdueAlert(context, state, isDark),
                    const SizedBox(height: 20),
                  ],

                  // ─── Next Payment Due ──────────────────────────────
                  if (state.nextDueFee != null) ...[
                    _buildNextPaymentCard(context, state.nextDueFee!, isDark),
                    const SizedBox(height: 24),
                  ],

                  // ─── Term-wise Fee Cards ───────────────────────────
                  _buildSectionHeader(
                      'Term-wise Breakdown', Icons.view_timeline_rounded, isDark),
                  const SizedBox(height: 12),
                  ...state.fees.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildTermCard(
                            context,
                            entry.value,
                            entry.key,
                            studentName,
                            studentGrade,
                            isDark,
                          ),
                        ),
                      ),

                  // ─── Payment History ───────────────────────────────
                  if (state.paymentHistory.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSectionHeader(
                        'Payment History', Icons.history_rounded, isDark),
                    const SizedBox(height: 12),
                    ...state.paymentHistory.take(5).map(
                          (txn) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildPaymentHistoryTile(context, txn, isDark),
                          ),
                        ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  CAMPUS PAYMENT QR CARD — Scan & Pay with zoom capability
  // ════════════════════════════════════════════════════════════════
  Widget _buildCampusQrCard(
      BuildContext context, StudentInfo student, bool isDark) {
    final driveId = student.paymentQrDriveId;
    final url = student.paymentQrUrl;
    final campus = student.campusName ?? 'Campus';

    final hasDriveId = driveId != null && driveId.isNotEmpty && DriveImageHelper.isValid(driveId);
    final hasUrl = url != null && url.isNotEmpty;

    if (!hasDriveId && !hasUrl) return const SizedBox.shrink();

    return NeuBox(
      borderRadius: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.qr_code_2_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CAMPUS SCAN & PAY',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: isDark
                            ? AppColors.textPrimaryDark.withOpacity(0.7)
                            : AppColors.textPrimary.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      campus,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Payment',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Scan this QR code using any UPI app (GPay, PhonePe, Paytm) to make payment. Tap the QR code to enlarge.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => _showFullscreenQr(context, campus, driveId, url, isDark),
                child: NeuBox(
                  borderRadius: 16,
                  padding: const EdgeInsets.all(8),
                  color: Colors.white,
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: hasDriveId
                        ? DriveNetworkImage(
                            driveId: driveId,
                            fit: BoxFit.contain,
                            placeholderType: DrivePlaceholderType.banner,
                          )
                        : Image.network(
                            url!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.broken_image_rounded,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFullscreenQr(BuildContext context, String campus, String? driveId, String? url, bool isDark) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final hasDriveId = driveId != null && driveId.isNotEmpty && DriveImageHelper.isValid(driveId);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: NeuBox(
                  width: 40,
                  height: 40,
                  borderRadius: 20,
                  padding: EdgeInsets.zero,
                  onTap: () => Navigator.pop(context),
                  child: Center(
                    child: Icon(
                      Icons.close_rounded,
                      color: isDark ? AppColors.accent : AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              NeuBox(
                borderRadius: 28,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      campus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                        letterSpacing: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Payment QR Code',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                      width: 280,
                      height: 280,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: hasDriveId
                            ? DriveNetworkImage(
                                driveId: driveId,
                                fit: BoxFit.contain,
                                placeholderType: DrivePlaceholderType.banner,
                              )
                            : Image.network(
                                url!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(
                                    Icons.broken_image_rounded,
                                    color: Colors.grey,
                                    size: 64,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Scan to make fee payment',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.accent : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  OVERVIEW CARD — Total Fee, Paid, Pending with progress arc
  // ════════════════════════════════════════════════════════════════
  Widget _buildOverviewCard(
      BuildContext context, FeeState state, bool isDark) {
    final progress = state.paymentProgress;
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return NeuBox(
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Structure name + course
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.account_balance_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.structureName.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.8,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (state.courseName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        state.courseName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Progress percentage
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _progressColor(progress).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: _progressColor(progress),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.08)
                  : AppColors.neuDark.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation(_progressColor(progress)),
            ),
          ),
          const SizedBox(height: 20),

          // Amount summary
          Row(
            children: [
              _buildAmountChip(
                'Total',
                currencyFmt.format(state.totalFee),
                isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimary,
                isDark,
              ),
              _buildAmountChip(
                'Paid',
                currencyFmt.format(state.totalPaid),
                AppColors.success,
                isDark,
              ),
              _buildAmountChip(
                'Pending',
                currencyFmt.format(state.totalPending),
                state.totalPending > 0 ? AppColors.warning : AppColors.success,
                isDark,
              ),
            ],
          ),
          if (state.discountAmount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.success.withOpacity(0.2), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.discount_rounded,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'Discount Applied: ${currencyFmt.format(state.discountAmount)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountChip(
      String label, String amount, Color color, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  QUICK STATS — Small icon-labeled stat boxes
  // ════════════════════════════════════════════════════════════════
  Widget _buildQuickStats(
      BuildContext context, FeeState state, bool isDark) {
    return Row(
      children: [
        _buildStatBox(
          icon: Icons.check_circle_rounded,
          label: 'Paid',
          value: '${state.paidCount}',
          color: AppColors.success,
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _buildStatBox(
          icon: Icons.schedule_rounded,
          label: 'Pending',
          value: '${state.pendingCount}',
          color: AppColors.warning,
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _buildStatBox(
          icon: Icons.receipt_long_rounded,
          label: 'Terms',
          value: '${state.fees.length}',
          color: AppColors.info,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildStatBox({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: NeuBox(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  OVERDUE ALERT
  // ════════════════════════════════════════════════════════════════
  Widget _buildOverdueAlert(
      BuildContext context, FeeState state, bool isDark) {
    final count = state.overdueFees.length;
    final totalOverdue = state.overdueFees.fold<double>(
      0,
      (sum, f) => sum + f.amount - (f.amountPaid ?? 0),
    );
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.error.withOpacity(0.15),
            AppColors.error.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Overdue Payment${count > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total overdue: ${currencyFmt.format(totalOverdue)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  NEXT PAYMENT DUE CARD
  // ════════════════════════════════════════════════════════════════
  Widget _buildNextPaymentCard(
      BuildContext context, FeeRecord fee, bool isDark) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final daysUntil = fee.dueDate.difference(DateTime.now()).inDays;
    final dueText = daysUntil == 0
        ? 'Due Today'
        : daysUntil == 1
            ? 'Due Tomorrow'
            : 'Due in $daysUntil days';

    return NeuBox(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      color: isDark
          ? AppColors.primary.withOpacity(0.08)
          : AppColors.primary.withOpacity(0.04),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.2),
                  AppColors.primary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.event_note_rounded,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UPCOMING PAYMENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.primary.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fee.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dueText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: daysUntil <= 3
                        ? AppColors.warning
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFmt.format(fee.amount),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM dd, yyyy').format(fee.dueDate),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  TERM CARD — Each term with status, amount, progress
  // ════════════════════════════════════════════════════════════════
  Widget _buildTermCard(
    BuildContext context,
    FeeRecord fee,
    int index,
    String studentName,
    String studentGrade,
    bool isDark,
  ) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay =
        DateTime(fee.dueDate.year, fee.dueDate.month, fee.dueDate.day);
    final daysToDue = dueDay.difference(today).inDays;

    // Status derived purely from this term's own state -- do NOT mark a
    // term as Paid just because some *other* term was paid.
    final isPaid = fee.isPaid;
    final isOverdue = !isPaid && daysToDue < 0;
    final isDueToday = !isPaid && daysToDue == 0;

    final String statusText;
    final Color statusColor;
    final String dueLabel;
    if (isPaid) {
      statusText = 'Paid';
      statusColor = AppColors.success;
      dueLabel = fee.paymentDate != null
          ? 'Paid on ${DateFormat('MMM dd, yyyy').format(fee.paymentDate!)}'
          : 'Payment received';
    } else if (isOverdue) {
      final overdueBy = -daysToDue;
      statusText = 'Overdue';
      statusColor = AppColors.error;
      dueLabel =
          'Overdue by $overdueBy day${overdueBy == 1 ? '' : 's'} '
          '(was due ${DateFormat('MMM dd, yyyy').format(fee.dueDate)})';
    } else if (isDueToday) {
      statusText = 'Due Today';
      statusColor = AppColors.error;
      dueLabel = 'Pay by end of today';
    } else if (daysToDue <= 7) {
      statusText = 'Due in $daysToDue d';
      statusColor = AppColors.warning;
      dueLabel =
          'Due in $daysToDue day${daysToDue == 1 ? '' : 's'} '
          '(${DateFormat('MMM dd, yyyy').format(fee.dueDate)})';
    } else {
      statusText = fee.status ?? 'Pending';
      statusColor = AppColors.warning;
      dueLabel = 'Due ${DateFormat('MMM dd, yyyy').format(fee.dueDate)}';
    }
    final paid = fee.amountPaid ?? 0.0;
    final termProgress = fee.amount > 0 ? (paid / fee.amount).clamp(0.0, 1.0) : 0.0;

    return NeuBox(
      borderRadius: 18,
      padding: EdgeInsets.zero,
      onTap: () {
        if (fee.isPaid) {
          _showReceiptBottomSheet(
              context, fee, studentName, studentGrade, isDark);
        } else {
          final studentState = context.read<StudentBloc>().state;
          final studentInfo = studentState.studentInfo;
          final paymentQrUrl = studentInfo?.paymentQrUrl;
          final paymentQrDriveId = studentInfo?.paymentQrDriveId;
          final studentId = studentInfo?.id ?? '';
          _showPaymentBottomSheet(
              context, fee, studentId, paymentQrUrl, paymentQrDriveId, isDark);
        }
      },
      child: Column(
        children: [
          // Top colored strip
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    // Term icon with number
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: isPaid
                            ? Icon(Icons.check_rounded,
                                color: statusColor, size: 22)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: statusColor,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fee.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            dueLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isPaid
                                  ? AppColors.success
                                  : (isOverdue || isDueToday)
                                      ? AppColors.error
                                      : (isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            statusText.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Amount + progress
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                currencyFmt.format(fee.amount),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (fee.isPaid) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.receipt_rounded,
                                    size: 16,
                                    color:
                                        AppColors.success.withOpacity(0.7)),
                                const SizedBox(width: 3),
                                Text(
                                  'Tap for receipt',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.success.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (!fee.isPaid && paid > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Paid: ${currencyFmt.format(paid)} • Remaining: ${currencyFmt.format(fee.amount - paid)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Partial payment progress bar
                if (!fee.isPaid && paid > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: termProgress,
                      minHeight: 5,
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.06)
                          : AppColors.neuDark.withOpacity(0.2),
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.warning),
                    ),
                  ),
                ],

                // Payment date for paid terms
                if (fee.isPaid && fee.paymentDate != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        'Paid on ${DateFormat('MMM dd, yyyy').format(fee.paymentDate!)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (fee.receiptId.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '• REF: ${fee.receiptId}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  PAYMENT HISTORY TILE
  // ════════════════════════════════════════════════════════════════
  Widget _buildPaymentHistoryTile(
      BuildContext context, Map<String, dynamic> txn, bool isDark) {
    final amount = (txn['amount'] ?? 0).toDouble();
    final dateStr = txn['payment_date']?.toString();
    final date = dateStr != null
        ? DateTime.tryParse(dateStr) ?? DateTime.now()
        : DateTime.now();
    final method = txn['payment_method']?.toString() ?? 'Online';
    final status = txn['status']?.toString() ?? 'Success';
    final refId = txn['transaction_id']?.toString() ?? txn['id']?.toString() ?? '';
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return NeuBox(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.payment_rounded,
                size: 18, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currencyFmt.format(amount),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('MMM dd, yyyy').format(date)} • $method',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: status.toLowerCase() == 'success' || status.toLowerCase() == 'completed'
                      ? AppColors.success.withOpacity(0.12)
                      : AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: status.toLowerCase() == 'success' || status.toLowerCase() == 'completed'
                        ? AppColors.success
                        : AppColors.warning,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (refId.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  refId.length > 12
                      ? '${refId.substring(0, 12)}…'
                      : refId,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark.withOpacity(0.6)
                        : AppColors.textSecondary.withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  SECTION HEADER
  // ════════════════════════════════════════════════════════════════
  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? AppColors.accent : AppColors.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (isDark ? AppColors.accent : AppColors.primary)
                      .withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  RECEIPT BOTTOM SHEET
  // ════════════════════════════════════════════════════════════════
  void _showReceiptBottomSheet(
    BuildContext context,
    FeeRecord fee,
    String studentName,
    String studentGrade,
    bool isDark,
  ) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final paymentDateStr = fee.paymentDate != null
        ? DateFormat('MMMM d, yyyy – hh:mm a').format(fee.paymentDate!)
        : DateFormat('MMMM d, yyyy')
            .format(DateTime.now().subtract(const Duration(days: 1)));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF151521)
                : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, -8),
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),

              // Verification badge
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.success.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: AppColors.success,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'PAYMENT RECEIPT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.success,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                currencyFmt.format(fee.amount),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),

              // Receipt details
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F0F18)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.grey.shade200,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildReceiptRow('Term', fee.title, isDark),
                    const SizedBox(height: 12),
                    _buildReceiptRow('Student', studentName, isDark),
                    const SizedBox(height: 12),
                    _buildReceiptRow('Program', studentGrade, isDark),
                    const SizedBox(height: 12),
                    if (fee.receiptId.isNotEmpty) ...[
                      _buildReceiptRow('Reference', fee.receiptId, isDark),
                      const SizedBox(height: 12),
                    ],

                    // Dashed separator
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: List.generate(
                          30,
                          (i) => Expanded(
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              height: 1,
                              color: isDark
                                  ? Colors.white10
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                    ),

                    _buildReceiptRow('Payment Date', paymentDateStr, isDark),
                    const SizedBox(height: 12),
                    _buildReceiptRow(
                      'Amount',
                      currencyFmt.format(fee.amount),
                      isDark,
                      isBold: true,
                    ),
                    const SizedBox(height: 12),
                    _buildReceiptRow(
                      'Status',
                      'PAID / SUCCESS',
                      isDark,
                      valueColor: AppColors.success,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                                'Receipt link copied!'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isDark
                              ? Colors.white24
                              : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
    String value,
    bool isDark, {
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
            color: isDark
                ? AppColors.textSecondaryDark.withOpacity(0.7)
                : AppColors.textSecondary.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor ??
                  (isDark ? Colors.white : AppColors.textPrimary),
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════
  Color _progressColor(double progress) {
    if (progress >= 0.9) return AppColors.success;
    if (progress >= 0.5) return AppColors.info;
    if (progress >= 0.25) return AppColors.warning;
    return AppColors.error;
  }

  void _showPaymentBottomSheet(
    BuildContext context,
    FeeRecord fee,
    String studentId,
    String? paymentQrUrl,
    String? paymentQrDriveId,
    bool isDark,
  ) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final txController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151521) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'PAY FEE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.accent : AppColors.primary,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fee.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currencyFmt.format(fee.amount),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.accent : AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 20),

                      if ((paymentQrDriveId != null && paymentQrDriveId.isNotEmpty && DriveImageHelper.isValid(paymentQrDriveId)) ||
                          (paymentQrUrl != null && paymentQrUrl.isNotEmpty)) ...[
                        Text(
                          'Scan the QR code below to make payment',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                            ),
                          ),
                          width: 220,
                          height: 220,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: (paymentQrDriveId != null && paymentQrDriveId.isNotEmpty && DriveImageHelper.isValid(paymentQrDriveId))
                                ? DriveNetworkImage(
                                    driveId: paymentQrDriveId,
                                    fit: BoxFit.contain,
                                    placeholderType: DrivePlaceholderType.banner,
                                  )
                                : Image.network(
                                    paymentQrUrl!,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.primary,
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Icon(
                                          Icons.broken_image_rounded,
                                          color: Colors.grey.shade400,
                                          size: 48,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.warning.withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No QR code configured for your campus. Please contact administration for payment details.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      TextFormField(
                        controller: txController,
                        enabled: !isSubmitting,
                        decoration: InputDecoration(
                          labelText: 'UPI Transaction ID / Ref Number',
                          labelStyle: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          hintText: 'Enter 12-digit transaction ID',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                          ),
                          prefixIcon: Icon(
                            Icons.receipt_rounded,
                            color: isDark ? AppColors.accent : AppColors.primary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? Colors.white24 : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.accent : AppColors.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter transaction ID';
                          }
                          if (value.trim().length < 6) {
                            return 'Transaction ID is too short';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      if (formKey.currentState!.validate()) {
                                        setState(() {
                                          isSubmitting = true;
                                        });

                                        try {
                                          final feeRepository = FeeRepository();
                                          await feeRepository.submitPaymentTransaction(
                                            studentId: studentId,
                                            amount: fee.amount,
                                            termName: fee.title,
                                            transactionId: txController.text.trim(),
                                            paymentMethod: 'UPI / QR',
                                          );

                                          if (context.mounted) {
                                            context.read<FeeBloc>().add(LoadFeeData());

                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: const Text('Payment proof submitted successfully!'),
                                                backgroundColor: AppColors.success,
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                            Navigator.pop(context);
                                          }
                                        } catch (e) {
                                          setState(() {
                                            isSubmitting = false;
                                          });
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Submission failed: $e'),
                                                backgroundColor: AppColors.error,
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Submit Confirmation'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting ? null : () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(
                                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
