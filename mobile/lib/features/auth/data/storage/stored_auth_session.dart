import 'package:memory_map/features/auth/data/storage/auth_session_storage.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';

final class StoredAuthSession {
  StoredAuthSession({
    required this.user,
    required this.tokens,
  });

  factory StoredAuthSession.fromDomain(AuthSession session) {
    return StoredAuthSession(
      user: session.user,
      tokens: session.tokens,
    );
  }

  factory StoredAuthSession.fromJson(Object? json) {
    if (json is! Map) {
      throw const CorruptStoredAuthSessionException();
    }

    final version = _requiredInt(json, 'version');
    if (version != currentVersion) {
      throw const CorruptStoredAuthSessionException();
    }

    final userJson = _requiredMap(json, 'user');
    final tokensJson = _requiredMap(json, 'tokens');

    try {
      return StoredAuthSession(
        user: AuthUser(
          id: _requiredString(userJson, 'id'),
          displayName: _requiredString(userJson, 'displayName'),
          avatarUrl: _optionalString(userJson, 'avatarUrl'),
          hasCustomAvatar: _optionalBool(userJson, 'hasCustomAvatar') ?? false,
        ),
        tokens: AuthTokens(
          accessToken: _requiredString(tokensJson, 'accessToken'),
          refreshToken: _requiredString(tokensJson, 'refreshToken'),
        ),
      );
    } on ArgumentError {
      throw const CorruptStoredAuthSessionException();
    }
  }

  static const int currentVersion = 1;

  final AuthUser user;
  final AuthTokens tokens;

  AuthSession toDomain() {
    return AuthSession(
      user: user,
      tokens: tokens,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'version': currentVersion,
      'user': <String, Object?>{
        'id': user.id,
        'displayName': user.displayName,
        'avatarUrl': user.avatarUrl,
        'hasCustomAvatar': user.hasCustomAvatar,
      },
      'tokens': <String, Object?>{
        'accessToken': tokens.accessToken,
        'refreshToken': tokens.refreshToken,
      },
    };
  }

  @override
  String toString() => 'StoredAuthSession[REDACTED]';

  static int _requiredInt(Map<Object?, Object?> json, String key) {
    final value = json[key];
    if (value is! int) {
      throw const CorruptStoredAuthSessionException();
    }

    return value;
  }

  static Map<Object?, Object?> _requiredMap(
    Map<Object?, Object?> json,
    String key,
  ) {
    final value = json[key];
    if (value is! Map) {
      throw const CorruptStoredAuthSessionException();
    }

    return value.cast<Object?, Object?>();
  }

  static String _requiredString(Map<Object?, Object?> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw const CorruptStoredAuthSessionException();
    }

    return value;
  }

  static String? _optionalString(Map<Object?, Object?> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }

    if (value is String) {
      return value;
    }

    throw const CorruptStoredAuthSessionException();
  }

  static bool? _optionalBool(Map<Object?, Object?> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }

    if (value is bool) {
      return value;
    }

    throw const CorruptStoredAuthSessionException();
  }
}
