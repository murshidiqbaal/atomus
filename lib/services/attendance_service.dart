import 'package:geolocator/geolocator.dart';
import '../models/teacher_attendance_model.dart';
import '../providers/campus_provider.dart';
import '../repositories/teacher_attendance_repository.dart';
import 'campus_geofence_service.dart';

class AttendanceService {
  final CampusGeofenceService _geofenceService;
  final TeacherAttendanceRepository _attendanceRepo;

  AttendanceService({
    required CampusGeofenceService geofenceService,
    required TeacherAttendanceRepository attendanceRepository,
  }) : _geofenceService = geofenceService,
       _attendanceRepo = attendanceRepository;

  /// Punch In teacher: checks geofence, determines matched campus,
  /// saves matching campus UUID to attendance log, and sets working campus.
  Future<TeacherAttendanceModel> punchIn({
    required String teacherId,
    required String? subjectId,
    required String? courseId,
    required String? batchId,
    required String sessionType,
    required CampusProvider campusProvider,
  }) async {
    // 1. Detect matched campus based on current geofence
    final matchedCampus = await _geofenceService.detectCurrentCampus();
    if (matchedCampus == null) {
      throw Exception('OUTSIDE_GEOFENCE');
    }

    // 2. Get current position for attendance log coordinates
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    ).catchError((_) => Position(
      latitude: matchedCampus.latitude,
      longitude: matchedCampus.longitude,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    ));

    // 3. Start attendance session using the matched campus UUID
    final session = await _attendanceRepo.startSession(
      teacherId: teacherId,
      campusId: matchedCampus.id,
      subjectId: subjectId,
      courseId: courseId,
      batchId: batchId,
      latitude: position.latitude,
      longitude: position.longitude,
      sessionType: sessionType,
    );

    // 4. Update current working campus in provider
    await campusProvider.detectWorkingCampus();

    return session;
  }

  /// Punch Out teacher: ends the active attendance session
  Future<TeacherAttendanceModel> punchOut(TeacherAttendanceModel activeSession) async {
    return _attendanceRepo.endSession(activeSession);
  }
}
