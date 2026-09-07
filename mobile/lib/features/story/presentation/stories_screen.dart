import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/presentation/auth_user_avatar.dart';
import 'package:memory_map/features/notification/application/unread_notification_count_notifier.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/application/stories_state.dart';
import 'package:memory_map/features/story/presentation/story_failure_message.dart';
import 'package:memory_map/features/story/presentation/widgets/stories_empty_state.dart';
import 'package:memory_map/features/story/presentation/widgets/stories_error_view.dart';
import 'package:memory_map/features/story/presentation/widgets/story_card.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const _storiesBackground = Color(0xFFFBF6F1);
const _storiesInk = Color(0xFF182331);
const _storiesMuted = Color(0xFF747B86);
const _storiesAccent = Color(0xFFE05D6E);
const _storiesAccentSoft = Color(0xFFFFEEF0);
const _storiesBorder = Color(0x1FEA6D7A);
const _storiesCreateAccent = Color(0xFFC45A66);
const _storiesDisplayFontFamily = 'NotoSerif';
const _storiesHorizontalPadding = 24.0;
const _storiesHeaderSecondaryStyle = TextStyle(
  color: _storiesMuted,
  fontSize: 14,
  fontWeight: FontWeight.w500,
  height: 1.18,
  letterSpacing: 0,
);
const _storiesSectionTitleStyle = TextStyle(
  color: Color(0xFF1F2937),
  fontFamily: _storiesDisplayFontFamily,
  fontFamilyFallback: <String>['NotoSerifGeorgian'],
  fontSize: 26.5,
  height: 1.08,
  fontWeight: FontWeight.w500,
  letterSpacing: 0,
);

class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({
    required this.displayName,
    this.avatarUrl,
    this.onCreateStory,
    this.onNotificationsSelected,
    this.onProfileSelected,
    this.onStorySelected,
    super.key,
  });

  final String displayName;
  final String? avatarUrl;
  final VoidCallback? onCreateStory;
  final VoidCallback? onNotificationsSelected;
  final VoidCallback? onProfileSelected;
  final ValueChanged<String>? onStorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final storiesValue = ref.watch(storiesNotifierProvider);
    final unreadNotificationCount = ref
        .watch(unreadNotificationCountProvider)
        .maybeWhen(data: (value) => value, orElse: () => 0);
    final effectiveDisplayName = displayName.trim().isEmpty
        ? l10n.fallbackDisplayName
        : displayName.trim();
    final greetingName = _greetingName(effectiveDisplayName);
    final daypartGreeting = _daypartGreeting(l10n, DateTime.now().hour);
    final isTrueEmptyState = storiesValue.maybeWhen(
      data: (state) => state.loadFailure == null && state.stories.isEmpty,
      orElse: () => false,
    );

    return Scaffold(
      backgroundColor: _storiesBackground,
      body: SafeArea(
        child: RefreshIndicator(
          color: _storiesAccent,
          onRefresh: () {
            return ref
                .read(storiesNotifierProvider.notifier)
                .refreshStories();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  _storiesHorizontalPadding,
                  24,
                  _storiesHorizontalPadding,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _StoriesHeader(
                    greeting: daypartGreeting,
                    displayName: greetingName,
                    avatarDisplayName: effectiveDisplayName,
                    avatarUrl: avatarUrl,
                    unreadNotificationCount: unreadNotificationCount,
                    onNotificationsSelected: onNotificationsSelected,
                    onProfileSelected: onProfileSelected,
                  ),
                ),
              ),
              if (!isTrueEmptyState)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    _storiesHorizontalPadding,
                    26,
                    _storiesHorizontalPadding,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _StoriesSectionHeader(
                      onCreateStory: onCreateStory,
                    ),
                  ),
                ),
              ..._contentSlivers(context, ref, storiesValue),
              if (!isTrueEmptyState)
                const SliverToBoxAdapter(
                  child: SizedBox(height: 36),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _contentSlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<StoriesState> storiesValue,
  ) {
    final l10n = AppLocalizations.of(context);

    if (storiesValue.isLoading) {
      return const [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            _storiesHorizontalPadding,
            24,
            _storiesHorizontalPadding,
            0,
          ),
          sliver: SliverToBoxAdapter(child: _StoriesLoadingView()),
        ),
      ];
    }

    if (storiesValue.hasError) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            _storiesHorizontalPadding,
            24,
            _storiesHorizontalPadding,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: StoriesErrorView(
              title: l10n.unexpectedErrorTitle,
              message: l10n.storyFailureUnknown,
              onRetry: () {
                ref.read(storiesNotifierProvider.notifier).retryLoad();
              },
            ),
          ),
        ),
      ];
    }

    final state = storiesValue.asData?.value;
    if (state == null) {
      return const [];
    }

    final loadFailure = state.loadFailure;
    if (loadFailure != null) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            _storiesHorizontalPadding,
            24,
            _storiesHorizontalPadding,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: StoriesErrorView(
              title: l10n.storiesLoadFailureTitle,
              message: storyFailureMessage(l10n, loadFailure),
              onRetry: () {
                ref.read(storiesNotifierProvider.notifier).retryLoad();
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
          padding: EdgeInsets.fromLTRB(
            _storiesHorizontalPadding,
            22,
            _storiesHorizontalPadding,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: LinearProgressIndicator(
              minHeight: 3,
              color: _storiesAccent,
              backgroundColor: _storiesAccentSoft,
            ),
          ),
        ),
      );
    }

    final refreshFailure = state.refreshFailure;
    if (refreshFailure != null) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            _storiesHorizontalPadding,
            22,
            _storiesHorizontalPadding,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: _RefreshFailureBanner(
              message: storyFailureMessage(l10n, refreshFailure),
              onRetry: () {
                ref.read(storiesNotifierProvider.notifier).refreshStories();
              },
            ),
          ),
        ),
      );
    }

    if (state.stories.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            child: Center(
              child: StoriesEmptyState(onCreateStory: onCreateStory),
            ),
          ),
        ),
      );

      return slivers;
    }

    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          _storiesHorizontalPadding,
          24,
          _storiesHorizontalPadding,
          0,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index.isOdd) {
                return const SizedBox(height: 24);
              }

              final storyIndex = index ~/ 2;
              return StoryCard(
                userStory: state.stories[storyIndex],
                onSelected: onStorySelected,
              );
            },
            childCount: state.stories.length * 2 - 1,
          ),
        ),
      ),
    );

    return slivers;
  }
}

String _greetingName(String displayName) {
  final trimmed = displayName.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }

  return trimmed.split(RegExp(r'\s+')).first;
}

String _daypartGreeting(AppLocalizations l10n, int hour) {
  if (hour >= 5 && hour < 12) {
    return l10n.storiesGreetingMorning;
  }

  if (hour >= 12 && hour < 18) {
    return l10n.storiesGreetingAfternoon;
  }

  return l10n.storiesGreetingEvening;
}

class _StoriesHeader extends StatelessWidget {
  const _StoriesHeader({
    required this.greeting,
    required this.displayName,
    required this.avatarDisplayName,
    required this.avatarUrl,
    required this.unreadNotificationCount,
    required this.onNotificationsSelected,
    required this.onProfileSelected,
  });

  final String greeting;
  final String displayName;
  final String avatarDisplayName;
  final String? avatarUrl;
  final int unreadNotificationCount;
  final VoidCallback? onNotificationsSelected;
  final VoidCallback? onProfileSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shouldStackHeader = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _storiesHeaderSecondaryStyle,
        ),
        const SizedBox(height: 5),
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _storiesHeaderSecondaryStyle,
        ),
      ],
    );
    final trailingControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 44,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IconButton(
                  key: const ValueKey('stories.notification.action'),
                  onPressed: onNotificationsSelected,
                  tooltip: l10n.storiesOpenNotificationsLabel,
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    size: 21,
                  ),
                  style: IconButton.styleFrom(
                    foregroundColor: _storiesInk,
                    backgroundColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              if (unreadNotificationCount > 0)
                const Positioned(
                  key: ValueKey('stories.notification.badge'),
                  right: 6,
                  top: 6,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFFF5D72),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(dimension: 9),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StoriesAvatar(
          displayName: avatarDisplayName,
          avatarUrl: avatarUrl,
          onSelected: onProfileSelected,
        ),
      ],
    );

    if (shouldStackHeader) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: trailingControls,
          ),
          const SizedBox(height: 16),
          textColumn,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: textColumn),
        const SizedBox(width: 14),
        trailingControls,
      ],
    );
  }
}

class _StoriesAvatar extends StatelessWidget {
  const _StoriesAvatar({
    required this.displayName,
    required this.avatarUrl,
    required this.onSelected,
  });

  final String displayName;
  final String? avatarUrl;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      label: l10n.storiesOpenProfileLabel(displayName),
      button: true,
      image: true,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('stories.header.profile-action'),
          customBorder: const CircleBorder(),
          onTap: onSelected,
          child: AuthUserAvatar(
            key: const ValueKey('stories.header.avatar'),
            displayName: displayName,
            avatarUrl: avatarUrl,
            radius: 26,
            backgroundColor: const Color(0xFFFFE6EA),
            foregroundColor: _storiesAccent,
            cacheDimension: 128,
          ),
        ),
      ),
    );
  }
}

class _StoriesSectionHeader extends StatelessWidget {
  const _StoriesSectionHeader({
    required this.onCreateStory,
  });

  final VoidCallback? onCreateStory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final shouldStackAction = textScaler.scale(1) > 1.2;

    final title = Text(
      l10n.storiesSectionTitle,
      maxLines: 1,
      softWrap: false,
      style: _storiesSectionTitleStyle,
    );

    final createAction = TextButton(
      key: const ValueKey('stories.create.section-action'),
      onPressed: onCreateStory,
      style: TextButton.styleFrom(
        foregroundColor: _storiesCreateAccent,
        disabledForegroundColor: _storiesCreateAccent.withValues(alpha: 0.46),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          letterSpacing: 0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              l10n.storiesCreateAction,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          const Icon(
            Icons.add_rounded,
            size: 17,
          ),
        ],
      ),
    );

    if (shouldStackAction) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 12),
          createAction,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: title),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 154),
          child: createAction,
        ),
      ],
    );
  }
}

class _RefreshFailureBanner extends StatelessWidget {
  const _RefreshFailureBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: const ValueKey('stories.refresh.failure-banner'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _storiesBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFFF5D72),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${l10n.storiesRefreshFailureTitle}. $message',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('stories.refresh.retry-action'),
            onPressed: onRetry,
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

class _StoriesLoadingView extends StatelessWidget {
  const _StoriesLoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('stories.loading.view'),
      children: const [
        _SkeletonCard(widthFactor: 1.0),
        SizedBox(height: 14),
        _SkeletonCard(widthFactor: 0.94),
        SizedBox(height: 14),
        _SkeletonCard(widthFactor: 0.88),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    required this.widthFactor,
  });

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 236,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDFB),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F4D2B32),
              offset: Offset(0, 14),
              blurRadius: 28,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFECE8),
                        Color(0xFFF3E8DF),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 104,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00FFFFFF),
                        Color(0x55FFFFFF),
                        Color(0xBFFFFFFF),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 22,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 150,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 214,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.54),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
