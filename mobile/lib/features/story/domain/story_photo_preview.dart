final class StoryPhotoPreview {
  factory StoryPhotoPreview({
    required String mediaId,
    required String thumbnailPath,
  }) {
    _validateIdentifier(mediaId, 'mediaId');
    _validateBackendPath(thumbnailPath, 'thumbnailPath');

    return StoryPhotoPreview._(
      mediaId: mediaId,
      thumbnailPath: thumbnailPath,
    );
  }

  const StoryPhotoPreview._({
    required this.mediaId,
    required this.thumbnailPath,
  });

  final String mediaId;
  final String thumbnailPath;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryPhotoPreview &&
            mediaId == other.mediaId &&
            thumbnailPath == other.thumbnailPath;
  }

  @override
  int get hashCode => Object.hash(mediaId, thumbnailPath);

  @override
  String toString() => 'StoryPhotoPreview(hasThumbnailPath: true)';

  static void _validateIdentifier(String value, String fieldName) {
    if (value.trim().isEmpty) {
      throw ArgumentError('$fieldName must not be blank');
    }
  }

  static void _validateBackendPath(String value, String fieldName) {
    if (value.trim().isEmpty) {
      throw ArgumentError('$fieldName must not be blank');
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment ||
        !value.startsWith('/api/v1/media/') ||
        !value.endsWith('/thumbnail')) {
      throw ArgumentError('$fieldName must be a backend media API path');
    }
  }
}
