import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../blocs/notification/notification_bloc.dart';
import '../../blocs/notification/notification_event.dart';
import '../../blocs/notification/notification_state.dart';
import '../../models/notification_model.dart';
import '../../models/dummy_data.dart' show Announcement;
import '../../repositories/announcement_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/app_background.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/drive_network_image.dart';
import '../../widgets/neu_box.dart' show NeuDivider;

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Announcement>? _activeAnnouncements;
  bool _isLoadingAnnouncements = true;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    try {
      final repository = context.read<AnnouncementRepository>();
      final announcements = await repository.getActiveAnnouncements();
      if (mounted) {
        setState(() {
          _activeAnnouncements = announcements;
          _isLoadingAnnouncements = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _activeAnnouncements = [];
          _isLoadingAnnouncements = false;
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    final notificationBloc = context.read<NotificationBloc>();
    notificationBloc.add(LoadNotifications());
    final notifFuture = notificationBloc.stream
        .firstWhere((s) => s.status != NotificationStatus.loading)
        .timeout(
          const Duration(seconds: 4),
          onTimeout: () => notificationBloc.state,
        );
    final announcementsFuture = _fetchAnnouncements();
    await Future.wait([notifFuture, announcementsFuture]);
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GlassBackground(
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                      const Text(
                        'NOTIFICATIONS',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 2,
                          color: AppColors.primary,
                        ),
                      ),
                      BlocBuilder<NotificationBloc, NotificationState>(
                        builder: (context, state) {
                          return TextButton(
                            onPressed: state.unreadCount > 0
                                ? () => context.read<NotificationBloc>().add(
                                    MarkAllNotificationsRead(),
                                  )
                                : null,
                            child: Text(
                              'MARK ALL',
                              style: TextStyle(
                                color: state.unreadCount > 0
                                    ? AppColors.accent
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Body
                Expanded(
                  child: BlocBuilder<NotificationBloc, NotificationState>(
                    builder: (context, state) {
                      if (state.status == NotificationStatus.loading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // Group by type, excluding announcements to prevent duplication
                      final groups = <String, List<NotificationModel>>{};
                      for (final n in state.notifications) {
                        if (n.type == 'announcements') continue;
                        groups.putIfAbsent(n.type, () => []).add(n);
                      }

                      return RefreshIndicator(
                        color: AppColors.accent,
                        backgroundColor: AppColors.primary,
                        onRefresh: _handleRefresh,
                        child: LayoutBuilder(
                          builder: (context, constraints) => ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              _buildAnnouncementsSection(),
                              if (groups.isEmpty && (_activeAnnouncements == null || _activeAnnouncements!.isEmpty))
                                _buildEmptyNotificationsPlaceholder(constraints)
                              else ...[
                                if (groups.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 20),
                                    child: Center(
                                      child: Text(
                                        'No other notifications yet',
                                        style: TextStyle(
                                          color: AppColors.textSecondary.withOpacity(0.7),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  for (final entry in groups.entries) ...[
                                    _buildGroupHeader(context, entry.key, entry.value),
                                    const SizedBox(height: 8),
                                    ...entry.value.map(
                                      (n) => _NotificationCard(
                                        notification: n,
                                        onTap: () => context
                                            .read<NotificationBloc>()
                                            .add(MarkNotificationRead(n.id)),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementsSection() {
    if (_isLoadingAnnouncements) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }
    if (_activeAnnouncements == null || _activeAnnouncements!.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 12),
          child: Text(
            'ACTIVE ANNOUNCEMENTS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.accent,
              letterSpacing: 1.5,
            ),
          ),
        ),
        ..._activeAnnouncements!.map((announcement) => _buildAnnouncementCard(announcement)),
        const SizedBox(height: 16),
        const NeuDivider(),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAnnouncementCard(Announcement announcement) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CustomCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: AppColors.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        announcement.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        announcement.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (announcement.hasImage) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: announcement.imageDriveId != null && announcement.imageDriveId!.isNotEmpty
                    ? DriveBannerImage(
                        driveId: announcement.imageDriveId!,
                        borderRadius: BorderRadius.circular(12),
                        alt: announcement.title,
                      )
                    : CachedNetworkImage(
                        imageUrl: announcement.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          height: 150,
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                        ),
                        errorWidget: (context, url, error) => const SizedBox(),
                      ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatTime(announcement.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyNotificationsPlaceholder(BoxConstraints constraints) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: constraints.maxHeight * 0.6,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No notifications yet',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(
    BuildContext context,
    String type,
    List<NotificationModel> items,
  ) {
    final unread = items.where((n) => !n.isRead).length;
    final label = switch (type) {
      'attendance' => 'ATTENDANCE ALERTS',
      'marks' => 'MARKS UPDATES',
      'fees' => 'FEE REMINDERS',
      'announcements' => 'ANNOUNCEMENTS',
      'emergency' => 'EMERGENCY ALERTS',
      _ => type.toUpperCase(),
    };

    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.accent,
            letterSpacing: 1.5,
          ),
        ),
        if (unread > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$unread',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, y').format(dt);
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: notification.isRead ? null : onTap,
        child: AnimatedOpacity(
          opacity: notification.isRead ? 0.55 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: CustomCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: notification.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    notification.icon,
                    color: notification.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 3, left: 8),
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTime(notification.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, y').format(dt);
  }
}
