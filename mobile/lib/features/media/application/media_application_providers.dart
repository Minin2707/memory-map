import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/media/application/default_media_repository.dart';
import 'package:memory_map/features/media/data/cache/private_media_disk_cache.dart';
import 'package:memory_map/features/media/data/picker/image_picker_photo_selection_gateway.dart';
import 'package:memory_map/features/media/data/preprocessing/image_photo_preprocessor.dart';
import 'package:memory_map/features/media/data/remote/dio_media_remote_data_source.dart';
import 'package:memory_map/features/media/domain/authenticated_media_cache.dart';
import 'package:memory_map/features/media/domain/media_repository.dart';
import 'package:memory_map/features/media/domain/photo_preprocessor.dart';
import 'package:memory_map/features/media/domain/photo_selection_gateway.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  final authenticatedMediaCache = ref.watch(authenticatedMediaCacheProvider);
  final sessionStore = ref.watch(authSessionStoreProvider);
  final sessionSubscription = sessionStore.changes.listen((session) {
    if (session == null) {
      unawaited(authenticatedMediaCache.clear());
    }
  });
  ref.onDispose(() {
    unawaited(sessionSubscription.cancel());
  });

  return DefaultMediaRepository(
    mediaRemoteDataSource: ref.watch(mediaRemoteDataSourceProvider),
    authenticatedMediaCache: authenticatedMediaCache,
  );
});

final authenticatedMediaCacheProvider = Provider<AuthenticatedMediaCache>((ref) {
  return PrivateMediaDiskCache(
    directoryProvider: defaultPrivateMediaCacheDirectory,
  );
});

final photoSelectionGatewayProvider = Provider<PhotoSelectionGateway>((ref) {
  return ImagePickerPhotoSelectionGateway();
});

final photoPreprocessorProvider = Provider<PhotoPreprocessor>((ref) {
  return const ImagePhotoPreprocessor();
});
