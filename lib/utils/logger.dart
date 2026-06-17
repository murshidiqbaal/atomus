import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error, critical }

class AppLogger {
  static LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.warning;

  static void setLogLevel(LogLevel level) {
    _minLevel = level;
  }

  static void _log(LogLevel level, String tag, String message, [Object? error, StackTrace? stackTrace]) {
    if (level.index < _minLevel.index) return;

    final prefix = '[${level.name.toUpperCase()}][$tag]';
    final timestamp = DateTime.now().toIso8601String();
    
    // Use debugPrint to ensure it respects console output guidelines and doesn't print verbose logs in release mode.
    debugPrint('$timestamp $prefix $message');
    if (error != null) {
      debugPrint('$timestamp $prefix Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('$timestamp $prefix StackTrace:\n$stackTrace');
    }
  }

  static void debug(String tag, String message) => _log(LogLevel.debug, tag, message);
  static void info(String tag, String message) => _log(LogLevel.info, tag, message);
  static void warning(String tag, String message) => _log(LogLevel.warning, tag, message);
  static void error(String tag, String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.error, tag, message, error, stackTrace);
  static void critical(String tag, String message, [Object? error, StackTrace? stackTrace]) =>
      _log(LogLevel.critical, tag, message, error, stackTrace);
}
