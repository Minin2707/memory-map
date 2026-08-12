import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';

final class MemoryMediaState {
  factory MemoryMediaState({
    List<Media> media = const <Media>[],
    MediaFailure? loadFailure,
    bool isRefreshing = false,
    MediaFailure? refreshFailure,
  }) {
    return MemoryMediaState._(
      media: List<Media>.unmodifiable(media),
      loadFailure: loadFailure,
      isRefreshing: isRefreshing,
      refreshFailure: refreshFailure,
    );
  }

  const MemoryMediaState._({
    required this.media,
    required this.loadFailure,
    required this.isRefreshing,
    required this.refreshFailure,
  });

  final List<Media> media;
  final MediaFailure? loadFailure;
  final bool isRefreshing;
  final MediaFailure? refreshFailure;

  bool get hasMedia => media.isNotEmpty;

  bool get hasLoadFailure => loadFailure != null;

  bool get isLoaded => loadFailure == null;

  MemoryMediaState copyWith({
    List<Media>? media,
    MediaFailure? loadFailure,
    bool? isRefreshing,
    MediaFailure? refreshFailure,
    bool clearLoadFailure = false,
    bool clearRefreshFailure = false,
  }) {
    return MemoryMediaState(
      media: media ?? this.media,
      loadFailure: clearLoadFailure ? null : loadFailure ?? this.loadFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshFailure:
          clearRefreshFailure ? null : refreshFailure ?? this.refreshFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MemoryMediaState &&
            _listEquals(media, other.media) &&
            loadFailure == other.loadFailure &&
            isRefreshing == other.isRefreshing &&
            refreshFailure == other.refreshFailure;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(media),
        loadFailure,
        isRefreshing,
        refreshFailure,
      );

  @override
  String toString() {
    return 'MemoryMediaState(mediaCount: ${media.length}, '
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
