enum MediaType {
  photo;

  static MediaType parse(String value) {
    return switch (value) {
      'PHOTO' => MediaType.photo,
      _ => throw const FormatException('Malformed media response'),
    };
  }
}
