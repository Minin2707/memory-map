import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/map/config/map_source_configuration.dart';
import 'package:memory_map/features/map/domain/map_camera.dart';
import 'package:memory_map/features/map/domain/map_coordinate.dart';
import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/map/presentation/widgets/maplibre_marker_map.dart';
import 'package:memory_map/features/memory/application/delete_memory_notifier.dart';
import 'package:memory_map/features/memory/application/delete_memory_state.dart';
import 'package:memory_map/features/memory/application/memory_details_notifier.dart';
import 'package:memory_map/features/memory/application/memory_details_state.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/presentation/memory_date_format.dart';
import 'package:memory_map/features/memory/presentation/memory_failure_message.dart';
import 'package:memory_map/features/media/application/memory_media_notifier.dart';
import 'package:memory_map/features/media/application/memory_media_state.dart';
import 'package:memory_map/features/media/application/upload_photo_notifier.dart';
import 'package:memory_map/features/media/application/upload_photo_state.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/presentation/media_failure_message.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const double _memoryDetailsSectionGap = 14;
const double _memoryDetailsFirstSectionGap = 14;
const double _memoryDetailsDeleteGap = 16;
const double _memoryDetailsBottomGap = 22;
const double _memoryDetailsCardPadding = 16;
const double _memoryDetailsMapHeight = 148;
const double _memoryDetailsThumbnailSize = 78;
const double _memoryDetailsThumbnailGap = 8;

typedef MemoryLocationMapBuilder = Widget Function(
  BuildContext context,
  MemoryLocationMapConfiguration configuration,
);

final class MemoryLocationMapConfiguration {
  MemoryLocationMapConfiguration({
    required this.marker,
    required this.sourceConfiguration,
    required this.cameraCommand,
  });

  final MapMarker marker;
  final MapSourceConfiguration sourceConfiguration;
  final MapCameraCommand cameraCommand;

  @override
  String toString() {
    return 'MemoryLocationMapConfiguration(hasMarker: true, '
        'hasCameraCommand: true)';
  }
}

class MemoryDetailsScreen extends ConsumerStatefulWidget {
  const MemoryDetailsScreen({
    required this.memoryId,
    this.onBack,
    this.onEdit,
    this.onDelete,
    this.onOpenMap,
    this.mapBuilder = defaultMemoryLocationMapBuilder,
    this.canUploadPhoto = false,
    this.canDeletePhoto = false,
    super.key,
  });

  final String memoryId;
  final VoidCallback? onBack;
  final ValueChanged<Memory>? onEdit;
  final ValueChanged<Memory>? onDelete;
  final ValueChanged<Memory>? onOpenMap;
  final MemoryLocationMapBuilder mapBuilder;
  final bool canUploadPhoto;
  final bool canDeletePhoto;

  @override
  ConsumerState<MemoryDetailsScreen> createState() =>
      _MemoryDetailsScreenState();
}

class _MemoryDetailsScreenState extends ConsumerState<MemoryDetailsScreen> {
  bool _deleteCompleted = false;
  late PageController _heroPageController;
  int _heroPhotoIndex = 0;

  @override
  void initState() {
    super.initState();
    _heroPageController = PageController();
  }

  @override
  void didUpdateWidget(MemoryDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memoryId != widget.memoryId) {
      _deleteCompleted = false;
      _heroPhotoIndex = 0;
      _heroPageController.dispose();
      _heroPageController = PageController();
    }
  }

  @override
  void dispose() {
    _heroPageController.dispose();
    super.dispose();
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
              key: const ValueKey('memory-details.scrollable'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                ..._contentSlivers(
                  context,
                  ref,
                  detailsValue,
                  deleteValue,
                  isDeleting,
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: _memoryDetailsBottomGap),
                ),
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

    final mediaValue = ref.watch(memoryMediaProvider(widget.memoryId));
    final heroPhotos = _heroPhotos(mediaValue);
    _reconcileHeroPhotoIndex(heroPhotos.length);
    final description = _visibleText(memory.description);
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
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
        sliver: SliverToBoxAdapter(
          child: _MemoryPhotoHero(
            memory: memory,
            photos: heroPhotos,
            mediaIsLoading: _isHeroMediaLoading(mediaValue),
            pageController: _heroPageController,
            currentIndex: _heroPhotoIndex,
            onPageChanged: (index) {
              setState(() {
                _heroPhotoIndex = index;
              });
            },
            onBack: widget.onBack,
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
      if (description != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            24,
            _memoryDetailsFirstSectionGap,
            24,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: _MemoryDescriptionSection(description: description),
          ),
        ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          24,
          description == null
              ? _memoryDetailsFirstSectionGap
              : _memoryDetailsSectionGap,
          24,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _MemoryPlaceSection(
            memory: memory,
            onOpenMap: widget.onOpenMap,
            mapBuilder: widget.mapBuilder,
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          24,
          _memoryDetailsSectionGap,
          24,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _MemoryPhotosStripSection(
            memoryId: memory.id,
            photos: heroPhotos,
            mediaValue: mediaValue,
            selectedIndex: _heroPhotoIndex,
            canUploadPhoto: widget.canUploadPhoto && !isDeleting,
            onPhotoSelected: _showHeroPhotoAt,
          ),
        ),
      ),
      if (widget.onDelete != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            24,
            _memoryDetailsDeleteGap,
            24,
            0,
          ),
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

  List<Media> _heroPhotos(AsyncValue<MemoryMediaState> mediaValue) {
    final state = mediaValue.asData?.value;
    if (state == null || state.loadFailure != null) {
      return const [];
    }

    return state.media.where((media) => media.isPhoto).toList(growable: false);
  }

  bool _isHeroMediaLoading(AsyncValue<MemoryMediaState> mediaValue) {
    final state = mediaValue.asData?.value;
    if (state == null) {
      return mediaValue.isLoading;
    }

    return mediaValue.isLoading || state.isRefreshing;
  }

  void _reconcileHeroPhotoIndex(int photoCount) {
    final nextIndex = photoCount == 0
        ? 0
        : _heroPhotoIndex.clamp(0, photoCount - 1);
    if (nextIndex == _heroPhotoIndex) {
      return;
    }

    _heroPhotoIndex = nextIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_heroPageController.hasClients) {
        return;
      }

      _heroPageController.jumpToPage(nextIndex);
    });
  }

  void _showHeroPhotoAt(int index) {
    if (index < 0) {
      return;
    }

    final photoCount = _heroPhotos(ref.read(memoryMediaProvider(widget.memoryId)))
        .length;
    if (index >= photoCount) {
      return;
    }

    setState(() {
      _heroPhotoIndex = index;
    });

    if (!_heroPageController.hasClients) {
      _heroPageController.dispose();
      _heroPageController = PageController(initialPage: index);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_heroPageController.hasClients) {
        return;
      }

      _heroPageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
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

class _MemoryPhotoHero extends StatelessWidget {
  const _MemoryPhotoHero({
    required this.memory,
    required this.photos,
    required this.mediaIsLoading,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onBack,
    required this.editEnabled,
    required this.onEdit,
  });

  final Memory memory;
  final List<Media> photos;
  final bool mediaIsLoading;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onBack;
  final bool editEnabled;
  final ValueChanged<Memory>? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height =
            (constraints.maxWidth * 0.78).clamp(286.0, 430.0).toDouble();

        return Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(30),
              ),
              child: SizedBox(
                key: const ValueKey('memory-details.hero'),
                height: height,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _MemoryHeroMedia(
                      photos: photos,
                      mediaIsLoading: mediaIsLoading,
                      pageController: pageController,
                      onPageChanged: onPageChanged,
                    ),
                    const _MemoryHeroScrim(),
                    Positioned(
                      left: 12,
                      top: 10,
                      child: _HeroCircleButton(
                        buttonKey:
                            const ValueKey('memory-details.back-action'),
                        tooltip: l10n.memoryDetailsBackLabel,
                        onPressed: editEnabled ? onBack : null,
                        icon: Icons.arrow_back_ios_new_rounded,
                      ),
                    ),
                    if (onEdit != null)
                      Positioned(
                        right: 12,
                        top: 10,
                        child: _HeroCircleButton(
                          buttonKey:
                              const ValueKey('memory-details.edit-action'),
                          tooltip: l10n.memoryDetailsEditAction,
                          onPressed:
                              editEnabled ? () => onEdit!(memory) : null,
                          icon: Icons.edit_rounded,
                        ),
                      ),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 24,
                      child: _MemoryHeroText(
                        memory: memory,
                        photoCount: photos.length,
                        currentIndex: currentIndex,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (photos.length > 1) ...[
              const SizedBox(height: 8),
              _HeroPageDots(
                count: photos.length,
                currentIndex: currentIndex,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MemoryHeroMedia extends StatelessWidget {
  const _MemoryHeroMedia({
    required this.photos,
    required this.mediaIsLoading,
    required this.pageController,
    required this.onPageChanged,
  });

  final List<Media> photos;
  final bool mediaIsLoading;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return _MemoryHeroFallback(
        key: const ValueKey('memory-details.hero.no-photo'),
        isLoading: mediaIsLoading,
      );
    }

    return PageView.builder(
      key: const ValueKey('memory-details.hero.page-view'),
      controller: pageController,
      itemCount: photos.length,
      onPageChanged: onPageChanged,
      itemBuilder: (context, index) {
        final photo = photos[index];

        return LayoutBuilder(
          builder: (context, constraints) {
            final decodeSize = authenticatedMediaDisplayDecodeSize(
              logicalSize: constraints.biggest,
              devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
            );
            return AuthenticatedMediaImage(
              key: ValueKey('memory-details.hero.display.${photo.id}'),
              media: photo,
              representation: AuthenticatedMediaRepresentation.display,
              fit: BoxFit.cover,
              cacheWidth: decodeSize.cacheWidth,
              cacheHeight: decodeSize.cacheHeight,
              placeholder: const _MemoryHeroFallback(
                key: ValueKey('memory-details.hero.display-loading'),
                isLoading: true,
              ),
              errorBuilder: (context) {
                return const _MemoryHeroFallback(
                  key: ValueKey('memory-details.hero.display-failure'),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MemoryHeroFallback extends StatelessWidget {
  const _MemoryHeroFallback({
    this.isLoading = false,
    super.key,
  });

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFA3AE),
            Color(0xFFFF6A7C),
            Color(0xFF6EA79E),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x33FFFFFF)),
          ),
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.all(25),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.photo_camera_outlined,
                  color: Colors.white,
                  size: 38,
                ),
        ),
      ),
    );
  }
}

class _MemoryHeroScrim extends StatelessWidget {
  const _MemoryHeroScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.42),
              Colors.black.withValues(alpha: 0.04),
              Colors.black.withValues(alpha: 0.70),
            ],
            stops: const [0, 0.48, 1],
          ),
        ),
      ),
    );
  }
}

class _MemoryHeroText extends StatelessWidget {
  const _MemoryHeroText({
    required this.memory,
    required this.photoCount,
    required this.currentIndex,
  });

  final Memory memory;
  final int photoCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          memory.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            height: 1.08,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _HeroDateText(memory: memory),
            ),
            if (photoCount > 0) ...[
              const SizedBox(width: 14),
              Text(
                '${currentIndex + 1} / $photoCount',
                key: const ValueKey('memory-details.hero.photo-counter'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _HeroDateText extends StatelessWidget {
  const _HeroDateText({
    required this.memory,
  });

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Text(
      formatMemoryDate(l10n, memory.eventDate),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFFEFF5F4),
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _HeroCircleButton extends StatelessWidget {
  const _HeroCircleButton({
    required this.buttonKey,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final Key buttonKey;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      key: buttonKey,
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.88),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.54),
        foregroundColor: const Color(0xFF28323C),
        disabledForegroundColor: const Color(0xFF8A93A3),
      ),
      icon: Icon(icon, size: 21),
    );
  }
}

class _HeroPageDots extends StatelessWidget {
  const _HeroPageDots({
    required this.count,
    required this.currentIndex,
  });

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('memory-details.hero.page-indicator'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isSelected = index == currentIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: isSelected ? 16 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF64717F)
                : const Color(0xFFE1E6ED),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

class _MemoryDescriptionSection extends StatelessWidget {
  const _MemoryDescriptionSection({
    required this.description,
  });

  final String description;

  @override
  Widget build(BuildContext context) {
    return Text(
      description,
      key: const ValueKey('memory-details.description-section'),
      style: const TextStyle(
        color: Color(0xFF3E4754),
        fontSize: 16,
        height: 1.44,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }
}

class _MemoryPlaceSection extends StatelessWidget {
  const _MemoryPlaceSection({
    required this.memory,
    required this.onOpenMap,
    required this.mapBuilder,
  });

  final Memory memory;
  final ValueChanged<Memory>? onOpenMap;
  final MemoryLocationMapBuilder mapBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final placeName = _visibleText(memory.placeName);
    final configuration = _memoryLocationMapConfiguration(memory);

    return _DetailsCard(
      key: const ValueKey('memory-details.place-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionTitle(
                  icon: Icons.place_rounded,
                  title: l10n.memoryDetailsPlaceTitle,
                ),
              ),
              if (onOpenMap != null)
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const ValueKey('memory-details.open-map-action'),
                      onPressed: () => onOpenMap!(memory),
                      icon: const Icon(Icons.map_rounded, size: 17),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFF5D72),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      label: Text(
                        l10n.memoryDetailsOpenOnMapAction,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (placeName != null) ...[
            const SizedBox(height: 7),
            Text(
              placeName,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 15,
                height: 1.32,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _MemoryLocationMapPreview(
            configuration: configuration,
            mapBuilder: mapBuilder,
          ),
        ],
      ),
    );
  }
}

class _MemoryLocationMapPreview extends StatelessWidget {
  const _MemoryLocationMapPreview({
    required this.configuration,
    required this.mapBuilder,
  });

  final MemoryLocationMapConfiguration configuration;
  final MemoryLocationMapBuilder mapBuilder;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        key: const ValueKey('memory-details.map-preview'),
        height: _memoryDetailsMapHeight,
        width: double.infinity,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xFFEAF0F5)),
          child: _SafeMemoryLocationMap(
            configuration: configuration,
            mapBuilder: mapBuilder,
          ),
        ),
      ),
    );
  }
}

class _SafeMemoryLocationMap extends StatelessWidget {
  const _SafeMemoryLocationMap({
    required this.configuration,
    required this.mapBuilder,
  });

  final MemoryLocationMapConfiguration configuration;
  final MemoryLocationMapBuilder mapBuilder;

  @override
  Widget build(BuildContext context) {
    try {
      return mapBuilder(context, configuration);
    } catch (_) {
      return const _MemoryLocationMapUnavailable();
    }
  }
}

class _MemoryLocationMapUnavailable extends StatelessWidget {
  const _MemoryLocationMapUnavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          l10n.memoryDetailsMapUnavailable,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _MemoryPhotosStripSection extends ConsumerWidget {
  const _MemoryPhotosStripSection({
    required this.memoryId,
    required this.photos,
    required this.mediaValue,
    required this.selectedIndex,
    required this.canUploadPhoto,
    required this.onPhotoSelected,
  });

  final String memoryId;
  final List<Media> photos;
  final AsyncValue<MemoryMediaState> mediaValue;
  final int selectedIndex;
  final bool canUploadPhoto;
  final ValueChanged<int> onPhotoSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uploadValue = ref.watch(uploadPhotoProvider(memoryId));
    final uploadState = uploadValue.asData?.value ?? const UploadPhotoState();

    return _DetailsCard(
      key: const ValueKey('memory-details.photos-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SectionTitle(
                  icon: Icons.photo_library_rounded,
                  title: l10n.memoryMediaTitle,
                ),
              ),
              IconButton(
                key: const ValueKey('memory-media.refresh-action'),
                onPressed: mediaValue.isLoading ||
                        uploadState.isBusy ||
                        _isRefreshing(mediaValue)
                    ? null
                    : () {
                        ref
                            .read(memoryMediaProvider(memoryId).notifier)
                            .refreshMedia();
                      },
                tooltip: l10n.memoryMediaRefreshAction,
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size.square(38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.refresh_rounded),
              ),
              if (canUploadPhoto)
                IconButton.filled(
                  key: const ValueKey('memory-media.add-photo-action'),
                  onPressed: uploadState.isBusy
                      ? null
                      : () {
                          ref
                              .read(uploadPhotoProvider(memoryId).notifier)
                              .selectPrepareAndUpload();
                        },
                  tooltip: l10n.memoryMediaAddPhotoAction,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5D72),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size.square(38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: uploadState.isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.add_photo_alternate_rounded),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (uploadState.phase == UploadPhotoPhase.selecting)
            _MediaStatusBanner(message: l10n.memoryMediaSelectingPhoto),
          if (uploadState.phase == UploadPhotoPhase.preparing)
            _MediaStatusBanner(message: l10n.memoryMediaPreparingPhoto),
          if (uploadState.phase == UploadPhotoPhase.uploading)
            _MediaStatusBanner(message: l10n.memoryMediaUploadingPhoto),
          if (uploadState.failure != null)
            _MediaFailureBanner(
              message: mediaFailureMessage(l10n, uploadState.failure!),
            ),
          if (uploadValue.hasError)
            _MediaFailureBanner(message: l10n.mediaFailureUnknown),
          if (mediaValue.hasError)
            _MediaFailureBanner(message: l10n.mediaFailureUnknown)
          else
            _MemoryPhotosStripContent(
              memoryId: memoryId,
              photos: photos,
              mediaValue: mediaValue,
              selectedIndex: selectedIndex,
              onPhotoSelected: onPhotoSelected,
            ),
        ],
      ),
    );
  }

  bool _isRefreshing(AsyncValue<MemoryMediaState> value) {
    return value.asData?.value.isRefreshing ?? false;
  }
}

class _MemoryPhotosStripContent extends ConsumerWidget {
  const _MemoryPhotosStripContent({
    required this.memoryId,
    required this.photos,
    required this.mediaValue,
    required this.selectedIndex,
    required this.onPhotoSelected,
  });

  final String memoryId;
  final List<Media> photos;
  final AsyncValue<MemoryMediaState> mediaValue;
  final int selectedIndex;
  final ValueChanged<int> onPhotoSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (mediaValue.isLoading) {
      return const _PhotoStripSkeleton();
    }

    final state = mediaValue.asData?.value;
    if (state == null) {
      return const SizedBox.shrink();
    }

    final loadFailure = state.loadFailure;
    if (loadFailure != null) {
      return _MediaRetryFailure(
        message: mediaFailureMessage(l10n, loadFailure),
        onRetry: () {
          ref.read(memoryMediaProvider(memoryId).notifier).retryLoad();
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.isRefreshing)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(
              minHeight: 3,
              color: Color(0xFFFF5D72),
              backgroundColor: Color(0xFFFFE6EA),
            ),
          ),
        if (state.refreshFailure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MediaRetryFailure(
              message: mediaFailureMessage(l10n, state.refreshFailure!),
              onRetry: () {
                ref.read(memoryMediaProvider(memoryId).notifier).refreshMedia();
              },
            ),
          ),
        if (photos.isEmpty)
          Text(
            l10n.memoryMediaEmpty,
            style: const TextStyle(
              color: Color(0xFF8A93A3),
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          )
        else
          SingleChildScrollView(
            key: const ValueKey('memory-media.thumbnail-strip'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < photos.length; index += 1) ...[
                  if (index > 0)
                    const SizedBox(width: _memoryDetailsThumbnailGap),
                  _PhotoStripThumbnail(
                    media: photos[index],
                    isSelected: index == selectedIndex,
                    onTap: () {
                      onPhotoSelected(index);
                    },
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PhotoStripThumbnail extends StatelessWidget {
  const _PhotoStripThumbnail({
    required this.media,
    required this.isSelected,
    required this.onTap,
  });

  final Media media;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      label: l10n.memoryMediaOpenPhotoLabel,
      image: true,
      selected: isSelected,
      button: true,
      child: Material(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('memory-media.thumbnail.${media.id}'),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: _memoryDetailsThumbnailSize,
            height: _memoryDetailsThumbnailSize,
            padding: EdgeInsets.all(isSelected ? 2 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFFF5D72)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isSelected ? 13 : 16),
              child: AuthenticatedMediaImage(
                media: media,
                representation: AuthenticatedMediaRepresentation.thumbnail,
                fit: BoxFit.cover,
                placeholder: const _PhotoThumbnailPlaceholder(),
                errorBuilder: (_) => const _PhotoThumbnailErrorPlaceholder(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoStripSkeleton extends StatelessWidget {
  const _PhotoStripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('memory-media.loading-view'),
      children: const [
        _PhotoSkeletonSquare(),
        SizedBox(width: _memoryDetailsThumbnailGap),
        _PhotoSkeletonSquare(),
        SizedBox(width: _memoryDetailsThumbnailGap),
        _PhotoSkeletonSquare(),
      ],
    );
  }
}

class _PhotoSkeletonSquare extends StatelessWidget {
  const _PhotoSkeletonSquare();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _memoryDetailsThumbnailSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFFF3F5F8),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _PhotoThumbnailPlaceholder extends StatelessWidget {
  const _PhotoThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF3F5F8),
      child: Center(
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFFF5D72),
          ),
        ),
      ),
    );
  }
}

class _PhotoThumbnailErrorPlaceholder extends StatelessWidget {
  const _PhotoThumbnailErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF3F5F8),
      child: Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: Color(0xFF8A93A3),
        ),
      ),
    );
  }
}

class _MediaStatusBanner extends StatelessWidget {
  const _MediaStatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFFF5D72),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaFailureBanner extends StatelessWidget {
  const _MediaFailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFFF5D72),
          fontWeight: FontWeight.w700,
          height: 1.35,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MediaRetryFailure extends StatelessWidget {
  const _MediaRetryFailure({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(child: _MediaFailureBanner(message: message)),
        TextButton(
          key: const ValueKey('memory-media.retry-action'),
          onPressed: onRetry,
          child: Text(l10n.retry),
        ),
      ],
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
          side: const BorderSide(color: Color(0xFFFFCAD2)),
          backgroundColor: const Color(0xFFFFFAFB),
          minimumSize: const Size.fromHeight(48),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        icon: isDeleting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: Color(0xFFFF5D72),
                ),
              )
            : const Icon(Icons.delete_outline_rounded, size: 20),
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
      padding: const EdgeInsets.all(_memoryDetailsCardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            offset: Offset(0, 8),
            blurRadius: 22,
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
        Icon(icon, color: const Color(0xFFFF5D72), size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 17,
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

MemoryLocationMapConfiguration _memoryLocationMapConfiguration(Memory memory) {
  final coordinate = MapCoordinate(
    latitude: memory.location.latitude,
    longitude: memory.location.longitude,
  );

  return MemoryLocationMapConfiguration(
    marker: MapMarker(id: memory.id, coordinate: coordinate),
    sourceConfiguration: MapSources.openFreeMapLiberty,
    cameraCommand: MapCameraCommand(
      revision: 1,
      target: MapCameraTarget.point(
        coordinate: coordinate,
        zoom: 13.0,
      ),
    ),
  );
}

Widget defaultMemoryLocationMapBuilder(
  BuildContext context,
  MemoryLocationMapConfiguration configuration,
) {
  return IgnorePointer(
    child: MapLibreMarkerMap(
      markers: [configuration.marker],
      sourceConfiguration: configuration.sourceConfiguration,
      selectedMarkerId: configuration.marker.id,
      cameraCommand: configuration.cameraCommand,
    ),
  );
}
