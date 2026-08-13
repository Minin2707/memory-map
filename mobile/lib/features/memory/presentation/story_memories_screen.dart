import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_state.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/presentation/memory_failure_message.dart';
import 'package:memory_map/features/memory/presentation/widgets/memory_tile.dart';
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          onBack?.call();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        floatingActionButton: onCreateMemory == null
            ? null
            : FloatingActionButton.extended(
                key: const ValueKey('story-memories.create-action'),
                onPressed: onCreateMemory,
                backgroundColor: const Color(0xFFFF5D72),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: Text(AppLocalizations.of(context).storyMemoriesCreate),
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
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  sliver: SliverToBoxAdapter(
                    child: _StoryMemoriesAppBar(
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
                ..._contentSlivers(context, ref, memoriesValue),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
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
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        sliver: SliverToBoxAdapter(
          child: _StoryMemoriesHeader(memoryCount: state.memories.length),
        ),
      ),
      if (state.memories.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Center(
              child: _StoryMemoriesEmptyState(
                onCreateMemory: onCreateMemory,
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverToBoxAdapter(
            child: _StoryMemoriesListCard(
              memories: state.memoryReadModels,
              onMemorySelected: onMemorySelected,
            ),
          ),
        ),
    ];
  }

  bool _isRefreshing(AsyncValue<StoryMemoriesState> value) {
    return value.asData?.value.isRefreshing ?? false;
  }
}

class _StoryMemoriesAppBar extends StatelessWidget {
  const _StoryMemoriesAppBar({
    required this.isRefreshing,
    required this.onBack,
    required this.onRefresh,
  });

  final bool isRefreshing;
  final VoidCallback? onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        IconButton(
          key: const ValueKey('story-memories.back-action'),
          onPressed: onBack,
          tooltip: l10n.storyMemoriesBackLabel,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        Expanded(
          child: Text(
            l10n.storyMemoriesPageTitle,
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
          key: const ValueKey('story-memories.refresh-action'),
          onPressed: isRefreshing ? null : onRefresh,
          tooltip: l10n.storyMemoriesRefreshAction,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _StoryMemoriesHeader extends StatelessWidget {
  const _StoryMemoriesHeader({
    required this.memoryCount,
  });

  final int memoryCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _MemoryCardShell(
      key: const ValueKey('story-memories.header-card'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE6EA),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: Color(0xFFFF5D72),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.storyMemoriesHeaderTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.storyMemoriesCount(memoryCount),
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 15,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryMemoriesListCard extends StatelessWidget {
  const _StoryMemoriesListCard({
    required this.memories,
    required this.onMemorySelected,
  });

  final List<MemoryReadModel> memories;
  final ValueChanged<Memory>? onMemorySelected;

  @override
  Widget build(BuildContext context) {
    return _MemoryCardShell(
      key: const ValueKey('story-memories.list-card'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < memories.length; index += 1) ...[
            if (index > 0) const Divider(height: 1, color: Color(0xFFE8EBEF)),
            MemoryTile(
              memory: memories[index].memory,
              previewPhoto: memories[index].previewPhoto,
              onSelected: onMemorySelected,
            ),
          ],
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
        _SkeletonBlock(height: 98),
        SizedBox(height: 18),
        _SkeletonBlock(height: 312),
      ],
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

class _MemoryCardShell extends StatelessWidget {
  const _MemoryCardShell({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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
