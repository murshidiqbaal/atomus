import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lib/services/student_performance_service.dart';

class MemoryGotrueAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> getItem({required String key}) async => _storage[key];

  @override
  Future<void> removeItem({required String key}) async {
    _storage.remove(key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    _storage[key] = value;
  }
}

void main() {
  // Allow real network connections under flutter test environment
  HttpOverrides.global = null;
  WidgetsFlutterBinding.ensureInitialized();

  test('Academic Performance Engine live Supabase integration and composite calculations', () async {
    // Initialize Supabase client using EmptyLocalStorage and MemoryGotrueAsyncStorage to bypass platform plugins in tests
    await Supabase.initialize(
      url: 'https://txtvvlxaurqovghtngzm.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: MemoryGotrueAsyncStorage(),
      ),
    );

    print('=====================================================');
    print('          ACADEMIC PERFORMANCE ENGINE TEST           ');
    print('=====================================================');

    print('\n--- CALCULATING & STORING PERFORMANCE FOR MAHIN ---');
    final mahinId = '59a0e20d-039e-464d-982c-e5161bd96a64';
    try {
      final performance = await StudentPerformanceService.calculateAndStorePerformance(mahinId);
      print('SUCCESS! Overall Metrics Calculated and Upserted to Database:');
      print('  - Attendance Percentage: ${performance.attendancePercentage.toStringAsFixed(2)}%');
      print('  - Marks Percentage: ${performance.marksPercentage.toStringAsFixed(2)}%');
      print('  - Composite Score: ${performance.academicPerformanceScore.toStringAsFixed(2)}%');
      print('  - Progress Status: ${performance.progressStatus}');
      print('  - Course/Batch Rank: ${performance.performanceRank}');

      print('\nSubject-Wise Performance Breakdown:');
      for (var s in performance.subjectWisePerformance) {
        print('  * Subject: ${s.subjectName}');
        print('    - Subject ID: ${s.subjectId}');
        print('    - Attendance: ${s.attendancePercentage.toStringAsFixed(2)}%');
        print('    - Marks: ${s.marksPercentage.toStringAsFixed(2)}%');
        print('    - Combined Score: ${s.combinedScore.toStringAsFixed(2)}%');
        print('    - Status: ${s.status}');
      }
      
      expect(performance.attendancePercentage, isNotNull);
      expect(performance.marksPercentage, isNotNull);
      expect(performance.academicPerformanceScore, isNotNull);
    } catch (e, stackTrace) {
      print('Calculation engine execution failed for MAHIN: $e');
      print(stackTrace);
      fail('MAHIN calculation failed');
    }

    print('\n--- CALCULATING & STORING PERFORMANCE FOR ASWIN MANOJ ---');
    final aswinId = 'd978fb66-f456-465e-93c8-af644d22db0b';
    try {
      final performance = await StudentPerformanceService.calculateAndStorePerformance(aswinId);
      print('SUCCESS! Overall Metrics Calculated and Upserted to Database:');
      print('  - Attendance Percentage: ${performance.attendancePercentage.toStringAsFixed(2)}%');
      print('  - Marks Percentage: ${performance.marksPercentage.toStringAsFixed(2)}%');
      print('  - Composite Score: ${performance.academicPerformanceScore.toStringAsFixed(2)}%');
      print('  - Progress Status: ${performance.progressStatus}');
      print('  - Course/Batch Rank: ${performance.performanceRank}');
      
      expect(performance.attendancePercentage, isNotNull);
      expect(performance.marksPercentage, isNotNull);
      expect(performance.academicPerformanceScore, isNotNull);
    } catch (e, stackTrace) {
      print('Calculation engine execution failed for ASWIN MANOJ: $e');
      print(stackTrace);
      fail('ASWIN calculation failed');
    }

    print('\n=====================================================');
    print('                  VERIFICATION DONE                  ');
    print('=====================================================');
  });
}
