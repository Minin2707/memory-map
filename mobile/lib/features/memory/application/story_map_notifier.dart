import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/story_map_projection.dart';
import 'package:memory_map/features/memory/application/story_map_state.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_state.dart';

final storyMapSelectionProvider = NotifierProvider.family<
    StoryMapSelectionNotifier, StoryMapSelectionState, String>(
  StoryMapSelectionNotifier.new,
);

final storyMapProvider =
    Provider.family<AsyncValue<StoryMapState>, String>((ref, storyId) {
  final memoriesValue = ref.watch(storyMemoriesProvider(storyId));
  final selectedMarkerId = ref
      .watch(storyMapSelectionProvider(storyId))
      .selectedMarkerId;

  if (memoriesValue.hasError) {
    return AsyncError<StoryMapState>(
      memoriesValue.error!,
      memoriesValue.stackTrace!,
    );
  }

  final memoriesState = memoriesValue.asData?.value;
  if (memoriesState == null) {
    return const AsyncLoading<StoryMapState>();
  }

  return AsyncData<StoryMapState>(
    _storyMapStateFrom(memoriesState, selectedMarkerId),
  );
});

final class StoryMapSelectionNotifier
    extends Notifier<StoryMapSelectionState> {
  StoryMapSelectionNotifier(this._storyId);

  final String _storyId;

  @override
  StoryMapSelectionState build() {
    ref.listen<AsyncValue<StoryMemoriesState>>(
      storyMemoriesProvider(_storyId),
      (previous, next) {
        _reconcileSelection(next.asData?.value);
      },
    );

    return StoryMapSelectionState();
  }

  void selectMarker(String markerId) {
    if (markerId.trim().isEmpty) {
      return;
    }

    final memoriesState = ref
        .read(storyMemoriesProvider(_storyId))
        .asData
        ?.value;
    if (!_containsSelectableMarker(memoriesState, markerId)) {
      return;
    }

    if (state.selectedMarkerId == markerId) {
      return;
    }

    state = StoryMapSelectionState(selectedMarkerId: markerId);
  }

  void clearSelection() {
    if (!state.hasSelection) {
      return;
    }

    state = StoryMapSelectionState();
  }

  void _reconcileSelection(StoryMemoriesState? memoriesState) {
    final selectedMarkerId = state.selectedMarkerId;
    if (selectedMarkerId == null) {
      return;
    }

    if (!_containsSelectableMarker(memoriesState, selectedMarkerId)) {
      state = StoryMapSelectionState();
    }
  }
}

StoryMapState _storyMapStateFrom(
  StoryMemoriesState memoriesState,
  String? selectedMarkerId,
) {
  if (memoriesState.hasLoadFailure) {
    return StoryMapState(
      loadFailure: memoriesState.loadFailure,
      isRefreshing: memoriesState.isRefreshing,
      refreshFailure: memoriesState.refreshFailure,
    );
  }

  final markerPresentations = storyMapMarkerPresentationsFromMemoryReadModels(
    memoriesState.memoryReadModels,
  );
  final reconciledSelection = markerPresentations.any(
    (presentation) => presentation.marker.id == selectedMarkerId,
  )
      ? selectedMarkerId
      : null;

  return StoryMapState(
    markerPresentations: markerPresentations,
    selectedMarkerId: reconciledSelection,
    isRefreshing: memoriesState.isRefreshing,
    refreshFailure: memoriesState.refreshFailure,
  );
}

bool _containsSelectableMarker(
  StoryMemoriesState? memoriesState,
  String markerId,
) {
  if (memoriesState == null || memoriesState.hasLoadFailure) {
    return false;
  }

  return memoriesState.memoryReadModels.any(
    (memory) => memory.memory.id == markerId,
  );
}
