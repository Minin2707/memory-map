import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/domain/media_repository.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/playback/domain/story_playback_state.dart';

final playbackMediaPrefetcherProvider = Provider<PlaybackMediaPrefetcher>((ref) {
  return DefaultPlaybackMediaPrefetcher(
    mediaRepository: ref.watch(mediaRepositoryProvider),
  );
});

abstract interface class PlaybackMediaPrefetcher {
  Future<void> prefetchNext(StoryPlaybackState playback);
}

final class DefaultPlaybackMediaPrefetcher implements PlaybackMediaPrefetcher {
  const DefaultPlaybackMediaPrefetcher({
    required MediaRepository mediaRepository,
  }) : _mediaRepository = mediaRepository;

  final MediaRepository _mediaRepository;

  @override
  Future<void> prefetchNext(StoryPlaybackState playback) async {
    final displayPath = nextPlaybackDisplayPath(playback);
    if (displayPath == null) {
      return;
    }

    try {
      await _mediaRepository.getDisplayByPath(displayPath);
    } on Object {
      // Prefetch is a best-effort cache warmup. Normal image rendering will
      // retry through the same repository/cache path if this attempt fails.
    }
  }
}

String? nextPlaybackDisplayPath(StoryPlaybackState playback) {
  final currentIndex = playback.currentIndex;
  if (!playback.isPlaying ||
      currentIndex == null ||
      currentIndex < 0 ||
      currentIndex >= playback.snapshot.length - 1) {
    return null;
  }

  final preview = playback.snapshot[currentIndex + 1].previewPhoto;
  if (preview == null) {
    return null;
  }

  return playbackDisplayPath(preview);
}

@visibleForTesting
String playbackDisplayPath(MemoryPhotoPreview preview) {
  return '/api/v1/media/${Uri.encodeComponent(preview.mediaId)}/display';
}
