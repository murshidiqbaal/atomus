import 'package:equatable/equatable.dart';
import '../../models/dummy_data.dart';

enum FeeStatus { initial, loading, success, failure }

class FeeState extends Equatable {
  final FeeStatus status;
  final List<FeeRecord> fees;
  final String? errorMessage;

  const FeeState({
    this.status = FeeStatus.initial,
    this.fees = const [],
    this.errorMessage,
  });

  FeeState copyWith({
    FeeStatus? status,
    List<FeeRecord>? fees,
    String? errorMessage,
  }) {
    return FeeState(
      status: status ?? this.status,
      fees: fees ?? this.fees,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, fees, errorMessage];
}
