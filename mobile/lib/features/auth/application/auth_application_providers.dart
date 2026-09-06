import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/auth/application/auth_user_response_decoder.dart';
import 'package:memory_map/features/auth/application/default_auth_repository.dart';
import 'package:memory_map/features/auth/data/google/google_sign_in_identity_provider.dart';
import 'package:memory_map/features/auth/data/remote/dio_auth_remote_data_source.dart';
import 'package:memory_map/features/auth/data/remote/dto/default_auth_user_response_decoder.dart';
import 'package:memory_map/features/auth/data/storage/flutter_secure_auth_session_storage.dart';
import 'package:memory_map/features/auth/domain/auth_repository.dart';

final authUserResponseDecoderProvider = Provider<AuthUserResponseDecoder>(
  (ref) => const DefaultAuthUserResponseDecoder(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return DefaultAuthRepository(
    googleIdentityProvider: ref.watch(googleIdentityProvider),
    authRemoteDataSource: ref.watch(authRemoteDataSourceProvider),
    authSessionStorage: ref.watch(authSessionStorageProvider),
    authSessionStore: ref.watch(authSessionStoreProvider),
  );
});
