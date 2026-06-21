import 'package:atomus/services/notification_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../blocs/notification/notification_bloc.dart';
import '../../blocs/notification/notification_event.dart';
import '../../blocs/notification/notification_state.dart';
import '../../models/dummy_data.dart' show Announcement;
import '../../models/notification_model.dart';
import '../../repositories/announcement_repository.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_background.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/drive_network_image.dart';
import '../../widgets/glass_background.dart';
import '../../widgets/neu_box.dart' show NeuDivider;
import '../../widgets/shimmer.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Announcement>? _activeAnnouncements;
  bool _isLoadingAnnouncements = true;

  // Filter & Search states
  String _selectedCategory = 'all';
  String _searchQuery = '';

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

  // Date grouping helper
  String _getDateGroupLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    final notifDate = DateTime(date.year, date.month, date.day);

    if (notifDate == today) {
      return 'TODAY';
    } else if (notifDate == yesterday) {
      return 'YESTERDAY';
    } else if (notifDate.isAfter(
      startOfWeek.subtract(const Duration(days: 1)),
    )) {
      return 'THIS WEEK';
    } else {
      return 'OLDER';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        icon: Icon(
                          Icons.search_rounded,
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                        hintText: 'Search notifications...',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white38
                              : AppColors.textSecondary.withOpacity(0.6),
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                    ),
                  ),
                ),

                // Category Chips Selector
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _buildCategoryChip('all', 'All'),
                        _buildCategoryChip('attendance', 'Attendance'),
                        _buildCategoryChip('marks', 'Marks'),
                        _buildCategoryChip('fees', 'Fees'),
                        _buildCategoryChip('reports', 'Reports'),
                        _buildCategoryChip('announcements', 'Announcements'),
                      ],
                    ),
                  ),
                ),

                // Body
                Expanded(
                  child: BlocBuilder<NotificationBloc, NotificationState>(
                    builder: (context, state) {
                      if (state.status == NotificationStatus.loading) {
                        return ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: List.generate(
                            5,
                            (_) => Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Shimmer.cardSkeleton(
                                height: 80,
                                borderRadius: 16,
                              ),
                            ),
                          ),
                        );
                      }

                      // Apply search + chip filtering
                      final filteredList = state.notifications.where((n) {
                        final matchesCategory =
                            _selectedCategory == 'all' ||
                            n.type.toLowerCase().startsWith(
                              _selectedCategory.substring(0, 3),
                            );

                        final matchesSearch =
                            n.title.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ) ||
                            n.message.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            );

                        return matchesCategory && matchesSearch;
                      }).toList();

                      // Group notifications chronologically by date group
                      final groups = <String, List<NotificationModel>>{};
                      for (final n in filteredList) {
                        final label = _getDateGroupLabel(n.createdAt);
                        groups.putIfAbsent(label, () => []).add(n);
                      }

                      // Ordered groups
                      final groupOrder = [
                        'TODAY',
                        'YESTERDAY',
                        'THIS WEEK',
                        'OLDER',
                      ];

                      return RefreshIndicator(
                        color: AppColors.accent,
                        backgroundColor: AppColors.primary,
                        onRefresh: _handleRefresh,
                        child: LayoutBuilder(
                          builder: (context, constraints) => ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            children: [
                              if (_selectedCategory == 'all' ||
                                  _selectedCategory == 'announcements')
                                _buildAnnouncementsSection(),
                              if (filteredList.isEmpty &&
                                  (_selectedCategory != 'all' ||
                                      _activeAnnouncements == null ||
                                      _activeAnnouncements!.isEmpty))
                                _buildEmptyNotificationsPlaceholder(constraints)
                              else ...[
                                for (final groupLabel in groupOrder)
                                  if (groups.containsKey(groupLabel)) ...[
                                    _buildGroupHeader(groupLabel),
                                    const SizedBox(height: 8),
                                    ...groups[groupLabel]!.map(
                                      (n) => _NotificationCard(
                                        notification: n,
                                        onTap: () {
                                          context.read<NotificationBloc>().add(
                                            MarkNotificationRead(n.id),
                                          );
                                          // Navigate based on type
                                          NotificationService.instance
                                              .handleDeepLink(
                                                n.type,
                                                referenceId: n.referenceId,
                                              );
                                        },
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

  Widget _buildCategoryChip(String id, String label) {
    final isSelected = _selectedCategory == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white60 : AppColors.textPrimary),
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.accent,
        backgroundColor: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.04),
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.transparent),
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedCategory = id;
            });
          }
        },
      ),
    );
  }

  Widget _buildAnnouncementsSection() {
    if (_isLoadingAnnouncements) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 12),
            child: Shimmer(width: 140, height: 11),
          ),
          ...List.generate(
            2,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Shimmer.cardSkeleton(height: 100, borderRadius: 16),
            ),
          ),
        ],
      );
    }
    if (_activeAnnouncements == null || _activeAnnouncements!.isEmpty) {
      return const SizedBox();
    }

    // Apply search filter if query is not empty
    final list = _activeAnnouncements!
        .where(
          (a) =>
              a.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              a.description.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    if (list.isEmpty) return const SizedBox();

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
        ...list.map((announcement) => _buildAnnouncementCard(announcement)),
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
                child:
                    announcement.imageDriveId != null &&
                        announcement.imageDriveId!.isNotEmpty
                    ? DriveBannerImage(
                        driveId: announcement.imageDriveId!,
                        borderRadius: BorderRadius.circular(12),
                        alt: announcement.title,
                      )
                    : CachedNetworkImage(
                        imageUrl: announcement.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => const Shimmer(
                          width: double.infinity,
                          height: 150,
                          borderRadius: 12,
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
      constraints: BoxConstraints(minHeight: constraints.maxHeight * 0.6),
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
              'No notifications found',
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

  Widget _buildGroupHeader(String groupLabel) {
    return Row(
      children: [
        Text(
          groupLabel,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.accent,
            letterSpacing: 1.5,
          ),
        ),
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
        onTap: onTap,
        child: AnimatedOpacity(
          opacity: notification.isRead ? 0.55 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: CustomCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                                  margin: const EdgeInsets.only(
                                    top: 3,
                                    left: 8,
                                  ),
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
                // Premium Google Drive Image Preview Support (Step 27)
                if (notification.imageUrl != null &&
                    notification.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: notification.imageUrl!.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: notification.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (context, url) => const Shimmer(
                              width: double.infinity,
                              height: 120,
                              borderRadius: 12,
                            ),
                            errorWidget: (context, url, error) =>
                                const SizedBox(),
                          )
                        : DriveNetworkImage(
                            driveId: notification.imageUrl!,
                            borderRadius: BorderRadius.circular(12),
                            alt: notification.title,
                          ),
                  ),
                ],
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
