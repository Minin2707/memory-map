import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_state.dart';
import 'package:memory_map/features/memory/application/story_timeline_projection.dart';
import 'package:memory_map/features/memory/application/story_timeline_section.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/presentation/memory_date_format.dart';
import 'package:memory_map/features/memory/presentation/memory_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const _timelineBackground = Color(0xFFFBF6F1);
const _timelineInk = Color(0xFF182331);
const _timelineMuted = Color(0xFF747B86);
const _timelineAccent = Color(0xFFD16A74);
const _timelineAccentSoft = Color(0xFFFFEEF0);
const _timelineWarmWhite = Color(0xFFFFFDFB);
const _timelineWarmBorder = Color(0xFFEFE5E1);
const _timelineDisplayFontFamily = 'NotoSerif';
const _timelineNoPhotoPreviewAsset =
    'assets/memory_timeline_no_photo_preview.png';

class StoryTimelineScreen extends ConsumerWidget {
  const StoryTimelineScreen({
    required this.storyId,
    this.storyTitle,
    this.onBack,
    this.onCreateMemory,
    this.onMemorySelected,
    this.onPlaybackSelected,
    super.key,
  });

  final String storyId;
  final String? storyTitle;
  final VoidCallback? onBack;
  final VoidCallback? onCreateMemory;
  final ValueChanged<Memory>? onMemorySelected;
  final VoidCallback? onPlaybackSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoriesValue = ref.watch(storyMemoriesProvider(storyId));
    final sectionsValue = ref.watch(storyTimelineSectionsProvider(storyId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          onBack?.call();
        }
      },
      child: Scaffold(
        backgroundColor: _timelineBackground,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: _timelineAccent,
            onRefresh: () {
              return ref
                  .read(storyMemoriesProvider(storyId).notifier)
                  .refreshMemories();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 24, 10),
                  sliver: SliverToBoxAdapter(
                    child: _StoryTimelineHeader(
                      title: storyTitle,
                      isRefreshing: _isRefreshing(memoriesValue),
                      onBack: onBack,
                      onRefresh: () {
                        ref
                            .read(storyMemoriesProvider(storyId).notifier)
                            .refreshMemories();
                      },
                      onPlaybackSelected: onPlaybackSelected,
                    ),
                  ),
                ),
                ..._contentSlivers(context, ref, memoriesValue, sectionsValue),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            ),
          ),
        ),
        floatingActionButton: onCreateMemory == null
            ? null
            : FloatingActionButton(
                key: const ValueKey('story-timeline.create-action'),
                onPressed: onCreateMemory,
                tooltip: AppLocalizations.of(context).storyTimelineCreate,
                backgroundColor: _timelineAccent,
                foregroundColor: Colors.white,
                elevation: 3,
                child: const Icon(Icons.add_rounded),
              ),
      ),
    );
  }

  List<Widget> _contentSlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<StoryMemoriesState> memoriesValue,
    AsyncValue<List<StoryTimelineSection>> sectionsValue,
  ) {
    final l10n = AppLocalizations.of(context);

    if (memoriesValue.isLoading) {
      return const [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
          sliver: SliverToBoxAdapter(child: _StoryTimelineLoadingView()),
        ),
      ];
    }

    if (memoriesValue.hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Center(
              child: _StoryTimelineErrorView(
                title: l10n.unexpectedErrorTitle,
                message: l10n.memoryFailureUnknown,
                onRetry: () {
                  ref
                      .read(storyMemoriesProvider(storyId).notifier)
                      .retryLoad();
                },
              ),
            ),
          ),
        ),
      ];
    }

    final state = memoriesValue.asData?.value;
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
              child: _StoryTimelineErrorView(
                title: l10n.storyTimelineLoadFailureTitle,
                message: memoryFailureMessage(l10n, loadFailure),
                onRetry: () {
                  ref
                      .read(storyMemoriesProvider(storyId).notifier)
                      .retryLoad();
                },
              ),
            ),
          ),
        ),
      ];
    }

    final sections =
        sectionsValue.asData?.value ?? const <StoryTimelineSection>[];

    return [
      if (state.isRefreshing)
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverToBoxAdapter(
            child: LinearProgressIndicator(
              minHeight: 3,
              color: _timelineAccent,
              backgroundColor: _timelineAccentSoft,
            ),
          ),
        ),
      if (state.refreshFailure != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverToBoxAdapter(
            child: _RefreshFailureBanner(
              message: memoryFailureMessage(l10n, state.refreshFailure!),
              onRetry: () {
                ref
                    .read(storyMemoriesProvider(storyId).notifier)
                    .refreshMemories();
              },
            ),
          ),
        ),
      if (sections.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Center(
              child: _StoryTimelineEmptyState(onCreateMemory: onCreateMemory),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: _TimelineSliverList(
            sections: sections,
            onMemorySelected: onMemorySelected,
          ),
        ),
    ];
  }

  bool _isRefreshing(AsyncValue<StoryMemoriesState> value) {
    return value.asData?.value.isRefreshing ?? false;
  }
}

class _StoryTimelineHeader extends StatelessWidget {
  const _StoryTimelineHeader({
    required this.title,
    required this.isRefreshing,
    required this.onBack,
    required this.onRefresh,
    required this.onPlaybackSelected,
  });

  final String? title;
  final bool isRefreshing;
  final VoidCallback? onBack;
  final VoidCallback onRefresh;
  final VoidCallback? onPlaybackSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: _timelineWarmWhite.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.68),
              width: 0.8,
            ),
          ),
          child: IconButton(
            key: const ValueKey('story-timeline.back-action'),
            onPressed: onBack,
            tooltip: l10n.storyTimelineBackLabel,
            color: _timelineInk,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _visibleText(title) ?? l10n.storyTimelinePageTitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _timelineInk,
                fontFamily: _timelineDisplayFontFamily,
                fontFamilyFallback: <String>['NotoSerifGeorgian'],
                fontSize: 33,
                fontWeight: FontWeight.w500,
                height: 1.08,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (onPlaybackSelected != null)
          _TimelineCircleAction(
            actionKey: const ValueKey('story-timeline.playback-action'),
            onPressed: onPlaybackSelected,
            tooltip: l10n.playbackTitle,
            icon: Icons.play_arrow_rounded,
            foregroundColor: Colors.white,
            backgroundColor: _timelineAccent,
          ),
        const SizedBox(width: 8),
        _TimelineCircleAction(
          actionKey: const ValueKey('story-timeline.refresh-action'),
          onPressed: isRefreshing ? null : onRefresh,
          tooltip: l10n.storyTimelineRefreshAction,
          icon: Icons.refresh_rounded,
          foregroundColor: _timelineInk,
          backgroundColor: _timelineWarmWhite.withValues(alpha: 0.76),
        ),
      ],
    );
  }
}

class _TimelineCircleAction extends StatelessWidget {
  const _TimelineCircleAction({
    required this.actionKey,
    required this.onPressed,
    required this.tooltip,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final Key actionKey;
  final VoidCallback? onPressed;
  final String tooltip;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: actionKey,
      onPressed: onPressed,
      tooltip: tooltip,
      color: foregroundColor,
      disabledColor: _timelineMuted.withValues(alpha: 0.56),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        backgroundColor: backgroundColor,
        disabledBackgroundColor: _timelineWarmWhite.withValues(alpha: 0.48),
        shape: const CircleBorder(),
      ),
      icon: Icon(icon),
    );
  }
}

class _TimelineSliverList extends StatelessWidget {
  const _TimelineSliverList({
    required this.sections,
    required this.onMemorySelected,
  });

  final List<StoryTimelineSection> sections;
  final ValueChanged<Memory>? onMemorySelected;

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries(sections);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = entries[index];
          return switch (entry) {
            _YearEntry(:final year) => _TimelineYearHeader(year: year),
            _MemoryEntry(:final readModel) => _TimelineMemoryItem(
                readModel: readModel,
                onMemorySelected: onMemorySelected,
              ),
          };
        },
        childCount: entries.length,
      ),
    );
  }

  List<_TimelineEntry> _buildEntries(List<StoryTimelineSection> sections) {
    final entries = <_TimelineEntry>[];
    for (final section in sections) {
      entries.add(_YearEntry(section.year));
      for (final readModel in section.memories) {
        entries.add(_MemoryEntry(readModel));
      }
    }

    return entries;
  }
}

sealed class _TimelineEntry {
  const _TimelineEntry();
}

final class _YearEntry extends _TimelineEntry {
  const _YearEntry(this.year);

  final int year;
}

final class _MemoryEntry extends _TimelineEntry {
  const _MemoryEntry(this.readModel);

  final MemoryReadModel readModel;
}

class _TimelineYearHeader extends StatelessWidget {
  const _TimelineYearHeader({
    required this.year,
  });

  final int year;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey<String>('story-timeline.year.$year'),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 22),
      child: Row(
        children: [
          Text(
            year.toString(),
            style: const TextStyle(
              color: _timelineAccent,
              fontFamily: _timelineDisplayFontFamily,
              fontFamilyFallback: <String>['NotoSerifGeorgian'],
              fontSize: 38,
              fontWeight: FontWeight.w500,
              height: 1,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0x5CD16A74),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineMemoryItem extends StatelessWidget {
  const _TimelineMemoryItem({
    required this.readModel,
    required this.onMemorySelected,
  });

  final MemoryReadModel readModel;
  final ValueChanged<Memory>? onMemorySelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _TimelineMemoryCard(
            readModel: readModel,
            onMemorySelected: onMemorySelected,
          ),
        ),
      ),
    );
  }
}

class _TimelineMemoryCard extends StatelessWidget {
  const _TimelineMemoryCard({
    required this.readModel,
    required this.onMemorySelected,
  });

  final MemoryReadModel readModel;
  final ValueChanged<Memory>? onMemorySelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final memory = readModel.memory;
    final description = _visibleText(memory.description);
    final placeName = _visibleText(memory.placeName);
    final selected = onMemorySelected;

    return Semantics(
      container: true,
      button: selected != null,
      label: selected == null ? memory.title : l10n.memoryOpenLabel(memory.title),
      child: Material(
        color: _timelineWarmWhite,
        borderRadius: BorderRadius.circular(22),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: selected == null
              ? null
              : () {
                  selected(memory);
                },
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _timelineWarmBorder, width: 0.8),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TimelinePreview(readModel: readModel),
                  const SizedBox(height: 16),
                  Text(
                    memory.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _timelineInk,
                      fontFamily: _timelineDisplayFontFamily,
                      fontFamilyFallback: <String>['NotoSerifGeorgian'],
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                      height: 1.16,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _timelineMuted,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _TimelineMetaLine(
                    date: formatMemoryDate(l10n, memory.eventDate),
                    placeName: placeName,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineMetaLine extends StatelessWidget {
  const _TimelineMetaLine({
    required this.date,
    required this.placeName,
  });

  final String date;
  final String? placeName;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _TimelineMetaPill(
          icon: Icons.calendar_today_rounded,
          text: date,
        ),
        if (placeName != null) ...[
          const Text(
            '·',
            style: TextStyle(
              color: _timelineMuted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          _TimelineMetaPill(
            icon: Icons.place_rounded,
            text: placeName!,
          ),
        ],
      ],
    );
  }
}

class _TimelineMetaPill extends StatelessWidget {
  const _TimelineMetaPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _timelineMuted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _timelineMuted,
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelinePreview extends StatelessWidget {
  const _TimelinePreview({
    required this.readModel,
  });

  final MemoryReadModel readModel;

  @override
  Widget build(BuildContext context) {
    final preview = readModel.previewPhoto;

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: preview == null
              ? const _NoPhotoVisual()
              : AuthenticatedMediaPathImage(
                  thumbnailPath: preview.thumbnailPath,
                  fit: BoxFit.cover,
                  placeholder: const _PhotoFallbackVisual(),
                  errorBuilder: (_) {
                    return const _PhotoFallbackVisual();
                  },
                ),
        ),
      ),
    );
  }
}

class _NoPhotoVisual extends StatelessWidget {
  const _NoPhotoVisual();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _timelineNoPhotoPreviewAsset,
      key: const ValueKey('story-timeline.no-photo-visual'),
      fit: BoxFit.cover,
    );
  }
}

class _PhotoFallbackVisual extends StatelessWidget {
  const _PhotoFallbackVisual();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      key: ValueKey('story-timeline.photo-fallback-visual'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _timelineAccentSoft,
            _timelineWarmWhite,
            Color(0xFFF7E8E2),
          ],
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
        key: const ValueKey('story-timeline.refresh.failure-banner'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _timelineAccentSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x3DD16A74)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: _timelineAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${l10n.storyTimelineRefreshFailureTitle}. $message',
                style: const TextStyle(
                  color: _timelineMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('story-timeline.refresh.retry-action'),
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryTimelineErrorView extends StatelessWidget {
  const _StoryTimelineErrorView({
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

    return _TimelineCardShell(
      key: const ValueKey('story-timeline.error-view'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _timelineAccentSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: _timelineAccent,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _timelineInk,
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
              color: _timelineMuted,
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            key: const ValueKey('story-timeline.error.retry-action'),
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: _timelineAccent,
              side: const BorderSide(color: Color(0x3DD16A74)),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

class _StoryTimelineEmptyState extends StatelessWidget {
  const _StoryTimelineEmptyState({
    required this.onCreateMemory,
  });

  final VoidCallback? onCreateMemory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _TimelineCardShell(
      key: const ValueKey('story-timeline.empty-state'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _timelineAccentSoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.timeline_rounded,
              color: _timelineAccent,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.storyTimelineEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _timelineInk,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.storyTimelineEmptyBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _timelineMuted,
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          if (onCreateMemory != null) ...[
            const SizedBox(height: 22),
            FilledButton.icon(
              key: const ValueKey('story-timeline.empty.create-action'),
              onPressed: onCreateMemory,
              style: FilledButton.styleFrom(
                backgroundColor: _timelineAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.storyTimelineCreate),
            ),
          ],
        ],
      ),
    );
  }
}

class _StoryTimelineLoadingView extends StatelessWidget {
  const _StoryTimelineLoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('story-timeline.loading-view'),
      children: const [
        _SkeletonBlock(height: 54),
        SizedBox(height: 22),
        _SkeletonBlock(height: 292),
        SizedBox(height: 22),
        _SkeletonBlock(height: 292),
      ],
    );
  }
}

class _TimelineCardShell extends StatelessWidget {
  const _TimelineCardShell({
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
        color: _timelineWarmWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _timelineWarmBorder, width: 0.8),
      ),
      child: child,
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.height,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: _timelineWarmWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _timelineWarmBorder, width: 0.8),
      ),
    );
  }
}

String? _visibleText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return value;
}
