import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://txtvvlxaurqovghtngzm.supabase.co/rest/v1/';
  final headers = {
    'apikey':
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  };

  try {
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      final spec = jsonDecode(response.body);
      final definitions = spec['definitions'] as Map<String, dynamic>;

      final tablesToInspect = [
        'students',
        'exams',
        'marks',
        'subject_attendance',
        'student_academic_performance',
      ];

      for (var tableName in tablesToInspect) {
        print('=== TABLE: $tableName ===');
        final tableDef = definitions[tableName];
        if (tableDef == null) {
          print('Not found in definitions.');
          continue;
        }
        final properties = tableDef['properties'] as Map<String, dynamic>;
        final requiredFields = tableDef['required'] ?? [];
        print('Required fields: $requiredFields');
        properties.forEach((name, details) {
          print(
            '  - $name: ${details['type']} (${details['format'] ?? ''}) - description: ${details['description'] ?? ''}',
          );
        });
        print('');
      }
    } else {
      print('Failed to load: ${response.statusCode}');
      print(response.body);
    }
  } catch (e) {
    print('Error: $e');
  }
}
