import 'package:memory_map/features/music/domain/music_failure.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';

final class StorySoundtrackState {
  const StorySoundtrackState({
    this.soundtrack,
    this.loadFailure,
    this.isRefreshing = false,
    this.refreshFailure,
    this.isMutating = false,
    this.mutationFailure,
  });

  final StorySoundtrack? soundtrack;
  final MusicFailure? loadFailure;
  final bool isRefreshing;
  final MusicFailure? refreshFailure;
  final bool isMutating;
  final MusicFailure? mutationFailure;

  bool get hasLoadFailure => loadFailure != null;

  bool get isLoaded => loadFailure == null && soundtrack != null;

  bool get hasMutationFailure => mutationFailure != null;

  StorySoundtrackState copyWith({
    StorySoundtrack? soundtrack,
    MusicFailure? loadFailure,
    bool? isRefreshing,
    MusicFailure? refreshFailure,
    bool? isMutating,
    MusicFailure? mutationFailure,
    bool clearLoadFailure = false,
    bool clearRefreshFailure = false,
    bool clearMutationFailure = false,
  }) {
    return StorySoundtrackState(
      soundtrack: soundtrack ?? this.soundtrack,
      loadFailure: clearLoadFailure ? null : loadFailure ?? this.loadFailure,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshFailure:
          clearRefreshFailure ? null : refreshFailure ?? this.refreshFailure,
      isMutating: isMutating ?? this.isMutating,
      mutationFailure:
          clearMutationFailure ? null : mutationFailure ?? this.mutationFailure,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StorySoundtrackState &&
            soundtrack == other.soundtrack &&
            loadFailure == other.loadFailure &&
            isRefreshing == other.isRefreshing &&
            refreshFailure == other.refreshFailure &&
            isMutating == other.isMutating &&
            mutationFailure == other.mutationFailure;
  }

  @override
  int get hashCode => Object.hash(
        soundtrack,
        loadFailure,
        isRefreshing,
        refreshFailure,
        isMutating,
        mutationFailure,
      );

  @override
  String toString() {
    return 'StorySoundtrackState(isLoaded: $isLoaded, '
        'isRefreshing: $isRefreshing, isMutating: $isMutating, '
        'hasLoadFailure: ${loadFailure != null}, '
        'hasRefreshFailure: ${refreshFailure != null}, '
        'hasMutationFailure: ${mutationFailure != null})';
  }
}
