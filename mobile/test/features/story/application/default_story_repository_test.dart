import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/application/default_story_repository.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/data/remote/create_story_remote_request.dart';
import 'package:memory_map/features/story/data/remote/story_remote_data_source.dart';
import 'package:memory_map/features/story/data/remote/story_remote_exception.dart';
import 'package:memory_map/features/story/data/remote/update_story_remote_request.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/story_update_field.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';

void main() {
  group('DefaultStoryRepository create', () {
    test('shouldDelegateCreateTitleAndDescription', () async {
      final fakes = StoryRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.createStory(
        title: 'Our Story',
        description: 'Together since 2021',
      );

      expect(fakes.remote.createCalls, 1);
      expect(fakes.remote.receivedCreateRequest?.title, 'Our Story');
      expect(
        fakes.remote.receivedCreateRequest?.description,
        'Together since 2021',
      );
    });

    test('shouldReturnExactCreatedStory', () async {
      final fakes = StoryRepositoryFakes();
      final repository = fakes.createRepository();

      final story = await repository.createStory(title: 'Our Story');

      expect(story, storyFixture);
    });

    test('shouldPassNullableDescription', () async {
      final fakes = StoryRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.createStory(
        title: 'Our Story',
        description: null,
      );

      expect(fakes.remote.receivedCreateRequest?.description, isNull);
    });

    test('shouldNotExposeInternalCreateFields', () async {
      final fakes = StoryRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.createStory(title: 'Our Story');

      final json = fakes.remote.receivedCreateRequest!.toJson();
      expect(json.containsKey('ownerId'), isFalse);
      expect(json.containsKey('userId'), isFalse);
      expect(json.containsKey('role'), isFalse);
    });

    test('shouldRejectBlankCreateTitleBeforeRemoteCall', () async {
      final fakes = StoryRepositoryFakes();
      final repository = fakes.createRepository();

      await expectLater(
        repository.createStory(title: '   '),
        throwsA(argumentErrorWithMessage('title must not be blank')),
      );
      expect(fakes.remote.createCalls, 0);
    });
  });

  group('DefaultStoryRepository getStories', () {
    test('shouldDelegateGetStoriesOnce', () async {
      final fakes = StoryRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.getStories();

      expect(fakes.remote.getStoriesCalls, 1);
    });

    test('shouldReturnExactOrderedStoryList', () async {
      final fakes = StoryRepositoryFakes()
        ..remote.stories = <UserStory>[
          userStoryFixture,
          coOwnerUserStoryFixture,
        ];
      final repository = fakes.createRepository();

      final stories = await repository.getStories();

      expect(stories, <UserStory>[
        userStoryFixture,
        coOwnerUserStoryFixture,
      ]);
    });

    test('shouldReturnEmptyStoryList', () async {
      final fakes = StoryRepositoryFakes()..remote.stories = <UserStory>[];
      final repository = fakes.createRepository();

      final stories = await repository.getStories();

      expect(stories, isEmpty);
    });
  });

  group('DefaultStoryRepository getStory', () {
    test('shouldPassExactStoryId', () async {
      final fakes = StoryRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.getStory('story-id');

      expect(fakes.remote.receivedStoryId, 'story-id');
    });

    test('shouldReturnExactUserStory', () async {
      final fakes = StoryRepositoryFakes();
      final repository = fakes.createRepository();

      final story = await repository.getStory('story-id');

      expect(story, userStoryFixture);
    });

    test('shouldRejectBlankStoryIdBeforeRemoteCall', () async {
      final fakes = StoryRepositoryFakes();
      final repository = fakes.createRepository();

      await expectLater(
        repository.getStory('   '),
        throwsA(argumentErrorWithMessage('storyId must not be blank')),
      );
      expect(fakes.remote.getStoryCalls, 0);
    });
  });

  group('DefaultStoryRepository updateStory', () {
    test('shouldPassExactUpdateStoryId', () async {
      final fakes = StoryRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.updateStory(titleOnlyInput());

      expect(fakes.remote.receivedUpdateStoryId, 'story-id');
    });

    test('shouldMapTitleOnlyUpdateToRemoteRequest', () async {
      final fakes = StoryRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.updateStory(titleOnlyInput());

      final request = fakes.remote.receivedUpdateRequest!;
      expect(request.title.isProvided, isTrue);
      expect(request.title.value, 'Updated Story');
      expect(request.description.isProvided, isFalse);
    });

    test('shouldMapDescriptionOnlyUpdateToRemoteRequest', () async {
      final fakes = StoryRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.updateStory(
        UpdateStoryInput(
          storyId: 'story-id',
          description:
              const StoryUpdateField<String>.provided('Updated description'),
        ),
      );

      final request = fakes.remote.receivedUpdateRequest!;
      expect(request.title.isProvided, isFalse);
      expect(request.description.isProvided, isTrue);
      expect(request.description.value, 'Updated description');
    });

    test('shouldMapClearDescriptionToRemoteRequest', () async {
      final fakes = StoryRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.updateStory(
        UpdateStoryInput(
          storyId: 'story-id',
          description: const StoryUpdateField<String>.provided(null),
        ),
      );

      final request = fakes.remote.receivedUpdateRequest!;
      expect(request.description.isProvided, isTrue);
      expect(request.description.value, isNull);
      expect(request.toJson().containsKey('description'), isTrue);
    });

    test('shouldMapBothFieldsToRemoteRequest', () async {
      final fakes = StoryRepositoryFakes();
      final repository = fakes.createRepository();

      await repository.updateStory(
        UpdateStoryInput(
          storyId: 'story-id',
          title: const StoryUpdateField<String>.provided('Updated Story'),
          description:
              const StoryUpdateField<String>.provided('Updated description'),
        ),
      );

      final request = fakes.remote.receivedUpdateRequest!;
      expect(request.title.value, 'Updated Story');
      expect(request.description.value, 'Updated description');
    });

    test('shouldReturnExactUpdatedUserStory', () async {
      final fakes = StoryRepositoryFakes();
      final repository = fakes.createRepository();

      final story = await repository.updateStory(titleOnlyInput());

      expect(story, userStoryFixture);
    });

    test('shouldRejectEmptyUpdateBeforeRemoteCall', () async {
      final fakes = StoryRepositoryFakes();

      expect(
        () => UpdateStoryInput(storyId: 'story-id'),
        throwsA(
          argumentErrorWithMessage(
            'at least one update field must be provided',
          ),
        ),
      );
      expect(fakes.remote.updateStoryCalls, 0);
    });

    test('shouldRejectInvalidTitleBeforeRemoteCall', () async {
      final fakes = StoryRepositoryFakes();

      expect(
        () => UpdateStoryInput(
          storyId: 'story-id',
          title: const StoryUpdateField<String>.provided('   '),
        ),
        throwsA(argumentErrorWithMessage('title must not be blank')),
      );
      expect(fakes.remote.updateStoryCalls, 0);
    });
  });

  group('DefaultStoryRepository failure mapping', () {
    test('shouldMapKnownRemoteFailures', () async {
      final cases = <RemoteFailureCase>[
        RemoteFailureCase(
          const StoryRemoteValidationException(),
          const StoryValidationFailure(),
        ),
        RemoteFailureCase(
          const StoryRemoteUnauthorizedException(),
          const StoryUnauthorized(),
        ),
        RemoteFailureCase(
          const StoryRemoteNotFoundException(),
          const StoryNotFound(),
        ),
        RemoteFailureCase(
          const StoryRemoteNetworkException(),
          const StoryNetworkUnavailable(),
        ),
        RemoteFailureCase(
          const StoryRemoteTimeoutException(),
          const StoryRequestTimedOut(),
        ),
        RemoteFailureCase(
          const StoryRemoteServerException(),
          const StoryServerFailure(),
        ),
        RemoteFailureCase(
          const StoryRemoteMalformedResponseException(),
          const UnknownStoryFailure(),
        ),
        RemoteFailureCase(
          const StoryRemoteUnknownException(),
          const UnknownStoryFailure(),
        ),
      ];

      for (final failureCase in cases) {
        await expectRemoteFailure(
          failureCase.exception,
          failureCase.failure,
        );
      }
    });

    test('shouldNotMaskUnexpectedException', () async {
      final fakes = StoryRepositoryFakes()
        ..remote.failure = const UnexpectedStoryException();
      final repository = fakes.createRepository();

      await expectLater(
        repository.getStories(),
        throwsA(isA<UnexpectedStoryException>()),
      );
    });

    test('shouldNotExposeSensitiveDetailsInApplicationException', () async {
      final fakes = StoryRepositoryFakes()
        ..remote.failure = const StoryRemoteNotFoundException();
      final repository = fakes.createRepository();

      try {
        await repository.getStory('private-story-id');
        fail('Expected story application exception');
      } on StoryApplicationException catch (error) {
        expect(error.toString(), 'StoryApplicationException');
        expect(error.toString(), isNot(contains('private-story-id')));
        expect(error.toString(), isNot(contains('token')));
        expect(error.toString(), isNot(contains('Dio')));
        expect(error.toString(), isNot(contains('StoryRemote')));
        expect(error.toString(), isNot(contains('404')));
      }
    });
  });
}

Future<void> expectRemoteFailure(
  StoryRemoteException exception,
  StoryFailure failure,
) async {
  final fakes = StoryRepositoryFakes()..remote.failure = exception;
  final repository = fakes.createRepository();

  await expectApplicationFailure(repository.getStories(), failure);
}

Future<void> expectApplicationFailure(
  Future<Object?> future,
  StoryFailure failure,
) async {
  await expectLater(
    future,
    throwsA(
      isA<StoryApplicationException>().having(
        (exception) => exception.failure,
        'failure',
        failure,
      ),
    ),
  );
}

UpdateStoryInput titleOnlyInput() {
  return UpdateStoryInput(
    storyId: 'story-id',
    title: const StoryUpdateField<String>.provided('Updated Story'),
  );
}

Matcher argumentErrorWithMessage(String message) {
  return isA<ArgumentError>().having(
    (error) => error.message,
    'message',
    message,
  );
}

final Story storyFixture = Story(
  id: 'story-id',
  title: 'Our Story',
  description: 'Together since 2021',
  createdAt: DateTime.utc(2026, 1, 1, 10),
  updatedAt: DateTime.utc(2026, 1, 10, 10),
);

final UserStory userStoryFixture = UserStory(
  story: storyFixture,
  role: StoryRole.owner,
);

final UserStory coOwnerUserStoryFixture = UserStory(
  story: Story(
    id: 'second-story-id',
    title: 'Second Story',
    description: null,
    createdAt: DateTime.utc(2026, 1, 2, 10),
    updatedAt: DateTime.utc(2026, 1, 11, 10),
  ),
  role: StoryRole.coOwner,
);

final class StoryRepositoryFakes {
  late final FakeStoryRemoteDataSource remote = FakeStoryRemoteDataSource();

  DefaultStoryRepository createRepository() {
    return DefaultStoryRepository(storyRemoteDataSource: remote);
  }
}

final class FakeStoryRemoteDataSource implements StoryRemoteDataSource {
  int createCalls = 0;
  int getStoriesCalls = 0;
  int getStoryCalls = 0;
  int updateStoryCalls = 0;
  Object? failure;
  CreateStoryRemoteRequest? receivedCreateRequest;
  String? receivedStoryId;
  String? receivedUpdateStoryId;
  UpdateStoryRemoteRequest? receivedUpdateRequest;
  List<UserStory> stories = <UserStory>[userStoryFixture];

  @override
  Future<Story> createStory(CreateStoryRemoteRequest request) async {
    createCalls += 1;
    receivedCreateRequest = request;
    _throwIfConfigured();

    return storyFixture;
  }

  @override
  Future<List<UserStory>> getStories() async {
    getStoriesCalls += 1;
    _throwIfConfigured();

    return stories;
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    getStoryCalls += 1;
    receivedStoryId = storyId;
    _throwIfConfigured();

    return userStoryFixture;
  }

  @override
  Future<UserStory> updateStory(
    String storyId,
    UpdateStoryRemoteRequest request,
  ) async {
    updateStoryCalls += 1;
    receivedUpdateStoryId = storyId;
    receivedUpdateRequest = request;
    _throwIfConfigured();

    return userStoryFixture;
  }

  void _throwIfConfigured() {
    final configuredFailure = failure;
    if (configuredFailure != null) {
      throw configuredFailure;
    }
  }
}

final class RemoteFailureCase {
  const RemoteFailureCase(this.exception, this.failure);

  final StoryRemoteException exception;
  final StoryFailure failure;
}

final class UnexpectedStoryException implements Exception {
  const UnexpectedStoryException();
}
