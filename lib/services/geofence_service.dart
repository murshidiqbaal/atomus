import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import '../models/teacher_model.dart';

class GeofenceResult {
  final bool isInsideGeofence;
  final double distanceMeters;
  final Position? position;
  final String? errorMessage;
  final String? matchedCampusId;

  const GeofenceResult({
    required this.isInsideGeofence,
    required this.distanceMeters,
    this.position,
    this.errorMessage,
    this.matchedCampusId,
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
    String? campusId,
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
        matchedCampusId: campusId,
      );
    } catch (e) {
      return GeofenceResult(
        isInsideGeofence: false,
        distanceMeters: double.infinity,
        errorMessage: 'Could not determine location: ${e.toString()}',
      );
    }
  }

  // Validates whether the device is within any of the campuses geofences.
  Future<GeofenceResult> validateMultipleGeofences({
    required List<CampusLocation> campuses,
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

      if (campuses.isEmpty) {
        return GeofenceResult(
          isInsideGeofence: false,
          distanceMeters: double.infinity,
          position: position,
          errorMessage: 'No campus locations configured.',
        );
      }

      double minDistance = double.infinity;
      bool isInsideAny = false;
      CampusLocation? matchedCampus;

      for (final campus in campuses) {
        if (campus.latitude == null || campus.longitude == null) continue;
        final distance = _haversineDistance(
          position.latitude,
          position.longitude,
          campus.latitude!,
          campus.longitude!,
        );

        if (distance <= campus.radiusMeters) {
          isInsideAny = true;
          if (distance < minDistance) {
            minDistance = distance;
            matchedCampus = campus;
          }
        } else {
          if (!isInsideAny && distance < minDistance) {
            minDistance = distance;
            matchedCampus = campus;
          }
        }
      }

      // If we didn't find any campus with valid coordinates
      if (matchedCampus == null) {
        return GeofenceResult(
          isInsideGeofence: false,
          distanceMeters: double.infinity,
          position: position,
          errorMessage: 'No campus locations with coordinates configured.',
        );
      }

      return GeofenceResult(
        isInsideGeofence: isInsideAny,
        distanceMeters: minDistance,
        position: position,
        matchedCampusId: matchedCampus.id,
      );
    } catch (e) {
      return GeofenceResult(
        isInsideGeofence: false,
        distanceMeters: double.infinity,
        errorMessage: 'Could not determine location: ${e.toString()}',
      );
    }
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
