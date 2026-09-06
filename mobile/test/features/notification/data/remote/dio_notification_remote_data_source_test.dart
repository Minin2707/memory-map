import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/notification/data/remote/dio_notification_remote_data_source.dart';
import 'package:memory_map/features/notification/data/remote/notification_remote_exception.dart';

void main() {
  group('DioNotificationRemoteDataSource unread count', () {
    test('shouldAcceptZeroAndPositiveUnreadCounts', () async {
      final cases = <int>[0, 7];

      for (final count in cases) {
        final dataSource = createDataSource(
          FakeHttpClientAdapter(
            responseData: <String, Object?>{'count': count},
          ),
        );

        expect(await dataSource.getUnreadCount(), count);
      }
    });

    test('shouldRejectNegativeUnreadCountAsMalformed', () async {
      final dataSource = createDataSource(
        FakeHttpClientAdapter(
          responseData: <String, Object?>{'count': -1},
        ),
      );

      await expectLater(
        dataSource.getUnreadCount(),
        throwsA(isA<NotificationRemoteMalformedResponseException>()),
      );
    });

    test('shouldRejectMissingAndWrongTypeUnreadCountAsMalformed', () async {
      final cases = <Object?>[
        <String, Object?>{},
        <String, Object?>{'count': null},
        <String, Object?>{'count': '1'},
      ];

      for (final responseData in cases) {
        final dataSource = createDataSource(
          FakeHttpClientAdapter(responseData: responseData),
        );

        await expectLater(
          dataSource.getUnreadCount(),
          throwsA(isA<NotificationRemoteMalformedResponseException>()),
        );
      }
    });
  });
}

DioNotificationRemoteDataSource createDataSource(
  FakeHttpClientAdapter adapter,
) {
  final dio = Dio(
    BaseOptions(
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  )..httpClientAdapter = adapter;

  return DioNotificationRemoteDataSource(dio);
}

final class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter({required this.responseData});

  final Object? responseData;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(responseData),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
