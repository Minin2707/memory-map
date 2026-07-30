import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/core/storage/secure_key_value_store.dart';
import 'package:memory_map/features/auth/data/storage/auth_session_storage.dart';
import 'package:memory_map/features/auth/data/storage/flutter_secure_auth_session_storage.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';

void main() {
  group('FlutterSecureAuthSessionStorage', () {
    test('shouldReturnNullWhenStoredSessionDoesNotExist', () async {
      final store = FakeSecureKeyValueStore();
      final storage = FlutterSecureAuthSessionStorage(store);

      final session = await storage.read();

      expect(session, isNull);
    });

    test('shouldReadStoredSession', () async {
      final store = FakeSecureKeyValueStore()
        ..values[sessionKey] = validSessionJsonString();
      final storage = FlutterSecureAuthSessionStorage(store);

      final session = await storage.read();

      expect(session, createSession());
    });

    test('shouldUseSingleStableSessionKeyForRead', () async {
      final store = FakeSecureKeyValueStore();
      final storage = FlutterSecureAuthSessionStorage(store);

      await storage.read();

      expect(store.readCalls, 1);
      expect(store.lastReadKey, sessionKey);
    });

    test('shouldWriteSessionAsSingleVersionedJsonBlob', () async {
      final store = FakeSecureKeyValueStore();
      final storage = FlutterSecureAuthSessionStorage(store);

      await storage.write(createSession());

      expect(store.writeCalls, 1);
      final decoded = jsonDecode(store.values[sessionKey]!) as Map;
      expect(decoded['version'], 1);
      expect(decoded['user'], validUserJson());
      expect(decoded['tokens'], validTokensJson());
    });

    test('shouldReplaceExistingSessionWithOneWrite', () async {
      final store = FakeSecureKeyValueStore()
        ..values[sessionKey] = validSessionJsonString(
          accessToken: 'old-access-token',
          refreshToken: 'old-refresh-token',
        );
      final storage = FlutterSecureAuthSessionStorage(store);

      await storage.write(createSession());

      final decoded = jsonDecode(store.values[sessionKey]!) as Map;
      final tokens = decoded['tokens'] as Map;
      expect(store.writeCalls, 1);
      expect(tokens['accessToken'], 'signed-access-token');
      expect(tokens['refreshToken'], 'raw-refresh-token');
    });

    test('shouldUseSingleStableSessionKeyForWrite', () async {
      final store = FakeSecureKeyValueStore();
      final storage = FlutterSecureAuthSessionStorage(store);

      await storage.write(createSession());

      expect(store.lastWriteKey, sessionKey);
    });

    test('shouldClearOnlyAuthSessionKey', () async {
      final store = FakeSecureKeyValueStore()
        ..values[sessionKey] = validSessionJsonString()
        ..values['other.key'] = 'other-value';
      final storage = FlutterSecureAuthSessionStorage(store);

      await storage.clear();

      expect(store.values.containsKey(sessionKey), isFalse);
      expect(store.values['other.key'], 'other-value');
      expect(store.lastDeleteKey, sessionKey);
      expect(store.deleteCalls, 1);
    });

    test('shouldTreatClearAsIdempotent', () async {
      final store = FakeSecureKeyValueStore();
      final storage = FlutterSecureAuthSessionStorage(store);

      await storage.clear();

      expect(store.values.containsKey(sessionKey), isFalse);
      expect(store.deleteCalls, 1);
    });

    test('shouldMapReadStoreFailureToStorageException', () async {
      final store = FakeSecureKeyValueStore()
        ..readFailure = const TestStoreException();
      final storage = FlutterSecureAuthSessionStorage(store);

      await expectLater(
        storage.read(),
        throwsA(isA<AuthSessionStorageException>()),
      );
    });

    test('shouldMapWriteStoreFailureToStorageException', () async {
      final store = FakeSecureKeyValueStore()
        ..writeFailure = const TestStoreException();
      final storage = FlutterSecureAuthSessionStorage(store);

      await expectLater(
        storage.write(createSession()),
        throwsA(isA<AuthSessionStorageException>()),
      );
    });

    test('shouldMapDeleteStoreFailureToStorageException', () async {
      final store = FakeSecureKeyValueStore()
        ..deleteFailure = const TestStoreException();
      final storage = FlutterSecureAuthSessionStorage(store);

      await expectLater(
        storage.clear(),
        throwsA(isA<AuthSessionStorageException>()),
      );
    });

    test('shouldMapMalformedJsonToCorruptSessionException', () async {
      final store = FakeSecureKeyValueStore()
        ..values[sessionKey] = 'not-json';
      final storage = FlutterSecureAuthSessionStorage(store);

      await expectLater(
        storage.read(),
        throwsA(isA<CorruptStoredAuthSessionException>()),
      );
    });

    test('shouldMapUnsupportedVersionToCorruptSessionException', () async {
      final store = FakeSecureKeyValueStore()
        ..values[sessionKey] = validSessionJsonString(version: 2);
      final storage = FlutterSecureAuthSessionStorage(store);

      await expectLater(
        storage.read(),
        throwsA(isA<CorruptStoredAuthSessionException>()),
      );
    });

    test('shouldNotDeleteCorruptSessionDuringRead', () async {
      final store = FakeSecureKeyValueStore()
        ..values[sessionKey] = 'not-json';
      final storage = FlutterSecureAuthSessionStorage(store);

      await expectLater(
        storage.read(),
        throwsA(isA<CorruptStoredAuthSessionException>()),
      );

      expect(store.deleteCalls, 0);
      expect(store.values[sessionKey], 'not-json');
    });

    test('shouldNotExposeStoredValueInExceptions', () async {
      const storedValue = 'signed-access-token raw-refresh-token user-id';
      final store = FakeSecureKeyValueStore()..values[sessionKey] = storedValue;
      final storage = FlutterSecureAuthSessionStorage(store);

      try {
        await storage.read();
        fail('Expected corrupt stored session');
      } on CorruptStoredAuthSessionException catch (error) {
        expect(error.toString(), 'CorruptStoredAuthSessionException');
        expect(error.toString(), isNot(contains(storedValue)));
        expect(error.toString(), isNot(contains('signed-access-token')));
        expect(error.toString(), isNot(contains('raw-refresh-token')));
        expect(error.toString(), isNot(contains('user-id')));
      }
    });

    test('shouldNotExposeTokensThroughToString', () {
      final store = FakeSecureKeyValueStore()
        ..values[sessionKey] = validSessionJsonString();
      final storage = FlutterSecureAuthSessionStorage(store);

      expect(storage.toString(), 'FlutterSecureAuthSessionStorage');
      expect(storage.toString(), isNot(contains('signed-access-token')));
      expect(storage.toString(), isNot(contains('raw-refresh-token')));
    });
  });
}

const String sessionKey = 'auth.session.v1';

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

String validSessionJsonString({
  int version = 1,
  String accessToken = 'signed-access-token',
  String refreshToken = 'raw-refresh-token',
}) {
  return jsonEncode(<String, Object?>{
    'version': version,
    'user': validUserJson(),
    'tokens': <String, Object?>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    },
  });
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

final class FakeSecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  int readCalls = 0;
  int writeCalls = 0;
  int deleteCalls = 0;

  String? lastReadKey;
  String? lastWriteKey;
  String? lastDeleteKey;

  Object? readFailure;
  Object? writeFailure;
  Object? deleteFailure;

  @override
  Future<String?> read({required String key}) async {
    readCalls += 1;
    lastReadKey = key;

    final failure = readFailure;
    if (failure != null) {
      throw failure;
    }

    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String value,
  }) async {
    writeCalls += 1;
    lastWriteKey = key;

    final failure = writeFailure;
    if (failure != null) {
      throw failure;
    }

    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    deleteCalls += 1;
    lastDeleteKey = key;

    final failure = deleteFailure;
    if (failure != null) {
      throw failure;
    }

    values.remove(key);
  }
}

final class TestStoreException implements Exception {
  const TestStoreException();
}
