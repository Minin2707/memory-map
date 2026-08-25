final class MusicTrack {
  factory MusicTrack({
    required String id,
    required String title,
    required String artist,
    required int durationSeconds,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('id must not be blank');
    }

    if (title.trim().isEmpty) {
      throw ArgumentError('title must not be blank');
    }

    if (artist.trim().isEmpty) {
      throw ArgumentError('artist must not be blank');
    }

    if (durationSeconds < 0) {
      throw ArgumentError('durationSeconds must not be negative');
    }

    return MusicTrack._(
      id: id,
      title: title,
      artist: artist,
      durationSeconds: durationSeconds,
    );
  }

  const MusicTrack._({
    required this.id,
    required this.title,
    required this.artist,
    required this.durationSeconds,
  });

  final String id;
  final String title;
  final String artist;
  final int durationSeconds;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MusicTrack &&
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
  String toString() {
    return 'MusicTrack(durationSeconds: $durationSeconds)';
  }
}
