import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/teacher_model.dart';
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
    double? campusLatitude,
    double? campusLongitude,
    int radiusMeters = 25,
    String? campusId,
    List<CampusLocation>? campuses,
  }) async {
    emit(state.copyWith(status: GeofenceStatus.checking));

    GeofenceResult result;
    if (campuses != null && campuses.isNotEmpty) {
      result = await _geofenceService.validateMultipleGeofences(campuses: campuses);
    } else if (campusLatitude != null && campusLongitude != null) {
      result = await _geofenceService.validateGeofence(
        campusLatitude:  campusLatitude,
        campusLongitude: campusLongitude,
        radiusMeters:    radiusMeters,
        campusId:        campusId,
      );
    } else {
      emit(state.copyWith(
        status: GeofenceStatus.error,
        errorMessage: 'No campus coordinates provided.',
      ));
      return;
    }

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
      matchedCampusId: result.matchedCampusId,
    ));
  }

  void reset() => emit(const GeofenceState());
}
