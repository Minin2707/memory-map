import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/data/remote/dio_invite_remote_data_source.dart';
import 'package:memory_map/features/invite/data/remote/invite_remote_exception.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('DioInviteRemoteDataSource createInvite', () {
    test('shouldPostCreateInviteWithoutBody', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 201,
        responseData: validInviteJson(),
      );
      final dataSource = createDataSource(adapter);

      await dataSource.createInvite('story-id');

      expect(adapter.lastMethod, 'POST');
      expect(adapter.lastPath, '/api/v1/stories/story-id/invites');
      expect(adapter.lastBody, isNull);
      expect(adapter.lastHeaders.toString(), isNot(contains('story-id')));
    });

    test('shouldEncodeCreateInviteStoryIdPathSegment', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 201,
        responseData: validInviteJson(),
      );
      final dataSource = createDataSource(adapter);

      await dataSource.createInvite('story/id');

      expect(adapter.lastPath, '/api/v1/stories/story%2Fid/invites');
    });

    test('shouldReturnCreatedInvite', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          statusCode: 201,
          responseData: validInviteJson(),
        ),
      );

      final invite = await dataSource.createInvite('story-id');

      expect(invite, createInvite());
      expect(invite.expiresAt.isUtc, isTrue);
    });

    test('shouldRejectBlankStoryIdWithoutNetworkCall', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 201,
        responseData: validInviteJson(),
      );
      final dataSource = createDataSource(adapter);

      await expectLater(
        dataSource.createInvite('   '),
        throwsA(argumentErrorWithMessage('storyId must not be blank')),
      );
      expect(adapter.fetchCalls, 0);
    });

    test('shouldNotSendClientControlledInviteFields', () async {
      final adapter = FakeHttpClientAdapter(
        statusCode: 201,
        responseData: validInviteJson(),
      );
      final dataSource = createDataSource(adapter);

      await dataSource.createInvite('story-id');

      expect(adapter.lastBody, isNull);
      expect(adapter.lastPath, isNot(contains('role')));
      expect(adapter.lastPath, isNot(contains('ttl')));
      expect(adapter.lastPath, isNot(contains('createdBy')));
      expect(adapter.lastPath, isNot(contains('userId')));
    });
  });

  group('DioInviteRemoteDataSource acceptInvite', () {
    test('shouldPostAcceptInviteWithoutBody', () async {
      final adapter = FakeHttpClientAdapter(
        responseData: validUserStoryJson(role: 'EDITOR'),
      );
      final dataSource = createDataSource(adapter);

      await dataSource.acceptInvite('share-token_123');

      expect(adapter.lastMethod, 'POST');
      expect(adapter.lastPath, '/api/v1/invites/share-token_123/accept');
      expect(adapter.lastBody, isNull);
      expect(adapter.lastHeaders.toString(), isNot(contains('share-token')));
    });

    test('shouldEncodeAcceptInviteTokenPathSegment', () async {
      final adapter = FakeHttpClientAdapter(responseData: validUserStoryJson());
      final dataSource = createDataSource(adapter);

      await dataSource.acceptInvite('token/with/slash');

      expect(adapter.lastPath, '/api/v1/invites/token%2Fwith%2Fslash/accept');
    });

    test('shouldPreserveBase64UrlTokenSymbolsInPath', () async {
      final adapter = FakeHttpClientAdapter(responseData: validUserStoryJson());
      final dataSource = createDataSource(adapter);

      await dataSource.acceptInvite('abc-DEF_123');

      expect(adapter.lastPath, '/api/v1/invites/abc-DEF_123/accept');
    });

    test('shouldReturnAcceptedUserStoryWithBackendRole', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          responseData: validUserStoryJson(role: 'VIEWER'),
        ),
      );

      final userStory = await dataSource.acceptInvite('share-token_123');

      expect(
        userStory,
        UserStory(story: createStory(), role: StoryRole.viewer),
      );
    });

    test('shouldRejectBlankRawTokenWithoutNetworkCall', () async {
      final adapter = FakeHttpClientAdapter(responseData: validUserStoryJson());
      final dataSource = createDataSource(adapter);

      await expectLater(
        dataSource.acceptInvite('   '),
        throwsA(argumentErrorWithMessage('rawToken must not be blank')),
      );
      expect(adapter.fetchCalls, 0);
    });

    test('shouldNotPutRawTokenIntoQueryBodyOrHeaders', () async {
      final adapter = FakeHttpClientAdapter(responseData: validUserStoryJson());
      final dataSource = createDataSource(adapter);

      await dataSource.acceptInvite('raw-token');

      expect(adapter.lastBody, isNull);
      expect(adapter.lastPath, isNot(contains('?')));
      expect(adapter.lastHeaders.toString(), isNot(contains('raw-token')));
      expect(adapter.lastPath, isNot(contains('role')));
      expect(adapter.lastPath, isNot(contains('userId')));
      expect(adapter.lastPath, isNot(contains('storyId')));
    });
  });

  group('DioInviteRemoteDataSource errors', () {
    test('shouldMap400ToValidationFailure', () async {
      await expectInviteStatusFailure(
        400,
        isA<InviteRemoteValidationException>(),
      );
    });

    test('shouldMap401ToUnauthorized', () async {
      await expectInviteStatusFailure(
        401,
        isA<InviteRemoteUnauthorizedException>(),
      );
    });

    test('shouldMap403ToUnauthorized', () async {
      await expectInviteStatusFailure(
        403,
        isA<InviteRemoteUnauthorizedException>(),
      );
    });

    test('shouldMap404ToNotFound', () async {
      await expectInviteStatusFailure(
        404,
        isA<InviteRemoteNotFoundException>(),
      );
    });

    test('shouldMap500ToServerFailure', () async {
      await expectInviteStatusFailure(
        500,
        isA<InviteRemoteServerException>(),
      );
    });

    test('shouldMapAccept401ToUnauthorized', () async {
      await expectAcceptInviteStatusFailure(
        401,
        isA<InviteRemoteUnauthorizedException>(),
      );
    });

    test('shouldMapAccept403ToUnauthorized', () async {
      await expectAcceptInviteStatusFailure(
        403,
        isA<InviteRemoteUnauthorizedException>(),
      );
    });

    test('shouldMapAccept404ToNotFound', () async {
      await expectAcceptInviteStatusFailure(
        404,
        isA<InviteRemoteNotFoundException>(),
      );
    });

    test('shouldMapAccept500ToServerFailure', () async {
      await expectAcceptInviteStatusFailure(
        500,
        isA<InviteRemoteServerException>(),
      );
    });

    test('shouldMapConnectionTimeout', () async {
      await expectInviteTransportFailure(
        DioExceptionType.connectionTimeout,
        isA<InviteRemoteTimeoutException>(),
      );
    });

    test('shouldMapSendTimeout', () async {
      await expectInviteTransportFailure(
        DioExceptionType.sendTimeout,
        isA<InviteRemoteTimeoutException>(),
      );
    });

    test('shouldMapReceiveTimeout', () async {
      await expectInviteTransportFailure(
        DioExceptionType.receiveTimeout,
        isA<InviteRemoteTimeoutException>(),
      );
    });

    test('shouldMapTransformTimeout', () async {
      await expectInviteTransportFailure(
        DioExceptionType.transformTimeout,
        isA<InviteRemoteTimeoutException>(),
      );
    });

    test('shouldMapConnectionError', () async {
      await expectInviteTransportFailure(
        DioExceptionType.connectionError,
        isA<InviteRemoteNetworkException>(),
      );
    });

    test('shouldMapBadCertificate', () async {
      await expectInviteTransportFailure(
        DioExceptionType.badCertificate,
        isA<InviteRemoteNetworkException>(),
      );
    });

    test('shouldMapCancelFailure', () async {
      await expectInviteTransportFailure(
        DioExceptionType.cancel,
        isA<InviteRemoteUnknownException>(),
      );
    });

    test('shouldMapUnknownDioFailure', () async {
      await expectInviteTransportFailure(
        DioExceptionType.unknown,
        isA<InviteRemoteUnknownException>(),
      );
    });

    test('shouldMapUnexpectedSuccessStatus', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 204, responseData: null),
      );

      await expectLater(
        dataSource.acceptInvite('share-token_123'),
        throwsA(isA<InviteRemoteUnknownException>()),
      );
    });

    test('shouldMapMalformedCreateInviteBody', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 201, responseData: <String, Object?>{}),
      );

      await expectLater(
        dataSource.createInvite('story-id'),
        throwsA(isA<InviteRemoteMalformedResponseException>()),
      );
    });

    test('shouldMapNullCreateInviteBody', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 201, responseData: null),
      );

      await expectLater(
        dataSource.createInvite('story-id'),
        throwsA(isA<InviteRemoteMalformedResponseException>()),
      );
    });

    test('shouldMapWrongCreateInviteShape', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(statusCode: 201, responseData: <Object?>[]),
      );

      await expectLater(
        dataSource.createInvite('story-id'),
        throwsA(isA<InviteRemoteMalformedResponseException>()),
      );
    });

    test('shouldMapMalformedAcceptUserStoryBody', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(responseData: <String, Object?>{}),
      );

      await expectLater(
        dataSource.acceptInvite('share-token_123'),
        throwsA(isA<InviteRemoteMalformedResponseException>()),
      );
    });

    test('shouldMapMalformedAcceptRoleWithoutSynthesizingRole', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          responseData: <String, Object?>{
            ...validUserStoryJson(),
            'role': 'ADMIN',
          },
        ),
      );

      await expectLater(
        dataSource.acceptInvite('share-token_123'),
        throwsA(isA<InviteRemoteMalformedResponseException>()),
      );
    });

    test('shouldNotExposeTokenLinkOrRawBodyInExceptions', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          statusCode: 404,
          responseData: inviteProblemJson(),
        ),
      );

      try {
        await dataSource.acceptInvite('private-token');
        fail('Expected remote exception');
      } on InviteRemoteException catch (error) {
        expect(error.toString(), 'InviteRemoteNotFoundException');
        expect(error.toString(), isNot(contains('private-token')));
        expect(error.toString(), isNot(contains('Invite could not')));
        expect(error.toString(), isNot(contains('Authorization')));
        expect(error.toString(), isNot(contains('inviteLink')));
        expect(error, isNot(isA<DioException>()));
      }
    });
  });
}

DioInviteRemoteDataSource createDataSource(FakeHttpClientAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  )..httpClientAdapter = adapter;

  return DioInviteRemoteDataSource(dio);
}

Future<void> expectInviteStatusFailure(
  int statusCode,
  Matcher matcher,
) async {
  final dataSource = createDataSource(
    FakeHttpClientAdapter(
      statusCode: statusCode,
      responseData: inviteProblemJson(),
    ),
  );

  await expectLater(
    dataSource.createInvite('story-id'),
    throwsA(matcher),
  );
}

Future<void> expectAcceptInviteStatusFailure(
  int statusCode,
  Matcher matcher,
) async {
  final dataSource = createDataSource(
    FakeHttpClientAdapter(
      statusCode: statusCode,
      responseData: inviteProblemJson(),
    ),
  );

  await expectLater(
    dataSource.acceptInvite('share-token_123'),
    throwsA(matcher),
  );
}

Future<void> expectInviteTransportFailure(
  DioExceptionType type,
  Matcher matcher,
) async {
  final adapter = FakeHttpClientAdapter(
    failure: DioException(
      requestOptions: RequestOptions(path: '/api/v1/invites/token/accept'),
      type: type,
    ),
  );
  final dataSource = createDataSource(adapter);

  await expectLater(
    dataSource.acceptInvite('share-token_123'),
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

Invite createInvite() {
  return Invite(
    inviteLink: Uri.parse('https://app.memorymap.app/invite/share-token-123'),
    expiresAt: DateTime.parse('2026-02-09T10:00:00Z'),
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

Map<String, Object?> validInviteJson() {
  return <String, Object?>{
    'inviteLink': 'https://app.memorymap.app/invite/share-token-123',
    'expiresAt': '2026-02-09T10:00:00Z',
  };
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
    'memoryCount': 0,
    'participantCount': 1,
    'previewPhoto': null,
  };
}

Map<String, Object?> inviteProblemJson() {
  return <String, Object?>{
    'title': 'Not Found',
    'status': 404,
    'detail': 'Invite could not be accepted',
    'instance': '/api/v1/invites/accept',
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
