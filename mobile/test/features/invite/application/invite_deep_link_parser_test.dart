import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/application/invite_deep_link.dart';
import 'package:memory_map/features/invite/application/invite_deep_link_parser.dart';

void main() {
  group('InviteDeepLinkParser', () {
    test('shouldParseCanonicalInviteLink', () {
      const parser = InviteDeepLinkParser();

      final result = parser.parseString(canonicalLink);

      expect(result, InviteDeepLink(validToken));
      expect(result?.rawToken, validToken);
    });

    test('shouldDecodeTokenExactlyOnce', () {
      const parser = InviteDeepLinkParser();

      final result = parser.parseString(
        'https://app.memorymap.app/invite/$encodedToken',
      );

      expect(result?.rawToken, validToken);
    });

    test('shouldRejectUnsupportedShapes', () {
      const parser = InviteDeepLinkParser();
      final invalidLinks = <String>[
        'http://app.memorymap.app/invite/$validToken',
        'https://memorymap.app/invite/$validToken',
        'https://user@app.memorymap.app/invite/$validToken',
        'https://app.memorymap.app/invite',
        'https://app.memorymap.app/invite/$validToken/extra',
        'https://app.memorymap.app/invites/$validToken',
        'https://app.memorymap.app/invite/$validToken?utm=source',
        'https://app.memorymap.app/invite/$validToken#fragment',
        'https://app.memorymap.app/invite?token=$validToken',
        'https://app.memorymap.app/invite/',
      ];

      for (final link in invalidLinks) {
        expect(parser.parseString(link), isNull, reason: link);
      }
    });

    test('shouldRejectInvalidTokenValues', () {
      const parser = InviteDeepLinkParser();
      final invalidTokens = <String>[
        '',
        '   ',
        '${validToken}a',
        validToken.substring(1),
        '${validToken.substring(0, 42)}=',
        '${validToken.substring(0, 42)}.',
        '${validToken.substring(0, 42)}%2F',
      ];

      for (final token in invalidTokens) {
        expect(
          parser.parseString('https://app.memorymap.app/invite/$token'),
          isNull,
          reason: token,
        );
      }
    });

    test('shouldRejectMalformedUriSafely', () {
      const parser = InviteDeepLinkParser();

      expect(parser.parseString('https://app.memorymap.app/invite/%'), isNull);
    });

    test('shouldUseSafeToString', () {
      const parser = InviteDeepLinkParser();
      final deepLink = parser.parseString(canonicalLink)!;

      expect(deepLink.toString(), isNot(contains(validToken)));
      expect(parser.toString(), isNot(contains(validToken)));
    });
  });
}

const validToken = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const encodedToken = 'AAAAAAAAAAAAAAAAAAAA%41AAAAAAAAAAAAAAAAAAAAAA';
const canonicalLink = 'https://app.memorymap.app/invite/$validToken';
