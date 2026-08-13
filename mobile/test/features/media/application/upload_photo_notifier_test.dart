import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/application/memory_media_notifier.dart';
import 'package:memory_map/features/media/application/upload_photo_notifier.dart';
import 'package:memory_map/features/media/application/upload_photo_state.dart';
import 'package:memory_map/features/media/domain/media.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/features/media/domain/selected_photo.dart';
import 'package:memory_map/features/memory/application/memory_application_exception.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/memory_details_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_failure.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_photo_preview.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';

import '../media_test_fixtures.dart';

void main() {
  group('UploadPhotoNotifier flow', () {
    test('shouldSelectPreprocessUploadPreparedBytesAndSyncLoadedMedia', () async {
      final repository = FakeMediaRepository()
        ..mediaResult = <Media>[media(id: 'existing-media-id')]
        ..uploadResult = media(id: 'uploaded-media-id');
      final gateway = FakePhotoSelectionGateway();
      final preprocessor = FakePhotoPreprocessor()
        ..result = preparedPhotoUpload(bytes: <int>[9, 9, 9]);
      final container = createContainer(
        repository: repository,
        gateway: gateway,
        preprocessor: preprocessor,
      );
      addTearDown(container.dispose);
      keepMemoryMediaAlive(container);
      await container.read(memoryMediaProvider(defaultMemoryId).future);
      final subscription = container.listen(
        uploadPhotoProvider(defaultMemoryId),
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(uploadPhotoProvider(defaultMemoryId).future);

      final uploaded = await container
          .read(uploadPhotoProvider(defaultMemoryId).notifier)
          .selectPrepareAndUpload();

      expect(uploaded, repository.uploadResult);
      expect(gateway.selectPhotoCalls, 1);
      expect(preprocessor.processCalls, 1);
      expect(repository.uploadPhotoCalls, 1);
      expect(repository.receivedUploads.single.bytes, <int>[9, 9, 9]);
      expect(
        container
            .read(memoryMediaProvider(defaultMemoryId))
            .asData!
            .value
            .media
            .map((item) => item.id),
        contains('uploaded-media-id'),
      );
      expect(
        container.read(uploadPhotoProvider(defaultMemoryId)).asData!.value,
        const UploadPhotoState(),
      );
    });

    test('shouldTreatPickerCancellationAsIdleWithoutFailure', () async {
      final repository = FakeMediaRepository();
      final gateway = FakePhotoSelectionGateway()..selectedPhotoResult = null;
      final preprocessor = FakePhotoPreprocessor();
      final container = createContainer(
        repository: repository,
        gateway: gateway,
        preprocessor: preprocessor,
      );
      addTearDown(container.dispose);
      await container.read(uploadPhotoProvider(defaultMemoryId).future);

      final result = await container
          .read(uploadPhotoProvider(defaultMemoryId).notifier)
          .selectPrepareAndUpload();

      expect(result, isNull);
      expect(gateway.selectPhotoCalls, 1);
      expect(preprocessor.processCalls, 0);
      expect(repository.uploadPhotoCalls, 0);
      expect(
        container.read(uploadPhotoProvider(defaultMemoryId)).asData!.value,
        const UploadPhotoState(),
      );
    });

    test('shouldIgnoreDuplicateUploadsWhileBusy', () async {
      final selectCompleter = Completer<SelectedPhoto?>();
      final repository = FakeMediaRepository();
      final gateway = FakePhotoSelectionGateway()
        ..selectCompleter = selectCompleter;
      final preprocessor = FakePhotoPreprocessor();
      final container = createContainer(
        repository: repository,
        gateway: gateway,
        preprocessor: preprocessor,
      );
      addTearDown(container.dispose);
      await container.read(uploadPhotoProvider(defaultMemoryId).future);

      final first = container
          .read(uploadPhotoProvider(defaultMemoryId).notifier)
          .selectPrepareAndUpload();
      await pumpEventQueue();
      final second = await container
          .read(uploadPhotoProvider(defaultMemoryId).notifier)
          .selectPrepareAndUpload();

      expect(second, isNull);
      expect(gateway.selectPhotoCalls, 1);

      selectCompleter.completeError(
        const MediaApplicationException(MediaUnavailable()),
      );
      await first;
    });

    test('shouldRefreshLoadedMemoryPreviewAfterUploadSuccess', () async {
      final preview = previewPhoto(mediaId: 'uploaded-media-id');
      final mediaRepository = FakeMediaRepository()
        ..uploadResult = media(id: 'uploaded-media-id');
      final memoryRepository = FakeMemoryRepository()
        ..memoryReadModelResult = MemoryReadModel(
          memory: memoryA,
          previewPhoto: preview,
        )
        ..memoriesResult = <Memory>[memoryA];
      final container = createContainer(
        repository: mediaRepository,
        gateway: FakePhotoSelectionGateway(),
        preprocessor: FakePhotoPreprocessor(),
        memoryRepository: memoryRepository,
      );
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(defaultMemoryId).future);
      await container.read(storyMemoriesProvider(defaultStoryId).future);
      await container.read(uploadPhotoProvider(defaultMemoryId).future);

      final uploaded = await container
          .read(uploadPhotoProvider(defaultMemoryId).notifier)
          .selectPrepareAndUpload();

      expect(uploaded, mediaRepository.uploadResult);
      expect(memoryRepository.getMemoryCalls, 2);
      expect(
        container
            .read(memoryDetailsProvider(defaultMemoryId))
            .asData!
            .value
            .previewPhoto,
        same(preview),
      );
      expect(
        container
            .read(storyMemoriesProvider(defaultStoryId))
            .asData!
            .value
            .memoryReadModels
            .single
            .previewPhoto,
        same(preview),
      );
    });

    test('shouldNotFailUploadWhenPreviewRefreshFails', () async {
      final oldPreview = previewPhoto(mediaId: 'old-media-id');
      final mediaRepository = FakeMediaRepository()
        ..uploadResult = media(id: 'uploaded-media-id');
      final memoryRepository = FakeMemoryRepository()
        ..memoryReadModelResult = MemoryReadModel(
          memory: memoryA,
          previewPhoto: oldPreview,
        );
      final container = createContainer(
        repository: mediaRepository,
        gateway: FakePhotoSelectionGateway(),
        preprocessor: FakePhotoPreprocessor(),
        memoryRepository: memoryRepository,
      );
      addTearDown(container.dispose);
      await container.read(memoryDetailsProvider(defaultMemoryId).future);
      await container.read(uploadPhotoProvider(defaultMemoryId).future);
      memoryRepository.getMemoryFailure = const MemoryApplicationException(
        MemoryNetworkUnavailable(),
      );

      final uploaded = await container
          .read(uploadPhotoProvider(defaultMemoryId).notifier)
          .selectPrepareAndUpload();

      expect(uploaded, mediaRepository.uploadResult);
      expect(
        container
            .read(memoryDetailsProvider(defaultMemoryId))
            .asData!
            .value
            .previewPhoto,
        same(oldPreview),
      );
      expect(
        container.read(uploadPhotoProvider(defaultMemoryId)).asData!.value,
        const UploadPhotoState(),
      );
    });
  });

  group('UploadPhotoNotifier failures', () {
    test('shouldExposeKnownPreprocessingFailureSafely', () async {
      final repository = FakeMediaRepository();
      final gateway = FakePhotoSelectionGateway();
      final preprocessor = FakePhotoPreprocessor()
        ..failure = const MediaApplicationException(
          MediaPreprocessingFailure(),
        );
      final container = createContainer(
        repository: repository,
        gateway: gateway,
        preprocessor: preprocessor,
      );
      addTearDown(container.dispose);
      await container.read(uploadPhotoProvider(defaultMemoryId).future);

      await container
          .read(uploadPhotoProvider(defaultMemoryId).notifier)
          .selectPrepareAndUpload();

      final state = container
          .read(uploadPhotoProvider(defaultMemoryId))
          .asData!
          .value;
      expect(state.failure, const MediaPreprocessingFailure());
      expect(repository.uploadPhotoCalls, 0);
      expect(state.toString(), isNot(contains('photo.jpg')));
      expect(state.toString(), isNot(contains('bytes')));
    });

    test('shouldExposeKnownUploadFailureAndClearOnNextAttempt', () async {
      final repository = FakeMediaRepository()
        ..uploadPhotoFailure =
            const MediaApplicationException(MediaNetworkUnavailable());
      final gateway = FakePhotoSelectionGateway();
      final preprocessor = FakePhotoPreprocessor();
      final container = createContainer(
        repository: repository,
        gateway: gateway,
        preprocessor: preprocessor,
      );
      addTearDown(container.dispose);
      await container.read(uploadPhotoProvider(defaultMemoryId).future);

      await container
          .read(uploadPhotoProvider(defaultMemoryId).notifier)
          .selectPrepareAndUpload();

      expect(
        container
            .read(uploadPhotoProvider(defaultMemoryId))
            .asData!
            .value
            .failure,
        const MediaNetworkUnavailable(),
      );

      repository.uploadPhotoFailure = null;
      await container
          .read(uploadPhotoProvider(defaultMemoryId).notifier)
          .selectPrepareAndUpload();

      expect(
        container.read(uploadPhotoProvider(defaultMemoryId)).asData!.value,
        const UploadPhotoState(),
      );
    });

    test('shouldRejectBlankMemoryIdWithoutPickerOrNetworkCall', () async {
      final repository = FakeMediaRepository();
      final gateway = FakePhotoSelectionGateway();
      final preprocessor = FakePhotoPreprocessor();
      final container = createContainer(
        repository: repository,
        gateway: gateway,
        preprocessor: preprocessor,
      );
      addTearDown(container.dispose);
      await container.read(uploadPhotoProvider('   ').future);

      await container
          .read(uploadPhotoProvider('   ').notifier)
          .selectPrepareAndUpload();

      expect(gateway.selectPhotoCalls, 0);
      expect(preprocessor.processCalls, 0);
      expect(repository.uploadPhotoCalls, 0);
      expect(
        container.read(uploadPhotoProvider('   ')).asData!.value.failure,
        const MediaValidationFailure(),
      );
    });

    test('shouldExposeUnexpectedFailureAsAsyncError', () async {
      final repository = FakeMediaRepository();
      final gateway = FakePhotoSelectionGateway()
        ..failure = const UnexpectedPickerException();
      final preprocessor = FakePhotoPreprocessor();
      final container = createContainer(
        repository: repository,
        gateway: gateway,
        preprocessor: preprocessor,
      );
      addTearDown(container.dispose);
      await container.read(uploadPhotoProvider(defaultMemoryId).future);

      await container
          .read(uploadPhotoProvider(defaultMemoryId).notifier)
          .selectPrepareAndUpload();

      expect(
        container.read(uploadPhotoProvider(defaultMemoryId)),
        isA<AsyncError<UploadPhotoState>>(),
      );
    });
  });
}

ProviderContainer createContainer({
  required FakeMediaRepository repository,
  required FakePhotoSelectionGateway gateway,
  required FakePhotoPreprocessor preprocessor,
  FakeMemoryRepository? memoryRepository,
}) {
  return ProviderContainer(
    overrides: [
      mediaRepositoryProvider.overrideWithValue(repository),
      memoryRepositoryProvider.overrideWithValue(
        memoryRepository ?? FakeMemoryRepository(),
      ),
      photoSelectionGatewayProvider.overrideWithValue(gateway),
      photoPreprocessorProvider.overrideWithValue(preprocessor),
    ],
  );
}

void keepMemoryMediaAlive(ProviderContainer container) {
  final subscription = container.listen(
    memoryMediaProvider(defaultMemoryId),
    (_, __) {},
    fireImmediately: true,
  );
  addTearDown(subscription.close);
}

final class UnexpectedPickerException implements Exception {
  const UnexpectedPickerException();
}

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoryCalls = 0;
  List<Memory> memoriesResult = <Memory>[];
  MemoryReadModel memoryReadModelResult = MemoryReadModel.fromMemory(memoryA);
  Object? getMemoryFailure;

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    return memoriesResult.map(MemoryReadModel.fromMemory).toList();
  }

  @override
  Future<MemoryReadModel> getMemory(String memoryId) async {
    getMemoryCalls += 1;

    final failure = getMemoryFailure;
    if (failure != null) {
      throw failure;
    }

    return memoryReadModelResult;
  }

  @override
  Future<Memory> createMemory(CreateMemoryInput input) async {
    return memoryA;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) async {
    return memoryA;
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) async {}
}

Memory memory({
  String id = defaultMemoryId,
  String storyId = defaultStoryId,
}) {
  return Memory(
    id: id,
    storyId: storyId,
    createdBy: 'author-id',
    title: 'First picnic',
    description: 'Near the river',
    placeName: 'Riverside Park',
    location: MemoryLocation(latitude: 55.751244, longitude: 37.618423),
    eventDate: MemoryDate(year: 2026, month: 8, day: 9),
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

MemoryPhotoPreview previewPhoto({
  required String mediaId,
}) {
  return MemoryPhotoPreview(
    mediaId: mediaId,
    thumbnailPath: '/api/v1/media/$mediaId/thumbnail',
  );
}

const String defaultStoryId = 'story-id';
final Memory memoryA = memory();
