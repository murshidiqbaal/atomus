import 'package:equatable/equatable.dart';

import '../../models/dummy_data.dart';

enum FeeStatus { initial, loading, success, failure }

class FeeState extends Equatable {
  final FeeStatus status;
  final List<FeeRecord> fees;
  final String? errorMessage;
  final Map<String, dynamic>? feeStructureInfo;
  final List<Map<String, dynamic>> paymentHistory;
  final double totalFee;
  final double totalPaid;
  final double totalPending;
  final double discountAmount;

  const FeeState({
    this.status = FeeStatus.initial,
    this.fees = const [],
    this.errorMessage,
    this.feeStructureInfo,
    this.paymentHistory = const [],
    this.totalFee = 0.0,
    double totalPaid = 0.0,
    double totalPending = 0.0,
    this.discountAmount = 0.0,
  }) : totalPaid = totalPaid > totalFee
           ? totalFee
           : (totalPaid < 0.0 ? 0.0 : totalPaid),
       totalPending = totalPending < 0.0 ? 0.0 : totalPending;

  /// Convenience: count of paid terms
  int get paidCount => fees.where((f) => f.isPaid).length;

  /// Convenience: count of pending terms
  int get pendingCount => fees.where((f) => !f.isPaid).length;

  /// Overall progress (0.0 to 1.0)
  double get paymentProgress =>
      totalFee > 0 ? (totalPaid / totalFee).clamp(0.0, 1.0) : 0.0;

  /// Fee structure display name
  String get structureName =>
      feeStructureInfo?['fee_structure_name'] ?? 'Fee Structure';

  /// Course name
  String get courseName => feeStructureInfo?['course_name'] ?? '';

  /// Next upcoming due fee
  FeeRecord? get nextDueFee {
    final now = DateTime.now();
    final upcoming = fees
        .where((f) => !f.isPaid && f.dueDate.isAfter(now))
        .toList();
    if (upcoming.isEmpty) return null;
    upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return upcoming.first;
  }

  /// Overdue fees — unpaid terms whose due date has already passed.
  List<FeeRecord> get overdueFees {
    final now = DateTime.now();
    return fees.where((f) => !f.isPaid && f.dueDate.isBefore(now)).toList();
  }

  /// List of term-wise/recurring fees
  List<FeeRecord> get termWiseFees => fees.where((f) => f.isTermWise).toList();

  /// List of other/individual/one-time fees
  List<FeeRecord> get otherFees => fees.where((f) => !f.isTermWise).toList();

  FeeState copyWith({
    FeeStatus? status,
    List<FeeRecord>? fees,
    String? errorMessage,
    Map<String, dynamic>? feeStructureInfo,
    List<Map<String, dynamic>>? paymentHistory,
    double? totalFee,
    double? totalPaid,
    double? totalPending,
    double? discountAmount,
  }) {
    return FeeState(
      status: status ?? this.status,
      fees: fees ?? this.fees,
      errorMessage: errorMessage ?? this.errorMessage,
      feeStructureInfo: feeStructureInfo ?? this.feeStructureInfo,
      paymentHistory: paymentHistory ?? this.paymentHistory,
      totalFee: totalFee ?? this.totalFee,
      totalPaid: totalPaid ?? this.totalPaid,
      totalPending: totalPending ?? this.totalPending,
      discountAmount: discountAmount ?? this.discountAmount,
    );
  }

  @override
  List<Object?> get props => [
    status,
    fees,
    errorMessage,
    feeStructureInfo,
    paymentHistory,
    totalFee,
    totalPaid,
    totalPending,
    discountAmount,
  ];
}
