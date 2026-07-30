import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/data/remote/dto/auth_token_response_dto.dart';
import 'package:memory_map/features/auth/data/remote/dto/auth_user_dto.dart';
import 'package:memory_map/features/auth/data/remote/dto/google_login_request_dto.dart';
import 'package:memory_map/features/auth/data/remote/dto/google_login_response_dto.dart';
import 'package:memory_map/features/auth/data/remote/dto/refresh_token_request_dto.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';

void main() {
  group('GoogleLoginRequestDto', () {
    test('shouldSerializeGoogleLoginRequest', () {
      final request = GoogleLoginRequestDto(
        idToken: 'raw-google-id-token',
      );

      expect(request.toJson(), <String, Object?>{
        'idToken': 'raw-google-id-token',
      });
    });

    test('shouldRejectEmptyGoogleIdToken', () {
      expect(
        () => GoogleLoginRequestDto(idToken: ''),
        throwsA(argumentErrorWithMessage('idToken must not be blank')),
      );
    });

    test('shouldRejectWhitespaceGoogleIdToken', () {
      expect(
        () => GoogleLoginRequestDto(idToken: '   '),
        throwsA(argumentErrorWithMessage('idToken must not be blank')),
      );
    });

    test('shouldCompareGoogleLoginRequestsByValue', () {
      final first = GoogleLoginRequestDto(idToken: 'raw-google-id-token');
      final second = GoogleLoginRequestDto(idToken: 'raw-google-id-token');
      final different = GoogleLoginRequestDto(idToken: 'other-google-token');

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldRedactGoogleIdTokenInToString', () {
      const idToken = 'raw-google-id-token';
      final request = GoogleLoginRequestDto(idToken: idToken);

      expect(request.toString(), 'GoogleLoginRequestDto[REDACTED]');
      expect(request.toString(), isNot(contains(idToken)));
    });
  });

  group('RefreshTokenRequestDto', () {
    test('shouldSerializeRefreshTokenRequest', () {
      final request = RefreshTokenRequestDto(
        refreshToken: 'raw-refresh-token',
      );

      expect(request.toJson(), <String, Object?>{
        'refreshToken': 'raw-refresh-token',
      });
    });

    test('shouldRejectEmptyRefreshToken', () {
      expect(
        () => RefreshTokenRequestDto(refreshToken: ''),
        throwsA(argumentErrorWithMessage('refreshToken must not be blank')),
      );
    });

    test('shouldRejectWhitespaceRefreshToken', () {
      expect(
        () => RefreshTokenRequestDto(refreshToken: '   '),
        throwsA(argumentErrorWithMessage('refreshToken must not be blank')),
      );
    });

    test('shouldCompareRefreshTokenRequestsByValue', () {
      final first = RefreshTokenRequestDto(refreshToken: 'raw-refresh-token');
      final second = RefreshTokenRequestDto(refreshToken: 'raw-refresh-token');
      final different = RefreshTokenRequestDto(
        refreshToken: 'other-refresh-token',
      );

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldRedactRefreshTokenInToString', () {
      const refreshToken = 'raw-refresh-token';
      final request = RefreshTokenRequestDto(refreshToken: refreshToken);

      expect(request.toString(), 'RefreshTokenRequestDto[REDACTED]');
      expect(request.toString(), isNot(contains(refreshToken)));
    });
  });

  group('AuthUserDto', () {
    test('shouldParseAuthUser', () {
      final user = AuthUserDto.fromJson(validUserJson());

      expect(user.id, 'user-id');
      expect(user.displayName, 'Ada Lovelace');
      expect(user.avatarUrl, 'https://example.com/avatar.png');
    });

    test('shouldAllowNullAvatarUrl', () {
      final user = AuthUserDto.fromJson(
        <String, Object?>{
          ...validUserJson(),
          'avatarUrl': null,
        },
      );

      expect(user.avatarUrl, isNull);
    });

    test('shouldAllowBlankAvatarUrl', () {
      final user = AuthUserDto.fromJson(
        <String, Object?>{
          ...validUserJson(),
          'avatarUrl': '   ',
        },
      );

      expect(user.avatarUrl, '   ');
    });

    test('shouldRejectNonMapAuthUser', () {
      expectMalformed(() => AuthUserDto.fromJson(<Object?>[]));
    });

    test('shouldRejectMissingUserId', () {
      final json = validUserJson()..remove('id');

      expectMalformed(() => AuthUserDto.fromJson(json));
    });

    test('shouldRejectNonStringUserId', () {
      expectMalformed(
        () => AuthUserDto.fromJson(
          <String, Object?>{
            ...validUserJson(),
            'id': 123,
          },
        ),
      );
    });

    test('shouldRejectBlankUserId', () {
      expectMalformed(
        () => AuthUserDto.fromJson(
          <String, Object?>{
            ...validUserJson(),
            'id': '   ',
          },
        ),
      );
    });

    test('shouldRejectMissingDisplayName', () {
      final json = validUserJson()..remove('displayName');

      expectMalformed(() => AuthUserDto.fromJson(json));
    });

    test('shouldRejectNonStringDisplayName', () {
      expectMalformed(
        () => AuthUserDto.fromJson(
          <String, Object?>{
            ...validUserJson(),
            'displayName': 123,
          },
        ),
      );
    });

    test('shouldRejectBlankDisplayName', () {
      expectMalformed(
        () => AuthUserDto.fromJson(
          <String, Object?>{
            ...validUserJson(),
            'displayName': '   ',
          },
        ),
      );
    });

    test('shouldRejectNonStringAvatarUrl', () {
      expectMalformed(
        () => AuthUserDto.fromJson(
          <String, Object?>{
            ...validUserJson(),
            'avatarUrl': 123,
          },
        ),
      );
    });

    test('shouldMapAuthUserToDomain', () {
      final user = AuthUserDto.fromJson(validUserJson()).toDomain();

      expect(
        user,
        AuthUser(
          id: 'user-id',
          displayName: 'Ada Lovelace',
          avatarUrl: 'https://example.com/avatar.png',
        ),
      );
    });
  });

  group('AuthTokenResponseDto', () {
    test('shouldParseAuthTokens', () {
      final tokens = AuthTokenResponseDto.fromJson(validTokensJson());

      expect(tokens.accessToken, 'signed-access-token');
      expect(tokens.refreshToken, 'raw-refresh-token');
    });

    test('shouldRejectMissingAccessToken', () {
      final json = validTokensJson()..remove('accessToken');

      expectMalformed(() => AuthTokenResponseDto.fromJson(json));
    });

    test('shouldRejectNonStringAccessToken', () {
      expectMalformed(
        () => AuthTokenResponseDto.fromJson(
          <String, Object?>{
            ...validTokensJson(),
            'accessToken': 123,
          },
        ),
      );
    });

    test('shouldRejectBlankAccessToken', () {
      expectMalformed(
        () => AuthTokenResponseDto.fromJson(
          <String, Object?>{
            ...validTokensJson(),
            'accessToken': '   ',
          },
        ),
      );
    });

    test('shouldRejectMissingRefreshToken', () {
      final json = validTokensJson()..remove('refreshToken');

      expectMalformed(() => AuthTokenResponseDto.fromJson(json));
    });

    test('shouldRejectNonStringRefreshToken', () {
      expectMalformed(
        () => AuthTokenResponseDto.fromJson(
          <String, Object?>{
            ...validTokensJson(),
            'refreshToken': 123,
          },
        ),
      );
    });

    test('shouldRejectBlankRefreshToken', () {
      expectMalformed(
        () => AuthTokenResponseDto.fromJson(
          <String, Object?>{
            ...validTokensJson(),
            'refreshToken': '   ',
          },
        ),
      );
    });

    test('shouldMapTokensToDomain', () {
      final tokens = AuthTokenResponseDto.fromJson(validTokensJson()).toDomain();

      expect(
        tokens,
        AuthTokens(
          accessToken: 'signed-access-token',
          refreshToken: 'raw-refresh-token',
        ),
      );
    });

    test('shouldRedactTokensInToString', () {
      final tokens = AuthTokenResponseDto.fromJson(validTokensJson());

      expect(tokens.toString(), 'AuthTokenResponseDto[REDACTED]');
      expect(tokens.toString(), isNot(contains('signed-access-token')));
      expect(tokens.toString(), isNot(contains('raw-refresh-token')));
    });
  });

  group('GoogleLoginResponseDto', () {
    test('shouldParseGoogleLoginResponse', () {
      final response = GoogleLoginResponseDto.fromJson(validLoginResponseJson());

      expect(response.user, AuthUserDto.fromJson(validUserJson()));
      expect(response.accessToken, 'signed-access-token');
      expect(response.refreshToken, 'raw-refresh-token');
    });

    test('shouldMapGoogleLoginResponseToAuthSession', () {
      final session = GoogleLoginResponseDto.fromJson(
        validLoginResponseJson(),
      ).toDomain();

      expect(
        session,
        AuthSession(
          user: AuthUser(
            id: 'user-id',
            displayName: 'Ada Lovelace',
            avatarUrl: 'https://example.com/avatar.png',
          ),
          tokens: AuthTokens(
            accessToken: 'signed-access-token',
            refreshToken: 'raw-refresh-token',
          ),
        ),
      );
    });

    test('shouldRejectMissingUser', () {
      final json = validLoginResponseJson()..remove('user');

      expectMalformed(() => GoogleLoginResponseDto.fromJson(json));
    });

    test('shouldRejectInvalidUser', () {
      expectMalformed(
        () => GoogleLoginResponseDto.fromJson(
          <String, Object?>{
            ...validLoginResponseJson(),
            'user': <String, Object?>{
              ...validUserJson(),
              'id': '   ',
            },
          },
        ),
      );
    });

    test('shouldRejectMissingAccessToken', () {
      final json = validLoginResponseJson()..remove('accessToken');

      expectMalformed(() => GoogleLoginResponseDto.fromJson(json));
    });

    test('shouldRejectMissingRefreshToken', () {
      final json = validLoginResponseJson()..remove('refreshToken');

      expectMalformed(() => GoogleLoginResponseDto.fromJson(json));
    });

    test('shouldRedactResponseInToString', () {
      final response = GoogleLoginResponseDto.fromJson(validLoginResponseJson());

      expect(response.toString(), 'GoogleLoginResponseDto[REDACTED]');
      expect(response.toString(), isNot(contains('signed-access-token')));
      expect(response.toString(), isNot(contains('raw-refresh-token')));
      expect(response.toString(), isNot(contains('user-id')));
    });
  });
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}

void expectMalformed(Object? Function() callback) {
  expect(callback, throwsA(isA<FormatException>()));
}

Map<String, Object?> validUserJson() {
  return <String, Object?>{
    'id': 'user-id',
    'displayName': 'Ada Lovelace',
    'avatarUrl': 'https://example.com/avatar.png',
  };
}

Map<String, Object?> validTokensJson() {
  return <String, Object?>{
    'accessToken': 'signed-access-token',
    'refreshToken': 'raw-refresh-token',
  };
}

Map<String, Object?> validLoginResponseJson() {
  return <String, Object?>{
    'user': validUserJson(),
    'accessToken': 'signed-access-token',
    'refreshToken': 'raw-refresh-token',
  };
}
