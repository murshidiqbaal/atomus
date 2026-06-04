/// Utility for generating Google Drive image URLs from file IDs.
///
/// Database tables store only the Drive file ID (e.g. "1A2BcD3EfGhIjKlMn"),
/// never full URLs. All URL construction is centralised here.
class DriveImageHelper {
  DriveImageHelper._();

  static const String _placeholderAvatar =
      'https://ui-avatars.com/api/?background=1a1a2e&color=d4af37&bold=true&size=256';

  static const String _placeholderBanner =
      'https://via.placeholder.com/1200x400/1a1a2e/d4af37?text=Atomus';

  static const String _placeholderCertificate =
      'https://via.placeholder.com/800x600/1a1a2e/d4af37?text=Certificate';

  /// Returns true when [fileId] looks like a valid Drive ID
  /// (10–60 alphanumeric characters, hyphens and underscores allowed).
  static bool isValid(String? fileId) {
    if (fileId == null || fileId.trim().isEmpty) return false;
    final trimmed = fileId.trim();
    return RegExp(r'^[A-Za-z0-9_\-]{10,60}$').hasMatch(trimmed);
  }

  /// Thumbnail URL — fast, optimised for lists and cards.
  /// Defaults to 1000 px wide.
  static String thumbnailUrl(String fileId, {int width = 1000}) {
    final id = fileId.trim();
    return 'https://drive.google.com/thumbnail?id=$id&sz=w$width';
  }

  /// High-quality URL — for full-screen previews.
  /// Defaults to 2000 px wide.
  static String highQualityUrl(String fileId, {int width = 2000}) {
    final id = fileId.trim();
    return 'https://lh3.googleusercontent.com/d/$id=w$width';
  }

  /// Extracts the Google Drive file ID from a URL, query, or path.
  /// Returns the original string if it is already a valid Drive ID.
  static String? extractDriveId(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final trimmed = input.trim();
    
    if (isValid(trimmed)) return trimmed;
    
    // Format: /file/d/DRIVE_ID/...
    final fileDRegExp = RegExp(r'/file/d/([A-Za-z0-9_\-]{10,60})');
    final matchFileD = fileDRegExp.firstMatch(trimmed);
    if (matchFileD != null && matchFileD.groupCount >= 1) {
      return matchFileD.group(1);
    }
    
    // Format: ?id=DRIVE_ID or &id=DRIVE_ID
    final queryIdRegExp = RegExp(r'[?&]id=([A-Za-z0-9_\-]{10,60})');
    final matchQueryId = queryIdRegExp.firstMatch(trimmed);
    if (matchQueryId != null && matchQueryId.groupCount >= 1) {
      return matchQueryId.group(1);
    }
    
    return null;
  }

  /// Resolves the best URL for [fileId].
  ///
  /// Returns [thumbnailUrl] for [highQuality]=false (default) and
  /// [highQualityUrl] for [highQuality]=true.
  /// Returns null when the ID is invalid so callers can show a placeholder.
  static String? resolve(
    String? fileId, {
    int width = 1000,
    bool highQuality = false,
  }) {
    final extractedId = extractDriveId(fileId);
    if (!isValid(extractedId)) return null;
    return highQuality
        ? highQualityUrl(extractedId!, width: width)
        : thumbnailUrl(extractedId!, width: width);
  }

  /// Compatibility helper for profile screens and admin surfaces.
  static String? getDriveImageUrl(String? fileId, {int width = 1000}) {
    return resolve(fileId, width: width);
  }

  /// Placeholder avatar URL (optionally personalised with [initials]).
  static String avatarPlaceholder({String? initials}) {
    if (initials != null && initials.isNotEmpty) {
      final encoded = Uri.encodeComponent(initials.toUpperCase());
      return '$_placeholderAvatar&name=$encoded';
    }
    return _placeholderAvatar;
  }

  /// Placeholder banner URL used for announcements / posters.
  static String get bannerPlaceholder => _placeholderBanner;

  /// Placeholder certificate URL.
  static String get certificatePlaceholder => _placeholderCertificate;
}

String? getDriveImageUrl(String? fileId, {int width = 1000}) {
  return DriveImageHelper.getDriveImageUrl(fileId, width: width);
}
