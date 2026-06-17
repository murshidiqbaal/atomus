import 'dart:io';

void main() {
  try {
    final parsed = HttpDate.parse("Tue, 16 Jun 2026 18:55:47 GMT");
    print('Parsed: $parsed');
  } catch (e) {
    print('Error: $e');
  }
}
