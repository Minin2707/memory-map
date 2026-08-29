import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';

void main() {
  group('AuthUser', () {
    test('shouldCreateAuthUser', () {
      final user = AuthUser(
        id: 'user-id',
        displayName: 'Ada Lovelace',
        avatarUrl: 'https://example.com/avatar.png',
      );

      expect(user.id, 'user-id');
      expect(user.displayName, 'Ada Lovelace');
      expect(user.avatarUrl, 'https://example.com/avatar.png');
      expect(user.hasCustomAvatar, isFalse);
    });

    test('shouldAllowNullAvatarUrl', () {
      final user = AuthUser(
        id: 'user-id',
        displayName: 'Ada Lovelace',
      );

      expect(user.avatarUrl, isNull);
    });

    test('shouldAllowBlankAvatarUrlUntilUrlValidationIsDefined', () {
      final user = AuthUser(
        id: 'user-id',
        displayName: 'Ada Lovelace',
        avatarUrl: '   ',
      );

      expect(user.avatarUrl, '   ');
    });

    test('shouldRejectEmptyId', () {
      expect(
        () => AuthUser(
          id: '',
          displayName: 'Ada Lovelace',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'id must not be blank',
          ),
        ),
      );
    });

    test('shouldRejectWhitespaceId', () {
      expect(
        () => AuthUser(
          id: '   ',
          displayName: 'Ada Lovelace',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'id must not be blank',
          ),
        ),
      );
    });

    test('shouldRejectEmptyDisplayName', () {
      expect(
        () => AuthUser(
          id: 'user-id',
          displayName: '',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'displayName must not be blank',
          ),
        ),
      );
    });

    test('shouldRejectWhitespaceDisplayName', () {
      expect(
        () => AuthUser(
          id: 'user-id',
          displayName: '   ',
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            'displayName must not be blank',
          ),
        ),
      );
    });

    test('shouldCompareAuthUsersByValue', () {
      final first = AuthUser(
        id: 'user-id',
        displayName: 'Ada Lovelace',
        avatarUrl: 'https://example.com/avatar.png',
      );
      final second = AuthUser(
        id: 'user-id',
        displayName: 'Ada Lovelace',
        avatarUrl: 'https://example.com/avatar.png',
      );
      final different = AuthUser(
        id: 'another-user-id',
        displayName: 'Ada Lovelace',
        avatarUrl: 'https://example.com/avatar.png',
      );

      expect(first, second);
      expect(first, isNot(different));
    });

    test('shouldCompareCustomAvatarPresenceByValue', () {
      final googleAvatar = AuthUser(
        id: 'user-id',
        displayName: 'Ada Lovelace',
        avatarUrl: 'https://example.com/avatar.png',
      );
      final customAvatar = AuthUser(
        id: 'user-id',
        displayName: 'Ada Lovelace',
        avatarUrl: '/api/v1/me/avatar/1',
        hasCustomAvatar: true,
      );

      expect(googleAvatar, isNot(customAvatar));
    });

    test('shouldProduceStableHashCode', () {
      final first = AuthUser(
        id: 'user-id',
        displayName: 'Ada Lovelace',
        avatarUrl: 'https://example.com/avatar.png',
      );
      final second = AuthUser(
        id: 'user-id',
        displayName: 'Ada Lovelace',
        avatarUrl: 'https://example.com/avatar.png',
      );

      expect(first.hashCode, second.hashCode);
    });

    test('shouldExposeOnlyPublicProfileInToString', () {
      final user = AuthUser(
        id: 'user-id',
        displayName: 'Ada Lovelace',
        avatarUrl: 'https://example.com/avatar.png',
      );

      expect(
        user.toString(),
        'AuthUser(id: user-id, displayName: Ada Lovelace, '
        'avatarUrl: https://example.com/avatar.png, hasCustomAvatar: false)',
      );
    });
  });
}
