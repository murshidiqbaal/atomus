import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/supabase_constants.dart';
import '../models/profile_models.dart';

class GoogleDriveProfileUploadService {
  GoogleDriveProfileUploadService({
    http.Client? client,
    SupabaseClient? supabase,
  }) : _client = client ?? http.Client(),
       _supabase = supabase ?? Supabase.instance.client;

  final http.Client _client;
  final SupabaseClient _supabase;

  Future<String> uploadProfileImage({
    required ProfileUploadTarget target,
    required String targetId,
    required String localPath,
  }) async {
    final session = _supabase.auth.currentSession;
    if (session == null || session.isExpired) {
      throw Exception('Your session expired. Please log in again.');
    }

    final file = File(localPath);
    if (!file.existsSync()) {
      throw Exception('The selected image is no longer available locally.');
    }

    final uri = Uri.parse(
      '${SupabaseConstants.url}/functions/v1/profile-image-upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'Authorization': 'Bearer ${session.accessToken}',
        'apikey': SupabaseConstants.anonKey,
      })
      ..fields['target_type'] = target.apiValue
      ..fields['target_id'] = targetId;

    final mimeType = lookupMimeType(localPath) ?? 'image/jpeg';
    final parts = mimeType.split('/');
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        localPath,
        contentType: MediaType(
          parts.first,
          parts.length > 1 ? parts.last : 'jpeg',
        ),
      ),
    );

    final streamedResponse = await _client
        .send(request)
        .timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Image upload failed. Please try again.';
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        message = json['error']?.toString() ?? message;
      } catch (_) {
        if (response.body.isNotEmpty) message = response.body;
      }
      throw Exception(message);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final fileId = json['fileId']?.toString() ?? json['file_id']?.toString();
    if (fileId == null || fileId.isEmpty) {
      throw Exception('Google Drive upload succeeded but returned no file ID.');
    }
    return fileId;
  }
}
