import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/application/story_details_state.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/features/story/presentation/story_failure_message.dart';
import 'package:memory_map/features/story/presentation/widgets/story_role_badge.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class StoryDetailsScreen extends ConsumerWidget {
  const StoryDetailsScreen({
    required this.storyId,
    this.onBack,
    this.onEditStory,
    this.onInvite,
    this.onMemoriesSelected,
    this.onParticipantsSelected,
    this.onMapSelected,
    this.onTimelineSelected,
    super.key,
  });

  final String storyId;
  final VoidCallback? onBack;
  final ValueChanged<UserStory>? onEditStory;
  final VoidCallback? onInvite;
  final ValueChanged<UserStory>? onMemoriesSelected;
  final ValueChanged<UserStory>? onParticipantsSelected;
  final ValueChanged<UserStory>? onMapSelected;
  final ValueChanged<UserStory>? onTimelineSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsValue = ref.watch(storyDetailsProvider(storyId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          onBack?.call();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: RefreshIndicator(
            color: const Color(0xFFFF5D72),
            onRefresh: () {
              return ref
                  .read(storyDetailsProvider(storyId).notifier)
                  .refreshStory();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  sliver: SliverToBoxAdapter(
                    child: _StoryDetailsAppBar(onBack: onBack),
                  ),
                ),
                ..._contentSlivers(context, ref, detailsValue),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _contentSlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<StoryDetailsState> detailsValue,
  ) {
    final l10n = AppLocalizations.of(context);

    if (detailsValue.isLoading) {
      return const [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
          sliver: SliverToBoxAdapter(child: _StoryDetailsLoadingView()),
        ),
      ];
    }

    if (detailsValue.hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Center(
              child: _StoryDetailsErrorView(
                title: l10n.unexpectedErrorTitle,
                message: l10n.storyFailureUnknown,
                onRetry: () {
                  ref
                      .read(storyDetailsProvider(storyId).notifier)
                      .retryLoad();
                },
              ),
            ),
          ),
        ),
      ];
    }

    final state = detailsValue.asData?.value;
    if (state == null) {
      return const [];
    }

    final loadFailure = state.loadFailure;
    if (loadFailure != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Center(
              child: _StoryDetailsErrorView(
                title: l10n.storyDetailsLoadFailureTitle,
                message: storyFailureMessage(l10n, loadFailure),
                onRetry: () {
                  ref
                      .read(storyDetailsProvider(storyId).notifier)
                      .retryLoad();
                },
              ),
            ),
          ),
        ),
      ];
    }

    final userStory = state.userStory;
    if (userStory == null) {
      return const [];
    }
    return [
      if (state.isRefreshing)
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverToBoxAdapter(
            child: LinearProgressIndicator(
              minHeight: 3,
              color: Color(0xFFFF5D72),
              backgroundColor: Color(0xFFFFE6EA),
            ),
          ),
        ),
      if (state.refreshFailure != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverToBoxAdapter(
            child: _RefreshFailureBanner(
              message: storyFailureMessage(l10n, state.refreshFailure!),
              onRetry: () {
                ref
                    .read(storyDetailsProvider(storyId).notifier)
                    .refreshStory();
              },
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        sliver: SliverToBoxAdapter(
          child: _StoryHero(
            userStory: userStory,
            onInvite: userStory.canUpdateStoryMetadata ? onInvite : null,
            onEditStory: userStory.canUpdateStoryMetadata
                ? onEditStory
                : null,
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        sliver: SliverToBoxAdapter(
          child: _DescriptionCard(story: userStory.story),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        sliver: SliverToBoxAdapter(
          child: _InfoCard(story: userStory.story),
        ),
      ),
      if (_hasFutureSections)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverToBoxAdapter(
            child: _FutureSectionsCard(
              userStory: userStory,
              onMemoriesSelected: onMemoriesSelected,
              onParticipantsSelected: onParticipantsSelected,
              onMapSelected: onMapSelected,
              onTimelineSelected: onTimelineSelected,
            ),
          ),
        ),
    ];
  }

  bool get _hasFutureSections {
    return onMemoriesSelected != null ||
        onParticipantsSelected != null ||
        onMapSelected != null ||
        onTimelineSelected != null;
  }
}

class _StoryDetailsAppBar extends StatelessWidget {
  const _StoryDetailsAppBar({
    required this.onBack,
  });

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        IconButton(
          key: const ValueKey('story-details.back-action'),
          onPressed: onBack,
          tooltip: l10n.storyDetailsBackLabel,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        Expanded(
          child: Text(
            l10n.storyDetailsPageTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _StoryHero extends StatelessWidget {
  const _StoryHero({
    required this.userStory,
    required this.onInvite,
    required this.onEditStory,
  });

  final UserStory userStory;
  final VoidCallback? onInvite;
  final ValueChanged<UserStory>? onEditStory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final story = userStory.story;
    final description = _visibleDescription(story);

    return Container(
      key: const ValueKey('story-details.hero'),
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF8A99),
            Color(0xFFFF5D72),
            Color(0xFF4F8F86),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24FF5D72),
            offset: Offset(0, 14),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: StoryRoleBadge(role: userStory.role)),
              if (onInvite != null) ...[
                Semantics(
                  label: l10n.invitePageTitle,
                  button: true,
                  child: IconButton.filled(
                    key: const ValueKey('story-details.invite-action'),
                    onPressed: onInvite,
                    tooltip: l10n.invitePageTitle,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFFF5D72),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (onEditStory != null)
                IconButton.filled(
                  key: const ValueKey('story-details.edit-action'),
                  onPressed: () {
                    onEditStory!(userStory);
                  },
                  tooltip: l10n.storyDetailsEditAction,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFFF5D72),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                ),
            ],
          ),
          const SizedBox(height: 34),
          ExcludeSemantics(
            child: Text(
              _initials(story.title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 50,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            story.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              height: 1.12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 12),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xF2FFFFFF),
                fontSize: 18,
                height: 1.4,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({
    required this.story,
  });

  final Story story;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final description = _visibleDescription(story);

    return _DetailsCard(
      key: const ValueKey('story-details.description-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.notes_rounded,
            title: l10n.storyDetailsDescriptionTitle,
          ),
          const SizedBox(height: 14),
          Text(
            description ?? l10n.storyDetailsNoDescription,
            style: TextStyle(
              color: description == null
                  ? const Color(0xFF8A93A3)
                  : const Color(0xFF4B5563),
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.story,
  });

  final Story story;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _DetailsCard(
      key: const ValueKey('story-details.info-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.info_outline_rounded,
            title: l10n.storyDetailsInfoTitle,
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.calendar_today_rounded,
            label: l10n.storyDetailsCreatedLabel,
            value: _formatDate(context, story.createdAt),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.update_rounded,
            label: l10n.storyDetailsUpdatedLabel,
            value: _formatDate(context, story.updatedAt),
          ),
        ],
      ),
    );
  }
}

class _FutureSectionsCard extends StatelessWidget {
  const _FutureSectionsCard({
    required this.userStory,
    required this.onMemoriesSelected,
    required this.onParticipantsSelected,
    required this.onMapSelected,
    required this.onTimelineSelected,
  });

  final UserStory userStory;
  final ValueChanged<UserStory>? onMemoriesSelected;
  final ValueChanged<UserStory>? onParticipantsSelected;
  final ValueChanged<UserStory>? onMapSelected;
  final ValueChanged<UserStory>? onTimelineSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = <Widget>[
      if (onMemoriesSelected != null)
        _SectionAction(
          actionKey: const ValueKey('story-details.memories-action'),
          icon: Icons.list_alt_rounded,
          label: l10n.storyDetailsMemoriesAction,
          onPressed: () {
            onMemoriesSelected!(userStory);
          },
        ),
      if (onParticipantsSelected != null)
        _SectionAction(
          actionKey: const ValueKey('story-details.participants-action'),
          icon: Icons.group_rounded,
          label: l10n.storyDetailsParticipantsAction,
          onPressed: () {
            onParticipantsSelected!(userStory);
          },
        ),
      if (onMapSelected != null)
        _SectionAction(
          actionKey: const ValueKey('story-details.map-action'),
          icon: Icons.map_rounded,
          label: l10n.storyDetailsMapAction,
          onPressed: () {
            onMapSelected!(userStory);
          },
        ),
      if (onTimelineSelected != null)
        _SectionAction(
          actionKey: const ValueKey('story-details.timeline-action'),
          icon: Icons.timeline_rounded,
          label: l10n.storyDetailsTimelineAction,
          onPressed: () {
            onTimelineSelected!(userStory);
          },
        ),
    ];

    return _DetailsCard(
      key: const ValueKey('story-details.future-sections-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.explore_rounded,
            title: l10n.storyDetailsSectionsTitle,
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < sections.length; index += 1) ...[
            if (index > 0) const SizedBox(height: 10),
            sections[index],
          ],
        ],
      ),
    );
  }
}

class _SectionAction extends StatelessWidget {
  const _SectionAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: actionKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1F2937),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        minimumSize: const Size.fromHeight(54),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF5D72)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF8A93A3)),
        ],
      ),
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

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('story-details.refresh.failure-banner'),
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
                '${l10n.storyDetailsRefreshFailureTitle}. $message',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('story-details.refresh.retry-action'),
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryDetailsErrorView extends StatelessWidget {
  const _StoryDetailsErrorView({
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

    return _DetailsCard(
      key: const ValueKey('story-details.error-view'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE6EA),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFFFF5D72),
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            key: const ValueKey('story-details.error.retry-action'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

class _StoryDetailsLoadingView extends StatelessWidget {
  const _StoryDetailsLoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('story-details.loading-view'),
      children: const [
        _SkeletonBlock(height: 250, radius: 30),
        SizedBox(height: 18),
        _SkeletonBlock(height: 132, radius: 24),
        SizedBox(height: 18),
        _SkeletonBlock(height: 146, radius: 24),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.height,
    required this.radius,
  });

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            offset: Offset(0, 10),
            blurRadius: 24,
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            offset: Offset(0, 12),
            blurRadius: 28,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF5D72)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF8A93A3)),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String? _visibleDescription(Story story) {
  final description = story.description;
  if (description == null || description.trim().isEmpty) {
    return null;
  }

  return description;
}

String _initials(String title) {
  final words = title
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  if (words.isEmpty) {
    return '?';
  }

  return words.take(2).map((word) => word.substring(0, 1)).join();
}

String _formatDate(BuildContext context, DateTime value) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMd(locale).format(value.toLocal());
}
