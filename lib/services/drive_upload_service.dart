import '../models/profile_models.dart';
import '../utils/drive_image_helper.dart';
import 'google_drive_profile_upload_service.dart';
import 'profile_image_service.dart';

class DriveUploadService {
  final ProfileImageService _imageService;
  final GoogleDriveProfileUploadService _uploader;

  DriveUploadService({
    required ProfileImageService imageService,
    required GoogleDriveProfileUploadService uploader,
  })  : _imageService = imageService,
        _uploader = uploader;

  Future<UploadResult> compressAndUpload({
    required String targetId,
    required String localPath,
  }) async {
    try {
      // The image at localPath is already compressed via ProfileImageService.
      // We upload it to Google Drive.
      final driveFileId = await _uploader.uploadProfileImage(
        target: ProfileUploadTarget.teacher,
        targetId: targetId,
        localPath: localPath,
      );

      // Generate the public image URL
      final publicUrl = DriveImageHelper.resolve(driveFileId) ?? '';

      return UploadResult(
        driveFileId: driveFileId,
        publicUrl: publicUrl,
        success: true,
      );
    } catch (e) {
      return UploadResult(
        driveFileId: '',
        publicUrl: '',
        success: false,
        error: e.toString(),
      );
    }
  }
}

class UploadResult {
  final String driveFileId;
  final String publicUrl;
  final bool success;
  final String? error;

  UploadResult({
    required this.driveFileId,
    required this.publicUrl,
    required this.success,
    this.error,
  });
}
