import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_state.dart';
import 'package:memory_map/features/memory/application/story_memories_year_projection.dart';
import 'package:memory_map/features/memory/application/story_memories_year_section.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/presentation/memory_date_format.dart';
import 'package:memory_map/features/memory/presentation/memory_failure_message.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/application/story_details_state.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class StoryMemoriesScreen extends ConsumerWidget {
  const StoryMemoriesScreen({
    required this.storyId,
    this.onBack,
    this.onCreateMemory,
    this.onMemorySelected,
    super.key,
  });

  final String storyId;
  final VoidCallback? onBack;
  final VoidCallback? onCreateMemory;
  final ValueChanged<Memory>? onMemorySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoriesValue = ref.watch(storyMemoriesProvider(storyId));
    final sectionsValue = ref.watch(storyMemoriesYearSectionsProvider(storyId));
    final storyValue = ref.watch(storyDetailsProvider(storyId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          onBack?.call();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F8),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: onCreateMemory == null
            ? null
            : Padding(
                padding: const EdgeInsets.fromLTRB(48, 0, 48, 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FloatingActionButton.extended(
                    key: const ValueKey('story-memories.create-action'),
                    onPressed: onCreateMemory,
                    backgroundColor: const Color(0xFFFF5D72),
                    foregroundColor: Colors.white,
                    elevation: 7,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 28),
                    label: Text(
                      AppLocalizations.of(context).storyMemoriesCreate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
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
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: _StoryMemoriesHeader(
                      storyValue: storyValue,
                      onBack: onBack,
                    ),
                  ),
                ),
                ..._contentSlivers(context, ref, memoriesValue, sectionsValue),
                const SliverToBoxAdapter(child: SizedBox(height: 116)),
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
    AsyncValue<StoryMemoriesState> memoriesValue,
    AsyncValue<List<StoryMemoriesYearSection>> sectionsValue,
  ) {
    final l10n = AppLocalizations.of(context);

    if (memoriesValue.isLoading) {
      return const [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
          sliver: SliverToBoxAdapter(child: _StoryMemoriesLoadingView()),
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
              child: _StoryMemoriesErrorView(
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
              child: _StoryMemoriesErrorView(
                title: l10n.storyMemoriesLoadFailureTitle,
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
        sectionsValue.asData?.value ?? const <StoryMemoriesYearSection>[];

    return [
      if (state.isRefreshing)
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(22, 14, 22, 0),
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
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Center(
              child: _StoryMemoriesEmptyState(
                onCreateMemory: onCreateMemory,
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 18, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == sections.length - 1 ? 0 : 22,
                  ),
                  child: _StoryMemoriesYearSectionView(
                    section: sections[index],
                    onMemorySelected: onMemorySelected,
                  ),
                );
              },
              childCount: sections.length,
            ),
          ),
        ),
    ];
  }
}

class _StoryMemoriesHeader extends StatelessWidget {
  const _StoryMemoriesHeader({
    required this.storyValue,
    required this.onBack,
  });

  final AsyncValue<StoryDetailsState> storyValue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final storyState = storyValue.asData?.value;
    final userStory = storyState?.userStory;

    return Row(
      key: const ValueKey('story-memories.header'),
      children: [
        _HeaderBackButton(onBack: onBack),
        const SizedBox(width: 10),
        if (storyValue.isLoading && userStory == null)
          const _HeaderThumbnailSkeleton()
        else
          _StoryHeaderThumbnail(userStory: userStory),
        const SizedBox(width: 12),
        Expanded(
          child: userStory == null
              ? const _StoryHeaderTextFallback()
              : _StoryHeaderText(userStory: userStory),
        ),
      ],
    );
  }
}

class _HeaderBackButton extends StatelessWidget {
  const _HeaderBackButton({
    required this.onBack,
  });

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: const Color(0x180F172A),
      child: IconButton(
        key: const ValueKey('story-memories.back-action'),
        onPressed: onBack,
        tooltip: AppLocalizations.of(context).storyMemoriesBackLabel,
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
        color: const Color(0xFF111827),
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class _StoryHeaderThumbnail extends StatelessWidget {
  const _StoryHeaderThumbnail({
    required this.userStory,
  });

  final UserStory? userStory;

  @override
  Widget build(BuildContext context) {
    final preview = userStory?.previewPhoto;
    final fallback = _StoryHeaderThumbnailFallback(userStory: userStory);

    if (preview == null) {
      return fallback;
    }

    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(
          dimension: 56,
          child: AuthenticatedMediaPathImage(
            key: ValueKey('story-memories.header-thumbnail.${preview.mediaId}'),
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

class _StoryHeaderThumbnailFallback extends StatelessWidget {
  const _StoryHeaderThumbnailFallback({
    required this.userStory,
  });

  final UserStory? userStory;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        key: const ValueKey('story-memories.header.no-photo'),
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
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
          child: Text(
            _initials(userStory?.story.title ?? ''),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFF5D72),
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderThumbnailSkeleton extends StatelessWidget {
  const _HeaderThumbnailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const _SkeletonBlock(
      key: ValueKey('story-memories.header.thumbnail-loading'),
      width: 56,
      height: 56,
      radius: 999,
    );
  }
}

class _StoryHeaderText extends StatelessWidget {
  const _StoryHeaderText({
    required this.userStory,
  });

  final UserStory userStory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          userStory.story.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 22,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.storyMemoriesCount(userStory.memoryCount),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF7B8494),
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _StoryHeaderTextFallback extends StatelessWidget {
  const _StoryHeaderTextFallback();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.storyMemoriesPageTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 22,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        const _SkeletonBlock(width: 108, height: 12, radius: 999),
      ],
    );
  }
}

class _StoryMemoriesYearSectionView extends StatelessWidget {
  const _StoryMemoriesYearSectionView({
    required this.section,
    required this.onMemorySelected,
  });

  final StoryMemoriesYearSection section;
  final ValueChanged<Memory>? onMemorySelected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: ValueKey('story-memories.year.${section.year}'),
      children: [
        const Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: _YearRail(),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _YearHeader(section: section),
              const SizedBox(height: 10),
              for (var index = 0;
                  index < section.memories.length;
                  index += 1) ...[
                if (index > 0) const SizedBox(height: 10),
                _StoryMemoryCard(
                  readModel: section.memories[index],
                  onMemorySelected: onMemorySelected,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _YearRail extends StatelessWidget {
  const _YearRail();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 24,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              top: 24,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 1.5,
                  color: const Color(0xFFFF9AA8),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5D72),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFF8F8), width: 4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearHeader extends StatelessWidget {
  const _YearHeader({
    required this.section,
  });

  final StoryMemoriesYearSection section;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            section.year.toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          l10n.storyMemoriesCount(section.memoryCount),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF8A93A3),
            fontSize: 15,
            height: 1.2,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _StoryMemoryCard extends StatelessWidget {
  const _StoryMemoryCard({
    required this.readModel,
    required this.onMemorySelected,
  });

  final MemoryReadModel readModel;
  final ValueChanged<Memory>? onMemorySelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final memory = readModel.memory;
    final placeName = _visibleText(memory.placeName);
    final selected = onMemorySelected;

    return Semantics(
      container: true,
      button: selected != null,
      label: selected == null
          ? memory.title
          : l10n.memoryOpenLabel(memory.title),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 4,
        shadowColor: const Color(0x160F172A),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: selected == null
              ? null
              : () {
                  selected(memory);
                },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 330;
                final previewWidth = compact ? 76.0 : 96.0;
                final previewHeight = compact ? 70.0 : 84.0;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MemoryPreview(
                      readModel: readModel,
                      width: previewWidth,
                      height: previewHeight,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              memory.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 17,
                                height: 1.16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 7),
                            _MemoryMetaRow(
                              icon: Icons.calendar_today_outlined,
                              text: formatMemoryDate(l10n, memory.eventDate),
                            ),
                            if (placeName != null) ...[
                              const SizedBox(height: 5),
                              _MemoryMetaRow(
                                icon: Icons.location_on_outlined,
                                text: placeName,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MemoryPreview extends StatelessWidget {
  const _MemoryPreview({
    required this.readModel,
    required this.width,
    required this.height,
  });

  final MemoryReadModel readModel;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final preview = readModel.previewPhoto;
    final fallback = _NoPhotoPreview(width: width, height: height);

    if (preview == null) {
      return fallback;
    }

    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: width,
          height: height,
          child: AuthenticatedMediaPathImage(
            key: ValueKey('story-memories.memory-thumbnail.${preview.mediaId}'),
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

class _NoPhotoPreview extends StatelessWidget {
  const _NoPhotoPreview({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        key: const ValueKey('story-memories.no-photo-preview'),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.photo_outlined,
          color: Color(0xFF9AA3AF),
          size: 26,
        ),
      ),
    );
  }
}

class _MemoryMetaRow extends StatelessWidget {
  const _MemoryMetaRow({
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
        Icon(icon, size: 15, color: const Color(0xFF8A93A3)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              height: 1.18,
              fontWeight: FontWeight.w600,
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
        key: const ValueKey('story-memories.refresh.failure-banner'),
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
                '${l10n.storyMemoriesRefreshFailureTitle}. $message',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('story-memories.refresh.retry-action'),
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryMemoriesErrorView extends StatelessWidget {
  const _StoryMemoriesErrorView({
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

    return _MemoryCardShell(
      key: const ValueKey('story-memories.error-view'),
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
            key: const ValueKey('story-memories.error.retry-action'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

class _StoryMemoriesEmptyState extends StatelessWidget {
  const _StoryMemoriesEmptyState({
    required this.onCreateMemory,
  });

  final VoidCallback? onCreateMemory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _MemoryCardShell(
      key: const ValueKey('story-memories.empty-state'),
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
              Icons.bookmark_add_outlined,
              color: Color(0xFFFF5D72),
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.storyMemoriesEmptyTitle,
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
            l10n.storyMemoriesEmptyBody,
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
              key: const ValueKey('story-memories.empty.create-action'),
              onPressed: onCreateMemory,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5D72),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.storyMemoriesCreate),
            ),
          ],
        ],
      ),
    );
  }
}

class _StoryMemoriesLoadingView extends StatelessWidget {
  const _StoryMemoriesLoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('story-memories.loading-view'),
      children: const [
        Row(
          children: [
            _SkeletonBlock(width: 24, height: 160, radius: 999),
            SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBlock(width: 160, height: 26, radius: 999),
                  SizedBox(height: 10),
                  _SkeletonBlock(height: 104, radius: 18),
                  SizedBox(height: 10),
                  _SkeletonBlock(height: 104, radius: 18),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.height,
    this.width,
    this.radius = 24,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
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

class _MemoryCardShell extends StatelessWidget {
  const _MemoryCardShell({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            offset: Offset(0, 10),
            blurRadius: 22,
          ),
        ],
      ),
      child: child,
    );
  }
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
    return '';
  }

  return words.take(2).map((word) => word.substring(0, 1)).join();
}
