import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/geofence_service.dart';
import 'geofence_state.dart';

class GeofenceCubit extends Cubit<GeofenceState> {
  final GeofenceService _geofenceService;

  GeofenceCubit({required GeofenceService geofenceService})
      : _geofenceService = geofenceService,
        super(const GeofenceState());

  /// One-time location fetch and campus radius validation.
  /// Call this only when the teacher explicitly taps "Verify Location".
  Future<void> checkGeofence({
    required double campusLatitude,
    required double campusLongitude,
    int radiusMeters = 25,
  }) async {
    emit(state.copyWith(status: GeofenceStatus.checking));

    final result = await _geofenceService.validateGeofence(
      campusLatitude:  campusLatitude,
      campusLongitude: campusLongitude,
      radiusMeters:    radiusMeters,
    );

    if (result.hasError) {
      final msg = result.errorMessage!;
      final status = msg.contains('permission')
          ? GeofenceStatus.permissionDenied
          : msg.contains('disabled') || msg.contains('GPS')
              ? GeofenceStatus.serviceDisabled
              : GeofenceStatus.error;
      emit(state.copyWith(status: status, errorMessage: msg));
      return;
    }

    emit(GeofenceState(
      status:         result.isInsideGeofence
                        ? GeofenceStatus.inside
                        : GeofenceStatus.outside,
      distanceMeters: result.distanceMeters,
      position:       result.position,
    ));
  }

  void reset() => emit(const GeofenceState());
}
