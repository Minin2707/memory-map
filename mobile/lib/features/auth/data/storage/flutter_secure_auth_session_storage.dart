import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/core/storage/flutter_secure_key_value_store.dart';
import 'package:memory_map/core/storage/secure_key_value_store.dart';
import 'package:memory_map/features/auth/data/storage/auth_session_storage.dart';
import 'package:memory_map/features/auth/data/storage/stored_auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';

final authSessionStorageProvider = Provider<AuthSessionStorage>((ref) {
  return FlutterSecureAuthSessionStorage(
    ref.watch(secureKeyValueStoreProvider),
  );
});

final class FlutterSecureAuthSessionStorage implements AuthSessionStorage {
  const FlutterSecureAuthSessionStorage(this._store);

  static const String _sessionKey = 'auth.session.v1';

  final SecureKeyValueStore _store;

  @override
  Future<AuthSession?> read() async {
    final value = await _readStoredValue();
    if (value == null) {
      return null;
    }

    return _decode(value);
  }

  @override
  Future<void> write(AuthSession session) async {
    final storedSession = StoredAuthSession.fromDomain(session);
    final value = jsonEncode(storedSession.toJson());

    try {
      await _store.write(
        key: _sessionKey,
        value: value,
      );
    } on Object {
      throw const AuthSessionStorageException();
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _store.delete(key: _sessionKey);
    } on Object {
      throw const AuthSessionStorageException();
    }
  }

  @override
  String toString() => 'FlutterSecureAuthSessionStorage';

  Future<String?> _readStoredValue() async {
    try {
      return await _store.read(key: _sessionKey);
    } on Object {
      throw const AuthSessionStorageException();
    }
  }

  AuthSession _decode(String value) {
    try {
      final decoded = jsonDecode(value);
      return StoredAuthSession.fromJson(decoded).toDomain();
    } on CorruptStoredAuthSessionException {
      rethrow;
    } on Object {
      throw const CorruptStoredAuthSessionException();
    }
  }
}
