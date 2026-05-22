import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'drive_network_image.dart';

class DriveProfileImage extends StatelessWidget {
  const DriveProfileImage({
    super.key,
    this.driveId,
    this.localPath,
    this.radius,
    this.size,
    this.initials,
    this.isUploading = false,
    this.hasError = false,
    this.onRetry,
    this.alt = '',
  });

  final String? driveId;
  final String? localPath;
  final double? radius;
  final double? size;
  final String? initials;
  final bool isUploading;
  final bool hasError;
  final VoidCallback? onRetry;
  final String alt;

  @override
  Widget build(BuildContext context) {
    final imageSize = size ?? (radius ?? 32) * 2;
    final imageRadius = radius ?? imageSize / 2;

    return SizedBox(
      width: imageSize,
      height: imageSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildImage(imageSize, imageRadius),
          if (isUploading)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
          if (hasError && onRetry != null)
            Align(
              alignment: Alignment.bottomRight,
              child: Material(
                color: AppColors.error,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onRetry,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(double imageSize, double imageRadius) {
    final path = localPath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipOval(
        child: Image.file(
          File(path),
          width: imageSize,
          height: imageSize,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => DriveAvatarImage(
            driveId: driveId,
            radius: imageRadius,
            initials: initials,
            alt: alt,
          ),
        ),
      );
    }

    return DriveAvatarImage(
      driveId: driveId,
      radius: imageRadius,
      initials: initials,
      alt: alt,
    );
  }
}
