import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/constants/supabase_constants.dart';

class AttendanceDateValidator {
  static Duration _timeOffset = Duration.zero;

  /// Fetches the authoritative UTC timestamp from the Supabase REST API server.
  static Future<DateTime> getDatabaseUtcTime() async {
    try {
      final uri = Uri.parse(SupabaseConstants.url);
      final start = DateTime.now();
      final response = await http.head(uri);
      final end = DateTime.now();
      final dateHeader = response.headers['date'];
      if (dateHeader != null) {
        final serverTimeUtc = HttpDate.parse(dateHeader);
        // Correct for network latency (assume request took equal time each way)
        final latency = end.difference(start) ~/ 2;
        final correctedUtc = serverTimeUtc.add(latency);
        _timeOffset = correctedUtc.toLocal().difference(end);
        return correctedUtc;
      }
    } catch (e) {
      print(
        'AttendanceDateValidator: Error fetching database time via HTTP header: $e',
      );
    }
    // Fallback: return current device time in UTC
    return DateTime.now().toUtc();
  }

  /// Returns the synchronized local time.
  static DateTime getCorrectedLocalTime() {
    return DateTime.now().add(_timeOffset);
  }

  /// Converts a UTC database time to the user's local timezone.
  static DateTime convertToLocal(DateTime utcTime) {
    return utcTime.toLocal();
  }

  /// Returns "today" in the user's local timezone.
  ///
  /// We take the *later* of (device local date) and (server-converted local
  /// date) so that around midnight the device clock — which is always IST —
  /// wins and prevents false "future date" errors caused by the server's UTC
  /// `Date` header lagging behind the local calendar day.
  static Future<DateTime> getDatabaseToday() async {
    final deviceNow = DateTime.now();
    final deviceToday = DateTime(deviceNow.year, deviceNow.month, deviceNow.day);

    try {
      final utcTime = await getDatabaseUtcTime();
      final localTime = convertToLocal(utcTime);
      final serverToday = DateTime(localTime.year, localTime.month, localTime.day);

      // Use whichever is later — this covers the midnight boundary where the
      // device has already ticked over to the next calendar day but the HTTP
      // Date header hasn't.
      return serverToday.isAfter(deviceToday) ? serverToday : deviceToday;
    } catch (_) {
      return deviceToday;
    }
  }

  /// Checks if [date] is today relative to [dbToday].
  static bool isToday(DateTime date, DateTime dbToday) {
    return date.year == dbToday.year &&
        date.month == dbToday.month &&
        date.day == dbToday.day;
  }

  /// Checks if [date] is a future date relative to [dbToday].
  static bool isFuture(DateTime date, DateTime dbToday) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.isAfter(dbToday);
  }

  /// Checks if [date] is valid to submit (not in the future).
  static bool canSubmit(DateTime date, DateTime dbToday) {
    return !isFuture(date, dbToday);
  }

  /// Logs time-related details for debugging timezone issues.
  static void logValidation({
    required DateTime deviceTime,
    required DateTime dbUtcTime,
    required DateTime selectedDate,
    required DateTime convertedLocalDate,
  }) {
    print('=== TIMEZONE VALIDATION LOG ===');
    print('Device local time: $deviceTime');
    print('Database UTC time: $dbUtcTime');
    print('Selected attendance date: $selectedDate');
    print('Converted local date: $convertedLocalDate');
    print('=================================');
  }
}
