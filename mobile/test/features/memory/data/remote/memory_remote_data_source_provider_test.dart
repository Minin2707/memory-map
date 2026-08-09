import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/data/network/authorized_dio_provider.dart';
import 'package:memory_map/features/memory/data/remote/dio_memory_remote_data_source.dart';
import 'package:memory_map/features/memory/data/remote/memory_remote_data_source.dart';

void main() {
  group('memoryRemoteDataSourceProvider', () {
    test('shouldCreateMemoryRemoteDataSourceFromAuthorizedDio', () async {
      final adapter = FakeHttpClientAdapter(
        responseData: <Object?>[validMemoryJson()],
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

      final dataSource = container.read(memoryRemoteDataSourceProvider);

      expect(dataSource, isA<MemoryRemoteDataSource>());
      expect(dataSource, isA<DioMemoryRemoteDataSource>());
      expect(adapter.fetchCalls, 0);

      await dataSource.getMemories('story-id');

      expect(adapter.fetchCalls, 1);
      expect(adapter.lastPath, '/api/v1/stories/story-id/memories');
    });
  });
}

Map<String, Object?> validMemoryJson() {
  return <String, Object?>{
    'id': 'memory-id',
    'storyId': 'story-id',
    'createdBy': 'user-id',
    'title': 'First picnic',
    'description': 'Near the river',
    'placeName': 'Riverside Park',
    'latitude': 55.751244,
    'longitude': 37.618423,
    'eventDate': '2026-08-09',
    'createdAt': '2026-08-09T10:00:00Z',
    'updatedAt': '2026-08-09T11:00:00Z',
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
