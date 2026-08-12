import 'package:memory_map/features/map/domain/map_marker.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';

final class StoryMapState {
  factory StoryMapState({
    List<MapMarker> markers = const <MapMarker>[],
    String? selectedMarkerId,
    MemoryFailure? loadFailure,
    bool isRefreshing = false,
    MemoryFailure? refreshFailure,
  }) {
    if (selectedMarkerId != null && selectedMarkerId.trim().isEmpty) {
      throw ArgumentError('selectedMarkerId must not be blank');
    }

    return StoryMapState._(
      markers: List<MapMarker>.unmodifiable(markers),
      selectedMarkerId: selectedMarkerId,
      loadFailure: loadFailure,
      isRefreshing: isRefreshing,
      refreshFailure: refreshFailure,
    );
  }

  const StoryMapState._({
    required this.markers,
    required this.selectedMarkerId,
    required this.loadFailure,
    required this.isRefreshing,
    required this.refreshFailure,
  });

  final List<MapMarker> markers;
  final String? selectedMarkerId;
  final MemoryFailure? loadFailure;
  final bool isRefreshing;
  final MemoryFailure? refreshFailure;

  bool get hasMarkers => markers.isNotEmpty;

  bool get hasSelection => selectedMarkerId != null;

  bool get hasLoadFailure => loadFailure != null;

  bool get hasRefreshFailure => refreshFailure != null;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryMapState &&
            _listEquals(markers, other.markers) &&
            selectedMarkerId == other.selectedMarkerId &&
            loadFailure == other.loadFailure &&
            isRefreshing == other.isRefreshing &&
            refreshFailure == other.refreshFailure;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(markers),
        selectedMarkerId,
        loadFailure,
        isRefreshing,
        refreshFailure,
      );

  @override
  String toString() {
    return 'StoryMapState(markerCount: ${markers.length}, '
        'hasSelection: $hasSelection, isRefreshing: $isRefreshing, '
        'hasLoadFailure: $hasLoadFailure, '
        'hasRefreshFailure: $hasRefreshFailure)';
  }

  static bool _listEquals<T>(List<T> left, List<T> right) {
    if (identical(left, right)) {
      return true;
    }

    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }
}

final class StoryMapSelectionState {
  factory StoryMapSelectionState({
    String? selectedMarkerId,
  }) {
    if (selectedMarkerId != null && selectedMarkerId.trim().isEmpty) {
      throw ArgumentError('selectedMarkerId must not be blank');
    }

    return StoryMapSelectionState._(
      selectedMarkerId: selectedMarkerId,
    );
  }

  const StoryMapSelectionState._({
    required this.selectedMarkerId,
  });

  final String? selectedMarkerId;

  bool get hasSelection => selectedMarkerId != null;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryMapSelectionState &&
            selectedMarkerId == other.selectedMarkerId;
  }

  @override
  int get hashCode => selectedMarkerId.hashCode;

  @override
  String toString() {
    return 'StoryMapSelectionState(hasSelection: $hasSelection)';
  }
}
