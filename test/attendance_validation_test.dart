import 'package:flutter_test/flutter_test.dart';
import 'package:atomus/utils/attendance_date_validator.dart';
import 'package:atomus/models/teacher_attendance_model.dart';

void main() {
  group('AttendanceDateValidator Tests', () {
    test('isToday checks correct date component matching', () {
      final dbToday = DateTime(2026, 6, 17);
      
      expect(
        AttendanceDateValidator.isToday(DateTime(2026, 6, 17, 10, 30), dbToday),
        true,
      );
      expect(
        AttendanceDateValidator.isToday(DateTime(2026, 6, 17, 0, 0), dbToday),
        true,
      );
      expect(
        AttendanceDateValidator.isToday(DateTime(2026, 6, 16, 23, 59), dbToday),
        false,
      );
      expect(
        AttendanceDateValidator.isToday(DateTime(2026, 6, 18, 0, 1), dbToday),
        false,
      );
    });

    test('isFuture identifies future dates correctly', () {
      final dbToday = DateTime(2026, 6, 17);

      expect(
        AttendanceDateValidator.isFuture(DateTime(2026, 6, 18), dbToday),
        true,
      );
      expect(
        AttendanceDateValidator.isFuture(DateTime(2026, 6, 17, 12, 0), dbToday),
        false,
      );
      expect(
        AttendanceDateValidator.isFuture(DateTime(2026, 6, 16), dbToday),
        false,
      );
    });

    test('canSubmit validates dates correctly', () {
      final dbToday = DateTime(2026, 6, 17);

      expect(
        AttendanceDateValidator.canSubmit(DateTime(2026, 6, 17), dbToday),
        true,
      );
      expect(
        AttendanceDateValidator.canSubmit(DateTime(2026, 6, 16), dbToday),
        true,
      );
      expect(
        AttendanceDateValidator.canSubmit(DateTime(2026, 6, 18), dbToday),
        false,
      );
    });
  });

  group('TeacherAttendanceModel Multi-Session Tests', () {
    test('isLate detects punch-in after 10:00 AM local time', () {
      final today = DateTime.now();

      final earlySession = TeacherAttendanceModel(
        teacherId: 't1',
        attendanceDate: today,
        startTime: DateTime(today.year, today.month, today.day, 9, 59, 59),
        status: TeacherAttendanceStatus.completed,
      );
      expect(earlySession.isLate, false);

      final exactlyTenSession = TeacherAttendanceModel(
        teacherId: 't1',
        attendanceDate: today,
        startTime: DateTime(today.year, today.month, today.day, 10, 0, 0),
        status: TeacherAttendanceStatus.completed,
      );
      expect(exactlyTenSession.isLate, false);

      final lateSession = TeacherAttendanceModel(
        teacherId: 't1',
        attendanceDate: today,
        startTime: DateTime(today.year, today.month, today.day, 10, 0, 1),
        status: TeacherAttendanceStatus.completed,
      );
      expect(lateSession.isLate, true);
    });

    test('durationLabel and duration minutes are calculated correctly', () {
      final today = DateTime.now();
      final startTime = DateTime(today.year, today.month, today.day, 9, 0, 0);

      // 45 seconds difference
      final shortSession = TeacherAttendanceModel(
        teacherId: 't1',
        attendanceDate: today,
        startTime: startTime,
        endTime: startTime.add(const Duration(seconds: 45)),
        status: TeacherAttendanceStatus.completed,
      );
      expect(shortSession.durationLabel, '45s');
      expect(shortSession.totalDurationMinutes, 0);

      // 5 minutes 30 seconds difference
      final mediumSession = TeacherAttendanceModel(
        teacherId: 't1',
        attendanceDate: today,
        startTime: startTime,
        endTime: startTime.add(const Duration(minutes: 5, seconds: 30)),
        status: TeacherAttendanceStatus.completed,
      );
      expect(mediumSession.durationLabel, '5m 30s');
      expect(mediumSession.totalDurationMinutes, 5);

      // 2 hours 15 minutes difference
      final longSession = TeacherAttendanceModel(
        teacherId: 't1',
        attendanceDate: today,
        startTime: startTime,
        endTime: startTime.add(const Duration(hours: 2, minutes: 15)),
        status: TeacherAttendanceStatus.completed,
      );
      expect(longSession.durationLabel, '2h 15m');
      expect(longSession.totalDurationMinutes, 135);
    });

    test('multiple sessions on same day calculate total working time', () {
      final today = DateTime.now();
      final s1 = TeacherAttendanceModel(
        id: 's1',
        teacherId: 't1',
        attendanceDate: today,
        startTime: DateTime(today.year, today.month, today.day, 9, 0),
        endTime: DateTime(today.year, today.month, today.day, 10, 0),
        status: TeacherAttendanceStatus.completed,
      );
      final s2 = TeacherAttendanceModel(
        id: 's2',
        teacherId: 't1',
        attendanceDate: today,
        startTime: DateTime(today.year, today.month, today.day, 11, 0),
        endTime: DateTime(today.year, today.month, today.day, 12, 30),
        status: TeacherAttendanceStatus.completed,
      );
      final s3 = TeacherAttendanceModel(
        id: 's3',
        teacherId: 't1',
        attendanceDate: today,
        startTime: DateTime(today.year, today.month, today.day, 14, 0),
        endTime: DateTime(today.year, today.month, today.day, 15, 0),
        status: TeacherAttendanceStatus.completed,
      );

      final sessions = [s1, s2, s3];
      int totalMinutes = 0;
      for (final s in sessions) {
        if (s.isCompleted && s.totalDurationMinutes != null) {
          totalMinutes += s.totalDurationMinutes!;
        }
      }

      expect(totalMinutes, 210); // 60 + 90 + 60 = 210 minutes = 3h 30m
      expect(s1.isActive, false);
      expect(s1.isCompleted, true);
    });

    test('open session status identifies active punch-in without end_time', () {
      final today = DateTime.now();
      final activeSession = TeacherAttendanceModel(
        id: 's4',
        teacherId: 't1',
        attendanceDate: today,
        startTime: today.subtract(const Duration(minutes: 30)),
        endTime: null,
        status: TeacherAttendanceStatus.active,
      );

      expect(activeSession.isActive, true);
      expect(activeSession.isCompleted, false);
      expect(activeSession.punchOut, null);
    });
  });
}
