import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/geofence_service.dart';
import 'geofence_state.dart';

class GeofenceCubit extends Cubit<GeofenceState> {
  final GeofenceService _geofenceService;
  StreamSubscription<Position>? _locationSub;

  GeofenceCubit({required GeofenceService geofenceService})
      : _geofenceService = geofenceService,
        super(const GeofenceState());

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

  // Battery-efficient location tracking during an active class session.
  void startSessionTracking({
    required double campusLatitude,
    required double campusLongitude,
    int radiusMeters = 25,
  }) {
    _locationSub?.cancel();
    _locationSub = _geofenceService.activeSessionLocationStream().listen(
      (position) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          campusLatitude,
          campusLongitude,
        );
        emit(GeofenceState(
          status: distance <= radiusMeters
              ? GeofenceStatus.inside
              : GeofenceStatus.outside,
          distanceMeters: distance,
          position: position,
        ));
      },
      onError: (_) {},
    );
  }

  void stopSessionTracking() {
    _locationSub?.cancel();
    _locationSub = null;
  }

  @override
  Future<void> close() {
    _locationSub?.cancel();
    return super.close();
  }
}
