import 'package:equatable/equatable.dart';

enum ConnectivityStatus { unknown, online, offline }

class ConnectivityState extends Equatable {
  final ConnectivityStatus status;

  const ConnectivityState({this.status = ConnectivityStatus.unknown});

  bool get isOnline => status == ConnectivityStatus.online;
  bool get isOffline => status == ConnectivityStatus.offline;

  ConnectivityState copyWith({ConnectivityStatus? status}) {
    return ConnectivityState(status: status ?? this.status);
  }

  @override
  List<Object?> get props => [status];
}
