import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/fee_repository.dart';
import '../../services/fee_hive_service.dart';
import 'fee_event.dart';
import 'fee_state.dart';

class FeeBloc extends Bloc<FeeEvent, FeeState> {
  final FeeRepository feeRepository;
  final FeeHiveService _hiveService = FeeHiveService();

  FeeBloc({required this.feeRepository}) : super(const FeeState()) {
    on<LoadFeeData>(_onLoadFeeData);
    on<PayFeeRequested>(_onPayFeeRequested);
  }

  Future<void> _onLoadFeeData(LoadFeeData event, Emitter<FeeState> emit) async {
    emit(state.copyWith(status: FeeStatus.loading));

    try {
      // Try Hive cache first for instant display
      await _hiveService.initBoxes();
      final cachedRecords = _hiveService.getCachedFeeRecords();
      final cachedHistory = _hiveService.getCachedPaymentHistory();

      if (cachedRecords != null && cachedRecords.isNotEmpty) {
        final totals = _computeTotals(cachedRecords);
        emit(state.copyWith(
          status: FeeStatus.success,
          fees: cachedRecords,
          paymentHistory: cachedHistory ?? [],
          totalFee: totals['totalFee'],
          totalPaid: totals['totalPaid'],
          totalPending: totals['totalPending'],
        ));
      }

      // Fetch fresh data from Supabase in parallel
      final results = await Future.wait([
        feeRepository.getFeeRecords(),
        feeRepository.getPaymentHistory(),
        feeRepository.getFeeStructureInfo(),
      ]);

      final fees = results[0] as List;
      final history = results[1] as List<Map<String, dynamic>>;
      final structureInfo = results[2] as Map<String, dynamic>?;

      // Use structure info totals if available, otherwise compute from records
      double totalFee;
      double totalPaid;
      double totalPending;
      double discountAmount;

      if (structureInfo != null) {
        totalFee = (structureInfo['total_fee'] as num?)?.toDouble() ?? 0.0;
        totalPaid = (structureInfo['paid_amount'] as num?)?.toDouble() ?? 0.0;
        totalPending = (structureInfo['balance_amount'] as num?)?.toDouble() ?? 0.0;
        discountAmount = (structureInfo['discount_amount'] as num?)?.toDouble() ?? 0.0;
      } else {
        final totals = _computeTotals(fees.cast());
        totalFee = totals['totalFee']!;
        totalPaid = totals['totalPaid']!;
        totalPending = totals['totalPending']!;
        discountAmount = 0.0;
      }

      // Cache for offline use
      await _hiveService.saveFeeRecords(fees.cast());
      if (history.isNotEmpty) {
        await _hiveService.savePaymentHistory(history);
      }
      if (structureInfo != null) {
        await _hiveService.saveFeeStructure(structureInfo);
      }

      emit(state.copyWith(
        status: FeeStatus.success,
        fees: fees.cast(),
        feeStructureInfo: structureInfo,
        paymentHistory: history,
        totalFee: totalFee,
        totalPaid: totalPaid,
        totalPending: totalPending,
        discountAmount: discountAmount,
      ));
    } catch (e) {
      print('ERROR [FeeBloc._onLoadFeeData]: $e');
      // If we already have cached data displayed, keep it
      if (state.fees.isNotEmpty) {
        emit(state.copyWith(
          status: FeeStatus.success,
          errorMessage: 'Using cached data. Could not refresh: $e',
        ));
      } else {
        emit(state.copyWith(
          status: FeeStatus.failure,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> _onPayFeeRequested(
    PayFeeRequested event,
    Emitter<FeeState> emit,
  ) async {
    await feeRepository.payFee(event.feeTitle);
    add(LoadFeeData()); // Refresh data
  }

  Map<String, double> _computeTotals(List fees) {
    double totalFee = 0, totalPaid = 0;
    for (final f in fees) {
      totalFee += (f.amount as num).toDouble();
      totalPaid += ((f.amountPaid ?? 0) as num).toDouble();
    }
    return {
      'totalFee': totalFee,
      'totalPaid': totalPaid,
      'totalPending': totalFee - totalPaid,
    };
  }
}
