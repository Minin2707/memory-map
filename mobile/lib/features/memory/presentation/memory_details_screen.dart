import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/delete_memory_notifier.dart';
import 'package:memory_map/features/memory/application/delete_memory_state.dart';
import 'package:memory_map/features/memory/application/memory_details_notifier.dart';
import 'package:memory_map/features/memory/application/memory_details_state.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/presentation/memory_date_format.dart';
import 'package:memory_map/features/memory/presentation/memory_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class MemoryDetailsScreen extends ConsumerStatefulWidget {
  const MemoryDetailsScreen({
    required this.memoryId,
    this.onBack,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  final String memoryId;
  final VoidCallback? onBack;
  final ValueChanged<Memory>? onEdit;
  final ValueChanged<Memory>? onDelete;

  @override
  ConsumerState<MemoryDetailsScreen> createState() =>
      _MemoryDetailsScreenState();
}

class _MemoryDetailsScreenState extends ConsumerState<MemoryDetailsScreen> {
  bool _deleteCompleted = false;

  @override
  void didUpdateWidget(MemoryDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memoryId != widget.memoryId) {
      _deleteCompleted = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailsValue = ref.watch(memoryDetailsProvider(widget.memoryId));
    final deleteValue = ref.watch(deleteMemoryProvider(widget.memoryId));
    final isDeleting = _isDeleting(deleteValue);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !isDeleting) {
          widget.onBack?.call();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: RefreshIndicator(
            color: const Color(0xFFFF5D72),
            onRefresh: () {
              if (isDeleting) {
                return Future<void>.value();
              }

              return ref
                  .read(memoryDetailsProvider(widget.memoryId).notifier)
                  .refreshMemory();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  sliver: SliverToBoxAdapter(
                    child: _MemoryDetailsAppBar(
                      isRefreshing: _isRefreshing(detailsValue),
                      isDeleting: isDeleting,
                      onBack: widget.onBack,
                      onRefresh: () {
                        ref
                            .read(
                              memoryDetailsProvider(widget.memoryId).notifier,
                            )
                            .refreshMemory();
                      },
                    ),
                  ),
                ),
                ..._contentSlivers(
                  context,
                  ref,
                  detailsValue,
                  deleteValue,
                  isDeleting,
                ),
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
    AsyncValue<MemoryDetailsState> detailsValue,
    AsyncValue<DeleteMemoryState> deleteValue,
    bool isDeleting,
  ) {
    final l10n = AppLocalizations.of(context);

    if (detailsValue.isLoading) {
      return const [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
          sliver: SliverToBoxAdapter(child: _MemoryDetailsLoadingView()),
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
              child: _MemoryDetailsErrorView(
                title: l10n.unexpectedErrorTitle,
                message: l10n.memoryFailureUnknown,
                onRetry: () {
                  ref
                      .read(memoryDetailsProvider(widget.memoryId).notifier)
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
              child: _MemoryDetailsErrorView(
                title: l10n.memoryDetailsLoadFailureTitle,
                message: memoryFailureMessage(l10n, loadFailure),
                onRetry: () {
                  ref
                      .read(memoryDetailsProvider(widget.memoryId).notifier)
                      .retryLoad();
                },
              ),
            ),
          ),
        ),
      ];
    }

    final memory = state.memory;
    if (memory == null) {
      return const [];
    }

    final deleteFailureMessage = _deleteFailureMessage(
      l10n,
      deleteValue,
      deleteValue.asData?.value ?? const DeleteMemoryState(),
    );
    final deleteActionDisabled = isDeleting || _deleteCompleted;

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
                    .read(memoryDetailsProvider(widget.memoryId).notifier)
                    .refreshMemory();
              },
            ),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        sliver: SliverToBoxAdapter(
          child: _MemoryHero(
            memory: memory,
            editEnabled: !isDeleting,
            onEdit: widget.onEdit,
          ),
        ),
      ),
      if (deleteFailureMessage != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverToBoxAdapter(
            child: _DeleteFailureBanner(message: deleteFailureMessage),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        sliver: SliverToBoxAdapter(
          child: _MemoryDescriptionCard(memory: memory),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        sliver: SliverToBoxAdapter(
          child: _MemoryPlaceCard(memory: memory),
        ),
      ),
      if (widget.onDelete != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          sliver: SliverToBoxAdapter(
            child: _DeleteMemoryCard(
              isDeleting: isDeleting,
              isDisabled: deleteActionDisabled,
              onDelete: () {
                _confirmDeleteMemory(memory);
              },
            ),
          ),
        ),
    ];
  }

  bool _isRefreshing(AsyncValue<MemoryDetailsState> value) {
    return value.asData?.value.isRefreshing ?? false;
  }

  bool _isDeleting(AsyncValue<DeleteMemoryState> value) {
    return value.asData?.value.isDeleting ?? false;
  }

  String? _deleteFailureMessage(
    AppLocalizations l10n,
    AsyncValue<DeleteMemoryState> deleteValue,
    DeleteMemoryState deleteState,
  ) {
    if (deleteValue.hasError) {
      return l10n.memoryFailureUnknown;
    }

    final failure = deleteState.deleteFailure;
    if (failure == null) {
      return null;
    }

    return memoryFailureMessage(l10n, failure);
  }

  Future<void> _confirmDeleteMemory(Memory memory) async {
    if (_deleteCompleted ||
        _isDeleting(ref.read(deleteMemoryProvider(widget.memoryId)))) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);

        return AlertDialog(
          title: Text(l10n.deleteMemoryDialogTitle),
          content: Text(l10n.deleteMemoryDialogBody),
          actions: [
            TextButton(
              key: const ValueKey('memory-details.delete.cancel-action'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(l10n.deleteMemoryCancel),
            ),
            FilledButton(
              key: const ValueKey('memory-details.delete.confirm-action'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5D72),
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.deleteMemoryConfirm),
            ),
          ],
        );
      },
    );

    if (!mounted ||
        confirmed != true ||
        _deleteCompleted ||
        _isDeleting(ref.read(deleteMemoryProvider(widget.memoryId)))) {
      return;
    }

    final provider = deleteMemoryProvider(widget.memoryId);
    final notifier = ref.read(provider.notifier);
    if (ref.read(provider).hasError) {
      notifier.reset();
    }

    final success = await notifier.deleteMemory(memory);
    if (!mounted || !success) {
      return;
    }

    setState(() {
      _deleteCompleted = true;
    });
    widget.onDelete?.call(memory);
  }
}

class _MemoryDetailsAppBar extends StatelessWidget {
  const _MemoryDetailsAppBar({
    required this.isRefreshing,
    required this.isDeleting,
    required this.onBack,
    required this.onRefresh,
  });

  final bool isRefreshing;
  final bool isDeleting;
  final VoidCallback? onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        IconButton(
          key: const ValueKey('memory-details.back-action'),
          onPressed: isDeleting ? null : onBack,
          tooltip: l10n.memoryDetailsBackLabel,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        Expanded(
          child: Text(
            l10n.memoryDetailsPageTitle,
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
          key: const ValueKey('memory-details.refresh-action'),
          onPressed: isRefreshing || isDeleting ? null : onRefresh,
          tooltip: l10n.memoryDetailsRefreshAction,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _MemoryHero extends StatelessWidget {
  const _MemoryHero({
    required this.memory,
    required this.editEnabled,
    required this.onEdit,
  });

  final Memory memory;
  final bool editEnabled;
  final ValueChanged<Memory>? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: const ValueKey('memory-details.hero'),
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
              Expanded(
                child: _HeroDatePill(memory: memory),
              ),
              if (onEdit != null)
                IconButton.filled(
                  key: const ValueKey('memory-details.edit-action'),
                  onPressed:
                      editEnabled ? () => onEdit!(memory) : null,
                  tooltip: l10n.memoryDetailsEditAction,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFFF5D72),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                ),
            ],
          ),
          const SizedBox(height: 34),
          Text(
            memory.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              height: 1.12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDatePill extends StatelessWidget {
  const _HeroDatePill({
    required this.memory,
  });

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0x2EFFFFFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x3DFFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                formatMemoryDate(l10n, memory.eventDate),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryDescriptionCard extends StatelessWidget {
  const _MemoryDescriptionCard({
    required this.memory,
  });

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final description = _visibleText(memory.description);

    return _DetailsCard(
      key: const ValueKey('memory-details.description-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.notes_rounded,
            title: l10n.memoryDetailsDescriptionTitle,
          ),
          const SizedBox(height: 14),
          Text(
            description ?? l10n.memoryDetailsNoDescription,
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

class _MemoryPlaceCard extends StatelessWidget {
  const _MemoryPlaceCard({
    required this.memory,
  });

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final placeName = _visibleText(memory.placeName);

    return _DetailsCard(
      key: const ValueKey('memory-details.place-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.place_rounded,
            title: l10n.memoryDetailsPlaceTitle,
          ),
          const SizedBox(height: 14),
          Text(
            placeName ?? l10n.memoryDetailsNoPlace,
            style: TextStyle(
              color: placeName == null
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

class _DeleteMemoryCard extends StatelessWidget {
  const _DeleteMemoryCard({
    required this.isDeleting,
    required this.isDisabled,
    required this.onDelete,
  });

  final bool isDeleting;
  final bool isDisabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _DetailsCard(
      key: const ValueKey('memory-details.delete-card'),
      child: OutlinedButton.icon(
        key: const ValueKey('memory-details.delete-action'),
        onPressed: isDisabled ? null : onDelete,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFF5D72),
          side: const BorderSide(color: Color(0xFFFF8A99)),
          minimumSize: const Size.fromHeight(56),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        icon: isDeleting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF5D72),
                ),
              )
            : const Icon(Icons.delete_outline_rounded),
        label: Text(
          isDeleting
              ? l10n.deleteMemoryDeleting
              : l10n.memoryDetailsDeleteAction,
        ),
      ),
    );
  }
}

class _DeleteFailureBanner extends StatelessWidget {
  const _DeleteFailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('memory-details.delete.failure-banner'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7F8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD6DC)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFFFF5D72),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ),
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
        key: const ValueKey('memory-details.refresh.failure-banner'),
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
                '${l10n.memoryDetailsRefreshFailureTitle}. $message',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('memory-details.refresh.retry-action'),
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryDetailsErrorView extends StatelessWidget {
  const _MemoryDetailsErrorView({
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
      key: const ValueKey('memory-details.error-view'),
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
            key: const ValueKey('memory-details.error.retry-action'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

class _MemoryDetailsLoadingView extends StatelessWidget {
  const _MemoryDetailsLoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('memory-details.loading-view'),
      children: const [
        _SkeletonBlock(height: 214, radius: 30),
        SizedBox(height: 18),
        _SkeletonBlock(height: 132, radius: 24),
        SizedBox(height: 18),
        _SkeletonBlock(height: 112, radius: 24),
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

String? _visibleText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return value;
}
