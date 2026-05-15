import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:ui';

import '../blocs/announcement/announcement_bloc.dart';
import '../blocs/announcement/announcement_event.dart';
import '../models/dummy_data.dart';
import '../theme/app_colors.dart';

class AnnouncementPopup extends StatefulWidget {
  final Announcement announcement;

  const AnnouncementPopup({
    super.key,
    required this.announcement,
  });

  @override
  State<AnnouncementPopup> createState() => _AnnouncementPopupState();
}

class _AnnouncementPopupState extends State<AnnouncementPopup> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
    _startTimer();
  }

  void _startTimer() {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) {
        context.read<AnnouncementBloc>().add(DismissAnnouncement());
      }
    });
  }

  @override
  void didUpdateWidget(AnnouncementPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.announcement.id != oldWidget.announcement.id) {
      _controller.forward(from: 0.0);
      _startTimer();
    }
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHighPriority = widget.announcement.priority >= 10;
    
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isHighPriority ? AppColors.error : AppColors.primary)
                      .withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isHighPriority ? AppColors.error : AppColors.primary)
                        .withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isHighPriority ? AppColors.error : AppColors.accent)
                            .withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isHighPriority ? Icons.priority_high_rounded : Icons.campaign_rounded,
                        color: isHighPriority ? AppColors.error : AppColors.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.announcement.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.announcement.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary.withOpacity(0.8),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _dismiss,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
