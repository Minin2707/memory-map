import 'package:memory_map/features/story/domain/story_failure.dart';

final class StoryApplicationException implements Exception {
  const StoryApplicationException(this.failure);

  final StoryFailure failure;

  @override
  String toString() => 'StoryApplicationException';
}
