// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:memory_map/features/media/domain/authenticated_media_cache.dart';
import 'package:path_provider/path_provider.dart';

typedef PrivateMediaCacheDirectoryProvider = Future<Directory> Function();

const int defaultPrivateMediaDiskCacheMaxBytes = 250 * 1024 * 1024;

final class PrivateMediaDiskCache implements AuthenticatedMediaCache {
  PrivateMediaDiskCache({
    required PrivateMediaCacheDirectoryProvider directoryProvider,
    this.maxBytes = defaultPrivateMediaDiskCacheMaxBytes,
    DateTime Function()? now,
  })  : assert(maxBytes > 0),
        _directoryProvider = directoryProvider,
        _now = now ?? DateTime.now;

  final PrivateMediaCacheDirectoryProvider _directoryProvider;
  final int maxBytes;
  final DateTime Function() _now;
  final Map<String, Future<Uint8List>> _inFlight =
      <String, Future<Uint8List>>{};
  int _clearGeneration = 0;

  @override
  Future<Uint8List> getOrFetch(
    String backendPath,
    Future<Uint8List> Function() fetch,
  ) {
    if (!privateMediaCachePathPolicy.isCacheable(backendPath)) {
      return fetch();
    }

    final active = _inFlight[backendPath];
    if (active != null) {
      return active;
    }

    final future = _getOrFetchUnshared(backendPath, fetch);
    _inFlight[backendPath] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[backendPath], future)) {
        _inFlight.remove(backendPath);
      }
    });
  }

  @override
  Future<void> clear() async {
    _clearGeneration += 1;
    _inFlight.clear();

    try {
      final directory = await _directory();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } on Object {
      // Cache cleanup must not break logout/session invalidation flows.
    }
  }

  Future<Uint8List> _getOrFetchUnshared(
    String backendPath,
    Future<Uint8List> Function() fetch,
  ) async {
    final requestGeneration = _clearGeneration;
    final fileName = privateMediaCacheFileNameForPath(backendPath);
    File? cacheFile;

    try {
      final directory = await _directory();
      cacheFile = File(
        '${directory.path}${Platform.pathSeparator}$fileName',
      );
      final cachedBytes = await _readCachedBytes(cacheFile);
      if (cachedBytes != null) {
        return cachedBytes;
      }
    } on Object {
      cacheFile = null;
    }

    final bytes = await fetch();
    if (!_isSupportedCompressedImage(bytes)) {
      return bytes;
    }

    if (cacheFile != null && requestGeneration == _clearGeneration) {
      await _writeAndEvict(cacheFile, bytes);
    }

    return bytes;
  }

  Future<Uint8List?> _readCachedBytes(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      if (!_isSupportedCompressedImage(bytes)) {
        await _deleteFile(file);
        return null;
      }

      await file.setLastModified(_now().toUtc());
      return bytes;
    } on Object {
      await _deleteFile(file);
      return null;
    }
  }

  Future<void> _writeAndEvict(File file, Uint8List bytes) async {
    try {
      await file.parent.create(recursive: true);
      final temporaryFile = File(
        '${file.path}.tmp.${DateTime.now().microsecondsSinceEpoch}',
      );
      await temporaryFile.writeAsBytes(bytes, flush: true);
      await temporaryFile.rename(file.path);
      await file.setLastModified(_now().toUtc());
      await _evictIfNeeded(file.parent);
    } on Object {
      // Network-loaded bytes have already been returned to the caller.
    }
  }

  Future<void> _evictIfNeeded(Directory directory) async {
    try {
      if (!await directory.exists()) {
        return;
      }

      final entries = <_CacheEntry>[];
      var totalBytes = 0;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.bin')) {
          continue;
        }

        final stat = await entity.stat();
        totalBytes += stat.size;
        entries.add(_CacheEntry(
          file: entity,
          size: stat.size,
          lastAccessed: stat.modified,
        ));
      }

      if (totalBytes <= maxBytes) {
        return;
      }

      entries.sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));
      for (final entry in entries) {
        if (totalBytes <= maxBytes) {
          break;
        }

        await _deleteFile(entry.file);
        totalBytes -= entry.size;
      }
    } on Object {
      // Eviction is best effort; failed cleanup must not break image loading.
    }
  }

  Future<Directory> _directory() async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    return directory;
  }

  Future<void> _deleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on Object {
      // Best-effort cache hygiene only.
    }
  }
}

final class PrivateMediaCachePathPolicy {
  const PrivateMediaCachePathPolicy();

  bool isCacheable(String backendPath) {
    final uri = Uri.tryParse(backendPath);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }

    return _isMemoryMediaPath(backendPath) || _isStoryCoverPath(backendPath);
  }

  bool _isMemoryMediaPath(String backendPath) {
    return backendPath.startsWith('/api/v1/media/') &&
        (backendPath.endsWith('/thumbnail') ||
            backendPath.endsWith('/display'));
  }

  bool _isStoryCoverPath(String backendPath) {
    final segments = Uri(path: backendPath).pathSegments;
    if (segments.length != 7 ||
        segments[0] != 'api' ||
        segments[1] != 'v1' ||
        segments[2] != 'stories' ||
        segments[4] != 'cover' ||
        (segments[5] != 'thumbnail' && segments[5] != 'display')) {
      return false;
    }

    return RegExp(r'^[0-9]+$').hasMatch(segments[6]);
  }
}

const PrivateMediaCachePathPolicy privateMediaCachePathPolicy =
    PrivateMediaCachePathPolicy();

String privateMediaCacheFileNameForPath(String backendPath) {
  final encoded = base64Url.encode(utf8.encode(backendPath)).replaceAll('=', '');
  return 'v1_$encoded.bin';
}

bool _isSupportedCompressedImage(Uint8List bytes) {
  return _isJpeg(bytes) || _isPng(bytes);
}

bool _isJpeg(Uint8List bytes) {
  return bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;
}

bool _isPng(Uint8List bytes) {
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A;
}

Future<Directory> defaultPrivateMediaCacheDirectory() async {
  final supportDirectory = await getApplicationSupportDirectory();
  return Directory(
    '${supportDirectory.path}${Platform.pathSeparator}private_media_cache',
  );
}

final class _CacheEntry {
  const _CacheEntry({
    required this.file,
    required this.size,
    required this.lastAccessed,
  });

  final File file;
  final int size;
  final DateTime lastAccessed;
}
