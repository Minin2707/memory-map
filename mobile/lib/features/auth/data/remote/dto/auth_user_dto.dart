import 'package:memory_map/features/auth/domain/auth_user.dart';

final class AuthUserDto {
  factory AuthUserDto.fromJson(Object? json) {
    final map = _requiredRootMap(json);

    return AuthUserDto(
      id: _requiredString(map, 'id'),
      displayName: _requiredString(map, 'displayName'),
      avatarUrl: _optionalString(map, 'avatarUrl'),
      hasCustomAvatar: _optionalBool(map, 'hasCustomAvatar') ?? false,
    );
  }

  AuthUserDto({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.hasCustomAvatar = false,
  }) {
    if (id.trim().isEmpty) {
      throw const FormatException('Malformed auth response');
    }

    if (displayName.trim().isEmpty) {
      throw const FormatException('Malformed auth response');
    }
  }

  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool hasCustomAvatar;

  AuthUser toDomain() {
    return AuthUser(
      id: id,
      displayName: displayName,
      avatarUrl: avatarUrl,
      hasCustomAvatar: hasCustomAvatar,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthUserDto &&
            id == other.id &&
            displayName == other.displayName &&
            avatarUrl == other.avatarUrl &&
            hasCustomAvatar == other.hasCustomAvatar;
  }

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        avatarUrl,
        hasCustomAvatar,
      );

  @override
  String toString() => 'AuthUserDto';
}

Map<Object?, Object?> _requiredRootMap(Object? json) {
  if (json is! Map) {
    throw const FormatException('Malformed auth response');
  }

  return json.cast<Object?, Object?>();
}

String _requiredString(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw const FormatException('Malformed auth response');
  }

  return value;
}

String? _optionalString(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is String) {
    return value;
  }

  throw const FormatException('Malformed auth response');
}

bool? _optionalBool(Map<Object?, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is bool) {
    return value;
  }

  throw const FormatException('Malformed auth response');
}
