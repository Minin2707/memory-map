import 'dart:typed_data';

final class SelectedPhoto {
  factory SelectedPhoto({
    required Future<Uint8List> Function() readBytes,
    String? declaredContentType,
  }) {
    if (declaredContentType != null && declaredContentType.trim().isEmpty) {
      throw ArgumentError('declaredContentType must not be blank');
    }

    return SelectedPhoto._(
      readBytes: readBytes,
      declaredContentType: declaredContentType,
    );
  }

  const SelectedPhoto._({
    required this.readBytes,
    required this.declaredContentType,
  });

  final Future<Uint8List> Function() readBytes;
  final String? declaredContentType;

  @override
  String toString() {
    return 'SelectedPhoto(hasDeclaredContentType: '
        '${declaredContentType != null})';
  }
}
