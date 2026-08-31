import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/common/presentation/widgets/glass_circle_icon_button.dart';
import 'package:memory_map/features/media/application/delete_media_notifier.dart';
import 'package:memory_map/features/media/application/delete_media_state.dart';
import 'package:memory_map/features/media/application/memory_media_notifier.dart';
import 'package:memory_map/features/media/application/memory_media_state.dart';
import 'package:memory_map/features/media/application/upload_photo_notifier.dart';
import 'package:memory_map/features/media/application/upload_photo_state.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/features/media/presentation/media_failure_message.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class MemoryMediaGallery extends ConsumerWidget {
  const MemoryMediaGallery({
    required this.memoryId,
    required this.canUploadPhoto,
    required this.canDeletePhoto,
    super.key,
  });

  final String memoryId;
  final bool canUploadPhoto;
  final bool canDeletePhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mediaValue = ref.watch(memoryMediaProvider(memoryId));
    final uploadValue = ref.watch(uploadPhotoProvider(memoryId));
    final uploadState = uploadValue.asData?.value ?? const UploadPhotoState();

    return _MediaCard(
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
          const SizedBox(height: 14),
          if (uploadState.phase == UploadPhotoPhase.selecting)
            _StatusBanner(message: l10n.memoryMediaSelectingPhoto),
          if (uploadState.phase == UploadPhotoPhase.preparing)
            _StatusBanner(message: l10n.memoryMediaPreparingPhoto),
          if (uploadState.phase == UploadPhotoPhase.uploading)
            _StatusBanner(message: l10n.memoryMediaUploadingPhoto),
          if (uploadState.failure != null)
            _FailureBanner(
              message: mediaFailureMessage(l10n, uploadState.failure!),
            ),
          if (uploadValue.hasError)
            _FailureBanner(message: l10n.mediaFailureUnknown),
          if (mediaValue.hasError)
            _FailureBanner(message: l10n.mediaFailureUnknown)
          else
            _MediaContent(
              memoryId: memoryId,
              mediaValue: mediaValue,
              canDeletePhoto: canDeletePhoto,
            ),
        ],
      ),
    );
  }

  bool _isRefreshing(AsyncValue<MemoryMediaState> value) {
    return value.asData?.value.isRefreshing ?? false;
  }
}

class _MediaContent extends ConsumerWidget {
  const _MediaContent({
    required this.memoryId,
    required this.mediaValue,
    required this.canDeletePhoto,
  });

  final String memoryId;
  final AsyncValue<MemoryMediaState> mediaValue;
  final bool canDeletePhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (mediaValue.isLoading) {
      return const _GallerySkeleton();
    }

    final state = mediaValue.asData?.value;
    if (state == null) {
      return const SizedBox.shrink();
    }

    final loadFailure = state.loadFailure;
    if (loadFailure != null) {
      return _RetryFailure(
        message: mediaFailureMessage(l10n, loadFailure),
        onRetry: () {
          ref.read(memoryMediaProvider(memoryId).notifier).retryLoad();
        },
      );
    }

    final refreshFailure = state.refreshFailure;
    final photos = state.media.where((media) => media.isPhoto).toList();
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
        if (refreshFailure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RetryFailure(
              message: mediaFailureMessage(l10n, refreshFailure),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 4 : 3;
              return GridView.builder(
                key: const ValueKey('memory-media.thumbnail-grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: photos.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final media = photos[index];
                  return _ThumbnailTile(
                    media: media,
                    canDeletePhoto: canDeletePhoto,
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({
    required this.media,
    required this.canDeletePhoto,
  });

  final Media media;
  final bool canDeletePhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: const Color(0xFFF3F5F8),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('memory-media.thumbnail.${media.id}'),
        onTap: () {
          showDialog<void>(
            context: context,
            builder: (context) {
              return _DisplayDialog(
                media: media,
                canDeletePhoto: canDeletePhoto,
              );
            },
          );
        },
        child: Semantics(
          label: l10n.memoryMediaOpenPhotoLabel,
          image: true,
          child: AuthenticatedMediaImage(
            media: media,
            representation: AuthenticatedMediaRepresentation.thumbnail,
            fit: BoxFit.cover,
            placeholder: const _ImagePlaceholder(),
            errorBuilder: (_) => const _ImageErrorPlaceholder(),
          ),
        ),
      ),
    );
  }
}

class _DisplayDialog extends ConsumerStatefulWidget {
  const _DisplayDialog({
    required this.media,
    required this.canDeletePhoto,
  });

  final Media media;
  final bool canDeletePhoto;

  @override
  ConsumerState<_DisplayDialog> createState() => _DisplayDialogState();
}

class _DisplayDialogState extends ConsumerState<_DisplayDialog> {
  @override
  Widget build(BuildContext context) {
    final deleteValue = ref.watch(deleteMediaProvider(widget.media.id));
    final deleteState = deleteValue.asData?.value ?? const DeleteMediaState();
    final isDeleting = deleteState.isDeleting;
    final failureMessage = _deleteFailureMessage(
      AppLocalizations.of(context),
      deleteValue,
      deleteState,
    );

    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: !isDeleting,
      child: Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final decodeSize = authenticatedMediaDisplayDecodeSize(
                      logicalSize: constraints.biggest,
                      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                    );
                    return Center(
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: AuthenticatedMediaImage(
                            key: const ValueKey('memory-media.display-image'),
                            media: widget.media,
                            representation:
                                AuthenticatedMediaRepresentation.display,
                            fit: BoxFit.contain,
                            cacheWidth: decodeSize.cacheWidth,
                            cacheHeight: decodeSize.cacheHeight,
                            placeholder: const _DisplayPlaceholder(),
                            errorBuilder: (_) =>
                                const _DisplayErrorPlaceholder(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: widget.canDeletePhoto
                    ? GlassCircleIconButton(
                        key: const ValueKey(
                          'memory-media.display.delete-action',
                        ),
                        onPressed:
                            isDeleting ? null : () => _confirmDeleteMedia(),
                        tooltip: l10n.deletePhotoAction,
                        size: 48,
                        foregroundColor: const Color(0xFFFF5D72),
                        disabledForegroundColor: const Color(0x99FF5D72),
                        icon: isDeleting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFFF5D72),
                                ),
                              )
                            : const Icon(Icons.delete_outline_rounded),
                      )
                    : const SizedBox.shrink(),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GlassCircleIconButton.icon(
                  key: const ValueKey('memory-media.display.close-action'),
                  onPressed: isDeleting
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  tooltip: l10n.memoryMediaClosePhotoAction,
                  size: 48,
                  icon: Icons.close_rounded,
                ),
              ),
              if (failureMessage != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _DisplayFailureBanner(message: failureMessage),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _deleteFailureMessage(
    AppLocalizations l10n,
    AsyncValue<DeleteMediaState> deleteValue,
    DeleteMediaState deleteState,
  ) {
    if (deleteValue.hasError) {
      return l10n.deletePhotoFailure;
    }

    final failure = deleteState.deleteFailure;
    if (failure == null) {
      return null;
    }

    return switch (failure) {
      MediaUnavailable() || UnknownMediaFailure() => l10n.deletePhotoFailure,
      _ => mediaFailureMessage(l10n, failure),
    };
  }

  Future<void> _confirmDeleteMedia() async {
    if (_isDeleting(ref.read(deleteMediaProvider(widget.media.id)))) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = AppLocalizations.of(context);

        return AlertDialog(
          title: Text(l10n.deletePhotoDialogTitle),
          content: Text(l10n.deletePhotoDialogBody),
          actions: [
            TextButton(
              key: const ValueKey('memory-media.delete.cancel-action'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text(l10n.deletePhotoCancel),
            ),
            FilledButton(
              key: const ValueKey('memory-media.delete.confirm-action'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5D72),
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.deletePhotoConfirm),
            ),
          ],
        );
      },
    );

    if (!mounted ||
        confirmed != true ||
        _isDeleting(ref.read(deleteMediaProvider(widget.media.id)))) {
      return;
    }

    final provider = deleteMediaProvider(widget.media.id);
    final notifier = ref.read(provider.notifier);
    if (ref.read(provider).hasError) {
      notifier.reset();
    }

    final success = await notifier.deleteMedia(widget.media);
    if (!mounted || !success) {
      return;
    }

    Navigator.of(context).pop();
  }

  bool _isDeleting(AsyncValue<DeleteMediaState> value) {
    return value.asData?.value.isDeleting ?? false;
  }
}

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('memory-media.card'),
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});

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

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.message});

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

class _DisplayFailureBanner extends StatelessWidget {
  const _DisplayFailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        key: const ValueKey('memory-media.delete.failure-banner'),
        decoration: BoxDecoration(
          color: const Color(0xEFFFFFFF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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

class _RetryFailure extends StatelessWidget {
  const _RetryFailure({
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
        Expanded(child: _FailureBanner(message: message)),
        TextButton(
          key: const ValueKey('memory-media.retry-action'),
          onPressed: onRetry,
          child: Text(l10n.retry),
        ),
      ],
    );
  }
}

class _GallerySkeleton extends StatelessWidget {
  const _GallerySkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('memory-media.loading-view'),
      children: const [
        Expanded(child: _SkeletonSquare()),
        SizedBox(width: 10),
        Expanded(child: _SkeletonSquare()),
        SizedBox(width: 10),
        Expanded(child: _SkeletonSquare()),
      ],
    );
  }
}

class _SkeletonSquare extends StatelessWidget {
  const _SkeletonSquare();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFFF3F5F8),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

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

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder();

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

class _DisplayPlaceholder extends StatelessWidget {
  const _DisplayPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white),
    );
  }
}

class _DisplayErrorPlaceholder extends StatelessWidget {
  const _DisplayErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.broken_image_rounded,
        color: Colors.white70,
        size: 42,
      ),
    );
  }
}
