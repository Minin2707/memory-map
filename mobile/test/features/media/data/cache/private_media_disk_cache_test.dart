import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/data/cache/private_media_disk_cache.dart';
import 'package:memory_map/features/media/data/remote/media_remote_exception.dart';

void main() {
  group('PrivateMediaDiskCache', () {
    test('shouldFetchAndCacheMediaOnMissThenServeDiskHit', () async {
      final directory = await createTemporaryCacheDirectory();
      final cache = cacheFor(directory);
      var fetchCalls = 0;

      final first = await cache.getOrFetch(thumbnailPath, () async {
        fetchCalls += 1;
        return imageBytes(1);
      });
      final second = await cache.getOrFetch(thumbnailPath, () async {
        fetchCalls += 1;
        return imageBytes(9);
      });

      expect(first, imageBytes(1));
      expect(second, imageBytes(1));
      expect(fetchCalls, 1);
      expect(await cachedFile(directory, thumbnailPath).exists(), isTrue);
    });

    test('shouldUseDistinctSafeKeysForThumbnailAndDisplay', () {
      final thumbnailKey = privateMediaCacheFileNameForPath(thumbnailPath);
      final displayKey = privateMediaCacheFileNameForPath(displayPath);

      expect(thumbnailKey, isNot(displayKey));
      expect(thumbnailKey, isNot(contains('/')));
      expect(displayKey, isNot(contains('/')));
      expect(thumbnailKey, isNot(contains('Bearer')));
      expect(displayKey, isNot(contains('signed-access-token')));
    });

    test('shouldIgnoreCorruptEntryAndFallBackToNetwork', () async {
      final directory = await createTemporaryCacheDirectory();
      final cache = cacheFor(directory);
      await cachedFile(directory, thumbnailPath).writeAsBytes(<int>[1, 2, 3]);
      var fetchCalls = 0;

      final result = await cache.getOrFetch(thumbnailPath, () async {
        fetchCalls += 1;
        return imageBytes(4);
      });

      expect(result, imageBytes(4));
      expect(fetchCalls, 1);
      expect(
        await cachedFile(directory, thumbnailPath).readAsBytes(),
        imageBytes(4),
      );
    });

    test('shouldNotCacheFailedFetches', () async {
      final directory = await createTemporaryCacheDirectory();
      final cache = cacheFor(directory);

      await expectLater(
        cache.getOrFetch(thumbnailPath, () async {
          throw const MediaRemoteUnavailableException();
        }),
        throwsA(isA<MediaRemoteUnavailableException>()),
      );

      expect(await cachedFile(directory, thumbnailPath).exists(), isFalse);
    });

    test('shouldShareConcurrentSamePathRequests', () async {
      final directory = await createTemporaryCacheDirectory();
      final cache = cacheFor(directory);
      final completer = Completer<Uint8List>();
      var fetchCalls = 0;

      final first = cache.getOrFetch(thumbnailPath, () {
        fetchCalls += 1;
        return completer.future;
      });
      final second = cache.getOrFetch(thumbnailPath, () {
        fetchCalls += 1;
        return Future<Uint8List>.value(imageBytes(9));
      });

      completer.complete(imageBytes(7));

      expect(await first, imageBytes(7));
      expect(await second, imageBytes(7));
      expect(fetchCalls, 1);
    });

    test('shouldEvictLeastRecentlyUsedEntriesWhenSizeLimitIsExceeded', () async {
      final directory = await createTemporaryCacheDirectory();
      final clock = FakeClock(DateTime.utc(2026, 8, 26));
      final cache = cacheFor(directory, maxBytes: 8, now: clock.now);

      await cache.getOrFetch(pathFor('a'), () async => imageBytes(1));
      clock.tick();
      await cache.getOrFetch(pathFor('b'), () async => imageBytes(2));
      clock.tick();
      await cache.getOrFetch(pathFor('a'), () async => imageBytes(9));
      clock.tick();
      await cache.getOrFetch(pathFor('c'), () async => imageBytes(3));

      expect(await cachedFile(directory, pathFor('a')).exists(), isTrue);
      expect(await cachedFile(directory, pathFor('b')).exists(), isFalse);
      expect(await cachedFile(directory, pathFor('c')).exists(), isTrue);
    });

    test('shouldEvictMultipleIdenticalOldEntriesUntilUnderLimit', () async {
      final directory = await createTemporaryCacheDirectory();
      final clock = FakeClock(DateTime.utc(2026, 8, 26));
      final cache = cacheFor(directory, maxBytes: 4, now: clock.now);

      await cache.getOrFetch(pathFor('a'), () async => imageBytes(1));
      clock.tick();
      await cache.getOrFetch(pathFor('b'), () async => imageBytes(2));
      clock.tick();
      await cache.getOrFetch(pathFor('c'), () async => imageBytes(3));

      expect(await cachedFile(directory, pathFor('a')).exists(), isFalse);
      expect(await cachedFile(directory, pathFor('b')).exists(), isFalse);
      expect(await cachedFile(directory, pathFor('c')).exists(), isTrue);
    });

    test('shouldFallBackToNetworkWhenCacheDirectoryFails', () async {
      final cache = PrivateMediaDiskCache(
        directoryProvider: () async => throw const FileSystemException('boom'),
      );

      final result = await cache.getOrFetch(thumbnailPath, () async {
        return bytes(<int>[1, 2, 3]);
      });

      expect(result, <int>[1, 2, 3]);
    });

    test('shouldSurviveAppRestartWhenDirectoryIsReused', () async {
      final directory = await createTemporaryCacheDirectory();
      final firstCache = cacheFor(directory);
      final secondCache = cacheFor(directory);
      var fetchCalls = 0;

      await firstCache.getOrFetch(thumbnailPath, () async {
        fetchCalls += 1;
        return imageBytes(8);
      });
      final restartedResult = await secondCache.getOrFetch(thumbnailPath, () {
        fetchCalls += 1;
        return Future<Uint8List>.value(imageBytes(0));
      });

      expect(restartedResult, imageBytes(8));
      expect(fetchCalls, 1);
    });

    test('shouldClearCacheDirectoryOnSessionInvalidation', () async {
      final directory = await createTemporaryCacheDirectory();
      final cache = cacheFor(directory);
      await cache.getOrFetch(thumbnailPath, () async => imageBytes(1));

      await cache.clear();

      expect(await directory.exists(), isFalse);
    });

    test('shouldNotWriteOldInFlightMediaAfterCacheClear', () async {
      final directory = await createTemporaryCacheDirectory();
      final cache = cacheFor(directory);
      final fetchCompleter = Completer<Uint8List>();

      final request = cache.getOrFetch(thumbnailPath, () {
        return fetchCompleter.future;
      });
      await cache.clear();
      fetchCompleter.complete(imageBytes(1));

      expect(await request, imageBytes(1));
      expect(await cachedFile(directory, thumbnailPath).exists(), isFalse);
    });

    test('shouldBypassNonMediaRepresentationPaths', () async {
      final directory = await createTemporaryCacheDirectory();
      final cache = cacheFor(directory);
      var fetchCalls = 0;

      final result = await cache.getOrFetch(
        '/api/v1/stories/story-id/soundtrack/audio',
        () async {
          fetchCalls += 1;
          return bytes(<int>[1, 2, 3]);
        },
      );

      expect(result, <int>[1, 2, 3]);
      expect(fetchCalls, 1);
      expect(await directory.list().isEmpty, isTrue);
    });
  });
}

PrivateMediaDiskCache cacheFor(
  Directory directory, {
  int maxBytes = defaultPrivateMediaDiskCacheMaxBytes,
  DateTime Function()? now,
}) {
  return PrivateMediaDiskCache(
    directoryProvider: () async => directory,
    maxBytes: maxBytes,
    now: now,
  );
}

Future<Directory> createTemporaryCacheDirectory() async {
  final directory = await Directory.systemTemp.createTemp('memory-map-cache-');
  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
  return directory;
}

File cachedFile(Directory directory, String backendPath) {
  return File(
    '${directory.path}${Platform.pathSeparator}'
    '${privateMediaCacheFileNameForPath(backendPath)}',
  );
}

String pathFor(String mediaId) => '/api/v1/media/$mediaId/thumbnail';

Uint8List bytes(List<int> values) => Uint8List.fromList(values);

Uint8List imageBytes(int marker) {
  return Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, marker]);
}

const String thumbnailPath = '/api/v1/media/media-id/thumbnail';
const String displayPath = '/api/v1/media/media-id/display';

final class FakeClock {
  FakeClock(this._value);

  DateTime _value;

  DateTime now() => _value;

  void tick() {
    _value = _value.add(const Duration(seconds: 1));
  }
}
