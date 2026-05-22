import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

class GeofenceResult {
  final bool isInsideGeofence;
  final double distanceMeters;
  final Position? position;
  final String? errorMessage;

  const GeofenceResult({
    required this.isInsideGeofence,
    required this.distanceMeters,
    this.position,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;
}

class GeofenceService {
  static const int _defaultRadiusMeters = 25;

  // Returns current device position; requests permission if needed.
  Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // Validates whether the device is within the campus geofence.
  Future<GeofenceResult> validateGeofence({
    required double campusLatitude,
    required double campusLongitude,
    int radiusMeters = _defaultRadiusMeters,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const GeofenceResult(
          isInsideGeofence: false,
          distanceMeters: double.infinity,
          errorMessage: 'Location services are disabled. Please enable GPS.',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const GeofenceResult(
          isInsideGeofence: false,
          distanceMeters: double.infinity,
          errorMessage: 'Location permission denied. Please allow location access.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final distance = _haversineDistance(
        position.latitude,
        position.longitude,
        campusLatitude,
        campusLongitude,
      );

      return GeofenceResult(
        isInsideGeofence: distance <= radiusMeters,
        distanceMeters: distance,
        position: position,
      );
    } catch (e) {
      return GeofenceResult(
        isInsideGeofence: false,
        distanceMeters: double.infinity,
        errorMessage: 'Could not determine location: ${e.toString()}',
      );
    }
  }

  // Stream of positions during an active session (battery-efficient 30s interval).
  Stream<Position> activeSessionLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 10, // update only when moved 10m
        timeLimit: Duration(seconds: 30),
      ),
    );
  }

  // Haversine formula for accurate earth-surface distance in metres.
  double _haversineDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const r = 6371000.0; // Earth radius in metres
    final phi1   = lat1 * math.pi / 180;
    final phi2   = lat2 * math.pi / 180;
    final dPhi   = (lat2 - lat1) * math.pi / 180;
    final dLambda = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
        math.cos(phi1) * math.cos(phi2) *
            math.sin(dLambda / 2) * math.sin(dLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  // Quick permission status check without triggering a prompt.
  Future<bool> hasLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();
}
