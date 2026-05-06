import 'package:equatable/equatable.dart';

abstract class FeeEvent extends Equatable {
  const FeeEvent();

  @override
  List<Object?> get props => [];
}

class LoadFeeData extends FeeEvent {}

class PayFeeRequested extends FeeEvent {
  final String feeTitle;

  const PayFeeRequested(this.feeTitle);

  @override
  List<Object?> get props => [feeTitle];
}
