import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:memory_map/core/storage/secure_key_value_store.dart';
import 'package:memory_map/core/storage/secure_storage_provider.dart';

final secureKeyValueStoreProvider = Provider<SecureKeyValueStore>((ref) {
  return FlutterSecureKeyValueStore(ref.watch(secureStorageProvider));
});

final class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore(this._secureStorage);

  final FlutterSecureStorage _secureStorage;

  @override
  Future<String?> read({required String key}) {
    return _secureStorage.read(key: key);
  }

  @override
  Future<void> write({
    required String key,
    required String value,
  }) {
    return _secureStorage.write(
      key: key,
      value: value,
    );
  }

  @override
  Future<void> delete({required String key}) {
    return _secureStorage.delete(key: key);
  }
}
