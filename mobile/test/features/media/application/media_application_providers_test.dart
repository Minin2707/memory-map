import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/auth/application/in_memory_auth_session_store.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/data/remote/dio_media_remote_data_source.dart';
import 'package:memory_map/features/media/data/remote/media_remote_data_source.dart';
import 'package:memory_map/features/media/domain/authenticated_media_cache.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';

void main() {
  group('mediaApplicationProviders private media cache lifecycle', () {
    test('shouldClearAuthenticatedMediaCacheWhenSessionInvalidates', () async {
      final sessionStore = InMemoryAuthSessionStore();
      final cache = FakeAuthenticatedMediaCache();
      final container = ProviderContainer(
        overrides: [
          authSessionStoreProvider.overrideWithValue(sessionStore),
          authenticatedMediaCacheProvider.overrideWithValue(cache),
          mediaRemoteDataSourceProvider.overrideWithValue(
            FakeMediaRemoteDataSource(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(sessionStore.dispose);

      container.read(mediaRepositoryProvider);
      sessionStore.setSession(session);
      sessionStore.clear();

      expect(cache.clearCalls, 1);
    });

    test('shouldNotClearAuthenticatedMediaCacheOnSessionRefresh', () async {
      final sessionStore = InMemoryAuthSessionStore();
      final cache = FakeAuthenticatedMediaCache();
      final container = ProviderContainer(
        overrides: [
          authSessionStoreProvider.overrideWithValue(sessionStore),
          authenticatedMediaCacheProvider.overrideWithValue(cache),
          mediaRemoteDataSourceProvider.overrideWithValue(
            FakeMediaRemoteDataSource(),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(sessionStore.dispose);

      container.read(mediaRepositoryProvider);
      sessionStore.setSession(session);
      sessionStore.setSession(refreshedSession);

      expect(cache.clearCalls, 0);
    });
  });
}

final AuthSession session = AuthSession(
  user: AuthUser(
    id: 'user-id',
    displayName: 'Ada Lovelace',
    avatarUrl: null,
  ),
  tokens: AuthTokens(
    accessToken: 'signed-access-token',
    refreshToken: 'raw-refresh-token',
  ),
);

final AuthSession refreshedSession = AuthSession(
  user: session.user,
  tokens: AuthTokens(
    accessToken: 'new-access-token',
    refreshToken: 'new-refresh-token',
  ),
);

final class FakeAuthenticatedMediaCache implements AuthenticatedMediaCache {
  int clearCalls = 0;

  @override
  Future<Uint8List> getOrFetch(
    String backendPath,
    Future<Uint8List> Function() fetch,
  ) {
    return fetch();
  }

  @override
  Future<void> clear() async {
    clearCalls += 1;
  }
}

final class FakeMediaRemoteDataSource implements MediaRemoteDataSource {
  @override
  Future<void> deleteMedia(String mediaId) async {}

  @override
  Future<List<Media>> getMedia(String memoryId) async {
    return <Media>[];
  }

  @override
  Future<Uint8List> getRepresentation(String backendPath) async {
    return Uint8List.fromList(<int>[1, 2, 3]);
  }

  @override
  Future<Media> uploadPhoto(
    String memoryId,
    PreparedPhotoUpload photo,
  ) {
    throw UnimplementedError();
  }
}
