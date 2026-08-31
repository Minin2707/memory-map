import 'package:memory_map/features/story/domain/story_photo_preview.dart';

bool isExplicitStoryCoverPreview({
  required String storyId,
  required StoryPhotoPreview? preview,
}) {
  if (storyId.trim().isEmpty || preview == null) {
    return false;
  }

  return _isExplicitStoryCoverPath(
        storyId: storyId,
        path: preview.thumbnailPath,
        representation: 'thumbnail',
      ) &&
      _isExplicitStoryCoverPath(
        storyId: storyId,
        path: preview.displayPath,
        representation: 'display',
      );
}

bool _isExplicitStoryCoverPath({
  required String storyId,
  required String path,
  required String representation,
}) {
  final uri = Uri.tryParse(path);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment ||
      !path.startsWith('/api/v1/')) {
    return false;
  }

  final segments = uri.pathSegments;
  if (segments.length != 7) {
    return false;
  }

  return segments[0] == 'api' &&
      segments[1] == 'v1' &&
      segments[2] == 'stories' &&
      segments[3] == storyId &&
      segments[4] == 'cover' &&
      segments[5] == representation &&
      RegExp(r'^[0-9]+$').hasMatch(segments[6]);
}
