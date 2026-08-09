import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/participant/data/remote/dio_participant_remote_data_source.dart';
import 'package:memory_map/features/participant/data/remote/participant_remote_exception.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

void main() {
  group('DioParticipantRemoteDataSource getParticipants', () {
    test('shouldGetParticipantsWithoutBody', () async {
      final adapter = FakeHttpClientAdapter(
        responseData: <Object?>[validParticipantJson()],
      );
      final dataSource = createDataSource(adapter);

      await dataSource.getParticipants('story-id');

      expect(adapter.lastMethod, 'GET');
      expect(adapter.lastPath, '/api/v1/stories/story-id/participants');
      expect(adapter.lastBody, isNull);
      expect(adapter.lastHeaders.toString(), isNot(contains('story-id')));
    });

    test('shouldEncodeStoryIdPathSegment', () async {
      final adapter = FakeHttpClientAdapter(
        responseData: <Object?>[validParticipantJson()],
      );
      final dataSource = createDataSource(adapter);

      await dataSource.getParticipants('story/id ?#');

      expect(
        adapter.lastPath,
        '/api/v1/stories/story%2Fid%20%3F%23/participants',
      );
    });

    test('shouldReturnParticipantsPreservingBackendOrder', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          responseData: <Object?>[
            validParticipantJson(
              userId: 'first-user',
              displayName: 'Anna',
              role: 'CO_OWNER',
              joinedAt: '2026-08-09T10:00:00Z',
            ),
            validParticipantJson(
              userId: 'second-user',
              displayName: 'Alex',
              role: 'OWNER',
              joinedAt: '2026-08-09T10:00:01Z',
            ),
          ],
        ),
      );

      final participants = await dataSource.getParticipants('story-id');

      expect(
        participants,
        <StoryParticipant>[
          StoryParticipant(
            userId: 'first-user',
            displayName: 'Anna',
            avatarUrl: 'https://cdn.memorymap.app/avatar.png',
            role: StoryRole.coOwner,
            joinedAt: DateTime.parse('2026-08-09T10:00:00Z'),
          ),
          StoryParticipant(
            userId: 'second-user',
            displayName: 'Alex',
            avatarUrl: 'https://cdn.memorymap.app/avatar.png',
            role: StoryRole.owner,
            joinedAt: DateTime.parse('2026-08-09T10:00:01Z'),
          ),
        ],
      );
    });

    test('shouldReturnEmptyParticipantList', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(responseData: <Object?>[]),
      );

      final participants = await dataSource.getParticipants('story-id');

      expect(participants, isEmpty);
    });

    test('shouldSupportNullableAvatarAndAllRoles', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          responseData: <Object?>[
            validParticipantJson(userId: 'owner', role: 'OWNER'),
            validParticipantJson(userId: 'co-owner', role: 'CO_OWNER'),
            validParticipantJson(userId: 'editor', role: 'EDITOR'),
            validParticipantJson(
              userId: 'viewer',
              role: 'VIEWER',
              avatarUrl: null,
            ),
          ],
        ),
      );

      final participants = await dataSource.getParticipants('story-id');

      expect(
        participants.map((participant) => participant.role),
        <StoryRole>[
          StoryRole.owner,
          StoryRole.coOwner,
          StoryRole.editor,
          StoryRole.viewer,
        ],
      );
      expect(participants.last.avatarUrl, isNull);
    });

    test('shouldMapMalformedTopLevelList', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(responseData: <String, Object?>{}),
      );

      await expectLater(
        dataSource.getParticipants('story-id'),
        throwsA(isA<ParticipantRemoteMalformedResponseException>()),
      );
    });

    test('shouldMapMalformedListItem', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          responseData: <Object?>[
            <String, Object?>{},
          ],
        ),
      );

      await expectLater(
        dataSource.getParticipants('story-id'),
        throwsA(isA<ParticipantRemoteMalformedResponseException>()),
      );
    });

    test('shouldMapUnexpectedSuccessStatus', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          statusCode: 201,
          responseData: <Object?>[validParticipantJson()],
        ),
      );

      await expectLater(
        dataSource.getParticipants('story-id'),
        throwsA(isA<ParticipantRemoteUnknownException>()),
      );
    });

    test('shouldMapGetStatusFailures', () async {
      await expectGetStatusFailure(
        400,
        isA<ParticipantRemoteValidationException>(),
      );
      await expectGetStatusFailure(
        401,
        isA<ParticipantRemoteUnauthorizedException>(),
      );
      await expectGetStatusFailure(
        403,
        isA<ParticipantRemoteUnauthorizedException>(),
      );
      await expectGetStatusFailure(
        404,
        isA<ParticipantRemoteNotFoundException>(),
      );
      await expectGetStatusFailure(
        500,
        isA<ParticipantRemoteServerException>(),
      );
    });

    test('shouldRejectBlankStoryIdWithoutNetworkCall', () async {
      final adapter = FakeHttpClientAdapter(
        responseData: <Object?>[validParticipantJson()],
      );
      final dataSource = createDataSource(adapter);

      await expectLater(
        dataSource.getParticipants('   '),
        throwsA(argumentErrorWithMessage('storyId must not be blank')),
      );
      expect(adapter.fetchCalls, 0);
    });
  });

  group('DioParticipantRemoteDataSource leaveStory', () {
    test('shouldDeleteLeaveStoryWithoutBody', () async {
      final adapter = FakeHttpClientAdapter(statusCode: 204);
      final dataSource = createDataSource(adapter);

      await dataSource.leaveStory('story-id');

      expect(adapter.lastMethod, 'DELETE');
      expect(adapter.lastPath, '/api/v1/stories/story-id/participants/me');
      expect(adapter.lastBody, isNull);
    });

    test('shouldEncodeLeaveStoryStoryIdButKeepMeLiteral', () async {
      final adapter = FakeHttpClientAdapter(statusCode: 204);
      final dataSource = createDataSource(adapter);

      await dataSource.leaveStory('story/id');

      expect(
        adapter.lastPath,
        '/api/v1/stories/story%2Fid/participants/me',
      );
    });

    test('shouldRejectBlankLeaveStoryIdWithoutNetworkCall', () async {
      final adapter = FakeHttpClientAdapter(statusCode: 204);
      final dataSource = createDataSource(adapter);

      await expectLater(
        dataSource.leaveStory('   '),
        throwsA(argumentErrorWithMessage('storyId must not be blank')),
      );
      expect(adapter.fetchCalls, 0);
    });

    test('shouldMapLeaveStatusFailures', () async {
      await expectLeaveStatusFailure(
        400,
        isA<ParticipantRemoteValidationException>(),
      );
      await expectLeaveStatusFailure(
        401,
        isA<ParticipantRemoteUnauthorizedException>(),
      );
      await expectLeaveStatusFailure(
        403,
        isA<ParticipantRemoteUnauthorizedException>(),
      );
      await expectLeaveStatusFailure(
        404,
        isA<ParticipantRemoteNotFoundException>(),
      );
      await expectLeaveStatusFailure(
        409,
        isA<ParticipantRemoteLastOwnerConflictException>(),
      );
      await expectLeaveStatusFailure(
        500,
        isA<ParticipantRemoteServerException>(),
      );
    });

    test('shouldMapUnexpectedLeaveSuccessStatus', () async {
      final dataSource = createDataSource(FakeHttpClientAdapter());

      await expectLater(
        dataSource.leaveStory('story-id'),
        throwsA(isA<ParticipantRemoteUnknownException>()),
      );
    });
  });

  group('DioParticipantRemoteDataSource removeParticipant', () {
    test('shouldDeleteRemoveParticipantWithoutBody', () async {
      final adapter = FakeHttpClientAdapter(statusCode: 204);
      final dataSource = createDataSource(adapter);

      await dataSource.removeParticipant('story-id', 'participant-id');

      expect(adapter.lastMethod, 'DELETE');
      expect(
        adapter.lastPath,
        '/api/v1/stories/story-id/participants/participant-id',
      );
      expect(adapter.lastBody, isNull);
    });

    test('shouldEncodeStoryAndParticipantPathSegments', () async {
      final adapter = FakeHttpClientAdapter(statusCode: 204);
      final dataSource = createDataSource(adapter);

      await dataSource.removeParticipant('story/id ?#', 'user/id ?#');

      expect(
        adapter.lastPath,
        '/api/v1/stories/story%2Fid%20%3F%23/participants/'
        'user%2Fid%20%3F%23',
      );
    });

    test('shouldRejectBlankRemoveStoryIdWithoutNetworkCall', () async {
      final adapter = FakeHttpClientAdapter(statusCode: 204);
      final dataSource = createDataSource(adapter);

      await expectLater(
        dataSource.removeParticipant('   ', 'participant-id'),
        throwsA(argumentErrorWithMessage('storyId must not be blank')),
      );
      expect(adapter.fetchCalls, 0);
    });

    test('shouldRejectBlankParticipantUserIdWithoutNetworkCall', () async {
      final adapter = FakeHttpClientAdapter(statusCode: 204);
      final dataSource = createDataSource(adapter);

      await expectLater(
        dataSource.removeParticipant('story-id', '   '),
        throwsA(
          argumentErrorWithMessage('participantUserId must not be blank'),
        ),
      );
      expect(adapter.fetchCalls, 0);
    });

    test('shouldMapRemoveStatusFailures', () async {
      await expectRemoveStatusFailure(
        400,
        isA<ParticipantRemoteValidationException>(),
      );
      await expectRemoveStatusFailure(
        401,
        isA<ParticipantRemoteUnauthorizedException>(),
      );
      await expectRemoveStatusFailure(
        403,
        isA<ParticipantRemoteUnauthorizedException>(),
      );
      await expectRemoveStatusFailure(
        404,
        isA<ParticipantRemoteNotFoundException>(),
      );
      await expectRemoveStatusFailure(
        500,
        isA<ParticipantRemoteServerException>(),
      );
    });

    test('shouldMapRemoveSelfConflictByExactDetail', () async {
      await expectRemoveStatusFailure(
        409,
        isA<ParticipantRemoteCannotRemoveSelfException>(),
        detail: 'Use the leave story operation to remove yourself',
      );
    });

    test('shouldMapRemoveOwnerConflictByExactDetail', () async {
      await expectRemoveStatusFailure(
        409,
        isA<ParticipantRemoteOwnerCannotBeRemovedException>(),
        detail: 'A story owner cannot be removed',
      );
    });

    test('shouldMapUnknownRemoveConflictDetail', () async {
      await expectRemoveStatusFailure(
        409,
        isA<ParticipantRemoteUnknownException>(),
        detail: 'use the leave story operation to remove yourself',
      );
    });

    test('shouldMapMissingAndNonStringRemoveConflictDetail', () async {
      await expectRemoveConflictDataFailure(
        problemJson(detail: null)..remove('detail'),
        isA<ParticipantRemoteUnknownException>(),
      );
      await expectRemoveConflictDataFailure(
        problemJson(detail: 123),
        isA<ParticipantRemoteUnknownException>(),
      );
    });

    test('shouldMapUnexpectedRemoveSuccessStatus', () async {
      final dataSource = createDataSource(FakeHttpClientAdapter());

      await expectLater(
        dataSource.removeParticipant('story-id', 'participant-id'),
        throwsA(isA<ParticipantRemoteUnknownException>()),
      );
    });
  });

  group('DioParticipantRemoteDataSource transport and confidentiality', () {
    test('shouldMapTimeoutFailures', () async {
      await expectTransportFailure(
        DioExceptionType.connectionTimeout,
        isA<ParticipantRemoteTimeoutException>(),
      );
      await expectTransportFailure(
        DioExceptionType.sendTimeout,
        isA<ParticipantRemoteTimeoutException>(),
      );
      await expectTransportFailure(
        DioExceptionType.receiveTimeout,
        isA<ParticipantRemoteTimeoutException>(),
      );
      await expectTransportFailure(
        DioExceptionType.transformTimeout,
        isA<ParticipantRemoteTimeoutException>(),
      );
    });

    test('shouldMapNetworkFailures', () async {
      await expectTransportFailure(
        DioExceptionType.connectionError,
        isA<ParticipantRemoteNetworkException>(),
      );
      await expectTransportFailure(
        DioExceptionType.badCertificate,
        isA<ParticipantRemoteNetworkException>(),
      );
    });

    test('shouldMapUnknownTransportFailures', () async {
      await expectTransportFailure(
        DioExceptionType.cancel,
        isA<ParticipantRemoteUnknownException>(),
      );
      await expectTransportFailure(
        DioExceptionType.unknown,
        isA<ParticipantRemoteUnknownException>(),
      );
    });

    test('shouldNotExposeIdsRawProblemDetailsOrDioInExceptions', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          statusCode: 409,
          responseData: problemJson(
            detail: 'Use the leave story operation to remove yourself',
          ),
        ),
      );

      try {
        await dataSource.removeParticipant('private-story', 'private-user');
        fail('Expected remote exception');
      } on ParticipantRemoteException catch (error) {
        expect(error.toString(), 'ParticipantRemoteCannotRemoveSelfException');
        expect(error.toString(), isNot(contains('private-story')));
        expect(error.toString(), isNot(contains('private-user')));
        expect(error.toString(), isNot(contains('Use the leave')));
        expect(error.toString(), isNot(contains('/api/v1/stories')));
        expect(error.toString(), isNot(contains('Authorization')));
        expect(error, isNot(isA<DioException>()));
      }
    });
  });
}

DioParticipantRemoteDataSource createDataSource(
  FakeHttpClientAdapter adapter,
) {
  final dio = Dio(
    BaseOptions(
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  )..httpClientAdapter = adapter;

  return DioParticipantRemoteDataSource(dio);
}

Future<void> expectGetStatusFailure(
  int statusCode,
  Matcher matcher,
) async {
  final dataSource = createDataSource(
    FakeHttpClientAdapter(
      statusCode: statusCode,
      responseData: problemJson(),
    ),
  );

  await expectLater(
    dataSource.getParticipants('story-id'),
    throwsA(matcher),
  );
}

Future<void> expectLeaveStatusFailure(
  int statusCode,
  Matcher matcher,
) async {
  final dataSource = createDataSource(
    FakeHttpClientAdapter(
      statusCode: statusCode,
      responseData: problemJson(),
    ),
  );

  await expectLater(
    dataSource.leaveStory('story-id'),
    throwsA(matcher),
  );
}

Future<void> expectRemoveStatusFailure(
  int statusCode,
  Matcher matcher, {
  Object? detail = 'Problem detail',
}) async {
  await expectRemoveConflictDataFailure(
    problemJson(detail: detail),
    matcher,
    statusCode: statusCode,
  );
}

Future<void> expectRemoveConflictDataFailure(
  Object? data,
  Matcher matcher, {
  int statusCode = 409,
}) async {
  final dataSource = createDataSource(
    FakeHttpClientAdapter(
      statusCode: statusCode,
      responseData: data,
    ),
  );

  await expectLater(
    dataSource.removeParticipant('story-id', 'participant-id'),
    throwsA(matcher),
  );
}

Future<void> expectTransportFailure(
  DioExceptionType type,
  Matcher matcher,
) async {
  final adapter = FakeHttpClientAdapter(
    failure: DioException(
      requestOptions: RequestOptions(
        path: '/api/v1/stories/story-id/participants',
      ),
      type: type,
    ),
  );
  final dataSource = createDataSource(adapter);

  await expectLater(
    dataSource.getParticipants('story-id'),
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

Map<String, Object?> validParticipantJson({
  String userId = 'user-id',
  String displayName = 'Anna',
  Object? avatarUrl = 'https://cdn.memorymap.app/avatar.png',
  String role = 'OWNER',
  String joinedAt = '2026-08-09T10:00:00Z',
}) {
  return <String, Object?>{
    'userId': userId,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'role': role,
    'joinedAt': joinedAt,
  };
}

Map<String, Object?> problemJson({Object? detail = 'Problem detail'}) {
  return <String, Object?>{
    'title': 'Conflict',
    'status': 409,
    'detail': detail,
    'instance': '/api/v1/stories/participants',
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
