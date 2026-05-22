import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

class ProfileImageService {
  ProfileImageService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<String?> pickAndPersistImage({
    required ImageSource source,
    required String filePrefix,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 95,
      maxWidth: 2400,
      maxHeight: 2400,
    );
    if (picked == null) return null;

    final mimeType = lookupMimeType(picked.path);
    if (mimeType == null || !mimeType.startsWith('image/')) {
      throw Exception('Please choose a valid image file.');
    }

    final targetDirectory = await _profileImageDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final targetPath = '${targetDirectory.path}/${filePrefix}_$timestamp.jpg';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      targetPath,
      quality: 78,
      minWidth: 1200,
      minHeight: 1200,
      format: CompressFormat.jpeg,
      keepExif: false,
    );

    if (compressed != null) {
      return compressed.path;
    }

    final fallbackExtension = mimeType == 'image/png' ? 'png' : 'jpg';
    final fallbackPath =
        '${targetDirectory.path}/${filePrefix}_${timestamp}_raw.$fallbackExtension';
    final fallbackFile = await File(picked.path).copy(fallbackPath);
    return fallbackFile.path;
  }

  Future<Directory> _profileImageDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/profile_images');
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }
}
