final class StoryPhotoPreview {
  factory StoryPhotoPreview({
    required String thumbnailPath,
    required String displayPath,
  }) {
    _validateBackendPath(thumbnailPath, 'thumbnailPath', 'thumbnail');
    _validateBackendPath(displayPath, 'displayPath', 'display');

    return StoryPhotoPreview._(
      thumbnailPath: thumbnailPath,
      displayPath: displayPath,
    );
  }

  const StoryPhotoPreview._({
    required this.thumbnailPath,
    required this.displayPath,
  });

  final String thumbnailPath;
  final String displayPath;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is StoryPhotoPreview &&
            thumbnailPath == other.thumbnailPath &&
            displayPath == other.displayPath;
  }

  @override
  int get hashCode => Object.hash(thumbnailPath, displayPath);

  @override
  String toString() =>
      'StoryPhotoPreview(hasThumbnailPath: true, hasDisplayPath: true)';

  static void _validateBackendPath(
    String value,
    String fieldName,
    String requiredSegment,
  ) {
    if (value.trim().isEmpty) {
      throw ArgumentError('$fieldName must not be blank');
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment ||
        !value.startsWith('/api/v1/') ||
        !value.split('/').contains(requiredSegment)) {
      throw ArgumentError('$fieldName must be a backend API path');
    }
  }
}
