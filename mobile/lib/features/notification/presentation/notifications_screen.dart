import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/presentation/auth_user_avatar.dart';
import 'package:memory_map/features/notification/application/notification_inbox_notifier.dart';
import 'package:memory_map/features/notification/application/notification_inbox_state.dart';
import 'package:memory_map/features/notification/application/unread_notification_count_notifier.dart';
import 'package:memory_map/features/notification/domain/notification_item.dart';
import 'package:memory_map/features/notification/presentation/notification_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({
    this.onBack,
    this.onParticipantsSelected,
    this.onMemorySelected,
    super.key,
  });

  final VoidCallback? onBack;
  final ValueChanged<String>? onParticipantsSelected;
  final void Function(String storyId, String memoryId)? onMemorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxValue = ref.watch(notificationInboxProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider)
            .maybeWhen(data: (value) => value, orElse: () => 0);
    final state = inboxValue.asData?.value;
    final showMarkAll = unreadCount > 0 || (state?.hasUnread ?? false);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F8),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFFF5D72),
          onRefresh: () {
            return ref
                .read(notificationInboxProvider.notifier)
                .refreshNotifications();
          },
          child: CustomScrollView(
            key: const ValueKey('notifications.scrollable'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _NotificationsHeader(
                    showMarkAll: showMarkAll,
                    markAllEnabled: !(state?.isMutating ?? false),
                    onBack: onBack,
                    onMarkAll: () {
                      _markAllRead(context, ref);
                    },
                  ),
                ),
              ),
              ..._contentSlivers(context, ref, inboxValue),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _contentSlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<NotificationInboxState> inboxValue,
  ) {
    final l10n = AppLocalizations.of(context);

    if (inboxValue.isLoading) {
      return const [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _NotificationsLoadingView(),
          ),
        ),
      ];
    }

    if (inboxValue.hasError) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _NotificationsErrorView(
              title: l10n.notificationsLoadFailureTitle,
              message: l10n.notificationFailureUnknown,
              onRetry: () {
                ref.read(notificationInboxProvider.notifier).retryLoad();
              },
            ),
          ),
        ),
      ];
    }

    final state = inboxValue.asData?.value;
    if (state == null) {
      return const [];
    }

    final loadFailure = state.loadFailure;
    if (loadFailure != null) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _NotificationsErrorView(
              title: l10n.notificationsLoadFailureTitle,
              message: notificationFailureMessage(l10n, loadFailure),
              onRetry: () {
                ref.read(notificationInboxProvider.notifier).retryLoad();
              },
            ),
          ),
        ),
      ];
    }

    final slivers = <Widget>[];
    if (state.isRefreshing) {
      slivers.add(
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
          sliver: SliverToBoxAdapter(
            child: LinearProgressIndicator(
              minHeight: 3,
              color: Color(0xFFFF5D72),
              backgroundColor: Color(0xFFFFE6EA),
            ),
          ),
        ),
      );
    }

    final refreshFailure = state.refreshFailure;
    if (refreshFailure != null) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _NotificationsBanner(
              message: notificationFailureMessage(l10n, refreshFailure),
            ),
          ),
        ),
      );
    }

    if (state.notifications.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            child: Center(
              child: _NotificationsEmptyView(
                title: l10n.notificationsEmptyTitle,
                body: l10n.notificationsEmptyBody,
              ),
            ),
          ),
        ),
      );
      return slivers;
    }

    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index.isOdd) {
                return const SizedBox(height: 10);
              }

              final notificationIndex = index ~/ 2;
              final notification = state.notifications[notificationIndex];
              return _NotificationCard(
                notification: notification,
                isMutating: state.isMutating,
                onSelected: () {
                  _selectNotification(context, ref, notification);
                },
              );
            },
            childCount: state.notifications.length * 2 - 1,
          ),
        ),
      ),
    );

    return slivers;
  }

  Future<void> _selectNotification(
    BuildContext context,
    WidgetRef ref,
    NotificationItem notification,
  ) async {
    final success = await ref
        .read(notificationInboxProvider.notifier)
        .markRead(notification.id);
    if (!context.mounted) {
      return;
    }

    if (!success) {
      _showFailure(context);
      return;
    }

    final storyId = notification.story?.storyId;
    final memoryId = notification.memory?.memoryId;
    switch (notification.type) {
      case NotificationType.participantJoined:
        if (storyId != null && storyId.trim().isNotEmpty) {
          onParticipantsSelected?.call(storyId);
        }
        break;
      case NotificationType.memoryCreated:
      case NotificationType.photosAdded:
        if (storyId != null &&
            storyId.trim().isNotEmpty &&
            memoryId != null &&
            memoryId.trim().isNotEmpty) {
          onMemorySelected?.call(storyId, memoryId);
        }
        break;
    }
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    final success =
        await ref.read(notificationInboxProvider.notifier).markAllRead();
    if (!context.mounted) {
      return;
    }

    if (!success) {
      _showFailure(context);
    }
  }

  void _showFailure(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.notificationsMutationFailure),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.showMarkAll,
    required this.markAllEnabled,
    required this.onMarkAll,
    required this.onBack,
  });

  final bool showMarkAll;
  final bool markAllEnabled;
  final VoidCallback? onMarkAll;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        SizedBox.square(
          dimension: 44,
          child: IconButton.filledTonal(
            key: const ValueKey('notifications.back-action'),
            onPressed: onBack,
            tooltip: l10n.notificationsBackLabel,
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF1F2937),
              backgroundColor: Colors.white,
              shadowColor: const Color(0x140F172A),
              elevation: 1,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            l10n.notificationsTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        if (showMarkAll) ...[
          const SizedBox(width: 10),
          TextButton(
            key: const ValueKey('notifications.mark-all-action'),
            onPressed: markAllEnabled ? onMarkAll : null,
            child: Text(
              l10n.notificationsMarkAllReadAction,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isMutating,
    required this.onSelected,
  });

  final NotificationItem notification;
  final bool isMutating;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unread = !notification.read;

    return Material(
      key: ValueKey('notifications.item.${notification.id}'),
      color: unread ? const Color(0xFFFFF7F8) : Colors.white,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isMutating ? null : onSelected,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthUserAvatar(
                key: ValueKey('notifications.item.avatar.${notification.id}'),
                displayName: notification.actor.displayName,
                avatarUrl: notification.actor.avatarUrl,
                radius: 22,
                backgroundColor: const Color(0xFFFFE6EA),
                foregroundColor: const Color(0xFFFF5D72),
                cacheDimension: 96,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _eventText(l10n, notification),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 14.5,
                        height: 1.28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _contextText(l10n, notification),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 13,
                        height: 1.28,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _timestamp(context, notification.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF98A2B3),
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread) ...[
                const SizedBox(width: 10),
                Container(
                  key: ValueKey(
                    'notifications.item.unread-indicator.${notification.id}',
                  ),
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF5D72),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _eventText(
    AppLocalizations l10n,
    NotificationItem notification,
  ) {
    final actor = notification.actor.displayName;
    final memoryTitle = notification.memory?.title?.trim();
    return switch (notification.type) {
      NotificationType.participantJoined =>
        l10n.notificationParticipantJoined(actor),
      NotificationType.memoryCreated => memoryTitle == null ||
              memoryTitle.isEmpty
          ? l10n.notificationMemoryCreated(actor)
          : l10n.notificationMemoryCreatedWithTitle(actor, memoryTitle),
      NotificationType.photosAdded => memoryTitle == null || memoryTitle.isEmpty
          ? l10n.notificationPhotosAdded(actor)
          : l10n.notificationPhotosAddedWithTitle(actor, memoryTitle),
    };
  }

  String _contextText(
    AppLocalizations l10n,
    NotificationItem notification,
  ) {
    final memoryTitle = notification.memory?.title?.trim();
    if (memoryTitle != null && memoryTitle.isNotEmpty) {
      return memoryTitle;
    }

    final storyTitle = notification.story?.title?.trim();
    if (storyTitle != null && storyTitle.isNotEmpty) {
      return storyTitle;
    }

    return l10n.notificationsReferenceUnavailable;
  }

  String _timestamp(BuildContext context, DateTime createdAt) {
    final local = createdAt.toLocal();
    final materialLocalizations = MaterialLocalizations.of(context);
    final date = materialLocalizations.formatShortDate(local);
    final time = materialLocalizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
    );
    return '$date, $time';
  }
}

class _NotificationsLoadingView extends StatelessWidget {
  const _NotificationsLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: CircularProgressIndicator(
          color: Color(0xFFFF5D72),
        ),
      ),
    );
  }
}

class _NotificationsEmptyView extends StatelessWidget {
  const _NotificationsEmptyView({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('notifications.empty-state'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFFFFE6EA),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: Color(0xFFFF5D72),
            size: 30,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 14.5,
            height: 1.35,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _NotificationsErrorView extends StatelessWidget {
  const _NotificationsErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: const ValueKey('notifications.error-view'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD6DC)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF667085),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonal(
            key: const ValueKey('notifications.retry-action'),
            onPressed: onRetry,
            child: Text(l10n.notificationsRetryAction),
          ),
        ],
      ),
    );
  }
}

class _NotificationsBanner extends StatelessWidget {
  const _NotificationsBanner({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('notifications.refresh.failure-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD6DC)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFFF5D72),
          fontSize: 13,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
