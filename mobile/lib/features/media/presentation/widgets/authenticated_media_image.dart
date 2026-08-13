import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/domain/media.dart';

enum AuthenticatedMediaRepresentation {
  thumbnail,
  display,
}

class AuthenticatedMediaImage extends ConsumerStatefulWidget {
  const AuthenticatedMediaImage({
    required this.media,
    required this.representation,
    required this.fit,
    required this.placeholder,
    required this.errorBuilder,
    super.key,
  });

  final Media media;
  final AuthenticatedMediaRepresentation representation;
  final BoxFit fit;
  final Widget placeholder;
  final Widget Function(BuildContext context) errorBuilder;

  @override
  ConsumerState<AuthenticatedMediaImage> createState() =>
      _AuthenticatedMediaImageState();
}

class AuthenticatedMediaPathImage extends ConsumerStatefulWidget {
  const AuthenticatedMediaPathImage({
    required this.thumbnailPath,
    required this.fit,
    required this.placeholder,
    required this.errorBuilder,
    super.key,
  });

  final String thumbnailPath;
  final BoxFit fit;
  final Widget placeholder;
  final Widget Function(BuildContext context) errorBuilder;

  @override
  ConsumerState<AuthenticatedMediaPathImage> createState() =>
      _AuthenticatedMediaPathImageState();
}

class _AuthenticatedMediaPathImageState
    extends ConsumerState<AuthenticatedMediaPathImage> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(AuthenticatedMediaPathImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thumbnailPath != widget.thumbnailPath) {
      _future = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(
            bytes,
            fit: widget.fit,
            gaplessPlayback: true,
          );
        }

        if (snapshot.hasError) {
          return widget.errorBuilder(context);
        }

        return widget.placeholder;
      },
    );
  }

  Future<Uint8List> _load() {
    return ref
        .read(mediaRepositoryProvider)
        .getThumbnailByPath(widget.thumbnailPath);
  }
}

class _AuthenticatedMediaImageState
    extends ConsumerState<AuthenticatedMediaImage> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(AuthenticatedMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media != widget.media ||
        oldWidget.representation != widget.representation) {
      _future = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(
            bytes,
            fit: widget.fit,
            gaplessPlayback: true,
          );
        }

        if (snapshot.hasError) {
          return widget.errorBuilder(context);
        }

        return widget.placeholder;
      },
    );
  }

  Future<Uint8List> _load() {
    final repository = ref.read(mediaRepositoryProvider);
    return switch (widget.representation) {
      AuthenticatedMediaRepresentation.thumbnail =>
        repository.getThumbnail(widget.media),
      AuthenticatedMediaRepresentation.display =>
        repository.getDisplay(widget.media),
    };
  }
}
