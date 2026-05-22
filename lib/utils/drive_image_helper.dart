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
    if (!isValid(fileId)) return null;
    return highQuality
        ? highQualityUrl(fileId!, width: width)
        : thumbnailUrl(fileId!, width: width);
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
