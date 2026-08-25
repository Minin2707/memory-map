import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/music/application/music_application_exception.dart';
import 'package:memory_map/features/music/application/music_application_providers.dart';
import 'package:memory_map/features/music/application/story_soundtrack_state.dart';
import 'package:memory_map/features/music/domain/music_failure.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/domain/story_soundtrack_repository.dart';

final storySoundtrackProvider = AsyncNotifierProvider.family<
    StorySoundtrackNotifier, StorySoundtrackState, String>(
  StorySoundtrackNotifier.new,
  retry: (retryCount, error) => null,
);

final class StorySoundtrackNotifier
    extends AsyncNotifier<StorySoundtrackState> {
  StorySoundtrackNotifier(this._storyId);

  final String _storyId;

  @override
  Future<StorySoundtrackState> build() async {
    return _load(_storyId, ref.watch(storySoundtrackRepositoryProvider));
  }

  Future<void> retryLoad() async {
    if (_isLoading) {
      return;
    }

    state = const AsyncLoading<StorySoundtrackState>();
    state = await AsyncValue.guard<StorySoundtrackState>(() async {
      return _load(_storyId, ref.read(storySoundtrackRepositoryProvider));
    });
  }

  Future<void> refreshSoundtrack() async {
    final currentState = _currentState;
    if (_isLoading ||
        currentState == null ||
        !currentState.isLoaded ||
        currentState.isRefreshing ||
        currentState.isMutating) {
      return;
    }

    final refreshingState = currentState.copyWith(
      isRefreshing: true,
      clearRefreshFailure: true,
    );
    state = AsyncData<StorySoundtrackState>(refreshingState);

    try {
      final soundtrack = await ref
          .read(storySoundtrackRepositoryProvider)
          .getStorySoundtrack(_storyId);
      state = AsyncData<StorySoundtrackState>(
        StorySoundtrackState(soundtrack: soundtrack),
      );
    } on MusicApplicationException catch (error) {
      state = AsyncData<StorySoundtrackState>(
        refreshingState.copyWith(
          isRefreshing: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      state = AsyncData<StorySoundtrackState>(
        refreshingState.copyWith(isRefreshing: false),
      );
      state = AsyncError<StorySoundtrackState>(error, stackTrace);
    }
  }

  Future<bool> setSoundtrack(String musicTrackId) async {
    final currentState = _currentState;
    if (_isLoading ||
        currentState == null ||
        !currentState.isLoaded ||
        currentState.isRefreshing ||
        currentState.isMutating) {
      return false;
    }

    if (musicTrackId.trim().isEmpty) {
      state = AsyncData<StorySoundtrackState>(
        currentState.copyWith(
          isMutating: false,
          mutationFailure: const MusicValidationFailure(),
        ),
      );
      return false;
    }

    return _mutate(
      currentState,
      () => ref.read(storySoundtrackRepositoryProvider).setStorySoundtrack(
            _storyId,
            musicTrackId,
          ),
    );
  }

  Future<bool> removeSoundtrack() async {
    final currentState = _currentState;
    if (_isLoading ||
        currentState == null ||
        !currentState.isLoaded ||
        currentState.isRefreshing ||
        currentState.isMutating) {
      return false;
    }

    return _mutate(
      currentState,
      () => ref
          .read(storySoundtrackRepositoryProvider)
          .removeStorySoundtrack(_storyId),
    );
  }

  Future<StorySoundtrackState> _load(
    String storyId,
    StorySoundtrackRepository repository,
  ) async {
    if (storyId.trim().isEmpty) {
      return const StorySoundtrackState(
        loadFailure: MusicValidationFailure(),
      );
    }

    try {
      return StorySoundtrackState(
        soundtrack: await repository.getStorySoundtrack(storyId),
      );
    } on MusicApplicationException catch (error) {
      return StorySoundtrackState(loadFailure: error.failure);
    }
  }

  Future<bool> _mutate(
    StorySoundtrackState currentState,
    Future<StorySoundtrack> Function() action,
  ) async {
    final mutatingState = currentState.copyWith(
      isMutating: true,
      clearMutationFailure: true,
    );
    state = AsyncData<StorySoundtrackState>(mutatingState);

    try {
      final soundtrack = await action();
      if (!ref.mounted) {
        return false;
      }

      state = AsyncData<StorySoundtrackState>(
        StorySoundtrackState(soundtrack: soundtrack),
      );
      return true;
    } on MusicApplicationException catch (error) {
      if (!ref.mounted) {
        return false;
      }

      state = AsyncData<StorySoundtrackState>(
        mutatingState.copyWith(
          isMutating: false,
          mutationFailure: error.failure,
        ),
      );
      return false;
    } on Object catch (error, stackTrace) {
      if (!ref.mounted) {
        return false;
      }

      state = AsyncData<StorySoundtrackState>(
        mutatingState.copyWith(isMutating: false),
      );
      state = AsyncError<StorySoundtrackState>(error, stackTrace);
      return false;
    }
  }

  bool get _isLoading => state is AsyncLoading<StorySoundtrackState>;

  StorySoundtrackState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<StorySoundtrackState>) {
      return currentState.value;
    }

    return null;
  }
}
