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
  int _providerGeneration = 0;

  @override
  Future<MusicCatalogState> build() async {
    _providerGeneration += 1;
    return _load(ref.watch(musicRepositoryProvider));
  }

  Future<void> retryLoad() async {
    if (_isLoading) {
      return;
    }

    final providerGeneration = _providerGeneration;
    state = const AsyncLoading<MusicCatalogState>();
    final result = await AsyncValue.guard<MusicCatalogState>(() async {
      return _load(ref.read(musicRepositoryProvider));
    });
    if (!_isCurrentProviderGeneration(providerGeneration)) {
      return;
    }

    state = result;
  }

  Future<void> refreshCatalog() async {
    final currentState = _currentState;
    if (_isLoading ||
        currentState == null ||
        currentState.hasLoadFailure ||
        currentState.isRefreshing) {
      return;
    }

    final providerGeneration = _providerGeneration;
    final refreshingState = currentState.copyWith(
      isRefreshing: true,
      clearRefreshFailure: true,
    );
    state = AsyncData<MusicCatalogState>(refreshingState);

    try {
      final tracks = await ref.read(musicRepositoryProvider)
          .getAvailableTracks();
      if (!_isCurrentProviderGeneration(providerGeneration)) {
        return;
      }

      state = AsyncData<MusicCatalogState>(
        MusicCatalogState(tracks: tracks),
      );
    } on MusicApplicationException catch (error) {
      if (!_isCurrentProviderGeneration(providerGeneration)) {
        return;
      }

      state = AsyncData<MusicCatalogState>(
        refreshingState.copyWith(
          isRefreshing: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (!_isCurrentProviderGeneration(providerGeneration)) {
        return;
      }

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

  bool _isCurrentProviderGeneration(int generation) {
    return ref.mounted && generation == _providerGeneration;
  }

  MusicCatalogState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<MusicCatalogState>) {
      return currentState.value;
    }

    return null;
  }
}
