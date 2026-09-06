import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/application/memory_media_state.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/features/media/domain/media_repository.dart';

final memoryMediaProvider =
    AsyncNotifierProvider.autoDispose.family<MemoryMediaNotifier,
        MemoryMediaState, String>(
  MemoryMediaNotifier.new,
  retry: (retryCount, error) => null,
);

final class MemoryMediaNotifier extends AsyncNotifier<MemoryMediaState> {
  MemoryMediaNotifier(this._memoryId);

  final String _memoryId;
  int _refreshRevision = 0;

  @override
  Future<MemoryMediaState> build() async {
    _invalidateRefresh();
    return _load(_memoryId, ref.watch(mediaRepositoryProvider));
  }

  Future<void> retryLoad() async {
    if (_isLoading) {
      return;
    }

    state = const AsyncLoading<MemoryMediaState>();
    final retryRevision = ++_refreshRevision;
    final result = await AsyncValue.guard<MemoryMediaState>(() async {
      return _load(_memoryId, ref.read(mediaRepositoryProvider));
    });
    if (!_isCurrentRefresh(retryRevision)) {
      return;
    }

    state = result;
  }

  Future<void> refreshMedia() async {
    final currentState = _currentState;
    if (_isLoading ||
        currentState == null ||
        currentState.hasLoadFailure ||
        currentState.isRefreshing) {
      return;
    }

    final refreshingState = currentState.copyWith(
      isRefreshing: true,
      clearRefreshFailure: true,
    );
    state = AsyncData<MemoryMediaState>(refreshingState);
    final refreshRevision = ++_refreshRevision;

    try {
      final media = await ref.read(mediaRepositoryProvider).getMedia(_memoryId);
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

      state = AsyncData<MemoryMediaState>(MemoryMediaState(media: media));
    } on MediaApplicationException catch (error) {
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

      state = AsyncData<MemoryMediaState>(
        refreshingState.copyWith(
          isRefreshing: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

      state = AsyncData<MemoryMediaState>(
        refreshingState.copyWith(isRefreshing: false),
      );
      state = AsyncError<MemoryMediaState>(error, stackTrace);
    }
  }

  void upsertMedia(Media media) {
    final currentState = _currentState;
    if (currentState == null ||
        currentState.hasLoadFailure ||
        media.memoryId != _memoryId) {
      return;
    }

    final updated = currentState.media
        .where((existing) => existing.id != media.id)
        .toList();
    updated.add(media);
    updated.sort(compareMediaCanonical);

    _invalidateRefresh();
    state = AsyncData<MemoryMediaState>(
      currentState.copyWith(media: updated, isRefreshing: false),
    );
  }

  void removeMediaById(String mediaId) {
    final currentState = _currentState;
    if (currentState == null || currentState.hasLoadFailure) {
      return;
    }

    final updated = currentState.media
        .where((existing) => existing.id != mediaId)
        .toList();
    if (updated.length == currentState.media.length) {
      return;
    }

    _invalidateRefresh();
    state = AsyncData<MemoryMediaState>(
      currentState.copyWith(media: updated, isRefreshing: false),
    );
  }

  Future<MemoryMediaState> _load(
    String memoryId,
    MediaRepository repository,
  ) async {
    if (memoryId.trim().isEmpty) {
      return MemoryMediaState(loadFailure: const MediaUnavailable());
    }

    try {
      return MemoryMediaState(media: await repository.getMedia(memoryId));
    } on MediaApplicationException catch (error) {
      return MemoryMediaState(loadFailure: error.failure);
    }
  }

  bool get _isLoading => state is AsyncLoading<MemoryMediaState>;

  void _invalidateRefresh() {
    _refreshRevision += 1;
  }

  bool _isCurrentRefresh(int refreshRevision) {
    return ref.mounted && _refreshRevision == refreshRevision;
  }

  MemoryMediaState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<MemoryMediaState>) {
      return currentState.value;
    }

    return null;
  }
}

int compareMediaCanonical(Media left, Media right) {
  final createdAt = left.createdAt.compareTo(right.createdAt);
  if (createdAt != 0) {
    return createdAt;
  }

  return left.id.compareTo(right.id);
}
