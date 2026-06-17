import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://txtvvlxaurqovghtngzm.supabase.co/rest/v1/';
  final headers = {
    'apikey':
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dHZ2bHhhdXJxb3ZnaHRuZ3ptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgwNTc3OTQsImV4cCI6MjA5MzYzMzc5NH0.7BJqpZTW64Vgz6VLbjSdOf8M2Oq8nrWrK8uDBTEHO3s',
  };

  try {
    final response = await http.get(Uri.parse(url), headers: headers);
    print('Status: ${response.statusCode}');
    print('Headers:');
    response.headers.forEach((k, v) {
      print('  $k: $v');
    });
    final dateHeader = response.headers['date'];
    if (dateHeader != null) {
      final parsedDate = HttpDate.parse(dateHeader);
      print('Parsed date: $parsedDate');
    }
  } catch (e) {
    print('Error: $e');
  }
}

class HttpDate {
  static DateTime parse(String dateStr) {
    return DateTime.parse(dateStr); // Dart's DateTime.parse can handle RFC 1123 dates if we convert or if we use HttpDate from dart:io or similar. Let's see if DateTime.parse handles it or we can use another parser.
  }
}
