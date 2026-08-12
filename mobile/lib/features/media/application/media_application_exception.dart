import 'package:memory_map/features/media/domain/media_failure.dart';

final class MediaApplicationException implements Exception {
  const MediaApplicationException(this.failure);

  final MediaFailure failure;

  @override
  String toString() => 'MediaApplicationException';
}
