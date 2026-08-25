import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';

final class MusicTrackDto {
  factory MusicTrackDto.fromJson(Object? json) {
    final map = musicRequiredRootMap(json);

    return MusicTrackDto(
      id: musicRequiredString(map, 'id'),
      title: musicRequiredString(map, 'title'),
      artist: musicRequiredString(map, 'artist'),
      durationSeconds: musicRequiredInt(map, 'durationSeconds'),
    );
  }

  static MusicTrackDto? fromNullableJson(Object? json) {
    if (json == null) {
      return null;
    }

    return MusicTrackDto.fromJson(json);
  }

  MusicTrackDto({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationSeconds,
  }) {
    try {
      MusicTrack(
        id: id,
        title: title,
        artist: artist,
        durationSeconds: durationSeconds,
      );
    } on Object {
      throw const FormatException('Malformed music response');
    }
  }

  final String id;
  final String title;
  final String artist;
  final int durationSeconds;

  MusicTrack toDomain() {
    return MusicTrack(
      id: id,
      title: title,
      artist: artist,
      durationSeconds: durationSeconds,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MusicTrackDto &&
            id == other.id &&
            title == other.title &&
            artist == other.artist &&
            durationSeconds == other.durationSeconds;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        artist,
        durationSeconds,
      );

  @override
  String toString() => 'MusicTrackDto';
}

final class StorySoundtrackDto {
  factory StorySoundtrackDto.fromJson(Object? json) {
    final map = musicRequiredRootMap(json);

    return StorySoundtrackDto(
      selectedSoundtrack: MusicTrackDto.fromNullableJson(
        musicRequiredNullableValue(map, 'selectedSoundtrack'),
      ),
      effectiveSoundtrack: MusicTrackDto.fromNullableJson(
        musicRequiredNullableValue(map, 'effectiveSoundtrack'),
      ),
    );
  }

  StorySoundtrackDto({
    this.selectedSoundtrack,
    this.effectiveSoundtrack,
  }) {
    try {
      toDomain();
    } on Object {
      throw const FormatException('Malformed music response');
    }
  }

  final MusicTrackDto? selectedSoundtrack;
  final MusicTrackDto? effectiveSoundtrack;

  StorySoundtrack toDomain() {
    return StorySoundtrack(
      selectedSoundtrack: selectedSoundtrack?.toDomain(),
      effectiveSoundtrack: effectiveSoundtrack?.toDomain(),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StorySoundtrackDto &&
            selectedSoundtrack == other.selectedSoundtrack &&
            effectiveSoundtrack == other.effectiveSoundtrack;
  }

  @override
  int get hashCode => Object.hash(
        selectedSoundtrack,
        effectiveSoundtrack,
      );

  @override
  String toString() => 'StorySoundtrackDto';
}

Map<Object?, Object?> musicRequiredRootMap(Object? json) {
  if (json is! Map) {
    throw const FormatException('Malformed music response');
  }

  return json.cast<Object?, Object?>();
}

String musicRequiredString(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const FormatException('Malformed music response');
  }

  return value;
}

int musicRequiredInt(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw const FormatException('Malformed music response');
  }

  return value;
}

Object? musicRequiredNullableValue(Map<Object?, Object?> json, String key) {
  if (!json.containsKey(key)) {
    throw const FormatException('Malformed music response');
  }

  return json[key];
}
