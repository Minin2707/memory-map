import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/data/network/authorized_dio_provider.dart';
import 'package:memory_map/features/participant/data/remote/dio_participant_remote_data_source.dart';
import 'package:memory_map/features/participant/data/remote/participant_remote_data_source.dart';

void main() {
  group('participantRemoteDataSourceProvider', () {
    test('shouldCreateParticipantRemoteDataSourceFromAuthorizedDio', () async {
      final adapter = FakeHttpClientAdapter(
        responseData: <Object?>[validParticipantJson()],
        statusCode: 200,
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

      final dataSource = container.read(participantRemoteDataSourceProvider);

      expect(dataSource, isA<ParticipantRemoteDataSource>());
      expect(dataSource, isA<DioParticipantRemoteDataSource>());
      expect(adapter.fetchCalls, 0);

      await dataSource.getParticipants('story-id');

      expect(adapter.fetchCalls, 1);
      expect(adapter.lastPath, '/api/v1/stories/story-id/participants');
    });
  });
}

Map<String, Object?> validParticipantJson() {
  return <String, Object?>{
    'userId': 'user-id',
    'displayName': 'Anna',
    'avatarUrl': null,
    'role': 'OWNER',
    'joinedAt': '2026-08-09T10:00:00Z',
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
