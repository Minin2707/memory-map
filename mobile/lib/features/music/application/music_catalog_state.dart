import 'package:memory_map/features/music/domain/music_failure.dart';
import 'package:memory_map/features/music/domain/music_track.dart';

final class MusicCatalogState {
  factory MusicCatalogState({
    List<MusicTrack> tracks = const <MusicTrack>[],
    MusicFailure? loadFailure,
    bool isRefreshing = false,
    MusicFailure? refreshFailure,
  }) {
    return MusicCatalogState._(
      tracks: List<MusicTrack>.unmodifiable(tracks),
      loadFailure: loadFailure,
      isRefreshing: isRefreshing,
      refreshFailure: refreshFailure,
    );
  }

  const MusicCatalogState._({
    required this.tracks,
    required this.loadFailure,
    required this.isRefreshing,
    required this.refreshFailure,
  });

  final List<MusicTrack> tracks;
  final MusicFailure? loadFailure;
  final bool isRefreshing;
  final MusicFailure? refreshFailure;

  bool get hasTracks => tracks.isNotEmpty;

  bool get hasLoadFailure => loadFailure != null;

  bool get isLoaded => loadFailure == null;

  MusicCatalogState copyWith({
    List<MusicTrack>? tracks,
    MusicFailure? loadFailure,
    bool? isRefreshing,
    MusicFailure? refreshFailure,
    bool clearLoadFailure = false,
    bool clearRefreshFailure = false,
  }) {
    return MusicCatalogState(
      tracks: tracks ?? this.tracks,
      loadFailure: clearLoadFailure ? null : loadFailure ?? this.loadFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshFailure:
          clearRefreshFailure ? null : refreshFailure ?? this.refreshFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MusicCatalogState &&
            _listEquals(tracks, other.tracks) &&
            loadFailure == other.loadFailure &&
            isRefreshing == other.isRefreshing &&
            refreshFailure == other.refreshFailure;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(tracks),
        loadFailure,
        isRefreshing,
        refreshFailure,
      );

  @override
  String toString() {
    return 'MusicCatalogState(trackCount: ${tracks.length}, '
        'isRefreshing: $isRefreshing, '
        'hasLoadFailure: ${loadFailure != null}, '
        'hasRefreshFailure: ${refreshFailure != null})';
  }

  static bool _listEquals<T>(List<T> left, List<T> right) {
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
