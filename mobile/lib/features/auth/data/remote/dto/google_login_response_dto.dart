import 'package:memory_map/features/auth/data/remote/dto/auth_user_dto.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';

final class GoogleLoginResponseDto {
  factory GoogleLoginResponseDto.fromJson(Object? json) {
    final map = _requiredRootMap(json);

    return GoogleLoginResponseDto(
      user: AuthUserDto.fromJson(map['user']),
      accessToken: _requiredString(map, 'accessToken'),
      refreshToken: _requiredString(map, 'refreshToken'),
    );
  }

  GoogleLoginResponseDto({
    required this.user,
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

  final AuthUserDto user;
  final String accessToken;
  final String refreshToken;

  AuthSession toDomain() {
    return AuthSession(
      user: user.toDomain(),
      tokens: AuthTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GoogleLoginResponseDto &&
            user == other.user &&
            accessToken == other.accessToken &&
            refreshToken == other.refreshToken;
  }

  @override
  int get hashCode => Object.hash(
        user,
        accessToken,
        refreshToken,
      );

  @override
  String toString() => 'GoogleLoginResponseDto[REDACTED]';
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
