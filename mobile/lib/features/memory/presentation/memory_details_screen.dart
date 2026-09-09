import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/common/presentation/widgets/glass_circle_icon_button.dart';
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
import 'package:memory_map/features/media/presentation/widgets/memory_media_gallery.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const Color _memoryDetailsIvory = Color(0xFFFBF6F1);
const Color _memoryDetailsInk = Color(0xFF182331);
const Color _memoryDetailsMuted = Color(0xFF747B86);
const Color _memoryDetailsDustyCoral = Color(0xFFD16A74);
const Color _memoryDetailsWarmWhite = Color(0xFFFFFDFB);
const String _memoryDetailsDisplayFontFamily = 'NotoSerif';
const List<String> _memoryDetailsDisplayFontFallback = <String>[
  'NotoSerifGeorgian',
];

const double _memoryDetailsSectionGap = 26;
const double _memoryDetailsFirstSectionGap = 18;
const double _memoryDetailsDeleteGap = 24;
const double _memoryDetailsBottomGap = 28;
const double _memoryDetailsCardPadding = 16;
const double _memoryDetailsMapHeight = 158;
const double _memoryDetailsThumbnailSize = 98;
const double _memoryDetailsThumbnailGap = 12;

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
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _memoryDetailsIvory,
          body: RefreshIndicator(
            color: _memoryDetailsDustyCoral,
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
      return [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            24,
            MediaQuery.paddingOf(context).top + 24,
            24,
            0,
          ),
          sliver: const SliverToBoxAdapter(
            child: _MemoryDetailsLoadingView(),
          ),
        ),
      ];
    }

    if (detailsValue.hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.paddingOf(context).top + 24,
              24,
              24,
            ),
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
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.paddingOf(context).top + 24,
              24,
              24,
            ),
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
              color: _memoryDetailsDustyCoral,
              backgroundColor: Color(0xFFF2D8D1),
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
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          24,
          _memoryDetailsFirstSectionGap,
          24,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _MemoryTitleSection(memory: memory),
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
            canDeletePhoto: widget.canDeletePhoto && !isDeleting,
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
    final topInset = MediaQuery.paddingOf(context).top;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasPhotos = photos.isNotEmpty;
        final visibleHeight = hasPhotos
            ? (constraints.maxWidth * 0.78).clamp(300.0, 330.0).toDouble()
            : (constraints.maxWidth * 0.62).clamp(224.0, 250.0).toDouble();
        final height = visibleHeight + topInset;

        return SizedBox(
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
              const _MemoryHeroTopVeil(),
              if (hasPhotos) const _MemoryHeroIvoryFade(),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Row(
                      children: [
                        GlassCircleIconButton.icon(
                          key: const ValueKey('memory-details.back-action'),
                          tooltip: l10n.memoryDetailsBackLabel,
                          onPressed: editEnabled ? onBack : null,
                          icon: Icons.arrow_back_ios_new_rounded,
                          foregroundColor: _memoryDetailsInk,
                        ),
                        const Spacer(),
                        if (onEdit != null)
                          GlassCircleIconButton.icon(
                            key: const ValueKey('memory-details.edit-action'),
                            tooltip: l10n.memoryDetailsEditAction,
                            onPressed:
                                editEnabled ? () => onEdit!(memory) : null,
                            icon: Icons.edit_rounded,
                            foregroundColor: _memoryDetailsInk,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (photos.isNotEmpty)
                Positioned(
                  right: 24,
                  bottom: 34,
                  child: _HeroPhotoCounter(
                    photoCount: photos.length,
                    currentIndex: currentIndex,
                  ),
                ),
              if (photos.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18,
                  child: _HeroPageDots(
                    count: photos.length,
                    currentIndex: currentIndex,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MemoryTitleSection extends StatelessWidget {
  const _MemoryTitleSection({
    required this.memory,
  });

  final Memory memory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          memory.title,
          style: const TextStyle(
            color: _memoryDetailsInk,
            fontFamily: _memoryDetailsDisplayFontFamily,
            fontFamilyFallback: _memoryDetailsDisplayFontFallback,
            fontSize: 31,
            height: 1.14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          formatMemoryDate(l10n, memory.eventDate),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _memoryDetailsMuted,
            fontSize: 14,
            height: 1.35,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _MemoryHeroTopVeil extends StatelessWidget {
  const _MemoryHeroTopVeil();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _memoryDetailsIvory.withValues(alpha: 0.62),
              _memoryDetailsIvory.withValues(alpha: 0.12),
              _memoryDetailsIvory.withValues(alpha: 0),
            ],
            stops: const [0, 0.24, 0.52],
          ),
        ),
      ),
    );
  }
}

class _MemoryHeroIvoryFade extends StatelessWidget {
  const _MemoryHeroIvoryFade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: double.infinity,
          height: 82,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _memoryDetailsIvory.withValues(alpha: 0),
                  _memoryDetailsIvory.withValues(alpha: 0),
                  _memoryDetailsIvory.withValues(alpha: 0.10),
                  _memoryDetailsIvory.withValues(alpha: 0.35),
                  _memoryDetailsIvory.withValues(alpha: 0.75),
                  _memoryDetailsIvory,
                ],
                stops: const [0, 0.35, 0.60, 0.78, 0.92, 1],
              ),
            ),
          ),
        ),
      ),
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
      if (mediaIsLoading) {
        return const _MemoryHeroLoadingFallback(
          key: ValueKey('memory-details.hero.loading'),
        );
      }

      return const _MemoryHeroAtmosphericFallback(
        key: ValueKey('memory-details.hero.no-photo'),
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
              placeholder: const _MemoryHeroLoadingFallback(
                key: ValueKey('memory-details.hero.display-loading'),
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
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF3A4651),
            Color(0xFFD7A69F),
            Color(0xFFFBF6F1),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: _memoryDetailsWarmWhite.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _memoryDetailsWarmWhite.withValues(alpha: 0.30),
              width: 0.7,
            ),
          ),
          child: const Icon(
            Icons.broken_image_outlined,
            color: _memoryDetailsInk,
            size: 25,
          ),
        ),
      ),
    );
  }
}

class _MemoryHeroLoadingFallback extends StatelessWidget {
  const _MemoryHeroLoadingFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF8F4),
            Color(0xFFF4D8D3),
            Color(0xFFEAC8C2),
          ],
        ),
      ),
      child: Center(
        child: SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: _memoryDetailsDustyCoral,
          ),
        ),
      ),
    );
  }
}

class _MemoryHeroAtmosphericFallback extends StatelessWidget {
  const _MemoryHeroAtmosphericFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/memory_details_no_photo_hero.png',
      key: const ValueKey('memory-details.hero.no-photo.asset'),
      fit: BoxFit.cover,
    );
  }
}

class _HeroPhotoCounter extends StatelessWidget {
  const _HeroPhotoCounter({
    required this.photoCount,
    required this.currentIndex,
  });

  final int photoCount;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _memoryDetailsWarmWhite.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _memoryDetailsWarmWhite.withValues(alpha: 0.20),
          width: 0.6,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          '${currentIndex + 1} / $photoCount',
          key: const ValueKey('memory-details.hero.photo-counter'),
          style: const TextStyle(
            color: _memoryDetailsInk,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
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
                ? _memoryDetailsDustyCoral
                : _memoryDetailsWarmWhite.withValues(alpha: 0.62),
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
        color: Color(0xFF38414C),
        fontSize: 16,
        height: 1.50,
        fontWeight: FontWeight.w500,
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

    return KeyedSubtree(
      key: const ValueKey('memory-details.place-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (placeName != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _MemorySectionIconSurface(
                  icon: Icons.location_on_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    placeName,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _memoryDetailsInk,
                      fontSize: 16,
                      height: 1.34,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (onOpenMap != null) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const ValueKey('memory-details.open-map-action'),
                        onPressed: () => onOpenMap!(memory),
                        icon: const Icon(Icons.north_east_rounded, size: 16),
                        style: TextButton.styleFrom(
                          foregroundColor: _memoryDetailsDustyCoral,
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
              ],
            ),
            const SizedBox(height: 14),
          ] else if (onOpenMap != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('memory-details.open-map-action'),
                onPressed: () => onOpenMap!(memory),
                icon: const Icon(Icons.north_east_rounded, size: 16),
                style: TextButton.styleFrom(
                  foregroundColor: _memoryDetailsDustyCoral,
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
            const SizedBox(height: 14),
          ],
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
          decoration: const BoxDecoration(color: Color(0xFFF1E6DF)),
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
    required this.canDeletePhoto,
    required this.onPhotoSelected,
  });

  final String memoryId;
  final List<Media> photos;
  final AsyncValue<MemoryMediaState> mediaValue;
  final int selectedIndex;
  final bool canUploadPhoto;
  final bool canDeletePhoto;
  final ValueChanged<int> onPhotoSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uploadValue = ref.watch(uploadPhotoProvider(memoryId));
    final uploadState = uploadValue.asData?.value ?? const UploadPhotoState();
    final mediaState = mediaValue.asData?.value;
    final hideLoadedMediaToolbar = mediaState != null &&
        !mediaValue.isLoading &&
        mediaState.loadFailure == null &&
        !mediaValue.hasError;

    return KeyedSubtree(
      key: const ValueKey('memory-details.photos-section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hideLoadedMediaToolbar) ...[
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
                    foregroundColor: _memoryDetailsMuted,
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size.square(38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                ),
                if (canUploadPhoto)
                  Flexible(
                    child: _MemoryAddPhotoAction(
                      memoryId: memoryId,
                      uploadState: uploadState,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
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
              canUploadPhoto: canUploadPhoto,
              canDeletePhoto: canDeletePhoto,
              uploadState: uploadState,
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
    required this.canUploadPhoto,
    required this.canDeletePhoto,
    required this.uploadState,
    required this.onPhotoSelected,
  });

  final String memoryId;
  final List<Media> photos;
  final AsyncValue<MemoryMediaState> mediaValue;
  final int selectedIndex;
  final bool canUploadPhoto;
  final bool canDeletePhoto;
  final UploadPhotoState uploadState;
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
              color: _memoryDetailsDustyCoral,
              backgroundColor: Color(0xFFF2D8D1),
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
          _EmptyPhotosState(
            memoryId: memoryId,
            canUploadPhoto: canUploadPhoto,
            uploadState: uploadState,
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('memory-media.thumbnail-strip'),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var index = 0; index < photos.length; index += 1)
                        Padding(
                          padding: EdgeInsets.only(
                            left: index == 0 ? 0 : _memoryDetailsThumbnailGap,
                          ),
                          child: _PhotoStripThumbnail(
                            media: photos[index],
                            isSelected: index == selectedIndex,
                            onTap: () {
                              onPhotoSelected(index);
                              showMemoryMediaDisplayViewer(
                                context: context,
                                photos: photos,
                                initialIndex: index,
                                canDeletePhoto: canDeletePhoto,
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (canUploadPhoto) ...[
                const SizedBox(width: _memoryDetailsThumbnailGap),
                _MemoryAddPhotoTile(
                  memoryId: memoryId,
                  uploadState: uploadState,
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _EmptyPhotosState extends StatelessWidget {
  const _EmptyPhotosState({
    required this.memoryId,
    required this.canUploadPhoto,
    required this.uploadState,
  });

  final String memoryId;
  final bool canUploadPhoto;
  final UploadPhotoState uploadState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.memoryMediaEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _memoryDetailsMuted,
                fontSize: 15,
                height: 1.38,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            if (canUploadPhoto) ...[
              const SizedBox(height: 8),
              _MemoryAddPhotoAction(
                memoryId: memoryId,
                uploadState: uploadState,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemoryAddPhotoAction extends ConsumerWidget {
  const _MemoryAddPhotoAction({
    required this.memoryId,
    required this.uploadState,
  });

  final String memoryId;
  final UploadPhotoState uploadState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return TextButton.icon(
      key: const ValueKey('memory-media.add-photo-action'),
      onPressed: uploadState.isBusy
          ? null
          : () {
              ref
                  .read(uploadPhotoProvider(memoryId).notifier)
                  .selectPrepareAndUpload();
            },
      style: TextButton.styleFrom(
        foregroundColor: _memoryDetailsDustyCoral,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 38),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      icon: uploadState.isBusy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _memoryDetailsDustyCoral,
              ),
            )
          : const Icon(Icons.add_rounded, size: 18),
      label: Text(
        l10n.memoryMediaAddPhotoAction,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
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
        color: const Color(0xFFF1E6DF),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('memory-media.thumbnail.${media.id}'),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: _memoryDetailsThumbnailSize,
            height: _memoryDetailsThumbnailSize,
            padding: EdgeInsets.all(isSelected ? 3 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? _memoryDetailsDustyCoral
                    : _memoryDetailsInk.withValues(alpha: 0.06),
                width: isSelected ? 1.8 : 0.6,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isSelected ? 16 : 20),
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

class _MemoryAddPhotoTile extends ConsumerWidget {
  const _MemoryAddPhotoTile({
    required this.memoryId,
    required this.uploadState,
  });

  final String memoryId;
  final UploadPhotoState uploadState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      enabled: !uploadState.isBusy,
      label: l10n.memoryMediaAddPhotoAction,
      child: Material(
        color: const Color(0xFFFBE8E4),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('memory-media.add-photo-action'),
          onTap: uploadState.isBusy
              ? null
              : () {
                  ref
                      .read(uploadPhotoProvider(memoryId).notifier)
                      .selectPrepareAndUpload();
                },
          child: SizedBox.square(
            dimension: _memoryDetailsThumbnailSize,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (uploadState.isBusy)
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: _memoryDetailsDustyCoral,
                      ),
                    )
                  else
                    const Icon(
                      Icons.add_rounded,
                      color: _memoryDetailsDustyCoral,
                      size: 28,
                    ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.memoryMediaAddPhotoAction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _memoryDetailsDustyCoral,
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
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
          color: Color(0xFFF1E6DF),
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
      color: Color(0xFFF1E6DF),
      child: Center(
        child: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _memoryDetailsDustyCoral,
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
      color: Color(0xFFF1E6DF),
      child: Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: _memoryDetailsMuted,
        ),
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
          color: _memoryDetailsDustyCoral,
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

    return Column(
      key: const ValueKey('memory-details.delete-card'),
      children: [
        Divider(
          height: 1,
          color: _memoryDetailsInk.withValues(alpha: 0.10),
        ),
        const SizedBox(height: 18),
        Center(
          child: OutlinedButton.icon(
            key: const ValueKey('memory-details.delete-action'),
            onPressed: isDisabled ? null : onDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: _memoryDetailsDustyCoral,
              disabledForegroundColor: _memoryDetailsDustyCoral.withValues(
                alpha: 0.44,
              ),
              side: const BorderSide(color: Colors.transparent),
              backgroundColor: Colors.transparent,
              minimumSize: const Size(0, 44),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            icon: isDeleting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: _memoryDetailsDustyCoral,
                    ),
                  )
                : const Icon(Icons.delete_outline_rounded, size: 20),
            label: Text(
              isDeleting
                  ? l10n.deleteMemoryDeleting
                  : l10n.memoryDetailsDeleteAction,
            ),
          ),
        ),
      ],
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
          color: const Color(0xFFFFF8F5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _memoryDetailsDustyCoral.withValues(alpha: 0.24),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: _memoryDetailsDustyCoral,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _memoryDetailsMuted,
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
          color: const Color(0xFFFFF8F5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _memoryDetailsDustyCoral.withValues(alpha: 0.24),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: _memoryDetailsDustyCoral,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${l10n.memoryDetailsRefreshFailureTitle}. $message',
                style: const TextStyle(
                  color: _memoryDetailsMuted,
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
              color: const Color(0xFFF2D8D1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: _memoryDetailsDustyCoral,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _memoryDetailsInk,
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
              color: _memoryDetailsMuted,
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
        color: _memoryDetailsWarmWhite.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3C241E).withValues(alpha: 0.06),
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
        color: _memoryDetailsWarmWhite.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3C241E).withValues(alpha: 0.06),
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
        Icon(icon, color: _memoryDetailsDustyCoral, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _memoryDetailsInk,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _MemorySectionIconSurface extends StatelessWidget {
  const _MemorySectionIconSurface({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _memoryDetailsWarmWhite.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _memoryDetailsDustyCoral.withValues(alpha: 0.18),
        ),
      ),
      child: Icon(icon, color: _memoryDetailsDustyCoral, size: 21),
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
