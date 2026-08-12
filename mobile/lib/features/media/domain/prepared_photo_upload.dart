import 'dart:typed_data';

final class PreparedPhotoUpload {
  factory PreparedPhotoUpload({
    required Uint8List bytes,
    required String contentType,
  }) {
    if (bytes.isEmpty) {
      throw ArgumentError('bytes must not be empty');
    }

    if (contentType.trim().isEmpty) {
      throw ArgumentError('contentType must not be blank');
    }

    return PreparedPhotoUpload._(
      bytes: Uint8List.fromList(bytes),
      contentType: contentType,
    );
  }

  PreparedPhotoUpload._({
    required Uint8List bytes,
    required this.contentType,
  }) : _bytes = bytes;

  final Uint8List _bytes;
  final String contentType;

  Uint8List get bytes => Uint8List.fromList(_bytes);

  int get byteLength => _bytes.lengthInBytes;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PreparedPhotoUpload &&
            _listEquals(_bytes, other._bytes) &&
            contentType == other.contentType;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(_bytes), contentType);

  @override
  String toString() {
    return 'PreparedPhotoUpload(byteLength: $byteLength, '
        'hasContentType: true)';
  }

  static bool _listEquals(Uint8List left, Uint8List right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }
}
