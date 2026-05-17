import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/notification/notification_bloc.dart';
import '../../blocs/notification/notification_event.dart';
import '../../blocs/notification/notification_state.dart';
import '../../models/notification_model.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/glass_background.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                              ? () => context
                                    .read<NotificationBloc>()
                                    .add(MarkAllNotificationsRead())
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

                    if (state.notifications.isEmpty) {
                      return Center(
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
                      );
                    }

                    // Group by type
                    final groups = <String, List<NotificationModel>>{};
                    for (final n in state.notifications) {
                      groups.putIfAbsent(n.type, () => []).add(n);
                    }

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
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
                    );
                  },
                ),
              ),
            ],
          ),
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
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

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
