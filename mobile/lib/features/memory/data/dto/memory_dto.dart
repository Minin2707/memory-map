import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';

final class MemoryDto {
  factory MemoryDto.fromJson(Object? json) {
    final map = memoryRequiredRootMap(json);

    return MemoryDto(
      id: memoryRequiredString(map, 'id'),
      storyId: memoryRequiredString(map, 'storyId'),
      createdBy: memoryRequiredString(map, 'createdBy'),
      title: memoryRequiredString(map, 'title'),
      description: memoryOptionalString(map, 'description'),
      placeName: memoryOptionalString(map, 'placeName'),
      latitude: memoryRequiredDouble(map, 'latitude'),
      longitude: memoryRequiredDouble(map, 'longitude'),
      eventDate: memoryRequiredMemoryDate(map, 'eventDate'),
      createdAt: memoryRequiredDate(map, 'createdAt'),
      updatedAt: memoryRequiredDate(map, 'updatedAt'),
      previewPhoto: MemoryPhotoPreviewDto.fromNullableJson(
        map['previewPhoto'],
      ),
    );
  }

  MemoryDto({
    required this.id,
    required this.storyId,
    required this.createdBy,
    required this.title,
    this.description,
    this.placeName,
    required this.latitude,
    required this.longitude,
    required this.eventDate,
    required this.createdAt,
    required this.updatedAt,
    this.previewPhoto,
  }) {
    try {
      Memory(
        id: id,
        storyId: storyId,
        createdBy: createdBy,
        title: title,
        description: description,
        placeName: placeName,
        location: MemoryLocation(
          latitude: latitude,
          longitude: longitude,
        ),
        eventDate: eventDate,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } on Object {
      throw const FormatException('Malformed memory response');
    }
  }

  final String id;
  final String storyId;
  final String createdBy;
  final String title;
  final String? description;
  final String? placeName;
  final double latitude;
  final double longitude;
  final MemoryDate eventDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MemoryPhotoPreviewDto? previewPhoto;

  Memory toDomain() {
    return Memory(
      id: id,
      storyId: storyId,
      createdBy: createdBy,
      title: title,
      description: description,
      placeName: placeName,
      location: MemoryLocation(
        latitude: latitude,
        longitude: longitude,
      ),
      eventDate: eventDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  MemoryReadModel toReadModel() {
    return MemoryReadModel(
      memory: toDomain(),
      previewPhoto: previewPhoto?.toDomain(),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MemoryDto &&
            id == other.id &&
            storyId == other.storyId &&
            createdBy == other.createdBy &&
            title == other.title &&
            description == other.description &&
            placeName == other.placeName &&
            latitude == other.latitude &&
            longitude == other.longitude &&
            eventDate == other.eventDate &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt &&
            previewPhoto == other.previewPhoto;
  }

  @override
  int get hashCode => Object.hash(
        id,
        storyId,
        createdBy,
        title,
        description,
        placeName,
        latitude,
        longitude,
        eventDate,
        createdAt,
        updatedAt,
        previewPhoto,
      );

  @override
  String toString() => 'MemoryDto';
}

final class MemoryPhotoPreviewDto {
  factory MemoryPhotoPreviewDto.fromJson(Object? json) {
    final map = memoryRequiredRootMap(json);

    return MemoryPhotoPreviewDto(
      mediaId: memoryRequiredString(map, 'mediaId'),
      thumbnailPath: memoryRequiredString(map, 'thumbnailUrl'),
    );
  }

  static MemoryPhotoPreviewDto? fromNullableJson(Object? json) {
    if (json == null) {
      return null;
    }

    return MemoryPhotoPreviewDto.fromJson(json);
  }

  MemoryPhotoPreviewDto({
    required this.mediaId,
    required this.thumbnailPath,
  }) {
    try {
      MemoryPhotoPreview(
        mediaId: mediaId,
        thumbnailPath: thumbnailPath,
      );
    } on Object {
      throw const FormatException('Malformed memory response');
    }
  }

  final String mediaId;
  final String thumbnailPath;

  MemoryPhotoPreview toDomain() {
    return MemoryPhotoPreview(
      mediaId: mediaId,
      thumbnailPath: thumbnailPath,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MemoryPhotoPreviewDto &&
            mediaId == other.mediaId &&
            thumbnailPath == other.thumbnailPath;
  }

  @override
  int get hashCode => Object.hash(mediaId, thumbnailPath);

  @override
  String toString() => 'MemoryPhotoPreviewDto';
}

Map<Object?, Object?> memoryRequiredRootMap(Object? json) {
  if (json is! Map) {
    throw const FormatException('Malformed memory response');
  }

  return json.cast<Object?, Object?>();
}

String memoryRequiredString(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const FormatException('Malformed memory response');
  }

  return value;
}

String? memoryOptionalString(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is String) {
    return value;
  }

  throw const FormatException('Malformed memory response');
}

double memoryRequiredDouble(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw const FormatException('Malformed memory response');
  }

  return value.toDouble();
}

MemoryDate memoryRequiredMemoryDate(Map<Object?, Object?> json, String key) {
  final value = memoryRequiredString(json, key);

  try {
    return MemoryDate.parse(value);
  } on Object {
    throw const FormatException('Malformed memory response');
  }
}

DateTime memoryRequiredDate(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const FormatException('Malformed memory response');
  }

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw const FormatException('Malformed memory response');
  }

  return parsed;
}
