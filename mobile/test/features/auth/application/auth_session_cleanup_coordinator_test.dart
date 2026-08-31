import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/app/router.dart';
import 'package:memory_map/features/auth/application/auth_application_providers.dart';
import 'package:memory_map/features/auth/application/auth_network_providers.dart';
import 'package:memory_map/features/auth/application/auth_notifier.dart';
import 'package:memory_map/features/auth/application/auth_session_cleanup_coordinator.dart';
import 'package:memory_map/features/auth/application/auth_state.dart';
import 'package:memory_map/features/auth/domain/auth_failure.dart';
import 'package:memory_map/features/auth/domain/auth_repository.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/domain/auth_tokens.dart';
import 'package:memory_map/features/auth/domain/auth_user.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/memory/application/memory_application_providers.dart';
import 'package:memory_map/features/memory/application/memory_details_notifier.dart';
import 'package:memory_map/features/memory/application/memory_details_state.dart';
import 'package:memory_map/features/memory/application/story_map_notifier.dart';
import 'package:memory_map/features/memory/application/story_memories_notifier.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/delete_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_read_model.dart';
import 'package:memory_map/features/memory/domain/memory_repository.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/music/application/music_application_providers.dart';
import 'package:memory_map/features/music/application/story_soundtrack_notifier.dart';
import 'package:memory_map/features/music/application/story_soundtrack_state.dart';
import 'package:memory_map/features/music/domain/music_track.dart';
import 'package:memory_map/features/music/domain/story_soundtrack.dart';
import 'package:memory_map/features/music/domain/story_soundtrack_repository.dart';
import 'package:memory_map/features/participant/application/participant_application_providers.dart';
import 'package:memory_map/features/participant/application/participants_notifier.dart';
import 'package:memory_map/features/participant/domain/leave_story_input.dart';
import 'package:memory_map/features/participant/domain/remove_story_participant_input.dart';
import 'package:memory_map/features/participant/domain/story_participant.dart';
import 'package:memory_map/features/participant/domain/story_participant_repository.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/application/story_details_notifier.dart';
import 'package:memory_map/features/story/application/story_details_state.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('AuthSessionCleanupCoordinator', () {
    test('shouldInvalidateAuthScopedPrivateReadModelsAfterSessionLoss',
        () async {
      final fakes = CleanupFakes()..useUserA();
      final container = createContainer(fakes);
      addTearDown(container.dispose);
      await loadAuthScopedPrivateState(container);
      container
          .read(storyMapSelectionProvider(storyId).notifier)
          .selectMarker(memoryId);

      expect(readStories(container).single.story.title, 'User A story');
      expect(readStoryDetails(container).userStory!.story.title, 'User A story');
      expect(readStoryMemories(container).single.memory.title, 'User A memory');
      expect(readMemoryDetails(container).memory!.title, 'User A memory');
      expect(readParticipants(container).single.displayName, 'User A participant');
      expect(
        readSoundtrack(container).soundtrack!.selectedSoundtrack!.title,
        'User A track',
      );
      expect(
        container
            .read(storyMapSelectionProvider(storyId))
            .selectedMarkerId,
        memoryId,
      );

      fakes.useUserB();
      container
          .read(authSessionCleanupCoordinatorProvider)
          .handleAuthStateChange(
            AsyncData<AuthState>(AuthLoggingOut(sessionA)),
            const AsyncData<AuthState>(AuthUnauthenticated()),
          );

      await loadAuthScopedPrivateState(container);

      expect(readStories(container).single.story.title, 'User B story');
      expect(readStoryDetails(container).userStory!.story.title, 'User B story');
      expect(readStoryMemories(container).single.memory.title, 'User B memory');
      expect(readMemoryDetails(container).memory!.title, 'User B memory');
      expect(readParticipants(container).single.displayName, 'User B participant');
      expect(
        readSoundtrack(container).soundtrack!.selectedSoundtrack!.title,
        'User B track',
      );
      expect(
        container
            .read(storyMapSelectionProvider(storyId))
            .selectedMarkerId,
        isNull,
      );
    });

    test('shouldNotClearPrivateStateWhenLocalLogoutFailureKeepsSession',
        () async {
      final fakes = CleanupFakes()..useUserA();
      final container = createContainer(fakes);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      fakes.useUserB();
      container
          .read(authSessionCleanupCoordinatorProvider)
          .handleAuthStateChange(
            AsyncData<AuthState>(AuthLoggingOut(sessionA)),
            AsyncData<AuthState>(
              AuthLogoutFailure(
                session: sessionA,
                failure: const SecureStorageFailure(),
              ),
            ),
          );

      expect(readStories(container).single.story.title, 'User A story');
      expect(fakes.story.getStoriesCalls, 1);
    });

    test('shouldClearPrivateStateWhenAuthenticatedUserChanges', () async {
      final fakes = CleanupFakes()..useUserA();
      final container = createContainer(fakes);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      fakes.useUserB();
      container
          .read(authSessionCleanupCoordinatorProvider)
          .handleAuthStateChange(
            AsyncData<AuthState>(AuthAuthenticated(sessionA)),
            AsyncData<AuthState>(AuthAuthenticated(sessionB)),
          );

      await container.read(storiesNotifierProvider.future);

      expect(readStories(container).single.story.title, 'User B story');
      expect(fakes.story.getStoriesCalls, 2);
    });

    test('shouldNotClearPrivateStateForSameUserTokenRefresh', () async {
      final fakes = CleanupFakes()..useUserA();
      final container = createContainer(fakes);
      addTearDown(container.dispose);
      await container.read(storiesNotifierProvider.future);

      fakes.useUserB();
      container
          .read(authSessionCleanupCoordinatorProvider)
          .handleAuthStateChange(
            AsyncData<AuthState>(AuthAuthenticated(sessionA)),
            AsyncData<AuthState>(AuthAuthenticated(refreshedSessionA)),
          );

      expect(readStories(container).single.story.title, 'User A story');
      expect(fakes.story.getStoriesCalls, 1);
    });

    test('shouldNotInvalidateUnrelatedPublicProviders', () {
      var builds = 0;
      final publicProvider = Provider<int>((_) {
        builds += 1;
        return builds;
      });
      final fakes = CleanupFakes()..useUserA();
      final container = createContainer(fakes);
      addTearDown(container.dispose);

      expect(container.read(publicProvider), 1);

      container
          .read(authSessionCleanupCoordinatorProvider)
          .handleAuthStateChange(
            AsyncData<AuthState>(AuthAuthenticated(sessionA)),
            const AsyncData<AuthState>(AuthUnauthenticated()),
          );

      expect(container.read(publicProvider), 1);
      expect(builds, 1);
    });

    test('shouldIgnoreStaleInFlightMemoryCompletionAfterCleanup', () async {
      final memoryCompleter = Completer<MemoryReadModel>();
      final fakes = CleanupFakes()
        ..useUserA()
        ..memory.getMemoryCompleter = memoryCompleter;
      final container = createContainer(fakes);
      addTearDown(container.dispose);

      final staleLoad = container.read(memoryDetailsProvider(memoryId).future);
      unawaited(
        staleLoad.catchError(
          (_) => MemoryDetailsState.loadedRead(
            readModel: MemoryReadModel.fromMemory(
              userMemory('ignored stale memory'),
            ),
          ),
        ),
      );
      await pumpEventQueue();

      fakes.useUserB();
      container
          .read(authSessionCleanupCoordinatorProvider)
          .handleAuthStateChange(
            AsyncData<AuthState>(AuthAuthenticated(sessionA)),
            const AsyncData<AuthState>(AuthUnauthenticated()),
          );
      final activeLoad = container.read(memoryDetailsProvider(memoryId).future);

      memoryCompleter.complete(
        MemoryReadModel.fromMemory(userMemory('User A stale memory')),
      );

      expect((await activeLoad).memory!.title, 'User B memory');
      await pumpEventQueue();
      expect(readMemoryDetails(container).memory!.title, 'User B memory');
    });
  });

  group('Auth session boundary wiring', () {
    test('shouldRunCleanupAfterSessionStoreClear', () async {
      final fakes = CleanupFakes()..useUserA();
      final container = createContainer(fakes);
      addTearDown(container.dispose);
      container.read(routerRefreshNotifierProvider);
      await container.read(authNotifierProvider.future);
      await container.read(storiesNotifierProvider.future);

      fakes.useUserB();
      container.read(authSessionStoreProvider).clear();
      await pumpEventQueue();
      await container.read(storiesNotifierProvider.future);

      expect(readStories(container).single.story.title, 'User B story');
      expect(fakes.story.getStoriesCalls, 2);
    });

    test('shouldRunCleanupAfterUserSwitchInSessionStore', () async {
      final fakes = CleanupFakes()..useUserA();
      final container = createContainer(fakes);
      addTearDown(container.dispose);
      container.read(routerRefreshNotifierProvider);
      await container.read(authNotifierProvider.future);
      await container.read(storiesNotifierProvider.future);

      fakes.useUserB();
      container.read(authSessionStoreProvider).setSession(sessionB);
      await pumpEventQueue();
      await container.read(storiesNotifierProvider.future);

      expect(readStories(container).single.story.title, 'User B story');
      expect(fakes.story.getStoriesCalls, 2);
    });
  });
}

ProviderContainer createContainer(CleanupFakes fakes) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakes.auth),
      storyRepositoryProvider.overrideWithValue(fakes.story),
      memoryRepositoryProvider.overrideWithValue(fakes.memory),
      storyParticipantRepositoryProvider.overrideWithValue(fakes.participant),
      storySoundtrackRepositoryProvider.overrideWithValue(fakes.soundtrack),
    ],
  );
}

Future<void> loadAuthScopedPrivateState(ProviderContainer container) async {
  await container.read(storiesNotifierProvider.future);
  await container.read(storyDetailsProvider(storyId).future);
  await container.read(storyMemoriesProvider(storyId).future);
  await container.read(memoryDetailsProvider(memoryId).future);
  await container.read(storyParticipantsProvider(storyId).future);
  await container.read(storySoundtrackProvider(storyId).future);
}

List<UserStory> readStories(ProviderContainer container) {
  return container.read(storiesNotifierProvider).asData!.value.stories;
}

StoryDetailsState readStoryDetails(ProviderContainer container) {
  return container.read(storyDetailsProvider(storyId)).asData!.value;
}

List<MemoryReadModel> readStoryMemories(ProviderContainer container) {
  return container
      .read(storyMemoriesProvider(storyId))
      .asData!
      .value
      .memoryReadModels;
}

MemoryDetailsState readMemoryDetails(ProviderContainer container) {
  return container.read(memoryDetailsProvider(memoryId)).asData!.value;
}

List<StoryParticipant> readParticipants(ProviderContainer container) {
  return container
      .read(storyParticipantsProvider(storyId))
      .asData!
      .value
      .participants;
}

StorySoundtrackState readSoundtrack(ProviderContainer container) {
  return container.read(storySoundtrackProvider(storyId)).asData!.value;
}

const String storyId = 'story-1';
const String memoryId = 'memory-1';

final AuthSession sessionA = AuthSession(
  user: AuthUser(
    id: 'user-a',
    displayName: 'User A',
    avatarUrl: null,
  ),
  tokens: AuthTokens(
    accessToken: 'access-a',
    refreshToken: 'refresh-a',
  ),
);

final AuthSession refreshedSessionA = AuthSession(
  user: sessionA.user,
  tokens: AuthTokens(
    accessToken: 'access-a-refreshed',
    refreshToken: 'refresh-a-refreshed',
  ),
);

final AuthSession sessionB = AuthSession(
  user: AuthUser(
    id: 'user-b',
    displayName: 'User B',
    avatarUrl: null,
  ),
  tokens: AuthTokens(
    accessToken: 'access-b',
    refreshToken: 'refresh-b',
  ),
);

final class CleanupFakes {
  final FakeAuthRepository auth = FakeAuthRepository();
  final FakeStoryRepository story = FakeStoryRepository();
  final FakeMemoryRepository memory = FakeMemoryRepository();
  final FakeStoryParticipantRepository participant =
      FakeStoryParticipantRepository();
  final FakeStorySoundtrackRepository soundtrack =
      FakeStorySoundtrackRepository();

  void useUserA() {
    auth.restoreResult = sessionA;
    story.userStory = testUserStory('User A story');
    memory.memoryReadModel = MemoryReadModel.fromMemory(
      userMemory('User A memory'),
    );
    participant.participants = <StoryParticipant>[
      storyParticipant('User A participant'),
    ];
    soundtrack.soundtrack = userSoundtrack('track-a', 'User A track');
  }

  void useUserB() {
    auth.restoreResult = sessionB;
    story.userStory = testUserStory('User B story');
    memory.memoryReadModel = MemoryReadModel.fromMemory(
      userMemory('User B memory'),
    );
    participant.participants = <StoryParticipant>[
      storyParticipant('User B participant'),
    ];
    soundtrack.soundtrack = userSoundtrack('track-b', 'User B track');
  }
}

final class FakeAuthRepository implements AuthRepository {
  AuthSession? restoreResult;

  @override
  Future<AuthSession?> restoreSession() async {
    return restoreResult;
  }

  @override
  Future<AuthSession> loginWithGoogle() async {
    return restoreResult ?? sessionA;
  }

  @override
  Future<void> logout(AuthSession session) async {}
}

final class FakeStoryRepository implements StoryRepository {
  int getStoriesCalls = 0;
  int getStoryCalls = 0;
  UserStory userStory = testUserStory('User A story');

  @override
  Future<Story> createStory({
    required String title,
    String? description,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    getStoryCalls += 1;
    return userStory;
  }

  @override
  Future<List<UserStory>> getStories() async {
    getStoriesCalls += 1;
    return <UserStory>[userStory];
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) {
    throw UnimplementedError();
  }

  @override
  Future<UserStory> uploadStoryCover({
    required String storyId,
    required PreparedPhotoUpload photo,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<UserStory> removeStoryCover({
    required String storyId,
  }) {
    throw UnimplementedError();
  }
}

final class FakeMemoryRepository implements MemoryRepository {
  int getMemoryCalls = 0;
  int getMemoriesCalls = 0;
  MemoryReadModel memoryReadModel = MemoryReadModel.fromMemory(
    userMemory('User A memory'),
  );
  Completer<MemoryReadModel>? getMemoryCompleter;

  @override
  Future<Memory> createMemory(CreateMemoryInput input) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteMemory(DeleteMemoryInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<MemoryReadModel>> getMemories(String storyId) async {
    getMemoriesCalls += 1;
    return <MemoryReadModel>[memoryReadModel];
  }

  @override
  Future<MemoryReadModel> getMemory(String memoryId) async {
    getMemoryCalls += 1;
    final completer = getMemoryCompleter;
    if (completer != null) {
      getMemoryCompleter = null;
      return completer.future;
    }

    return memoryReadModel;
  }

  @override
  Future<Memory> updateMemory(UpdateMemoryInput input) {
    throw UnimplementedError();
  }
}

final class FakeStoryParticipantRepository
    implements StoryParticipantRepository {
  List<StoryParticipant> participants = <StoryParticipant>[
    storyParticipant('User A participant'),
  ];

  @override
  Future<List<StoryParticipant>> getParticipants(String storyId) async {
    return participants;
  }

  @override
  Future<void> leaveStory(LeaveStoryInput input) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeParticipant(RemoveStoryParticipantInput input) {
    throw UnimplementedError();
  }
}

final class FakeStorySoundtrackRepository
    implements StorySoundtrackRepository {
  StorySoundtrack soundtrack = userSoundtrack('track-a', 'User A track');

  @override
  Future<StorySoundtrack> getStorySoundtrack(String storyId) async {
    return soundtrack;
  }

  @override
  Future<StorySoundtrack> removeStorySoundtrack(String storyId) {
    throw UnimplementedError();
  }

  @override
  Future<StorySoundtrack> setStorySoundtrack(
    String storyId,
    String musicTrackId,
  ) {
    throw UnimplementedError();
  }
}

UserStory testUserStory(String title) {
  return UserStory(
    story: Story(
      id: storyId,
      title: title,
      description: '$title description',
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 2),
    ),
    role: StoryRole.owner,
    memoryCount: 1,
    participantCount: 1,
  );
}

Memory userMemory(String title) {
  return Memory(
    id: memoryId,
    storyId: storyId,
    createdBy: 'author-id',
    title: title,
    description: '$title description',
    placeName: 'Tbilisi',
    location: MemoryLocation(latitude: 41.7151, longitude: 44.8271),
    eventDate: MemoryDate(year: 2026, month: 8, day: 9),
    createdAt: DateTime.utc(2026, 8, 9, 10),
    updatedAt: DateTime.utc(2026, 8, 9, 11),
  );
}

StoryParticipant storyParticipant(String displayName) {
  return StoryParticipant(
    userId: '$displayName-id',
    displayName: displayName,
    avatarUrl: null,
    role: StoryRole.owner,
    joinedAt: DateTime.utc(2026, 8, 9, 12),
  );
}

StorySoundtrack userSoundtrack(String id, String title) {
  final track = MusicTrack(
    id: id,
    title: title,
    artist: 'Memory Story',
    durationSeconds: 120,
  );
  return StorySoundtrack(
    selectedSoundtrack: track,
    effectiveSoundtrack: track,
  );
}
