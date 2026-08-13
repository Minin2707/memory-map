import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_state.dart';
import 'package:memory_map/features/memory/application/story_timeline_projection.dart';
import 'package:memory_map/features/memory/application/story_timeline_section.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/presentation/memory_date_format.dart';
import 'package:memory_map/features/memory/presentation/memory_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class StoryTimelineScreen extends ConsumerWidget {
  const StoryTimelineScreen({
    required this.storyId,
    this.storyTitle,
    this.onBack,
    this.onCreateMemory,
    this.onMemorySelected,
    super.key,
  });

  final String storyId;
  final String? storyTitle;
  final VoidCallback? onBack;
  final VoidCallback? onCreateMemory;
  final ValueChanged<Memory>? onMemorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoriesValue = ref.watch(storyMemoriesProvider(storyId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          onBack?.call();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F8),
        body: SafeArea(
          child: RefreshIndicator(
            color: const Color(0xFFFF5D72),
            onRefresh: () {
              return ref
                  .read(storyMemoriesProvider(storyId).notifier)
                  .refreshMemories();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  sliver: SliverToBoxAdapter(
                    child: _StoryTimelineAppBar(
                      title: storyTitle,
                      isRefreshing: _isRefreshing(memoriesValue),
                      onBack: onBack,
                      onRefresh: () {
                        ref
                            .read(storyMemoriesProvider(storyId).notifier)
                            .refreshMemories();
                      },
                    ),
                  ),
                ),
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                  sliver: SliverToBoxAdapter(child: _TimelineTabs()),
                ),
                ..._contentSlivers(context, ref, memoriesValue),
                const SliverToBoxAdapter(child: SizedBox(height: 104)),
              ],
            ),
          ),
        ),
        floatingActionButton: onCreateMemory == null
            ? null
            : FloatingActionButton.extended(
                key: const ValueKey('story-timeline.create-action'),
                onPressed: onCreateMemory,
                backgroundColor: const Color(0xFFFF5D72),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: Text(AppLocalizations.of(context).storyTimelineCreate),
              ),
      ),
    );
  }

  List<Widget> _contentSlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<StoryMemoriesState> memoriesValue,
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

    final sections = buildStoryTimelineSections(state.memoryReadModels);

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
          padding: const EdgeInsets.fromLTRB(24, 24, 20, 0),
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

class _StoryTimelineAppBar extends StatelessWidget {
  const _StoryTimelineAppBar({
    required this.title,
    required this.isRefreshing,
    required this.onBack,
    required this.onRefresh,
  });

  final String? title;
  final bool isRefreshing;
  final VoidCallback? onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        IconButton(
          key: const ValueKey('story-timeline.back-action'),
          onPressed: onBack,
          tooltip: l10n.storyTimelineBackLabel,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        Expanded(
          child: Text(
            _visibleText(title) ?? l10n.storyTimelinePageTitle,
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
        IconButton(
          key: const ValueKey('story-timeline.refresh-action'),
          onPressed: isRefreshing ? null : onRefresh,
          tooltip: l10n.storyTimelineRefreshAction,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _TimelineTabs extends StatelessWidget {
  const _TimelineTabs();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      key: const ValueKey('story-timeline.tabs'),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE9EC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _TimelineTab(
                label: l10n.storyTimelineTabTimeline,
                selected: true,
              ),
            ),
            Expanded(
              child: _TimelineTab(
                label: l10n.storyTimelineTabMap,
                selected: false,
              ),
            ),
            Expanded(
              child: _TimelineTab(
                label: l10n.storyTimelineTabStats,
                selected: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({
    required this.label,
    required this.selected,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    offset: Offset(0, 6),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? const Color(0xFFFF5D72) : const Color(0xFF7B8494),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 14),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              year.toString(),
              style: const TextStyle(
                color: Color(0xFFFF5D72),
                fontSize: 25,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFFFFCDD5),
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
    final memory = readModel.memory;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TimelineDateLabel(date: memory.eventDate),
            const SizedBox(width: 12),
            const _TimelineRail(),
            const SizedBox(width: 14),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: _TimelineMemoryCard(
                    readModel: readModel,
                    onMemorySelected: onMemorySelected,
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

class _TimelineDateLabel extends StatelessWidget {
  const _TimelineDateLabel({
    required this.date,
  });

  final MemoryDate date;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            date.day.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _monthNumber(date.month),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8A93A3),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRail extends StatelessWidget {
  const _TimelineRail();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 20,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              top: 10,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 2,
                  color: const Color(0xFFFFCDD5),
                ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5D72),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33FF5D72),
                    offset: Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 10,
        shadowColor: const Color(0x1F0F172A),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: selected == null
              ? null
              : () {
                  selected(memory);
                },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimelinePreview(readModel: readModel),
                const SizedBox(height: 14),
                Text(
                  memory.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    height: 1.2,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _TimelineMetaRow(
                  icon: Icons.calendar_today_rounded,
                  text: formatMemoryDate(l10n, memory.eventDate),
                ),
                if (placeName != null) ...[
                  const SizedBox(height: 7),
                  _TimelineMetaRow(
                    icon: Icons.place_rounded,
                    text: placeName,
                  ),
                ],
              ],
            ),
          ),
        ),
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
              ? _NoPhotoVisual(date: readModel.memory.eventDate)
              : AuthenticatedMediaPathImage(
                  thumbnailPath: preview.thumbnailPath,
                  fit: BoxFit.cover,
                  placeholder: _NoPhotoVisual(date: readModel.memory.eventDate),
                  errorBuilder: (_) {
                    return _NoPhotoVisual(date: readModel.memory.eventDate);
                  },
                ),
        ),
      ),
    );
  }
}

class _NoPhotoVisual extends StatelessWidget {
  const _NoPhotoVisual({
    required this.date,
  });

  final MemoryDate date;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('story-timeline.no-photo-visual'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE6EA),
            Color(0xFFFFF6D9),
            Color(0xFFEAF7FF),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: const Color(0xCCFFFFFF),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                date.day.toString(),
                style: const TextStyle(
                  color: Color(0xFFFF5D72),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _monthNumber(date.month),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFF5D72),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
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

class _TimelineMetaRow extends StatelessWidget {
  const _TimelineMetaRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF8A93A3)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4B5563),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
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

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('story-timeline.refresh.failure-banner'),
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
                '${l10n.storyTimelineRefreshFailureTitle}. $message',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
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
              fontWeight: FontWeight.w900,
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
            key: const ValueKey('story-timeline.error.retry-action'),
            onPressed: onRetry,
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
              color: const Color(0xFFFFE6EA),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.timeline_rounded,
              color: Color(0xFFFF5D72),
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.storyTimelineEmptyTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.storyTimelineEmptyBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
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
                backgroundColor: const Color(0xFFFF5D72),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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

String? _visibleText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return value;
}

String _monthNumber(int month) {
  return month.toString().padLeft(2, '0');
}
