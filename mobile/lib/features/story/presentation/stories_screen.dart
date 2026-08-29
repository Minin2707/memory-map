import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/presentation/auth_user_avatar.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/application/stories_state.dart';
import 'package:memory_map/features/story/presentation/story_failure_message.dart';
import 'package:memory_map/features/story/presentation/widgets/stories_empty_state.dart';
import 'package:memory_map/features/story/presentation/widgets/stories_error_view.dart';
import 'package:memory_map/features/story/presentation/widgets/story_card.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({
    required this.displayName,
    this.avatarUrl,
    this.onCreateStory,
    this.onProfileSelected,
    this.onStorySelected,
    super.key,
  });

  final String displayName;
  final String? avatarUrl;
  final VoidCallback? onCreateStory;
  final VoidCallback? onProfileSelected;
  final ValueChanged<String>? onStorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final storiesValue = ref.watch(storiesNotifierProvider);
    final effectiveDisplayName = displayName.trim().isEmpty
        ? l10n.fallbackDisplayName
        : displayName.trim();
    final greetingName = _greetingName(effectiveDisplayName);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F8),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFFFF5D72),
          onRefresh: () {
            return ref
                .read(storiesNotifierProvider.notifier)
                .refreshStories();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: _StoriesHeader(
                    displayName: greetingName,
                    avatarDisplayName: effectiveDisplayName,
                    avatarUrl: avatarUrl,
                    onProfileSelected: onProfileSelected,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 21, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: _StoriesSectionHeader(
                    onCreateStory: onCreateStory,
                  ),
                ),
              ),
              ..._contentSlivers(context, ref, storiesValue),
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
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
          padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
          sliver: SliverToBoxAdapter(child: _StoriesLoadingView()),
        ),
      ];
    }

    if (storiesValue.hasError) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
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
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
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
          padding: EdgeInsets.fromLTRB(24, 14, 24, 0),
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
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
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
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
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
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index.isOdd) {
                return const SizedBox(height: 12);
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

class _StoriesHeader extends StatelessWidget {
  const _StoriesHeader({
    required this.displayName,
    required this.avatarDisplayName,
    required this.avatarUrl,
    required this.onProfileSelected,
  });

  final String displayName;
  final String avatarDisplayName;
  final String? avatarUrl;
  final VoidCallback? onProfileSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shouldStackHeader = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.storiesGreeting(displayName),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 25,
            fontWeight: FontWeight.w800,
            height: 1.13,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.storiesSubtitle,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF667085),
            fontSize: 14.5,
            height: 1.32,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ],
    );
    final trailingControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 44,
          child: IconButton.filledTonal(
            key: const ValueKey('stories.notification.action'),
            onPressed: () {},
            tooltip: l10n.storiesNotificationUnavailableLabel,
            icon: const Icon(
              Icons.notifications_none_rounded,
              size: 21,
            ),
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFF1F2937),
              backgroundColor: Colors.white,
              shadowColor: const Color(0x140F172A),
              elevation: 1,
              padding: EdgeInsets.zero,
            ),
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
            foregroundColor: const Color(0xFFFF5D72),
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
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF1F2937),
        fontSize: 20.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );

    final createAction = FilledButton.tonalIcon(
      key: const ValueKey('stories.create.section-action'),
      onPressed: onCreateStory,
      icon: const Icon(
        Icons.add_rounded,
        size: 20,
      ),
      label: Text(
        l10n.storiesCreateAction,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: FilledButton.styleFrom(
        foregroundColor: const Color(0xFFFF5D72),
        backgroundColor: const Color(0xFFFFF7F8),
        disabledForegroundColor: const Color(0xFFFF5D72),
        disabledBackgroundColor: const Color(0xFFFFF7F8),
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFFFD6DC)),
        ),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          letterSpacing: 0,
        ),
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
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 166),
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
        color: const Color(0xFFFFF7F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD6DC)),
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
        height: 124,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              offset: Offset(0, 8),
              blurRadius: 20,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: const Color(0xFFECEFF3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        width: 70,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F3F5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 180,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECEFF3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 140,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const Spacer(),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Row(
                          children: [
                            Flexible(
                              flex: 6,
                              child: _SkeletonLine(
                                width: constraints.maxWidth * 0.46,
                                height: 14,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              flex: 5,
                              child: _SkeletonLine(
                                width: constraints.maxWidth * 0.38,
                                height: 14,
                              ),
                            ),
                          ],
                        );
                      },
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

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
