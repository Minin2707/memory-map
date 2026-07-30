import 'package:memory_map/features/auth/domain/auth_tokens.dart';

final class AuthTokenResponseDto {
  factory AuthTokenResponseDto.fromJson(Object? json) {
    final map = _requiredRootMap(json);

    return AuthTokenResponseDto(
      accessToken: _requiredString(map, 'accessToken'),
      refreshToken: _requiredString(map, 'refreshToken'),
    );
  }

  AuthTokenResponseDto({
    required this.accessToken,
    required this.refreshToken,
  }) {
    if (accessToken.trim().isEmpty) {
      throw const FormatException('Malformed auth response');
    }

    if (refreshToken.trim().isEmpty) {
      throw const FormatException('Malformed auth response');
    }
  }

  final String accessToken;
  final String refreshToken;

  AuthTokens toDomain() {
    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthTokenResponseDto &&
            accessToken == other.accessToken &&
            refreshToken == other.refreshToken;
  }

  @override
  int get hashCode => Object.hash(
        accessToken,
        refreshToken,
      );

  @override
  String toString() => 'AuthTokenResponseDto[REDACTED]';
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
