import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'connectivity_state.dart';

class ConnectivityCubit extends Cubit<ConnectivityState> {
  StreamSubscription<List<ConnectivityResult>>? _sub;

  ConnectivityCubit() : super(const ConnectivityState()) {
    _init();
  }

  Future<void> _init() async {
    final result = await Connectivity().checkConnectivity();
    _emitFromResults(result);
    _sub = Connectivity().onConnectivityChanged.listen(_emitFromResults);
  }

  void _emitFromResults(List<ConnectivityResult> results) {
    final isOnline = !results.contains(ConnectivityResult.none);
    if (!isClosed) {
      emit(ConnectivityState(
        status: isOnline ? ConnectivityStatus.online : ConnectivityStatus.offline,
      ));
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
