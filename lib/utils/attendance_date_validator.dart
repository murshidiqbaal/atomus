import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/constants/supabase_constants.dart';

class AttendanceDateValidator {
  /// Fetches the authoritative UTC timestamp from the Supabase REST API server.
  static Future<DateTime> getDatabaseUtcTime() async {
    try {
      final uri = Uri.parse(SupabaseConstants.url);
      final response = await http.head(uri);
      final dateHeader = response.headers['date'];
      if (dateHeader != null) {
        return HttpDate.parse(dateHeader);
      }
    } catch (e) {
      print(
        'AttendanceDateValidator: Error fetching database time via HTTP header: $e',
      );
    }
    // Fallback: return current device time in UTC
    return DateTime.now().toUtc();
  }

  /// Converts a UTC database time to the user's local timezone.
  static DateTime convertToLocal(DateTime utcTime) {
    return utcTime.toLocal();
  }

  /// Gets the local today date at midnight (local Year, Month, Day) from database time.
  static Future<DateTime> getDatabaseToday() async {
    final utcTime = await getDatabaseUtcTime();
    final localTime = convertToLocal(utcTime);
    return DateTime(localTime.year, localTime.month, localTime.day);
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
