import 'package:memory_map/features/music/domain/music_track.dart';

final class StorySoundtrack {
  factory StorySoundtrack({
    MusicTrack? selectedSoundtrack,
    MusicTrack? effectiveSoundtrack,
  }) {
    if (selectedSoundtrack == null && effectiveSoundtrack != null) {
      throw ArgumentError(
        'effectiveSoundtrack requires selectedSoundtrack',
      );
    }

    return StorySoundtrack._(
      selectedSoundtrack: selectedSoundtrack,
      effectiveSoundtrack: effectiveSoundtrack,
    );
  }

  const StorySoundtrack._({
    required this.selectedSoundtrack,
    required this.effectiveSoundtrack,
  });

  factory StorySoundtrack.noMusic() {
    return StorySoundtrack();
  }

  final MusicTrack? selectedSoundtrack;
  final MusicTrack? effectiveSoundtrack;

  bool get hasSelection => selectedSoundtrack != null;

  bool get isNoMusic {
    return selectedSoundtrack == null && effectiveSoundtrack == null;
  }

  bool get isEffective {
    return selectedSoundtrack != null && effectiveSoundtrack != null;
  }

  bool get isSelectedUnavailable {
    return selectedSoundtrack != null && effectiveSoundtrack == null;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StorySoundtrack &&
            selectedSoundtrack == other.selectedSoundtrack &&
            effectiveSoundtrack == other.effectiveSoundtrack;
  }

  @override
  int get hashCode => Object.hash(
        selectedSoundtrack,
        effectiveSoundtrack,
      );

  @override
  String toString() {
    return 'StorySoundtrack(hasSelection: $hasSelection, '
        'isEffective: $isEffective, '
        'isSelectedUnavailable: $isSelectedUnavailable)';
  }
}
