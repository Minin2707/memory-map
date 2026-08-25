import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/music/application/music_application_exception.dart';
import 'package:memory_map/features/music/application/music_application_providers.dart';
import 'package:memory_map/features/music/application/music_catalog_state.dart';
import 'package:memory_map/features/music/domain/music_repository.dart';

final musicCatalogProvider =
    AsyncNotifierProvider<MusicCatalogNotifier, MusicCatalogState>(
  MusicCatalogNotifier.new,
  retry: (retryCount, error) => null,
);

final class MusicCatalogNotifier extends AsyncNotifier<MusicCatalogState> {
  @override
  Future<MusicCatalogState> build() async {
    return _load(ref.watch(musicRepositoryProvider));
  }

  Future<void> retryLoad() async {
    if (_isLoading) {
      return;
    }

    state = const AsyncLoading<MusicCatalogState>();
    state = await AsyncValue.guard<MusicCatalogState>(() async {
      return _load(ref.read(musicRepositoryProvider));
    });
  }

  Future<void> refreshCatalog() async {
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
    state = AsyncData<MusicCatalogState>(refreshingState);

    try {
      final tracks = await ref.read(musicRepositoryProvider)
          .getAvailableTracks();
      state = AsyncData<MusicCatalogState>(
        MusicCatalogState(tracks: tracks),
      );
    } on MusicApplicationException catch (error) {
      state = AsyncData<MusicCatalogState>(
        refreshingState.copyWith(
          isRefreshing: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      state = AsyncData<MusicCatalogState>(
        refreshingState.copyWith(isRefreshing: false),
      );
      state = AsyncError<MusicCatalogState>(error, stackTrace);
    }
  }

  Future<MusicCatalogState> _load(MusicRepository repository) async {
    try {
      return MusicCatalogState(
        tracks: await repository.getAvailableTracks(),
      );
    } on MusicApplicationException catch (error) {
      return MusicCatalogState(loadFailure: error.failure);
    }
  }

  bool get _isLoading => state is AsyncLoading<MusicCatalogState>;

  MusicCatalogState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<MusicCatalogState>) {
      return currentState.value;
    }

    return null;
  }
}
