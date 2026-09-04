import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/data/network/authorized_dio_provider.dart';
import 'package:memory_map/features/invite/data/remote/dio_invite_remote_data_source.dart';
import 'package:memory_map/features/invite/data/remote/invite_remote_data_source.dart';
import 'package:memory_map/features/story/domain/story_role.dart';

void main() {
  group('inviteRemoteDataSourceProvider', () {
    test('shouldCreateInviteRemoteDataSourceFromAuthorizedDio', () async {
      final adapter = FakeHttpClientAdapter(
        responseData: validInviteJson(),
        statusCode: 201,
      );
      final dio = Dio(
        BaseOptions(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      )..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [
          authorizedDioProvider.overrideWithValue(dio),
        ],
      );
      addTearDown(container.dispose);

      final dataSource = container.read(inviteRemoteDataSourceProvider);

      expect(dataSource, isA<InviteRemoteDataSource>());
      expect(dataSource, isA<DioInviteRemoteDataSource>());
      expect(adapter.fetchCalls, 0);

      await dataSource.createInvite('story-id', StoryRole.editor);

      expect(adapter.fetchCalls, 1);
      expect(adapter.lastPath, '/api/v1/stories/story-id/invites');
    });
  });
}

Map<String, Object?> validInviteJson() {
  return <String, Object?>{
    'inviteLink': 'https://app.memorymap.app/invite/share-token-123',
    'expiresAt': '2026-02-09T10:00:00Z',
  };
}

final class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter({
    required this.statusCode,
    required this.responseData,
  });

  final int statusCode;
  final Object? responseData;

  int fetchCalls = 0;
  String? lastPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCalls += 1;
    lastPath = options.path;

    return ResponseBody.fromString(
      jsonEncode(responseData),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
