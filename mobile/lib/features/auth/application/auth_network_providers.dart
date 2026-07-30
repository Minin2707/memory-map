import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/application/default_authorized_session_manager.dart';
import 'package:memory_map/features/auth/application/in_memory_auth_session_store.dart';
import 'package:memory_map/features/auth/data/remote/dio_auth_remote_data_source.dart';
import 'package:memory_map/features/auth/data/storage/flutter_secure_auth_session_storage.dart';
import 'package:memory_map/features/auth/domain/auth_session_store.dart';
import 'package:memory_map/features/auth/domain/authorized_session_manager.dart';

final authSessionStoreProvider = Provider<AuthSessionStore>((ref) {
  final store = InMemoryAuthSessionStore();
  ref.onDispose(store.dispose);

  return store;
});

final authorizedSessionManagerProvider =
    Provider<AuthorizedSessionManager>((ref) {
  return DefaultAuthorizedSessionManager(
    authSessionStore: ref.watch(authSessionStoreProvider),
    authRemoteDataSource: ref.watch(authRemoteDataSourceProvider),
    authSessionStorage: ref.watch(authSessionStorageProvider),
  );
});
