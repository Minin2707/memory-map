import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/data/storage/auth_session_storage.dart';
import 'package:memory_map/features/auth/data/storage/stored_auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';

void main() {
  group('StoredAuthSession', () {
    test('shouldConvertDomainSessionToVersionOneJson', () {
      final storedSession = StoredAuthSession.fromDomain(createSession());

      expect(storedSession.toJson(), validJson());
    });

    test('shouldRestoreDomainSessionFromVersionOneJson', () {
      final storedSession = StoredAuthSession.fromJson(validJson());

      expect(storedSession.toDomain(), createSession());
    });

    test('shouldPreserveNullableAvatarUrl', () {
      final json = validJson(
        user: <String, Object?>{
          'id': 'user-id',
          'displayName': 'Ada Lovelace',
          'avatarUrl': null,
        },
      );

      final storedSession = StoredAuthSession.fromJson(json);

      expect(storedSession.toDomain().user.avatarUrl, isNull);
    });

    test('shouldPreserveBlankAvatarUrl', () {
      final json = validJson(
        user: <String, Object?>{
          'id': 'user-id',
          'displayName': 'Ada Lovelace',
          'avatarUrl': '   ',
        },
      );

      final storedSession = StoredAuthSession.fromJson(json);

      expect(storedSession.toDomain().user.avatarUrl, '   ');
    });

    test('shouldRoundTripAuthSession', () {
      final session = createSession();
      final encoded = jsonEncode(
        StoredAuthSession.fromDomain(session).toJson(),
      );
      final decoded = jsonDecode(encoded);

      final restored = StoredAuthSession.fromJson(decoded).toDomain();

      expect(restored, session);
    });

    test('shouldRejectMissingVersion', () {
      final json = validJson()..remove('version');

      expectCorruptJson(json);
    });

    test('shouldRejectNonIntegerVersion', () {
      expectCorruptJson(validJson(version: '1'));
    });

    test('shouldRejectUnsupportedVersion', () {
      expectCorruptJson(validJson(version: 2));
    });

    test('shouldRejectNonMapRoot', () {
      expectCorruptJson(<Object?>[]);
    });

    test('shouldRejectMissingUser', () {
      final json = validJson()..remove('user');

      expectCorruptJson(json);
    });

    test('shouldRejectNonMapUser', () {
      expectCorruptJson(validJson(user: 'user'));
    });

    test('shouldRejectMissingTokens', () {
      final json = validJson()..remove('tokens');

      expectCorruptJson(json);
    });

    test('shouldRejectNonMapTokens', () {
      expectCorruptJson(validJson(tokens: 'tokens'));
    });

    test('shouldRejectMissingUserId', () {
      final user = validUserJson()..remove('id');

      expectCorruptJson(validJson(user: user));
    });

    test('shouldRejectNonStringUserId', () {
      expectCorruptJson(
        validJson(
          user: <String, Object?>{
            ...validUserJson(),
            'id': 123,
          },
        ),
      );
    });

    test('shouldRejectMissingDisplayName', () {
      final user = validUserJson()..remove('displayName');

      expectCorruptJson(validJson(user: user));
    });

    test('shouldRejectNonStringDisplayName', () {
      expectCorruptJson(
        validJson(
          user: <String, Object?>{
            ...validUserJson(),
            'displayName': 123,
          },
        ),
      );
    });

    test('shouldRejectNonStringAvatarUrl', () {
      expectCorruptJson(
        validJson(
          user: <String, Object?>{
            ...validUserJson(),
            'avatarUrl': 123,
          },
        ),
      );
    });

    test('shouldRejectMissingAccessToken', () {
      final tokens = validTokensJson()..remove('accessToken');

      expectCorruptJson(validJson(tokens: tokens));
    });

    test('shouldRejectNonStringAccessToken', () {
      expectCorruptJson(
        validJson(
          tokens: <String, Object?>{
            ...validTokensJson(),
            'accessToken': 123,
          },
        ),
      );
    });

    test('shouldRejectMissingRefreshToken', () {
      final tokens = validTokensJson()..remove('refreshToken');

      expectCorruptJson(validJson(tokens: tokens));
    });

    test('shouldRejectNonStringRefreshToken', () {
      expectCorruptJson(
        validJson(
          tokens: <String, Object?>{
            ...validTokensJson(),
            'refreshToken': 123,
          },
        ),
      );
    });

    test('shouldRejectBlankDomainValuesAsCorrupt', () {
      final corruptDocuments = <Object?>[
        validJson(
          user: <String, Object?>{
            ...validUserJson(),
            'id': '   ',
          },
        ),
        validJson(
          user: <String, Object?>{
            ...validUserJson(),
            'displayName': '   ',
          },
        ),
        validJson(
          tokens: <String, Object?>{
            ...validTokensJson(),
            'accessToken': '   ',
          },
        ),
        validJson(
          tokens: <String, Object?>{
            ...validTokensJson(),
            'refreshToken': '   ',
          },
        ),
      ];

      for (final document in corruptDocuments) {
        expectCorruptJson(document);
      }
    });

    test('shouldRedactStoredAuthSessionInToString', () {
      final storedSession = StoredAuthSession.fromDomain(createSession());

      expect(storedSession.toString(), 'StoredAuthSession[REDACTED]');
      expect(storedSession.toString(), isNot(contains('signed-access-token')));
      expect(storedSession.toString(), isNot(contains('raw-refresh-token')));
      expect(storedSession.toString(), isNot(contains('user-id')));
      expect(storedSession.toString(), isNot(contains('Ada Lovelace')));
      expect(
        storedSession.toString(),
        isNot(contains('https://example.com/avatar.png')),
      );
      expect(storedSession.toString(), isNot(contains('"version"')));
    });
  });
}

AuthSession createSession() {
  return AuthSession(
    user: AuthUser(
      id: 'user-id',
      displayName: 'Ada Lovelace',
      avatarUrl: 'https://example.com/avatar.png',
    ),
    tokens: AuthTokens(
      accessToken: 'signed-access-token',
      refreshToken: 'raw-refresh-token',
    ),
  );
}

Map<String, Object?> validJson({
  Object? version = StoredAuthSession.currentVersion,
  Object? user,
  Object? tokens,
}) {
  return <String, Object?>{
    'version': version,
    'user': user ?? validUserJson(),
    'tokens': tokens ?? validTokensJson(),
  };
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

void expectCorruptJson(Object? json) {
  expect(
    () => StoredAuthSession.fromJson(json),
    throwsA(isA<CorruptStoredAuthSessionException>()),
  );
}
