import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/memory/data/remote/dio_memory_remote_data_source.dart';
import 'package:memory_map/features/memory/data/remote/memory_remote_exception.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_update_field.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';

void main() {
  group('DioMemoryRemoteDataSource getMemories', () {
    test('shouldGetStoryMemoriesByEncodedStoryId', () async {
      final adapter = FakeHttpClientAdapter(
        responseData: <Object?>[validMemoryJson()],
      );
      final dataSource = createDataSource(adapter);

      await dataSource.getMemories('story/id');

      expect(adapter.lastMethod, 'GET');
      expect(adapter.lastPath, '/api/v1/stories/story%2Fid/memories');
      expect(adapter.lastBody, isNull);
    });

    test('shouldReturnOrderedMemories', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          responseData: <Object?>[
            validMemoryJson(),
            <String, Object?>{
              ...validMemoryJson(),
              'id': 'second-memory-id',
              'title': 'Second picnic',
            },
          ],
        ),
      );

      final memories = await dataSource.getMemories('story-id');

      expect(memories, <Memory>[
        createMemory(),
        createMemory(id: 'second-memory-id', title: 'Second picnic'),
      ]);
    });

    test('shouldReturnEmptyMemoryList', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(responseData: <Object?>[]),
      );

      final memories = await dataSource.getMemories('story-id');

      expect(memories, isEmpty);
    });

    test('shouldRejectBlankStoryIdWithoutNetworkCall', () async {
      final adapter = FakeHttpClientAdapter(
        responseData: <Object?>[validMemoryJson()],
      );
      final dataSource = createDataSource(adapter);

      await expectLater(
        dataSource.getMemories('   '),
        throwsA(argumentErrorWithMessage('storyId must not be blank')),
      );
      expect(adapter.fetchCalls, 0);
    });
  });

  group('DioMemoryRemoteDataSource getMemory', () {
    test('shouldGetMemoryByEncodedId', () async {
      final adapter = FakeHttpClientAdapter(responseData: validMemoryJson());
      final dataSource = createDataSource(adapter);

      await dataSource.getMemory('memory/id');

      expect(adapter.lastMethod, 'GET');
      expect(adapter.lastPath, '/api/v1/memories/memory%2Fid');
    });

    test('shouldReturnMemory', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(responseData: validMemoryJson()),
      );

      final memory = await dataSource.getMemory('memory-id');

      expect(memory, createMemory());
    });

    test('shouldRejectBlankMemoryIdWithoutNetworkCall', () async {
      final adapter = FakeHttpClientAdapter(responseData: validMemoryJson());
      final dataSource = createDataSource(adapter);

      await expectLater(
        dataSource.getMemory('   '),
        throwsA(argumentErrorWithMessage('memoryId must not be blank')),
      );
      expect(adapter.fetchCalls, 0);
    });
  });

  group('DioMemoryRemoteDataSource createMemory', () {
    test('shouldPostCreateMemoryRequest', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 201,
        responseData: validMemoryJson(),
      );
      final dataSource = createDataSource(adapter);

      await dataSource.createMemory(createMemoryInput());

      expect(adapter.lastMethod, 'POST');
      expect(adapter.lastPath, '/api/v1/stories/story-id/memories');
      expect(adapter.lastBody, <String, Object?>{
        'title': 'First picnic',
        'description': 'Near the river',
        'placeName': 'Riverside Park',
        'latitude': 55.751244,
        'longitude': 37.618423,
        'eventDate': '2026-08-09',
      });
    });

    test('shouldReturnCreatedMemory', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          statusCode: 201,
          responseData: validMemoryJson(),
        ),
      );

      final memory = await dataSource.createMemory(createMemoryInput());

      expect(memory, createMemory());
    });
  });

  group('DioMemoryRemoteDataSource updateMemory', () {
    test('shouldPatchMemoryByEncodedId', () async {
      final adapter = FakeHttpClientAdapter(responseData: validMemoryJson());
      final dataSource = createDataSource(adapter);

      await dataSource.updateMemory(
        UpdateMemoryInput(
          memoryId: 'memory/id',
          title: const MemoryUpdateField<String>.provided('Updated title'),
        ),
      );

      expect(adapter.lastMethod, 'PATCH');
      expect(adapter.lastPath, '/api/v1/memories/memory%2Fid');
      expect(adapter.lastBody, <String, Object?>{
        'title': 'Updated title',
      });
    });

    test('shouldPreservePatchOmittedNullAndValueSemantics', () async {
      final adapter = FakeHttpClientAdapter(responseData: validMemoryJson());
      final dataSource = createDataSource(adapter);

      await dataSource.updateMemory(
        UpdateMemoryInput(
          memoryId: 'memory-id',
          title: const MemoryUpdateField<String>.provided('Updated title'),
          description: const MemoryUpdateField<String?>.provided(null),
          placeName:
              const MemoryUpdateField<String?>.provided('Updated place'),
          location: MemoryUpdateField<MemoryLocation>.provided(location()),
        ),
      );

      expect(adapter.lastBody, <String, Object?>{
        'title': 'Updated title',
        'description': null,
        'placeName': 'Updated place',
        'latitude': 55.751244,
        'longitude': 37.618423,
      });
      expect(adapter.lastBody, isNot(containsPair('eventDate', anything)));
    });

    test('shouldReturnUpdatedMemory', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(responseData: validMemoryJson(title: 'Updated')),
      );

      final memory = await dataSource.updateMemory(
        UpdateMemoryInput(
          memoryId: 'memory-id',
          title: const MemoryUpdateField<String>.provided('Updated'),
        ),
      );

      expect(memory.title, 'Updated');
    });
  });

  group('DioMemoryRemoteDataSource deleteMemory', () {
    test('shouldDeleteMemoryByEncodedId', () async {
      final adapter = FakeHttpClientAdapter(statusCode: 204);
      final dataSource = createDataSource(adapter);

      await dataSource.deleteMemory(
        DeleteMemoryInput(memoryId: 'memory/id'),
      );

      expect(adapter.lastMethod, 'DELETE');
      expect(adapter.lastPath, '/api/v1/memories/memory%2Fid');
      expect(adapter.lastBody, isNull);
    });

    test('shouldNotParseDeleteResponseBody', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          statusCode: 204,
          responseData: 'not-a-memory',
        ),
      );

      await dataSource.deleteMemory(DeleteMemoryInput(memoryId: 'memory-id'));
    });
  });

  group('DioMemoryRemoteDataSource failures', () {
    test('shouldMapMalformedSingleMemoryResponse', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(responseData: <String, Object?>{}),
      );

      await expectLater(
        dataSource.getMemory('memory-id'),
        throwsA(isA<MemoryRemoteMalformedResponseException>()),
      );
    });

    test('shouldMapMalformedMemoryListResponse', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(responseData: <String, Object?>{}),
      );

      await expectLater(
        dataSource.getMemories('story-id'),
        throwsA(isA<MemoryRemoteMalformedResponseException>()),
      );
    });

    test('shouldMapValidationStatus', () async {
      await expectMemoryStatusFailure(
        400,
        isA<MemoryRemoteValidationException>(),
      );
    });

    test('shouldMapUnauthorizedStatuses', () async {
      await expectMemoryStatusFailure(
        401,
        isA<MemoryRemoteUnauthorizedException>(),
      );
      await expectMemoryStatusFailure(
        403,
        isA<MemoryRemoteUnauthorizedException>(),
      );
    });

    test('shouldMapStoryMemoriesNotFoundToStoryUnavailable', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 404, responseData: problemJson()),
      );

      await expectLater(
        dataSource.getMemories('story-id'),
        throwsA(isA<MemoryRemoteStoryUnavailableException>()),
      );
    });

    test('shouldMapGetMemoryNotFound', () async {
      await expectMemoryStatusFailure(
        404,
        isA<MemoryRemoteNotFoundException>(),
      );
    });

    test('shouldMapCreateMemoryNotFoundToCreationUnavailable', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 404, responseData: problemJson()),
      );

      await expectLater(
        dataSource.createMemory(createMemoryInput()),
        throwsA(isA<MemoryRemoteCreationUnavailableException>()),
      );
    });

    test('shouldMapUpdateMemoryNotFoundToUpdateUnavailable', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 404, responseData: problemJson()),
      );

      await expectLater(
        dataSource.updateMemory(
          UpdateMemoryInput(
            memoryId: 'memory-id',
            title: const MemoryUpdateField<String>.provided('Updated'),
          ),
        ),
        throwsA(isA<MemoryRemoteUpdateUnavailableException>()),
      );
    });

    test('shouldMapDeleteMemoryNotFoundToDeletionUnavailable', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 404, responseData: problemJson()),
      );

      await expectLater(
        dataSource.deleteMemory(DeleteMemoryInput(memoryId: 'memory-id')),
        throwsA(isA<MemoryRemoteDeletionUnavailableException>()),
      );
    });

    test('shouldMapServerStatus', () async {
      await expectMemoryStatusFailure(
        500,
        isA<MemoryRemoteServerException>(),
      );
    });

    test('shouldMapUnknownStatus', () async {
      await expectMemoryStatusFailure(
        418,
        isA<MemoryRemoteUnknownException>(),
      );
    });

    test('shouldMapTimeoutTransportFailures', () async {
      await expectMemoryTransportFailure(
        DioExceptionType.connectionTimeout,
        isA<MemoryRemoteTimeoutException>(),
      );
      await expectMemoryTransportFailure(
        DioExceptionType.receiveTimeout,
        isA<MemoryRemoteTimeoutException>(),
      );
    });

    test('shouldMapNetworkTransportFailures', () async {
      await expectMemoryTransportFailure(
        DioExceptionType.connectionError,
        isA<MemoryRemoteNetworkException>(),
      );
      await expectMemoryTransportFailure(
        DioExceptionType.badCertificate,
        isA<MemoryRemoteNetworkException>(),
      );
    });

    test('shouldMapUnknownTransportFailures', () async {
      await expectMemoryTransportFailure(
        DioExceptionType.cancel,
        isA<MemoryRemoteUnknownException>(),
      );
      await expectMemoryTransportFailure(
        DioExceptionType.unknown,
        isA<MemoryRemoteUnknownException>(),
      );
    });
  });

  group('MemoryRemoteException', () {
    test('shouldCompareExceptionsByType', () {
      expect(
        const MemoryRemoteNotFoundException(),
        const MemoryRemoteNotFoundException(),
      );
      expect(
        const MemoryRemoteNotFoundException(),
        isNot(const MemoryRemoteUnauthorizedException()),
      );
    });

    test('shouldExposeSafeToString', () {
      expect(
        const MemoryRemoteNotFoundException().toString(),
        'MemoryRemoteNotFoundException',
      );
      expect(
        const MemoryRemoteNotFoundException().toString(),
        isNot(contains('memory-id')),
      );
    });
  });
}

DioMemoryRemoteDataSource createDataSource(FakeHttpClientAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  )..httpClientAdapter = adapter;

  return DioMemoryRemoteDataSource(dio);
}

Future<void> expectMemoryStatusFailure(
  int statusCode,
  Matcher matcher,
) async {
  final dataSource = createDataSource(
    FakeHttpClientAdapter(statusCode: statusCode, responseData: problemJson()),
  );

  await expectLater(
    dataSource.getMemory('memory-id'),
    throwsA(matcher),
  );
}

Future<void> expectMemoryTransportFailure(
  DioExceptionType type,
  Matcher matcher,
) async {
  final adapter = FakeHttpClientAdapter(
    failure: DioException(
      requestOptions: RequestOptions(path: '/api/v1/memories/memory-id'),
      type: type,
    ),
  );
  final dataSource = createDataSource(adapter);

  await expectLater(
    dataSource.getMemory('memory-id'),
    throwsA(matcher),
  );
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}

CreateMemoryInput createMemoryInput() {
  return CreateMemoryInput(
    storyId: 'story-id',
    title: 'First picnic',
    description: 'Near the river',
    placeName: 'Riverside Park',
    location: location(),
    eventDate: eventDate(),
  );
}

Memory createMemory({
  String id = 'memory-id',
  String title = 'First picnic',
}) {
  return Memory(
    id: id,
    storyId: 'story-id',
    createdBy: 'user-id',
    title: title,
    description: 'Near the river',
    placeName: 'Riverside Park',
    location: location(),
    eventDate: eventDate(),
    createdAt: DateTime.parse('2026-08-09T10:00:00Z'),
    updatedAt: DateTime.parse('2026-08-09T11:00:00Z'),
  );
}

MemoryLocation location() {
  return MemoryLocation(
    latitude: 55.751244,
    longitude: 37.618423,
  );
}

MemoryDate eventDate() {
  return MemoryDate(year: 2026, month: 8, day: 9);
}

Map<String, Object?> validMemoryJson({
  String id = 'memory-id',
  String title = 'First picnic',
}) {
  return <String, Object?>{
    'id': id,
    'storyId': 'story-id',
    'createdBy': 'user-id',
    'title': title,
    'description': 'Near the river',
    'placeName': 'Riverside Park',
    'latitude': 55.751244,
    'longitude': 37.618423,
    'eventDate': '2026-08-09',
    'createdAt': '2026-08-09T10:00:00Z',
    'updatedAt': '2026-08-09T11:00:00Z',
  };
}

Map<String, Object?> problemJson() {
  return <String, Object?>{
    'title': 'Not Found',
    'status': 404,
    'detail': 'Memory was not found',
    'instance': '/api/v1/memories',
  };
}

final class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter({
    this.statusCode = 200,
    this.responseData,
    this.failure,
  });

  final int statusCode;
  final Object? responseData;
  final DioException? failure;

  int fetchCalls = 0;
  String? lastMethod;
  String? lastPath;
  Object? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCalls += 1;
    lastMethod = options.method;
    lastPath = options.path;
    lastBody = await decodeRequestBody(requestStream);

    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }

    return ResponseBody.fromString(
      encodeResponseBody(responseData),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<Object?> decodeRequestBody(Stream<Uint8List>? requestStream) async {
  if (requestStream == null) {
    return null;
  }

  final bytes = await requestStream.expand((chunk) => chunk).toList();
  if (bytes.isEmpty) {
    return null;
  }

  return jsonDecode(utf8.decode(bytes));
}

String encodeResponseBody(Object? responseData) {
  if (responseData == null) {
    return '';
  }

  return jsonEncode(responseData);
}
