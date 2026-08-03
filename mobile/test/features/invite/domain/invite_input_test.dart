import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/domain/accept_invite_input.dart';
import 'package:memory_map/features/invite/domain/create_invite_input.dart';

void main() {
  group('CreateInviteInput', () {
    test('shouldCreateInput', () {
      final input = CreateInviteInput(storyId: 'story-id');

      expect(input.storyId, 'story-id');
    });

    test('shouldRejectBlankStoryId', () {
      expect(
        () => CreateInviteInput(storyId: '   '),
        throwsA(argumentErrorWithMessage('storyId must not be blank')),
      );
    });

    test('shouldNotNormalizeStoryId', () {
      final input = CreateInviteInput(storyId: ' story-id ');

      expect(input.storyId, ' story-id ');
    });

    test('shouldCompareInputsByValue', () {
      final first = CreateInviteInput(storyId: 'story-id');
      final second = CreateInviteInput(storyId: 'story-id');
      final different = CreateInviteInput(storyId: 'another-story-id');

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldUseSafeToString', () {
      final input = CreateInviteInput(storyId: 'story-id');

      expect(input.toString(), 'CreateInviteInput');
      expect(input.toString(), isNot(contains('story-id')));
      expect(input.toString(), isNot(contains('token')));
    });
  });

  group('AcceptInviteInput', () {
    test('shouldCreateInput', () {
      final input = AcceptInviteInput(rawToken: 'raw-token');

      expect(input.rawToken, 'raw-token');
    });

    test('shouldRejectBlankRawToken', () {
      expect(
        () => AcceptInviteInput(rawToken: '   '),
        throwsA(argumentErrorWithMessage('rawToken must not be blank')),
      );
    });

    test('shouldNotNormalizeRawToken', () {
      final input = AcceptInviteInput(rawToken: ' raw-token ');

      expect(input.rawToken, ' raw-token ');
    });

    test('shouldCompareInputsByValue', () {
      final first = AcceptInviteInput(rawToken: 'raw-token');
      final second = AcceptInviteInput(rawToken: 'raw-token');
      final different = AcceptInviteInput(rawToken: 'another-token');

      expect(first, second);
      expect(first, isNot(different));
      expect(first.hashCode, second.hashCode);
    });

    test('shouldUseSafeToString', () {
      final input = AcceptInviteInput(rawToken: 'raw-token');

      expect(input.toString(), 'AcceptInviteInput');
      expect(input.toString(), isNot(contains('raw-token')));
      expect(input.toString(), isNot(contains('tokenHash')));
      expect(input.toString(), isNot(contains('Dio')));
      expect(input.toString(), isNot(contains('HTTP')));
    });
  });
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}
