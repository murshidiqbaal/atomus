import 'package:geolocator/geolocator.dart';
import '../models/campus_model.dart';
import '../repositories/campus_repository.dart';
import '../services/teacher_hive_service.dart';

class CampusGeofenceService {
  final CampusRepository _campusRepo;
  final TeacherHiveService _teacherHive;

  CampusGeofenceService({
    required CampusRepository campusRepository,
    required TeacherHiveService teacherHive,
  }) : _campusRepo = campusRepository,
       _teacherHive = teacherHive;

  // Calculates distance between two coordinates
  Future<double> distance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) async {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // Detects the current campus based on GPS location and allowed radius
  Future<Campus?> detectCurrentCampus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('GPS_DISABLED');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('PERMISSION_DENIED');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('PERMISSION_DENIED_FOREVER');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );

    // 1. Get assigned campuses from teacher profile (Hive cache or Supabase)
    final profile = _teacherHive.getTeacherProfile();
    if (profile == null) return null;

    final assignedCampusesRaw = profile['assigned_campuses'];
    final List<String> campusIds = assignedCampusesRaw is List
        ? assignedCampusesRaw.map((e) => e.toString()).toList()
        : [];

    if (campusIds.isEmpty) return null;

    // 2. Fetch campus details
    final campuses = await _campusRepo.fetchCampusesByIds(campusIds);

    Campus? nearestMatchedCampus;
    double minMatchedDistance = double.infinity;

    for (final campus in campuses) {
      final dist = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        campus.latitude,
        campus.longitude,
      );

      if (dist <= campus.allowedRadiusMeters) {
        if (dist < minMatchedDistance) {
          minMatchedDistance = dist;
          nearestMatchedCampus = campus;
        }
      }
    }

    return nearestMatchedCampus;
  }

  // Checks if the user is inside any campus geofence and allowed to punch
  Future<bool> canPunch() async {
    try {
      final campus = await detectCurrentCampus();
      return campus != null;
    } catch (_) {
      return false;
    }
  }

  // Fetches assigned campuses
  Future<List<Campus>> getAssignedCampuses() async {
    final profile = _teacherHive.getTeacherProfile();
    if (profile == null) return [];

    final assignedCampusesRaw = profile['assigned_campuses'];
    final List<String> campusIds = assignedCampusesRaw is List
        ? assignedCampusesRaw.map((e) => e.toString()).toList()
        : [];

    if (campusIds.isEmpty) return [];
    return _campusRepo.fetchCampusesByIds(campusIds);
  }
}
