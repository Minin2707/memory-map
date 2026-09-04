import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/invite/application/default_invite_repository.dart';
import 'package:memory_map/features/invite/application/invite_application_providers.dart';
import 'package:memory_map/features/invite/data/remote/dio_invite_remote_data_source.dart';
import 'package:memory_map/features/invite/data/remote/invite_remote_data_source.dart';
import 'package:memory_map/features/invite/domain/accept_invite_input.dart';
import 'package:memory_map/features/invite/domain/create_invite_input.dart';
import 'package:memory_map/features/invite/domain/invite.dart';
import 'package:memory_map/features/invite/domain/invite_repository.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('inviteRepositoryProvider', () {
    test('shouldCreateInviteRepositoryFromRemoteDataSourceProvider', () {
      final remote = FakeInviteRemoteDataSource();
      final container = ProviderContainer(
        overrides: [
          inviteRemoteDataSourceProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);

      final repository = container.read(inviteRepositoryProvider);

      expect(repository, isA<InviteRepository>());
      expect(repository, isA<DefaultInviteRepository>());
      expect(remote.totalCalls, 0);
    });

    test('shouldDelegateThroughProviderCreatedRepository', () async {
      final remote = FakeInviteRemoteDataSource();
      final container = ProviderContainer(
        overrides: [
          inviteRemoteDataSourceProvider.overrideWithValue(remote),
        ],
      );
      addTearDown(container.dispose);
      final repository = container.read(inviteRepositoryProvider);

      final invite = await repository.createInvite(
        CreateInviteInput(
          storyId: 'story-id',
          targetRole: StoryRole.editor,
        ),
      );
      final userStory = await repository.acceptInvite(
        AcceptInviteInput(rawToken: 'raw-token'),
      );

      expect(invite, inviteFixture);
      expect(userStory, userStoryFixture);
      expect(remote.receivedStoryId, 'story-id');
      expect(remote.receivedTargetRole, StoryRole.editor);
      expect(remote.receivedRawToken, 'raw-token');
      expect(remote.totalCalls, 2);
    });
  });
}

final Invite inviteFixture = Invite(
  inviteLink: Uri.parse('https://app.memorymap.app/invite/share-token-123'),
  expiresAt: DateTime.utc(2026, 2, 9, 10),
);

final UserStory userStoryFixture = UserStory(
  story: Story(
    id: 'story-id',
    title: 'Our Story',
    description: 'Together since 2021',
    createdAt: DateTime.utc(2026, 1, 1, 10),
    updatedAt: DateTime.utc(2026, 1, 10, 10),
  ),
  role: StoryRole.coOwner,
);

final class FakeInviteRemoteDataSource implements InviteRemoteDataSource {
  int totalCalls = 0;
  String? receivedStoryId;
  StoryRole? receivedTargetRole;
  String? receivedRawToken;

  @override
  Future<Invite> createInvite(String storyId, StoryRole targetRole) async {
    totalCalls += 1;
    receivedStoryId = storyId;
    receivedTargetRole = targetRole;

    return inviteFixture;
  }

  @override
  Future<UserStory> acceptInvite(String rawToken) async {
    totalCalls += 1;
    receivedRawToken = rawToken;

    return userStoryFixture;
  }
}
