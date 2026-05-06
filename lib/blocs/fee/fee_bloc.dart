import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/fee_repository.dart';
import 'fee_event.dart';
import 'fee_state.dart';

class FeeBloc extends Bloc<FeeEvent, FeeState> {
  final FeeRepository feeRepository;

  FeeBloc({required this.feeRepository}) : super(const FeeState()) {
    on<LoadFeeData>(_onLoadFeeData);
    on<PayFeeRequested>(_onPayFeeRequested);
  }

  Future<void> _onLoadFeeData(LoadFeeData event, Emitter<FeeState> emit) async {
    emit(state.copyWith(status: FeeStatus.loading));
    try {
      final fees = await feeRepository.getFeeRecords();
      emit(state.copyWith(status: FeeStatus.success, fees: fees));
    } catch (e) {
      emit(state.copyWith(status: FeeStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onPayFeeRequested(PayFeeRequested event, Emitter<FeeState> emit) async {
    // Optimistic or simple implementation
    await feeRepository.payFee(event.feeTitle);
    add(LoadFeeData()); // Refresh data
  }
}
