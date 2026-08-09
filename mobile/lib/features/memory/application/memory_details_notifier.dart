import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/memory_details_state.dart';
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

  @override
  Future<MemoryDetailsState> build() async {
    return _load(_memoryId, ref.watch(memoryRepositoryProvider));
  }

  Future<void> retryLoad() async {
    if (_isLoading) {
      return;
    }

    state = const AsyncLoading<MemoryDetailsState>();
    state = await AsyncValue.guard<MemoryDetailsState>(() async {
      return _load(_memoryId, ref.read(memoryRepositoryProvider));
    });
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

    try {
      final memory = await ref.read(memoryRepositoryProvider).getMemory(
            _memoryId,
          );
      state = AsyncData<MemoryDetailsState>(
        MemoryDetailsState.loaded(memory: memory),
      );
    } on MemoryApplicationException catch (error) {
      state = AsyncData<MemoryDetailsState>(
        refreshingState.copyWith(
          isRefreshing: false,
          refreshFailure: error.failure,
        ),
      );
    } on Object catch (error, stackTrace) {
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

    state = AsyncData<MemoryDetailsState>(
      currentState.copyWith(
        memory: updatedMemory,
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
      return MemoryDetailsState.loaded(
        memory: await repository.getMemory(memoryId),
      );
    } on MemoryApplicationException catch (error) {
      return MemoryDetailsState.loadFailure(error.failure);
    }
  }

  bool get _isLoading => state is AsyncLoading<MemoryDetailsState>;

  MemoryDetailsState? get _currentState {
    final currentState = state;
    if (currentState is AsyncData<MemoryDetailsState>) {
      return currentState.value;
    }

    return null;
  }
}
