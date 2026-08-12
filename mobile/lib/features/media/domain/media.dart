import 'package:memory_map/features/media/domain/media_type.dart';

final class Media {
  factory Media({
    required String id,
    required String memoryId,
    required MediaType type,
    required int displayFileSize,
    required int thumbnailFileSize,
    required String mimeType,
    required DateTime createdAt,
    required String thumbnailPath,
    required String displayPath,
  }) {
    _validateIdentifier(id, 'id');
    _validateIdentifier(memoryId, 'memoryId');
    _validatePositive(displayFileSize, 'displayFileSize');
    _validatePositive(thumbnailFileSize, 'thumbnailFileSize');
    _validateMimeType(mimeType);
    _validateBackendPath(thumbnailPath, 'thumbnailPath');
    _validateBackendPath(displayPath, 'displayPath');

    return Media._(
      id: id,
      memoryId: memoryId,
      type: type,
      displayFileSize: displayFileSize,
      thumbnailFileSize: thumbnailFileSize,
      mimeType: mimeType,
      createdAt: createdAt.toUtc(),
      thumbnailPath: thumbnailPath,
      displayPath: displayPath,
    );
  }

  const Media._({
    required this.id,
    required this.memoryId,
    required this.type,
    required this.displayFileSize,
    required this.thumbnailFileSize,
    required this.mimeType,
    required this.createdAt,
    required this.thumbnailPath,
    required this.displayPath,
  });

  final String id;
  final String memoryId;
  final MediaType type;
  final int displayFileSize;
  final int thumbnailFileSize;
  final String mimeType;
  final DateTime createdAt;
  final String thumbnailPath;
  final String displayPath;

  bool get isPhoto => type == MediaType.photo;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Media &&
            id == other.id &&
            memoryId == other.memoryId &&
            type == other.type &&
            displayFileSize == other.displayFileSize &&
            thumbnailFileSize == other.thumbnailFileSize &&
            mimeType == other.mimeType &&
            createdAt == other.createdAt &&
            thumbnailPath == other.thumbnailPath &&
            displayPath == other.displayPath;
  }

  @override
  int get hashCode => Object.hash(
        id,
        memoryId,
        type,
        displayFileSize,
        thumbnailFileSize,
        mimeType,
        createdAt,
        thumbnailPath,
        displayPath,
      );

  @override
  String toString() {
    return 'Media(type: $type, hasThumbnailPath: true, hasDisplayPath: true)';
  }

  static void _validateIdentifier(String value, String fieldName) {
    if (value.trim().isEmpty) {
      throw ArgumentError('$fieldName must not be blank');
    }
  }

  static void _validatePositive(int value, String fieldName) {
    if (value <= 0) {
      throw ArgumentError('$fieldName must be positive');
    }
  }

  static void _validateMimeType(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError('mimeType must not be blank');
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
        !value.startsWith('/api/v1/')) {
      throw ArgumentError('$fieldName must be a backend API path');
    }
  }
}
