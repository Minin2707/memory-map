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

  @override
  Future<MemoryMediaState> build() async {
    return _load(_memoryId, ref.watch(mediaRepositoryProvider));
  }

  Future<void> retryLoad() async {
    if (_isLoading) {
      return;
    }

    state = const AsyncLoading<MemoryMediaState>();
    state = await AsyncValue.guard<MemoryMediaState>(() async {
      return _load(_memoryId, ref.read(mediaRepositoryProvider));
    });
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

    try {
      final media = await ref.read(mediaRepositoryProvider).getMedia(_memoryId);
      state = AsyncData<MemoryMediaState>(MemoryMediaState(media: media));
    } on MediaApplicationException catch (error) {
      state = AsyncData<MemoryMediaState>(
        refreshingState.copyWith(
          isRefreshing: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
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

    state = AsyncData<MemoryMediaState>(
      currentState.copyWith(media: updated),
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

    state = AsyncData<MemoryMediaState>(
      currentState.copyWith(media: updated),
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
