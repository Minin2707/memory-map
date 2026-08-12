import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/media_type.dart';

final class MediaDto {
  factory MediaDto.fromJson(Object? json) {
    final map = mediaRequiredRootMap(json);

    return MediaDto(
      id: mediaRequiredString(map, 'id'),
      memoryId: mediaRequiredString(map, 'memoryId'),
      type: MediaType.parse(mediaRequiredString(map, 'mediaType')),
      displayFileSize: mediaRequiredPositiveInt(map, 'displayFileSize'),
      thumbnailFileSize: mediaRequiredPositiveInt(map, 'thumbnailFileSize'),
      mimeType: mediaRequiredString(map, 'mimeType'),
      createdAt: mediaRequiredDate(map, 'createdAt'),
      thumbnailPath: mediaRequiredString(map, 'thumbnailUrl'),
      displayPath: mediaRequiredString(map, 'displayUrl'),
    );
  }

  MediaDto({
    required this.id,
    required this.memoryId,
    required this.type,
    required this.displayFileSize,
    required this.thumbnailFileSize,
    required this.mimeType,
    required this.createdAt,
    required this.thumbnailPath,
    required this.displayPath,
  }) {
    try {
      toDomain();
    } on Object {
      throw const FormatException('Malformed media response');
    }
  }

  final String id;
  final String memoryId;
  final MediaType type;
  final int displayFileSize;
  final int thumbnailFileSize;
  final String mimeType;
  final DateTime createdAt;
  final String thumbnailPath;
  final String displayPath;

  Media toDomain() {
    return Media(
      id: id,
      memoryId: memoryId,
      type: type,
      displayFileSize: displayFileSize,
      thumbnailFileSize: thumbnailFileSize,
      mimeType: mimeType,
      createdAt: createdAt,
      thumbnailPath: thumbnailPath,
      displayPath: displayPath,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MediaDto &&
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
  String toString() => 'MediaDto';
}

Map<Object?, Object?> mediaRequiredRootMap(Object? json) {
  if (json is! Map) {
    throw const FormatException('Malformed media response');
  }

  return json.cast<Object?, Object?>();
}

String mediaRequiredString(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const FormatException('Malformed media response');
  }

  return value;
}

int mediaRequiredPositiveInt(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw const FormatException('Malformed media response');
  }

  final intValue = value.toInt();
  if (intValue != value || intValue <= 0) {
    throw const FormatException('Malformed media response');
  }

  return intValue;
}

DateTime mediaRequiredDate(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const FormatException('Malformed media response');
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const FormatException('Malformed media response');
  }

  return parsed;
}
