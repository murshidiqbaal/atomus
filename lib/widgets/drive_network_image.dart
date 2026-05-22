import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/drive_image_helper.dart';

enum DrivePlaceholderType { avatar, banner, certificate }

/// Reusable widget that renders a Google Drive image from a file ID.
///
/// Handles: caching, shimmer loading skeleton, fallback placeholder,
/// and graceful error display — no broken-image UI.
class DriveNetworkImage extends StatelessWidget {
  const DriveNetworkImage({
    super.key,
    required this.driveId,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.placeholderType = DrivePlaceholderType.banner,
    this.initials,
    this.highQuality = false,
    this.imageWidth = 1000,
    this.alt = '',
  });

  final String? driveId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadiusGeometry borderRadius;
  final DrivePlaceholderType placeholderType;

  /// Used for avatar placeholder personalisation.
  final String? initials;

  /// When true uses lh3.googleusercontent.com (higher quality, slower).
  final bool highQuality;

  /// Pixel width hint sent to Google's image pipeline.
  final int imageWidth;

  /// Semantic label for accessibility.
  final String alt;

  /// Returns a valid Google Drive URL only when the ID is valid,
  /// otherwise returns null.
  String? get _resolvedUrl {
    return DriveImageHelper.resolve(
      driveId,
      width: imageWidth,
      highQuality: highQuality,
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolvedUrl;

    // No valid Drive ID → skip network entirely, show local placeholder
    if (url == null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: _LocalPlaceholder(
          width: width,
          height: height,
          type: placeholderType,
          initials: initials,
        ),
      );
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Semantics(
        label: alt,
        image: true,
        child: CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: fit,
          fadeInDuration: const Duration(milliseconds: 300),
          placeholder: (context, url) =>
              _ShimmerPlaceholder(width: width, height: height),
          errorWidget: (context, url, error) => _LocalPlaceholder(
            width: width,
            height: height,
            type: placeholderType,
            initials: initials,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer loading skeleton (shown while the network image is downloading)
// ---------------------------------------------------------------------------
class _ShimmerPlaceholder extends StatefulWidget {
  const _ShimmerPlaceholder({this.width, this.height});
  final double? width;
  final double? height;

  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_animation.value, 0),
              end: Alignment(_animation.value + 2, 0),
              colors: const [
                Color(0xFF1A1A2E),
                Color(0xFF2A2A3E),
                Color(0xFF1A1A2E),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Local widget placeholder — never hits the network, so can't loop
// ---------------------------------------------------------------------------
class _LocalPlaceholder extends StatelessWidget {
  const _LocalPlaceholder({
    this.width,
    this.height,
    required this.type,
    this.initials,
  });
  final double? width;
  final double? height;
  final DrivePlaceholderType type;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case DrivePlaceholderType.avatar:
        return _AvatarPlaceholder(
          width: width,
          height: height,
          initials: initials,
        );
      case DrivePlaceholderType.banner:
        return _BannerPlaceholder(width: width, height: height);
      case DrivePlaceholderType.certificate:
        return _CertificatePlaceholder(width: width, height: height);
    }
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({this.width, this.height, this.initials});
  final double? width;
  final double? height;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    final letter = (initials != null && initials!.isNotEmpty)
        ? initials!.substring(0, 1).toUpperCase()
        : '?';
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: (width ?? 56) * 0.45,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFD4AF37),
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder({this.width, this.height});
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF0F3460)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.image_rounded, color: Color(0x55D4AF37), size: 40),
      ),
    );
  }
}

class _CertificatePlaceholder extends StatelessWidget {
  const _CertificatePlaceholder({this.width, this.height});
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        border: Border.all(color: const Color(0x44D4AF37), width: 2),
      ),
      child: const Center(
        child: Icon(
          Icons.workspace_premium_rounded,
          color: Color(0x55D4AF37),
          size: 36,
        ),
      ),
    );
  }
}

// =========================================================================
// Convenience Variants
// =========================================================================

/// Convenience variant pre-configured for circular avatar display.
class DriveAvatarImage extends StatelessWidget {
  const DriveAvatarImage({
    super.key,
    required this.driveId,
    this.radius = 28,
    this.initials,
    this.alt = '',
  });

  final String? driveId;
  final double radius;
  final String? initials;
  final String alt;

  @override
  Widget build(BuildContext context) {
    return DriveNetworkImage(
      driveId: driveId,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(radius),
      placeholderType: DrivePlaceholderType.avatar,
      initials: initials,
      imageWidth: 256,
      alt: alt,
    );
  }
}

/// Convenience variant pre-configured for banner / announcement images.
class DriveBannerImage extends StatelessWidget {
  const DriveBannerImage({
    super.key,
    required this.driveId,
    this.height = 200,
    this.borderRadius = BorderRadius.zero,
    this.alt = '',
  });

  final String? driveId;
  final double height;
  final BorderRadiusGeometry borderRadius;
  final String alt;

  @override
  Widget build(BuildContext context) {
    return DriveNetworkImage(
      driveId: driveId,
      height: height,
      fit: BoxFit.cover,
      borderRadius: borderRadius,
      placeholderType: DrivePlaceholderType.banner,
      imageWidth: 1200,
      alt: alt,
    );
  }
}

/// Convenience variant pre-configured for certificate thumbnails.
class DriveCertificateImage extends StatelessWidget {
  const DriveCertificateImage({
    super.key,
    required this.driveId,
    this.width,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.alt = '',
  });

  final String? driveId;
  final double? width;
  final double? height;
  final BorderRadiusGeometry borderRadius;
  final String alt;

  @override
  Widget build(BuildContext context) {
    return DriveNetworkImage(
      driveId: driveId,
      width: width,
      height: height,
      fit: BoxFit.contain,
      borderRadius: borderRadius,
      placeholderType: DrivePlaceholderType.certificate,
      imageWidth: 800,
      alt: alt,
    );
  }
}
