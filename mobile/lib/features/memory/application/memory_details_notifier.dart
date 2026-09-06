import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/memory_details_state.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';

final memoryDetailsProvider = AsyncNotifierProvider.family<
    MemoryDetailsNotifier, MemoryDetailsState, String>(
  MemoryDetailsNotifier.new,
  retry: (retryCount, error) => null,
);

final class MemoryDetailsNotifier extends AsyncNotifier<MemoryDetailsState> {
  MemoryDetailsNotifier(this._memoryId);

  final String _memoryId;
  int _refreshRevision = 0;

  @override
  Future<MemoryDetailsState> build() async {
    _invalidateRefresh();
    return _load(_memoryId, ref.watch(memoryRepositoryProvider));
  }

  Future<void> retryLoad() async {
    if (_isLoading) {
      return;
    }

    state = const AsyncLoading<MemoryDetailsState>();
    final retryRevision = ++_refreshRevision;
    final result = await AsyncValue.guard<MemoryDetailsState>(() async {
      return _load(_memoryId, ref.read(memoryRepositoryProvider));
    });
    if (!_isCurrentRefresh(retryRevision)) {
      return;
    }

    state = result;
  }

  Future<void> refreshMemory() async {
    final currentState = _currentState;
    if (_isLoading ||
        currentState == null ||
        !currentState.isLoaded ||
        currentState.isRefreshing) {
      return;
    }

    final refreshingState = currentState.copyWith(
      isRefreshing: true,
      clearRefreshFailure: true,
    );
    state = AsyncData<MemoryDetailsState>(refreshingState);
    final refreshRevision = ++_refreshRevision;

    try {
      final memory = await ref.read(memoryRepositoryProvider).getMemory(
            _memoryId,
          );
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

      state = AsyncData<MemoryDetailsState>(
        MemoryDetailsState.loadedRead(readModel: memory),
      );
    } on MemoryApplicationException catch (error) {
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

      state = AsyncData<MemoryDetailsState>(
        refreshingState.copyWith(
          isRefreshing: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (!_isCurrentRefresh(refreshRevision)) {
        return;
      }

      state = AsyncData<MemoryDetailsState>(
        refreshingState.copyWith(isRefreshing: false),
      );
      state = AsyncError<MemoryDetailsState>(error, stackTrace);
    }
  }

  void applyUpdatedMemory(Memory updatedMemory) {
    final currentState = _currentState;
    final currentMemory = currentState?.memory;
    if (currentState == null ||
        currentMemory == null ||
        currentMemory.id != updatedMemory.id) {
      return;
    }

    _invalidateRefresh();
    state = AsyncData<MemoryDetailsState>(
      currentState.copyWith(
        readModel: currentState.readModel!.withMemoryMutation(updatedMemory),
        isRefreshing: false,
        clearRefreshFailure: true,
      ),
    );
  }

  void applyAuthoritativeRead(MemoryReadModel readModel) {
    final currentState = _currentState;
    final currentMemory = currentState?.memory;
    if (currentState == null ||
        currentMemory == null ||
        currentMemory.id != readModel.memory.id) {
      return;
    }

    _invalidateRefresh();
    state = AsyncData<MemoryDetailsState>(
      currentState.copyWith(
        readModel: readModel,
        isRefreshing: false,
        clearRefreshFailure: true,
      ),
    );
  }

  Future<MemoryDetailsState> _load(
    String memoryId,
    MemoryRepository repository,
  ) async {
    if (memoryId.trim().isEmpty) {
      return MemoryDetailsState.loadFailure(const MemoryNotFound());
    }

    try {
      return MemoryDetailsState.loadedRead(
        readModel: await repository.getMemory(memoryId),
      );
    } on MemoryApplicationException catch (error) {
      return MemoryDetailsState.loadFailure(error.failure);
    }
  }

  bool get _isLoading => state is AsyncLoading<MemoryDetailsState>;

  void _invalidateRefresh() {
    _refreshRevision += 1;
  }

  bool _isCurrentRefresh(int refreshRevision) {
    return ref.mounted && _refreshRevision == refreshRevision;
  }

  MemoryDetailsState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<MemoryDetailsState>) {
      return currentState.value;
    }

    return null;
  }
}
