import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/common/presentation/widgets/glass_circle_icon_button.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
import 'package:memory_map/features/memory/application/story_details_memory_projection.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_state.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/presentation/memory_date_format.dart';
import 'package:memory_map/features/memory/presentation/memory_failure_message.dart';
import 'package:memory_map/features/music/presentation/story_soundtrack_summary_card.dart';
import 'package:memory_map/features/participant/application/participants_notifier.dart';
import 'package:memory_map/features/participant/application/participants_state.dart';
import 'package:memory_map/features/participant/domain/participant_failure.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/participant/presentation/participant_failure_message.dart';
import 'package:memory_map/features/story/application/delete_story_notifier.dart';
import 'package:memory_map/features/story/application/delete_story_state.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/application/story_details_state.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/features/story/presentation/story_failure_message.dart';
import 'package:memory_map/features/story/presentation/widgets/story_role_badge.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const _storyHubBackground = Color(0xFFFBF6F1);
const _storyHubInk = Color(0xFF182331);
const _storyHubMuted = Color(0xFF747B86);
const _storyHubAccent = Color(0xFFD16A74);
const _storyHubAccentSoft = Color(0xFFFFEEF0);
const _storyHubWarmWhite = Color(0xFFFFFDFB);
const _storyHubWarmBorder = Color(0xFFEFE5E1);
const _storyHubDisplayFontFamily = 'NotoSerif';
const _storyHubDisplayFontFallback = <String>['NotoSerifGeorgian'];

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
    this.onSoundtrackSelected,
    this.onCreateMemory,
    this.onMemorySelected,
    this.onPlaybackSelected,
    this.onStoryDeleted,
    super.key,
  });

  final String storyId;
  final VoidCallback? onBack;
  final ValueChanged<UserStory>? onEditStory;
  final ValueChanged<StoryRole>? onInvite;
  final ValueChanged<UserStory>? onMemoriesSelected;
  final ValueChanged<UserStory>? onParticipantsSelected;
  final ValueChanged<UserStory>? onMapSelected;
  final ValueChanged<UserStory>? onTimelineSelected;
  final ValueChanged<UserStory>? onSoundtrackSelected;
  final VoidCallback? onCreateMemory;
  final ValueChanged<Memory>? onMemorySelected;
  final ValueChanged<UserStory>? onPlaybackSelected;
  final ValueChanged<UserStory>? onStoryDeleted;

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
        backgroundColor: _storyHubBackground,
        body: RefreshIndicator(
          color: _storyHubAccent,
          onRefresh: () {
            return ref
                .read(storyDetailsProvider(storyId).notifier)
                .refreshStory();
          },
          child: CustomScrollView(
            key: const ValueKey('story-details.screen'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              ..._contentSlivers(context, ref, detailsValue),
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
                onBack: onBack,
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
                onBack: onBack,
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
    final canDeleteStory =
        onStoryDeleted != null && userStory.role.canDeleteStory;
    final deleteValue = canDeleteStory
        ? ref.watch(deleteStoryProvider(storyId))
        : const AsyncData<DeleteStoryState>(DeleteStoryState());
    final deleteState = deleteValue.asData?.value ?? const DeleteStoryState();

    return [
      if (state.isRefreshing)
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverToBoxAdapter(
            child: LinearProgressIndicator(
              minHeight: 3,
              color: _storyHubAccent,
              backgroundColor: _storyHubAccentSoft,
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
        padding: EdgeInsets.zero,
        sliver: SliverToBoxAdapter(
          child: _StoryHeroSection(
            storyId: storyId,
            userStory: userStory,
            onBack: onBack,
            onInvite: onInvite != null && userStory.canUpdateStoryMetadata
                ? () {
                    onInvite!(userStory.role);
                  }
                : null,
            onEditStory: userStory.canUpdateStoryMetadata
                ? onEditStory
                : null,
            onDeleteStory: canDeleteStory
                ? () {
                    _confirmDeleteStory(context, ref, userStory);
                  }
                : null,
            deleteEnabled: !deleteState.isDeleting,
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        sliver: SliverToBoxAdapter(
          child: _ParticipantsSummarySection(
            storyId: storyId,
            userStory: userStory,
            onOpenParticipants: onParticipantsSelected,
            canManageParticipants: userStory.canUpdateStoryMetadata,
            onInvite: onInvite != null && userStory.canUpdateStoryMetadata
                ? () {
                    onInvite!(userStory.role);
                  }
                : null,
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        sliver: SliverToBoxAdapter(
          child: StorySoundtrackSummaryCard(
            storyId: storyId,
            editable: _canEditSoundtrack(userStory),
            onSelected: onSoundtrackSelected == null
                ? null
                : () {
                    onSoundtrackSelected!(userStory);
                  },
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        sliver: SliverToBoxAdapter(
          child: _StoryLowerCompositionSection(
            storyId: storyId,
            userStory: userStory,
            onMemoriesSelected: onMemoriesSelected,
            onMapSelected: onMapSelected,
            onTimelineSelected: onTimelineSelected,
            onCreateMemory: _canCreateMemory(userStory) ? onCreateMemory : null,
            onMemorySelected: onMemorySelected,
            onPlaybackSelected: onPlaybackSelected,
          ),
        ),
      ),
    ];
  }

  Future<void> _confirmDeleteStory(
    BuildContext context,
    WidgetRef ref,
    UserStory userStory,
  ) async {
    final provider = deleteStoryProvider(storyId);
    if (_isDeleting(ref.read(provider))) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);

        return AlertDialog(
          title: Text(l10n.deleteStoryDialogTitle),
          content: Text(l10n.deleteStoryDialogBody),
          actions: [
            TextButton(
              key: const ValueKey('story-details.delete.cancel-action'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(l10n.deleteStoryCancel),
            ),
            FilledButton(
              key: const ValueKey('story-details.delete.confirm-action'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _storyHubAccent,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.deleteStoryConfirm),
            ),
          ],
        );
      },
    );

    if (!context.mounted ||
        confirmed != true ||
        _isDeleting(ref.read(provider))) {
      return;
    }

    final notifier = ref.read(provider.notifier);
    if (ref.read(provider).hasError) {
      notifier.reset();
    }

    final success = await notifier.deleteStory();
    if (!context.mounted) {
      return;
    }

    if (success) {
      onStoryDeleted?.call(userStory);
      return;
    }

    final l10n = AppLocalizations.of(context);
    final message = _deleteFailureMessage(l10n, ref.read(provider));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('story-details.delete.failure-snackbar'),
          content: Text(message),
        ),
      );
  }

  bool _isDeleting(AsyncValue<DeleteStoryState> value) {
    return value.asData?.value.isDeleting ?? false;
  }

  String _deleteFailureMessage(
    AppLocalizations l10n,
    AsyncValue<DeleteStoryState> deleteValue,
  ) {
    if (deleteValue.hasError) {
      return l10n.storyFailureUnknown;
    }

    final failure = deleteValue.asData?.value.deleteFailure;
    if (failure == null) {
      return l10n.storyFailureUnknown;
    }

    return storyFailureMessage(l10n, failure);
  }
}

class _StoryHeroSection extends ConsumerWidget {
  const _StoryHeroSection({
    required this.storyId,
    required this.userStory,
    required this.onBack,
    required this.onInvite,
    required this.onEditStory,
    required this.onDeleteStory,
    required this.deleteEnabled,
  });

  final String storyId;
  final UserStory userStory;
  final VoidCallback? onBack;
  final VoidCallback? onInvite;
  final ValueChanged<UserStory>? onEditStory;
  final VoidCallback? onDeleteStory;
  final bool deleteEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodValue = ref.watch(storyDetailsMemoryPeriodProvider(storyId));
    final periodLabel = _storyPeriodLabel(
      context,
      periodValue.asData?.value,
      DateTime.now().year,
    );

    return _StoryHero(
      userStory: userStory,
      periodLabel: periodLabel,
      onBack: onBack,
      onInvite: onInvite,
      onEditStory: onEditStory,
      onDeleteStory: onDeleteStory,
      deleteEnabled: deleteEnabled,
    );
  }
}

class _StoryHero extends StatelessWidget {
  const _StoryHero({
    required this.userStory,
    required this.periodLabel,
    required this.onBack,
    required this.onInvite,
    required this.onEditStory,
    required this.onDeleteStory,
    required this.deleteEnabled,
  });

  final UserStory userStory;
  final String? periodLabel;
  final VoidCallback? onBack;
  final VoidCallback? onInvite;
  final ValueChanged<UserStory>? onEditStory;
  final VoidCallback? onDeleteStory;
  final bool deleteEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final story = userStory.story;
    final description = _visibleDescription(story);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1.0);
        final accessibilityHeight =
            textScale <= 1 ? 0.0 : ((textScale - 1) * 250).clamp(0.0, 180.0);
        final heroHeight =
            (constraints.maxWidth * 0.92 + accessibilityHeight)
                .clamp(340.0, 620.0);

        return Container(
          key: const ValueKey('story-details.hero'),
          height: heroHeight,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: _storyHubInk,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _HeroBackground(userStory: userStory),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x660F172A),
                      Color(0x050F172A),
                      Color(0xC90F172A),
                    ],
                    stops: [0, 0.42, 1],
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 150,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x00FBF6F1),
                        Color(0x66FBF6F1),
                        _storyHubBackground,
                      ],
                      stops: [0, 0.58, 1],
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GlassCircleIconButton.icon(
                            key: const ValueKey('story-details.back-action'),
                            tooltip: l10n.storyDetailsBackLabel,
                            icon: Icons.arrow_back_ios_new_rounded,
                            foregroundColor: Colors.white,
                            onPressed: onBack,
                          ),
                          const Spacer(),
                          if (onInvite != null) ...[
                            GlassCircleIconButton.icon(
                              key: const ValueKey(
                                'story-details.invite-action',
                              ),
                              tooltip: l10n.invitePageTitle,
                              icon: Icons.person_add_alt_1_rounded,
                              foregroundColor: Colors.white,
                              onPressed: onInvite,
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (onEditStory != null)
                            GlassCircleIconButton.icon(
                              key: const ValueKey(
                                'story-details.edit-action',
                              ),
                              tooltip: l10n.storyDetailsEditAction,
                              icon: Icons.edit_rounded,
                              foregroundColor: Colors.white,
                              onPressed: () {
                                onEditStory!(userStory);
                              },
                            ),
                          if (onDeleteStory != null) ...[
                            const SizedBox(width: 10),
                            GlassCircleIconButton(
                              key: const ValueKey(
                                'story-details.delete-action',
                              ),
                              tooltip: l10n.deleteStoryAction,
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 22,
                                color: deleteEnabled ? _storyHubAccent : null,
                              ),
                              foregroundColor: Colors.white,
                              onPressed: deleteEnabled ? onDeleteStory : null,
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      Text(
                        story.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          height: 1.08,
                          fontWeight: FontWeight.w700,
                          fontFamily: _storyHubDisplayFontFamily,
                          fontFamilyFallback: _storyHubDisplayFontFallback,
                          letterSpacing: 0,
                          shadows: [
                            Shadow(
                              color: Color(0x99000000),
                              offset: Offset(0, 2),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xF2FFFFFF),
                            fontSize: 18,
                            height: 1.32,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _HeroMetadataRow(
                        userStory: userStory,
                        periodLabel: periodLabel,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroBackground extends StatelessWidget {
  const _HeroBackground({
    required this.userStory,
  });

  final UserStory userStory;

  @override
  Widget build(BuildContext context) {
    final preview = userStory.previewPhoto;
    final fallback = _HeroFallback(userStory: userStory);

    if (preview == null) {
      return fallback;
    }

    return Semantics(
      image: true,
      label: AppLocalizations.of(context).storyThumbnailLabel,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final decodeSize = authenticatedMediaDisplayDecodeSize(
              logicalSize: constraints.biggest,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            );
            return AuthenticatedMediaPathImage(
              key: ValueKey(
                'story-details.hero-display.${preview.displayPath}',
              ),
              thumbnailPath: preview.displayPath,
              representation: AuthenticatedMediaRepresentation.display,
              fit: BoxFit.cover,
              cacheWidth: decodeSize.cacheWidth,
              cacheHeight: decodeSize.cacheHeight,
              placeholder: fallback,
              errorBuilder: (_) => _HeroDisplayFailureFallback(
                userStory: userStory,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback({
    required this.userStory,
  });

  final UserStory userStory;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('story-details.hero.no-photo'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8A0A0),
            _storyHubAccent,
            Color(0xFF587D74),
          ],
        ),
      ),
      child: Align(
        alignment: Alignment.center,
        child: ExcludeSemantics(
          child: Text(
            _initials(userStory.story.title),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0x33FFFFFF),
              fontSize: 112,
              height: 1,
              fontWeight: FontWeight.w700,
              fontFamily: _storyHubDisplayFontFamily,
              fontFamilyFallback: _storyHubDisplayFontFallback,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroDisplayFailureFallback extends StatelessWidget {
  const _HeroDisplayFailureFallback({
    required this.userStory,
  });

  final UserStory userStory;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: const ValueKey('story-details.hero.display-failure'),
      fit: StackFit.expand,
      children: [
        _HeroFallback(userStory: userStory),
        const Align(
          alignment: Alignment.center,
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Color(0x55FFFFFF),
            size: 46,
          ),
        ),
      ],
    );
  }
}

class _HeroMetadataRow extends StatelessWidget {
  const _HeroMetadataRow({
    required this.userStory,
    required this.periodLabel,
  });

  final UserStory userStory;
  final String? periodLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pills = <Widget>[
      _HeroMetadataPill(
        icon: Icons.location_on_outlined,
        label: l10n.storyMemoryCount(userStory.memoryCount),
      ),
      _HeroMetadataPill(
        icon: Icons.group_outlined,
        label: l10n.storyParticipantCount(userStory.participantCount),
      ),
      if (periodLabel != null)
        _HeroMetadataPill(
          icon: Icons.calendar_month_outlined,
          label: periodLabel!,
        ),
    ];

    return Wrap(
      key: const ValueKey('story-details.hero.metadata'),
      spacing: 10,
      runSpacing: 10,
      children: pills,
    );
  }
}

class _HeroMetadataPill extends StatelessWidget {
  const _HeroMetadataPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(20);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 210),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _storyHubInk.withValues(alpha: 0.24),
                _storyHubInk.withValues(alpha: 0.10),
              ],
            ),
            border: Border.all(
              color: _storyHubWarmWhite.withValues(alpha: 0.16),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _storyHubWarmWhite, size: 17),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _storyHubWarmWhite,
                    fontSize: 14,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantsSummaryCard extends StatelessWidget {
  const _ParticipantsSummaryCard({
    required this.participantsValue,
    required this.onOpenParticipants,
    required this.canManageParticipants,
    required this.onInvite,
    required this.onRetry,
  });

  static const int _previewLimit = 3;

  final AsyncValue<ParticipantsState> participantsValue;
  final VoidCallback? onOpenParticipants;
  final bool canManageParticipants;
  final VoidCallback? onInvite;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _DetailsCard(
      key: const ValueKey('story-details.participants-summary'),
      borderColor: _storyHubWarmBorder.withValues(alpha: 0.42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.storyDetailsParticipantsAction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _storyHubInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    fontFamily: _storyHubDisplayFontFamily,
                    fontFamilyFallback: _storyHubDisplayFontFallback,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (onOpenParticipants != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 148),
                  child: TextButton(
                    key: ValueKey(
                      canManageParticipants
                          ? 'story-details.participants.manage-action'
                          : 'story-details.participants.view-action',
                    ),
                    onPressed: onOpenParticipants,
                    style: TextButton.styleFrom(
                      foregroundColor: _storyHubAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            canManageParticipants
                                ? l10n.storyDetailsParticipantsManageAction
                                : l10n.storyDetailsSeeAllAction,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, size: 20),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _ParticipantsSummaryBody(
            participantsValue: participantsValue,
            previewLimit: _previewLimit,
            onInvite: onInvite,
            onRetry: onRetry,
          ),
        ],
      ),
    );
  }
}

class _ParticipantsSummarySection extends ConsumerStatefulWidget {
  const _ParticipantsSummarySection({
    required this.storyId,
    required this.userStory,
    required this.onOpenParticipants,
    required this.canManageParticipants,
    required this.onInvite,
  });

  final String storyId;
  final UserStory userStory;
  final ValueChanged<UserStory>? onOpenParticipants;
  final bool canManageParticipants;
  final VoidCallback? onInvite;

  @override
  ConsumerState<_ParticipantsSummarySection> createState() =>
      _ParticipantsSummarySectionState();
}

class _ParticipantsSummarySectionState
    extends ConsumerState<_ParticipantsSummarySection> {
  @override
  void initState() {
    super.initState();
    _refreshParticipantsOnEntry();
  }

  @override
  void didUpdateWidget(_ParticipantsSummarySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storyId != widget.storyId) {
      _refreshParticipantsOnEntry();
    }
  }

  @override
  Widget build(BuildContext context) {
    final participantsValue = ref.watch(
      storyParticipantsProvider(widget.storyId),
    );

    return _ParticipantsSummaryCard(
      participantsValue: participantsValue,
      onOpenParticipants: widget.onOpenParticipants == null
          ? null
          : () {
              widget.onOpenParticipants!(widget.userStory);
            },
      canManageParticipants: widget.canManageParticipants,
      onInvite: widget.onInvite,
      onRetry: () {
        ref
            .read(storyParticipantsProvider(widget.storyId).notifier)
            .retryLoad();
      },
    );
  }

  void _refreshParticipantsOnEntry() {
    final storyId = widget.storyId;
    final provider = storyParticipantsProvider(storyId);
    if (!ref.exists(provider)) {
      return;
    }

    final state = ref.read(provider).asData?.value;
    if (state == null || !state.isLoaded || state.hasActiveOperation) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.storyId != storyId) {
        return;
      }

      ref.read(provider.notifier).refreshParticipants();
    });
  }
}

class _ParticipantsSummaryBody extends StatelessWidget {
  const _ParticipantsSummaryBody({
    required this.participantsValue,
    required this.previewLimit,
    required this.onInvite,
    required this.onRetry,
  });

  final AsyncValue<ParticipantsState> participantsValue;
  final int previewLimit;
  final VoidCallback? onInvite;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (participantsValue.hasError) {
      return _ParticipantsSummaryFailure(
        message: participantFailureMessage(
          l10n,
          const UnknownParticipantFailure(),
        ),
        onRetry: onRetry,
      );
    }

    final state = participantsValue.asData?.value;
    if (participantsValue.isLoading && state == null) {
      return const _ParticipantsSummaryLoading();
    }

    if (state == null) {
      return const _ParticipantsSummaryLoading();
    }

    if (state.hasLoadFailure) {
      return _ParticipantsSummaryFailure(
        message: participantFailureMessage(l10n, state.loadFailure!),
        onRetry: onRetry,
      );
    }

    final participants = state.participants;
    if (participants.isEmpty) {
      return _ParticipantsSummaryEmpty(onInvite: onInvite);
    }

    final visibleParticipants = participants.take(previewLimit).toList();
    final remainingCount = participants.length - visibleParticipants.length;

    return SingleChildScrollView(
      key: const ValueKey('story-details.participants.preview'),
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < visibleParticipants.length; index += 1)
            Padding(
              padding: EdgeInsets.only(
                right: index == visibleParticipants.length - 1 ? 0 : 18,
              ),
              child: _ParticipantPreviewItem(
                key: ValueKey('story-details.participants.item.$index'),
                participant: visibleParticipants[index],
              ),
            ),
          if (remainingCount > 0) ...[
            const SizedBox(width: 18),
            _ParticipantsOverflowIndicator(count: remainingCount),
          ],
          if (onInvite != null) ...[
            const SizedBox(width: 18),
            _ParticipantInvitePreview(onInvite: onInvite!),
          ],
        ],
      ),
    );
  }
}

class _ParticipantsSummaryLoading extends StatelessWidget {
  const _ParticipantsSummaryLoading();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      key: ValueKey('story-details.participants.loading'),
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          _ParticipantSkeleton(),
          SizedBox(width: 18),
          _ParticipantSkeleton(),
          SizedBox(width: 18),
          _ParticipantSkeleton(),
        ],
      ),
    );
  }
}

class _ParticipantSkeleton extends StatelessWidget {
  const _ParticipantSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F1F3),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 58,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1F3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 46,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1F3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantsSummaryEmpty extends StatelessWidget {
  const _ParticipantsSummaryEmpty({
    required this.onInvite,
  });

  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      key: const ValueKey('story-details.participants.empty'),
      children: [
        Expanded(
          child: Text(
            l10n.participantsEmptyTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _storyHubMuted,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        if (onInvite != null) ...[
          const SizedBox(width: 12),
          _ParticipantInvitePreview(onInvite: onInvite!),
        ],
      ],
    );
  }
}

class _ParticipantsSummaryFailure extends StatelessWidget {
  const _ParticipantsSummaryFailure({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: const ValueKey('story-details.participants.failure'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9C8C4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _storyHubAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${l10n.participantsLoadFailed}. $message',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _storyHubMuted,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('story-details.participants.retry-action'),
            onPressed: onRetry,
            child: Text(l10n.participantsRetry),
          ),
        ],
      ),
    );
  }
}

class _ParticipantPreviewItem extends StatelessWidget {
  const _ParticipantPreviewItem({
    required this.participant,
    super.key,
  });

  final StoryParticipant participant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final avatarUrl = participant.avatarUrl?.trim();
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final itemWidth = textScale <= 1.15 ? 78.0 : 116.0;

    return SizedBox(
      width: itemWidth,
      child: Column(
        children: [
          Semantics(
            label: l10n.participantsAvatarLabel(participant.displayName),
            image: true,
            child: _avatar(avatarUrl),
          ),
          const SizedBox(height: 10),
          Text(
            participant.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _storyHubInk,
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: itemWidth),
            child: StoryRoleBadge(
              role: participant.role,
              showIcon: false,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String? avatarUrl) {
    final fallback = _ParticipantPreviewAvatarFallback(
      displayName: participant.displayName,
    );
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return fallback;
    }

    final uri = Uri.tryParse(avatarUrl);
    if (uri != null && uri.hasScheme && uri.hasAuthority) {
      return CircleAvatar(
        key: const ValueKey('story-details.participants.avatar'),
        radius: 32,
        foregroundImage: NetworkImage(avatarUrl),
        onForegroundImageError: (_, __) {},
        backgroundColor: _storyHubAccentSoft,
        child: _ParticipantPreviewInitials(
          displayName: participant.displayName,
        ),
      );
    }

    return ClipOval(
      child: SizedBox.square(
        dimension: 64,
        child: AuthenticatedMediaPathImage(
          thumbnailPath: avatarUrl,
          representation: AuthenticatedMediaRepresentation.display,
          fit: BoxFit.cover,
          cacheWidth: 128,
          cacheHeight: 128,
          placeholder: fallback,
          errorBuilder: (_) => fallback,
        ),
      ),
    );
  }
}

class _ParticipantPreviewAvatarFallback extends StatelessWidget {
  const _ParticipantPreviewAvatarFallback({
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      key: const ValueKey('story-details.participants.avatar'),
      radius: 32,
      backgroundColor: _storyHubAccentSoft,
      child: _ParticipantPreviewInitials(displayName: displayName),
    );
  }
}

class _ParticipantPreviewInitials extends StatelessWidget {
  const _ParticipantPreviewInitials({
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Text(
      _participantInitials(displayName),
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: const TextStyle(
        color: _storyHubAccent,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _ParticipantsOverflowIndicator extends StatelessWidget {
  const _ParticipantsOverflowIndicator({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('story-details.participants.overflow'),
      width: 64,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _storyHubWarmWhite,
              shape: BoxShape.circle,
              border: Border.all(color: _storyHubWarmBorder),
            ),
            child: Text(
              '+$count',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _storyHubMuted,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantInvitePreview extends StatelessWidget {
  const _ParticipantInvitePreview({
    required this.onInvite,
  });

  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final itemWidth = textScale <= 1.15 ? 78.0 : 110.0;

    return SizedBox(
      width: itemWidth,
      child: InkWell(
        key: const ValueKey('story-details.participants.invite-action'),
        onTap: onInvite,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _storyHubAccentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE9C8C4),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: _storyHubAccent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.participantsInvite,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _storyHubMuted,
                  fontSize: 13.5,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryLowerCompositionCard extends StatelessWidget {
  const _StoryLowerCompositionCard({
    required this.userStory,
    required this.memoriesValue,
    required this.recentMemoriesValue,
    required this.onMemoriesSelected,
    required this.onMapSelected,
    required this.onTimelineSelected,
    required this.onCreateMemory,
    required this.onMemorySelected,
    required this.onPlaybackSelected,
    required this.onRetryMemories,
  });

  final UserStory userStory;
  final AsyncValue<StoryMemoriesState> memoriesValue;
  final AsyncValue<List<MemoryReadModel>> recentMemoriesValue;
  final ValueChanged<UserStory>? onMemoriesSelected;
  final ValueChanged<UserStory>? onMapSelected;
  final ValueChanged<UserStory>? onTimelineSelected;
  final VoidCallback? onCreateMemory;
  final ValueChanged<Memory>? onMemorySelected;
  final ValueChanged<UserStory>? onPlaybackSelected;
  final VoidCallback onRetryMemories;

  @override
  Widget build(BuildContext context) {
    return _LowerDetailsCard(
      key: const ValueKey('story-details.lower-content'),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
            child: _StorySectionNavigationRow(
              userStory: userStory,
              onMemoriesSelected: onMemoriesSelected,
              onMapSelected: onMapSelected,
              onTimelineSelected: onTimelineSelected,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 28, 0, 0),
            child: Column(
              children: [
                _RecentMemoriesSection(
                  memoriesValue: memoriesValue,
                  recentMemoriesValue: recentMemoriesValue,
                  onSeeAll: onMemoriesSelected == null
                      ? null
                      : () {
                          onMemoriesSelected!(userStory);
                        },
                  onMemorySelected: onMemorySelected,
                  onRetry: onRetryMemories,
                ),
                const SizedBox(height: 28),
                if (onCreateMemory != null) ...[
                  _AddMemoryAction(onPressed: onCreateMemory!),
                  const SizedBox(height: 14),
                ],
                if (onPlaybackSelected != null)
                  _PlaybackStoryAction(
                    onPressed: () {
                      onPlaybackSelected!(userStory);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryLowerCompositionSection extends ConsumerWidget {
  const _StoryLowerCompositionSection({
    required this.storyId,
    required this.userStory,
    required this.onMemoriesSelected,
    required this.onMapSelected,
    required this.onTimelineSelected,
    required this.onCreateMemory,
    required this.onMemorySelected,
    required this.onPlaybackSelected,
  });

  final String storyId;
  final UserStory userStory;
  final ValueChanged<UserStory>? onMemoriesSelected;
  final ValueChanged<UserStory>? onMapSelected;
  final ValueChanged<UserStory>? onTimelineSelected;
  final VoidCallback? onCreateMemory;
  final ValueChanged<Memory>? onMemorySelected;
  final ValueChanged<UserStory>? onPlaybackSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoriesValue = ref.watch(storyMemoriesProvider(storyId));
    final recentMemoriesValue = ref.watch(
      storyDetailsRecentMemoriesProvider(storyId),
    );

    return _StoryLowerCompositionCard(
      userStory: userStory,
      memoriesValue: memoriesValue,
      recentMemoriesValue: recentMemoriesValue,
      onMemoriesSelected: onMemoriesSelected,
      onMapSelected: onMapSelected,
      onTimelineSelected: onTimelineSelected,
      onCreateMemory: onCreateMemory,
      onMemorySelected: onMemorySelected,
      onPlaybackSelected: onPlaybackSelected,
      onRetryMemories: () {
        ref.read(storyMemoriesProvider(storyId).notifier).retryLoad();
      },
    );
  }
}

class _StorySectionNavigationRow extends StatelessWidget {
  const _StorySectionNavigationRow({
    required this.userStory,
    required this.onMemoriesSelected,
    required this.onMapSelected,
    required this.onTimelineSelected,
  });

  final UserStory userStory;
  final ValueChanged<UserStory>? onMemoriesSelected;
  final ValueChanged<UserStory>? onMapSelected;
  final ValueChanged<UserStory>? onTimelineSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      key: const ValueKey('story-details.section-navigation'),
      children: [
        Expanded(
          flex: 5,
          child: _SectionNavigationAction(
            actionKey: const ValueKey('story-details.memories-action'),
            icon: Icons.list_rounded,
            label: l10n.storyDetailsMemoriesAction,
            selected: true,
            onPressed: onMemoriesSelected == null
                ? null
                : () {
                    onMemoriesSelected!(userStory);
                  },
          ),
        ),
        Expanded(
          flex: 3,
          child: _SectionNavigationAction(
            actionKey: const ValueKey('story-details.map-action'),
            icon: Icons.map_outlined,
            label: l10n.storyDetailsMapAction,
            onPressed: onMapSelected == null
                ? null
                : () {
                    onMapSelected!(userStory);
                  },
          ),
        ),
        Expanded(
          flex: 4,
          child: _SectionNavigationAction(
            actionKey: const ValueKey('story-details.timeline-action'),
            icon: Icons.schedule_rounded,
            label: l10n.storyDetailsTimelineAction,
            onPressed: onTimelineSelected == null
                ? null
                : () {
                    onTimelineSelected!(userStory);
                  },
          ),
        ),
      ],
    );
  }
}

class _SectionNavigationAction extends StatelessWidget {
  const _SectionNavigationAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? _storyHubAccent : _storyHubMuted;

    return InkWell(
      key: actionKey,
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 4, 3, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 21, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            SizedBox(
              height: 2,
              width: double.infinity,
              child: Align(
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: selected ? 0.92 : 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: _storyHubAccent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentMemoriesSection extends StatelessWidget {
  const _RecentMemoriesSection({
    required this.memoriesValue,
    required this.recentMemoriesValue,
    required this.onSeeAll,
    required this.onMemorySelected,
    required this.onRetry,
  });

  final AsyncValue<StoryMemoriesState> memoriesValue;
  final AsyncValue<List<MemoryReadModel>> recentMemoriesValue;
  final VoidCallback? onSeeAll;
  final ValueChanged<Memory>? onMemorySelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      key: const ValueKey('story-details.recent-memories'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.storyDetailsRecentMemoriesTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _storyHubInk,
                  fontSize: 21,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  fontFamily: _storyHubDisplayFontFamily,
                  fontFamilyFallback: _storyHubDisplayFontFallback,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (onSeeAll != null)
              TextButton(
                key: const ValueKey(
                  'story-details.recent-memories.see-all-action',
                ),
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  foregroundColor: _storyHubAccent,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.storyDetailsSeeAllAction),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _RecentMemoriesBody(
          memoriesValue: memoriesValue,
          recentMemoriesValue: recentMemoriesValue,
          onMemorySelected: onMemorySelected,
          onRetry: onRetry,
        ),
      ],
    );
  }
}

class _RecentMemoriesBody extends StatelessWidget {
  const _RecentMemoriesBody({
    required this.memoriesValue,
    required this.recentMemoriesValue,
    required this.onMemorySelected,
    required this.onRetry,
  });

  final AsyncValue<StoryMemoriesState> memoriesValue;
  final AsyncValue<List<MemoryReadModel>> recentMemoriesValue;
  final ValueChanged<Memory>? onMemorySelected;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (memoriesValue.isLoading) {
      return const _RecentMemoriesLoading();
    }

    if (memoriesValue.hasError) {
      return _RecentMemoriesFailure(
        message: l10n.memoryFailureUnknown,
        onRetry: onRetry,
      );
    }

    final state = memoriesValue.asData?.value;
    final loadFailure = state?.loadFailure;
    if (loadFailure != null) {
      return _RecentMemoriesFailure(
        message: memoryFailureMessage(l10n, loadFailure),
        onRetry: onRetry,
      );
    }

    final recentMemories =
        recentMemoriesValue.asData?.value ?? const <MemoryReadModel>[];
    if (recentMemories.isEmpty) {
      return const _RecentMemoriesEmpty();
    }

    return Column(
      children: [
        for (var index = 0; index < recentMemories.length; index += 1) ...[
          if (index > 0) const SizedBox(height: 12),
          _RecentMemoryRow(
            key: ValueKey('story-details.recent-memory.$index'),
            readModel: recentMemories[index],
            onMemorySelected: onMemorySelected,
          ),
        ],
      ],
    );
  }
}

class _RecentMemoryRow extends StatelessWidget {
  const _RecentMemoryRow({
    required this.readModel,
    required this.onMemorySelected,
    super.key,
  });

  final MemoryReadModel readModel;
  final ValueChanged<Memory>? onMemorySelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final memory = readModel.memory;
    final selected = onMemorySelected;
    final placeName = _visibleText(memory.placeName);

    return Semantics(
      container: true,
      button: selected != null,
      label: selected == null
          ? memory.title
          : l10n.memoryOpenLabel(memory.title),
      child: Material(
        color: _storyHubWarmWhite,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _storyHubWarmBorder),
        ),
        child: InkWell(
          onTap: selected == null
              ? null
              : () {
                  selected(memory);
                },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _RecentMemoryVisual(readModel: readModel),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        memory.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _storyHubInk,
                          fontSize: 17,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _RecentMemoryMetaLine(
                        icon: Icons.calendar_today_outlined,
                        label: formatMemoryDate(l10n, memory.eventDate),
                      ),
                      if (placeName != null) ...[
                        const SizedBox(height: 6),
                        _RecentMemoryMetaLine(
                          icon: Icons.location_on_outlined,
                          label: placeName,
                        ),
                      ],
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
}

class _RecentMemoryVisual extends StatelessWidget {
  const _RecentMemoryVisual({
    required this.readModel,
  });

  final MemoryReadModel readModel;

  @override
  Widget build(BuildContext context) {
    final preview = readModel.previewPhoto;
    final fallback = _RecentMemoryDateVisual(memory: readModel.memory);

    if (preview == null) {
      return const _RecentMemoryNoPhotoVisual();
    }

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 104,
          height: 78,
          child: AuthenticatedMediaPathImage(
            thumbnailPath: preview.thumbnailPath,
            fit: BoxFit.cover,
            placeholder: fallback,
            errorBuilder: (_) => fallback,
          ),
        ),
      ),
    );
  }
}

class _RecentMemoryNoPhotoVisual extends StatelessWidget {
  const _RecentMemoryNoPhotoVisual();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/memory_timeline_no_photo_preview.png',
          width: 104,
          height: 78,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _RecentMemoryDateVisual extends StatelessWidget {
  const _RecentMemoryDateVisual({
    required this.memory,
  });

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 104,
        height: 78,
        decoration: BoxDecoration(
          color: _storyHubAccentSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              memory.eventDate.day.toString(),
              style: const TextStyle(
                color: _storyHubAccent,
                fontSize: 24,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              memory.eventDate.month.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: _storyHubAccent,
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentMemoryMetaLine extends StatelessWidget {
  const _RecentMemoryMetaLine({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: _storyHubMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _storyHubMuted,
              fontSize: 14.5,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentMemoriesLoading extends StatelessWidget {
  const _RecentMemoriesLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('story-details.recent-memories.loading'),
      children: const [
        _SkeletonBlock(height: 96, radius: 20),
        SizedBox(height: 12),
        _SkeletonBlock(height: 96, radius: 20),
      ],
    );
  }
}

class _RecentMemoriesEmpty extends StatelessWidget {
  const _RecentMemoriesEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: const ValueKey('story-details.recent-memories.empty'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _storyHubWarmWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _storyHubWarmBorder),
      ),
      child: Text(
        l10n.storyMemoriesEmptyTitle,
        style: const TextStyle(
          color: _storyHubMuted,
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _RecentMemoriesFailure extends StatelessWidget {
  const _RecentMemoriesFailure({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: const ValueKey('story-details.recent-memories.failure'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9C8C4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _storyHubAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${l10n.storyMemoriesLoadFailureTitle}. $message',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _storyHubMuted,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('story-details.recent-memories.retry-action'),
            onPressed: onRetry,
            child: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

class _AddMemoryAction extends StatelessWidget {
  const _AddMemoryAction({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FilledButton.icon(
      key: const ValueKey('story-details.add-memory-action'),
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded, size: 28),
      label: Text(l10n.storyMemoriesCreate),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        backgroundColor: _storyHubAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        textStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PlaybackStoryAction extends StatelessWidget {
  const _PlaybackStoryAction({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return OutlinedButton.icon(
      key: const ValueKey('story-details.playback-action'),
      onPressed: onPressed,
      icon: const Icon(
        Icons.play_circle_outline_rounded,
        color: _storyHubMuted,
        size: 25,
      ),
      label: Text(l10n.storyDetailsPlaybackStoryAction),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        foregroundColor: _storyHubInk,
        backgroundColor: _storyHubWarmWhite.withValues(alpha: 0.28),
        side: BorderSide(
          color: _storyHubWarmBorder.withValues(alpha: 0.44),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        textStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
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
          border: Border.all(color: const Color(0xFFE9C8C4)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: _storyHubAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${l10n.storyDetailsRefreshFailureTitle}. $message',
                style: const TextStyle(
                  color: _storyHubMuted,
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
    required this.onBack,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onBack;
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
              color: _storyHubAccentSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: _storyHubAccent,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _storyHubInk,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontFamily: _storyHubDisplayFontFamily,
              fontFamilyFallback: _storyHubDisplayFontFallback,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _storyHubMuted,
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('story-details.error.back-action'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(l10n.storyDetailsBackLabel),
              ),
              OutlinedButton.icon(
                key: const ValueKey('story-details.error.retry-action'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.retry),
              ),
            ],
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
        color: _storyHubWarmWhite,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            offset: Offset(0, 8),
            blurRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.child,
    this.borderColor = _storyHubWarmBorder,
    super.key,
  });

  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _storyHubWarmWhite.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class _LowerDetailsCard extends StatelessWidget {
  const _LowerDetailsCard({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(2),
      ),
      child: child,
    );
  }
}

bool _canCreateMemory(UserStory userStory) {
  return userStory.role == StoryRole.owner ||
      userStory.role == StoryRole.coOwner ||
      userStory.role == StoryRole.editor;
}

bool _canEditSoundtrack(UserStory userStory) {
  return userStory.role == StoryRole.owner ||
      userStory.role == StoryRole.coOwner;
}

String? _visibleDescription(Story story) {
  final description = story.description;
  if (description == null || description.trim().isEmpty) {
    return null;
  }

  return description;
}

String? _visibleText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return value;
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

String _participantInitials(String displayName) {
  return _initials(displayName).toUpperCase();
}

String? _storyPeriodLabel(
  BuildContext context,
  StoryMemoryPeriod? period,
  int currentYear,
) {
  if (period == null) {
    return null;
  }

  final startYear = period.startYear;
  final endYear = period.endYear;
  if (startYear == endYear) {
    return startYear.toString();
  }

  final endLabel = endYear == currentYear
      ? AppLocalizations.of(context).storyDetailsPeriodPresent
      : endYear.toString();
  return '$startYear — $endLabel';
}
