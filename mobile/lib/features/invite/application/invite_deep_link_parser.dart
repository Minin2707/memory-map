import 'package:memory_map/features/invite/application/invite_deep_link.dart';

final class InviteDeepLinkParser {
  const InviteDeepLinkParser();

  static const scheme = 'https';
  static const host = 'app.memorymap.app';
  static const tokenLength = 43;
  static final _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

  InviteDeepLink? parse(Uri uri) {
    if (uri.scheme != scheme) {
      return null;
    }
    if (uri.host != host) {
      return null;
    }
    if (uri.userInfo.isNotEmpty) {
      return null;
    }
    if (uri.hasQuery || uri.hasFragment) {
      return null;
    }

    final segments = uri.pathSegments;
    if (segments.length != 2 || segments.first != 'invite') {
      return null;
    }

    final token = segments.last;
    if (token.trim().isEmpty || token.contains('/')) {
      return null;
    }
    if (token.length != tokenLength || !_tokenPattern.hasMatch(token)) {
      return null;
    }

    return InviteDeepLink(token);
  }

  InviteDeepLink? parseString(String rawUri) {
    try {
      return parse(Uri.parse(rawUri));
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => 'InviteDeepLinkParser';
}
