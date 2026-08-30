import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/data/remote/create_story_remote_request.dart';
import 'package:memory_map/features/story/data/remote/dio_story_remote_data_source.dart';
import 'package:memory_map/features/story/data/remote/story_patch_field.dart';
import 'package:memory_map/features/story/data/remote/story_remote_exception.dart';
import 'package:memory_map/features/story/data/remote/update_story_remote_request.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('DioStoryRemoteDataSource create', () {
    test('shouldPostCreateStoryRequest', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 201,
        responseData: validStoryJson(),
      );
      final dataSource = createDataSource(adapter);

      await dataSource.createStory(
        CreateStoryRemoteRequest(
          title: 'Our Story',
          description: 'Together since 2021',
        ),
      );

      expect(adapter.lastMethod, 'POST');
      expect(adapter.lastPath, '/api/v1/stories');
      expect(adapter.lastBody, <String, Object?>{
        'title': 'Our Story',
        'description': 'Together since 2021',
      });
    });

    test('shouldReturnCreatedStory', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          statusCode: 201,
          responseData: validStoryJson(),
        ),
      );

      final story = await dataSource.createStory(
        CreateStoryRemoteRequest(title: 'Our Story'),
      );

      expect(story, createStory());
    });
  });

  group('DioStoryRemoteDataSource getStories', () {
    test('shouldGetStoriesEndpoint', () async {
      final adapter = FakeHttpClientAdapter(
        responseData: <Object?>[validUserStoryJson()],
      );
      final dataSource = createDataSource(adapter);

      await dataSource.getStories();

      expect(adapter.lastMethod, 'GET');
      expect(adapter.lastPath, '/api/v1/stories');
      expect(adapter.lastBody, isNull);
    });

    test('shouldReturnOrderedUserStories', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          responseData: <Object?>[
            validUserStoryJson(role: 'OWNER'),
            <String, Object?>{
              ...validUserStoryJson(role: 'EDITOR'),
              'id': 'second-story-id',
              'title': 'Second Story',
            },
          ],
        ),
      );

      final stories = await dataSource.getStories();

      expect(stories, <UserStory>[
        UserStory(
          story: createStory(),
          role: StoryRole.owner,
          memoryCount: 12,
          participantCount: 2,
        ),
        UserStory(
          story: Story(
            id: 'second-story-id',
            title: 'Second Story',
            description: 'Together since 2021',
            createdAt: DateTime.parse('2026-01-01T10:00:00.123456Z'),
            updatedAt: DateTime.parse('2026-01-10T10:00:00.123456Z'),
          ),
          role: StoryRole.editor,
          memoryCount: 12,
          participantCount: 2,
        ),
      ]);
    });

    test('shouldReturnEmptyStoryList', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(responseData: <Object?>[]),
      );

      final stories = await dataSource.getStories();

      expect(stories, isEmpty);
    });
  });

  group('DioStoryRemoteDataSource getStory', () {
    test('shouldGetStoryByEncodedId', () async {
      final adapter = FakeHttpClientAdapter(responseData: validUserStoryJson());
      final dataSource = createDataSource(adapter);

      await dataSource.getStory('story/id');

      expect(adapter.lastMethod, 'GET');
      expect(adapter.lastPath, '/api/v1/stories/story%2Fid');
    });

    test('shouldReturnUserStory', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(responseData: validUserStoryJson(role: 'VIEWER')),
      );

      final story = await dataSource.getStory('story-id');

      expect(
        story,
        UserStory(
          story: createStory(),
          role: StoryRole.viewer,
          memoryCount: 12,
          participantCount: 2,
        ),
      );
    });

    test('shouldReturnUserStoryWithPreviewPhoto', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          responseData: <String, Object?>{
            ...validUserStoryJson(),
            'previewPhoto': <String, Object?>{
              'thumbnailUrl': '/api/v1/media/media-id/thumbnail',
              'displayUrl': '/api/v1/media/media-id/display',
            },
          },
        ),
      );

      final story = await dataSource.getStory('story-id');

      expect(
        story.previewPhoto?.thumbnailPath,
        '/api/v1/media/media-id/thumbnail',
      );
      expect(
        story.previewPhoto?.displayPath,
        '/api/v1/media/media-id/display',
      );
    });

    test('shouldRejectBlankStoryIdWithoutNetworkCall', () async {
      final adapter = FakeHttpClientAdapter(responseData: validUserStoryJson());
      final dataSource = createDataSource(adapter);

      await expectLater(
        dataSource.getStory('   '),
        throwsA(argumentErrorWithMessage('storyId must not be blank')),
      );
      expect(adapter.fetchCalls, 0);
    });
  });

  group('DioStoryRemoteDataSource updateStory', () {
    test('shouldPatchStoryById', () async {
      final adapter = FakeHttpClientAdapter(responseData: validUserStoryJson());
      final dataSource = createDataSource(adapter);

      await dataSource.updateStory(
        'story-id',
        UpdateStoryRemoteRequest(
          title: const StoryPatchField<String>.provided('Updated Story'),
        ),
      );

      expect(adapter.lastMethod, 'PATCH');
      expect(adapter.lastPath, '/api/v1/stories/story-id');
      expect(adapter.lastBody, <String, Object?>{
        'title': 'Updated Story',
      });
    });

    test('shouldPreservePatchOmittedNullAndValueSemantics', () async {
      final adapter = FakeHttpClientAdapter(responseData: validUserStoryJson());
      final dataSource = createDataSource(adapter);

      await dataSource.updateStory(
        'story-id',
        UpdateStoryRemoteRequest(
          title: const StoryPatchField<String>.provided('Updated Story'),
          description: const StoryPatchField<String>.provided(null),
        ),
      );

      expect(adapter.lastBody, <String, Object?>{
        'title': 'Updated Story',
        'description': null,
      });
      expect(
        (adapter.lastBody! as Map).containsKey(
          'description',
        ),
        isTrue,
      );
    });

    test('shouldReturnUpdatedUserStory', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          responseData: <String, Object?>{
            ...validUserStoryJson(role: 'CO_OWNER'),
            'title': 'Updated Story',
            'description': null,
          },
        ),
      );

      final story = await dataSource.updateStory(
        'story-id',
        UpdateStoryRemoteRequest(
          title: const StoryPatchField<String>.provided('Updated Story'),
        ),
      );

      expect(
        story,
        UserStory(
          story: Story(
            id: 'story-id',
            title: 'Updated Story',
            description: null,
            createdAt: DateTime.parse('2026-01-01T10:00:00.123456Z'),
            updatedAt: DateTime.parse('2026-01-10T10:00:00.123456Z'),
          ),
          role: StoryRole.coOwner,
          memoryCount: 12,
          participantCount: 2,
        ),
      );
    });
  });

  group('DioStoryRemoteDataSource errors', () {
    test('shouldMap400ToValidationFailure', () async {
      await expectStoryStatusFailure(
        400,
        isA<StoryRemoteValidationException>(),
      );
    });

    test('shouldMap401ToUnauthorized', () async {
      await expectStoryStatusFailure(
        401,
        isA<StoryRemoteUnauthorizedException>(),
      );
    });

    test('shouldMap403ToUnauthorized', () async {
      await expectStoryStatusFailure(
        403,
        isA<StoryRemoteUnauthorizedException>(),
      );
    });

    test('shouldMap404ToNotFound', () async {
      await expectStoryStatusFailure(
        404,
        isA<StoryRemoteNotFoundException>(),
      );
    });

    test('shouldMap500ToServerFailure', () async {
      await expectStoryStatusFailure(
        500,
        isA<StoryRemoteServerException>(),
      );
    });

    test('shouldMapConnectionTimeout', () async {
      await expectStoryTransportFailure(
        DioExceptionType.connectionTimeout,
        isA<StoryRemoteTimeoutException>(),
      );
    });

    test('shouldMapSendTimeout', () async {
      await expectStoryTransportFailure(
        DioExceptionType.sendTimeout,
        isA<StoryRemoteTimeoutException>(),
      );
    });

    test('shouldMapReceiveTimeout', () async {
      await expectStoryTransportFailure(
        DioExceptionType.receiveTimeout,
        isA<StoryRemoteTimeoutException>(),
      );
    });

    test('shouldMapTransformTimeout', () async {
      await expectStoryTransportFailure(
        DioExceptionType.transformTimeout,
        isA<StoryRemoteTimeoutException>(),
      );
    });

    test('shouldMapConnectionError', () async {
      await expectStoryTransportFailure(
        DioExceptionType.connectionError,
        isA<StoryRemoteNetworkException>(),
      );
    });

    test('shouldMapBadCertificate', () async {
      await expectStoryTransportFailure(
        DioExceptionType.badCertificate,
        isA<StoryRemoteNetworkException>(),
      );
    });

    test('shouldMapUnknownDioFailure', () async {
      await expectStoryTransportFailure(
        DioExceptionType.unknown,
        isA<StoryRemoteUnknownException>(),
      );
    });

    test('shouldMapMalformedStoryObject', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 201, responseData: <String, Object?>{}),
      );

      await expectLater(
        dataSource.createStory(CreateStoryRemoteRequest(title: 'Our Story')),
        throwsA(isA<StoryRemoteMalformedResponseException>()),
      );
    });

    test('shouldMapMalformedStoryList', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(responseData: <String, Object?>{}),
      );

      await expectLater(
        dataSource.getStories(),
        throwsA(isA<StoryRemoteMalformedResponseException>()),
      );
    });

    test('shouldMapMalformedStoryListItem', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(responseData: <Object?>[<String, Object?>{}]),
      );

      await expectLater(
        dataSource.getStories(),
        throwsA(isA<StoryRemoteMalformedResponseException>()),
      );
    });

    test('shouldNotExposeStoryIdOrRawBodyInExceptions', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          statusCode: 404,
          responseData: problemJson(),
        ),
      );

      try {
        await dataSource.getStory('private-story-id');
        fail('Expected remote exception');
      } on StoryRemoteException catch (error) {
        expect(error.toString(), 'StoryRemoteNotFoundException');
        expect(error.toString(), isNot(contains('private-story-id')));
        expect(error.toString(), isNot(contains('Story was not found')));
        expect(error.toString(), isNot(contains('Authorization')));
        expect(error, isNot(isA<DioException>()));
      }
    });
  });
}

DioStoryRemoteDataSource createDataSource(FakeHttpClientAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  )..httpClientAdapter = adapter;

  return DioStoryRemoteDataSource(dio);
}

Future<void> expectStoryStatusFailure(
  int statusCode,
  Matcher matcher,
) async {
  final dataSource = createDataSource(
    FakeHttpClientAdapter(statusCode: statusCode, responseData: problemJson()),
  );

  await expectLater(
    dataSource.getStory('story-id'),
    throwsA(matcher),
  );
}

Future<void> expectStoryTransportFailure(
  DioExceptionType type,
  Matcher matcher,
) async {
  final adapter = FakeHttpClientAdapter(
    failure: DioException(
      requestOptions: RequestOptions(path: '/api/v1/stories/story-id'),
      type: type,
    ),
  );
  final dataSource = createDataSource(adapter);

  await expectLater(
    dataSource.getStory('story-id'),
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

Story createStory() {
  return Story(
    id: 'story-id',
    title: 'Our Story',
    description: 'Together since 2021',
    createdAt: DateTime.parse('2026-01-01T10:00:00.123456Z'),
    updatedAt: DateTime.parse('2026-01-10T10:00:00.123456Z'),
  );
}

Map<String, Object?> validStoryJson() {
  return <String, Object?>{
    'id': 'story-id',
    'title': 'Our Story',
    'description': 'Together since 2021',
    'createdAt': '2026-01-01T10:00:00.123456Z',
    'updatedAt': '2026-01-10T10:00:00.123456Z',
  };
}

Map<String, Object?> validUserStoryJson({String role = 'OWNER'}) {
  return <String, Object?>{
    ...validStoryJson(),
    'role': role,
    'memoryCount': 12,
    'participantCount': 2,
    'previewPhoto': null,
  };
}

Map<String, Object?> problemJson() {
  return <String, Object?>{
    'title': 'Not Found',
    'status': 404,
    'detail': 'Story was not found',
    'instance': '/api/v1/stories',
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
  Map<String, dynamic> lastHeaders = <String, dynamic>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCalls += 1;
    lastMethod = options.method;
    lastPath = options.path;
    lastHeaders = options.headers;
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
