import 'package:memory_map/features/music/domain/music_failure.dart';

final class MusicApplicationException implements Exception {
  const MusicApplicationException(this.failure);

  final MusicFailure failure;

  @override
  String toString() => 'MusicApplicationException';
}
