import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/campus_geofence_service.dart';
import 'geofence_state.dart';

class GeofenceCubit extends Cubit<GeofenceState> {
  final CampusGeofenceService _geofenceService;

  GeofenceCubit({required CampusGeofenceService geofenceService})
    : _geofenceService = geofenceService,
      super(const GeofenceState());

  /// One-time location fetch and campus radius validation.
  /// Call this when checking multi-campus geofence.
  Future<void> checkGeofence() async {
    emit(state.copyWith(status: GeofenceStatus.checking));

    try {
      final matchedCampus = await _geofenceService.detectCurrentCampus();
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (matchedCampus == null) {
        // If not inside any campus, find the distance to the nearest campus
        final assigned = await _geofenceService.getAssignedCampuses();
        double minDistance = double.infinity;
        for (final campus in assigned) {
          final dist = await _geofenceService.distance(
            position.latitude,
            position.longitude,
            campus.latitude,
            campus.longitude,
          );
          if (dist < minDistance) {
            minDistance = dist;
          }
        }
        
        emit(
          state.copyWith(
            status: GeofenceStatus.outside,
            position: position,
            distanceMeters: minDistance == double.infinity ? 0.0 : minDistance,
            errorMessage: 'You are not inside any assigned campus.',
          ),
        );
        return;
      }

      final dist = await _geofenceService.distance(
        position.latitude,
        position.longitude,
        matchedCampus.latitude,
        matchedCampus.longitude,
      );

      emit(
        GeofenceState(
          status: GeofenceStatus.inside,
          distanceMeters: dist,
          position: position,
          matchedCampusId: matchedCampus.id,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      final status = msg.contains('PERMISSION_DENIED')
          ? GeofenceStatus.permissionDenied
          : msg.contains('GPS_DISABLED')
          ? GeofenceStatus.serviceDisabled
          : GeofenceStatus.error;
      emit(
        state.copyWith(
          status: status,
          errorMessage: msg == 'PERMISSION_DENIED'
              ? 'Location permission denied. Please allow location access.'
              : msg == 'GPS_DISABLED'
                  ? 'Location services are disabled. Please enable GPS.'
                  : msg,
        ),
      );
    }
  }

  void reset() => emit(const GeofenceState());
}
