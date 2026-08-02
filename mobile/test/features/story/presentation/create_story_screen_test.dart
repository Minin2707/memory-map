import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/features/story/presentation/create_story_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('CreateStoryScreen rendering', () {
    testWidgets('shouldRenderEnglishContent', (WidgetTester tester) async {
      await pumpScreen(tester, FakeStoryRepository());

      expect(find.text('Create story'), findsWidgets);
      expect(find.text('New story'), findsOneWidget);
      expect(
        find.text('Create a space for your shared memories'),
        findsOneWidget,
      );
      expect(find.text('Story title'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('optional'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('shouldRenderRussianContent', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        locale: const Locale('ru'),
      );

      expect(find.text('Создание истории'), findsOneWidget);
      expect(find.text('Новая история'), findsOneWidget);
      expect(
        find.text('Создайте пространство для ваших совместных воспоминаний'),
        findsOneWidget,
      );
      expect(find.text('Название истории'), findsOneWidget);
      expect(find.text('Описание'), findsOneWidget);
      expect(find.text('необязательно'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
    });

    testWidgets('shouldRenderBackAction', (WidgetTester tester) async {
      await pumpScreen(tester, FakeStoryRepository());

      expect(
        find.byKey(const ValueKey('create-story.back-action')),
        findsOneWidget,
      );
    });
  });

  group('CreateStoryScreen validation', () {
    testWidgets('shouldRejectEmptyTitleBeforeNotifierCall', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository();
      await pumpScreen(tester, repository);

      await tapSubmit(tester);

      expect(find.text('Enter a story title.'), findsOneWidget);
      expect(repository.createCalls, 0);
    });

    testWidgets('shouldRejectWhitespaceTitleBeforeNotifierCall', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository();
      await pumpScreen(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey('create-story.title-field')),
        '   ',
      );
      await tapSubmit(tester);

      expect(find.text('Story title cannot be blank.'), findsOneWidget);
      expect(repository.createCalls, 0);
    });

    testWidgets('shouldAcceptValidTitleWithoutNormalization', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()..createResult = createdStory;
      await pumpScreen(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey('create-story.title-field')),
        '  Our story  ',
      );
      await tapSubmit(tester);

      expect(repository.createdTitle, '  Our story  ');
    });

    testWidgets('shouldSendAbsentDescriptionAsNull', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()..createResult = createdStory;
      await pumpScreen(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey('create-story.title-field')),
        'Our story',
      );
      await tapSubmit(tester);

      expect(repository.createdDescription, isNull);
    });

    testWidgets('shouldPreserveWhitespaceDescriptionWhenEntered', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()..createResult = createdStory;
      await pumpScreen(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey('create-story.title-field')),
        'Our story',
      );
      await tester.enterText(
        find.byKey(const ValueKey('create-story.description-field')),
        '   ',
      );
      await tapSubmit(tester);

      expect(repository.createdDescription, '   ');
    });

    testWidgets('shouldSendDescriptionValueWithoutNormalization', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()..createResult = createdStory;
      await pumpScreen(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey('create-story.title-field')),
        'Our story',
      );
      await tester.enterText(
        find.byKey(const ValueKey('create-story.description-field')),
        '  Together since 2021  ',
      );
      await tapSubmit(tester);

      expect(repository.createdDescription, '  Together since 2021  ');
    });
  });

  group('CreateStoryScreen submit', () {
    testWidgets('shouldCreateStoryAndCallOnCreatedOnce', (
      WidgetTester tester,
    ) async {
      Story? callbackStory;
      var callbackCalls = 0;
      final repository = FakeStoryRepository()..createResult = createdStory;
      await pumpScreen(
        tester,
        repository,
        onCreated: (story) {
          callbackCalls += 1;
          callbackStory = story;
        },
      );

      await tester.enterText(
        find.byKey(const ValueKey('create-story.title-field')),
        'Our story',
      );
      await tester.enterText(
        find.byKey(const ValueKey('create-story.description-field')),
        'Together since 2021',
      );
      await tapSubmit(tester);

      expect(repository.operations, <String>[
        'getStories',
        'createStory',
        'getStories',
      ]);
      expect(callbackCalls, 1);
      expect(callbackStory, createdStory);
    });

    testWidgets('shouldShowLoadingAndPreventDuplicateSubmit', (
      WidgetTester tester,
    ) async {
      final createCompleter = Completer<Story>();
      final repository = FakeStoryRepository()
        ..createCompleter = createCompleter;
      await pumpScreen(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey('create-story.title-field')),
        'Our story',
      );
      await tapSubmit(tester, settle: false);
      await tester.pump();
      await tapSubmit(tester, settle: false);

      expect(find.text('Creating story...'), findsOneWidget);
      expect(repository.createCalls, 1);

      createCompleter.complete(createdStory);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldCallOnCreatedWhenReloadFailsAfterCreateSuccess', (
      WidgetTester tester,
    ) async {
      Story? callbackStory;
      final repository = FakeStoryRepository()
        ..createResult = createdStory;
      await pumpScreen(
        tester,
        repository,
        onCreated: (story) {
          callbackStory = story;
        },
      );
      repository.getStoriesFailures.add(
        const StoryApplicationException(StoryNetworkUnavailable()),
      );

      await tester.enterText(
        find.byKey(const ValueKey('create-story.title-field')),
        'Our story',
      );
      await tapSubmit(tester);

      expect(callbackStory, createdStory);
      expect(
        find.text('No network connection. Check your connection and try again.'),
        findsNothing,
      );
    });
  });

  group('CreateStoryScreen failures', () {
    testWidgets('shouldRenderKnownFailureAndPreserveFields', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..createFailure = const StoryApplicationException(
          StoryValidationFailure(),
        );
      Story? callbackStory;
      await pumpScreen(
        tester,
        repository,
        onCreated: (story) {
          callbackStory = story;
        },
      );

      await tester.enterText(
        find.byKey(const ValueKey('create-story.title-field')),
        'Our story',
      );
      await tester.enterText(
        find.byKey(const ValueKey('create-story.description-field')),
        'Together',
      );
      await tapSubmit(tester);

      expect(
        find.text('The request was invalid. Please try again.'),
        findsOneWidget,
      );
      expect(
        textFieldValue(
          tester,
          find.byKey(const ValueKey('create-story.title-field')),
        ),
        'Our story',
      );
      expect(
        textFieldValue(
          tester,
          find.byKey(const ValueKey('create-story.description-field')),
        ),
        'Together',
      );
      expect(callbackStory, isNull);
      expect(find.textContaining('StoryApplicationException'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
    });

    testWidgets('shouldRenderUnexpectedFailureSafely', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..createFailure = const UnexpectedStoryException();
      await pumpScreen(tester, repository);

      await tester.enterText(
        find.byKey(const ValueKey('create-story.title-field')),
        'Our story',
      );
      await tapSubmit(tester);

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('UnexpectedStoryException'), findsNothing);
      expect(find.textContaining('StackTrace'), findsNothing);
    });
  });

  group('CreateStoryScreen cancel and responsiveness', () {
    testWidgets('shouldCallCancelFromBackAction', (
      WidgetTester tester,
    ) async {
      var cancelCalls = 0;
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        onCancel: () {
          cancelCalls += 1;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('create-story.back-action')),
      );

      expect(cancelCalls, 1);
    });

    testWidgets('shouldCallCancelFromCancelButton', (
      WidgetTester tester,
    ) async {
      var cancelCalls = 0;
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        onCancel: () {
          cancelCalls += 1;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('create-story.cancel-action')),
      );

      expect(cancelCalls, 1);
    });

    testWidgets('shouldCallCancelFromSystemBack', (
      WidgetTester tester,
    ) async {
      var cancelCalls = 0;
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        onCancel: () {
          cancelCalls += 1;
        },
      );

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(cancelCalls, 1);
    });

    testWidgets('shouldDisableCancelActionsDuringCreate', (
      WidgetTester tester,
    ) async {
      final createCompleter = Completer<Story>();
      final repository = FakeStoryRepository()
        ..createCompleter = createCompleter;
      var cancelCalls = 0;
      await pumpScreen(
        tester,
        repository,
        onCancel: () {
          cancelCalls += 1;
        },
      );

      await tester.enterText(
        find.byKey(const ValueKey('create-story.title-field')),
        'Our story',
      );
      await tapSubmit(tester, settle: false);
      await tester.pump();
      await pressButton(
        tester,
        find.byKey(const ValueKey('create-story.cancel-action')),
        settle: false,
      );
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(cancelCalls, 0);

      createCompleter.complete(createdStory);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldNotOverflowOnSmallPhoneWithLargeText', (
      WidgetTester tester,
    ) async {
      setSurface(tester, const Size(360, 640));

      await pumpScreen(
        tester,
        FakeStoryRepository(),
        textScaler: const TextScaler.linear(1.3),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('shouldNotExposeConfidentialOrInfrastructureText', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, FakeStoryRepository());

      expect(find.textContaining('accessToken'), findsNothing);
      expect(find.textContaining('refreshToken'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('raw response'), findsNothing);
      expect(find.textContaining('ownerId'), findsNothing);
      expect(find.textContaining('userId'), findsNothing);
      expect(find.textContaining(createdStory.id), findsNothing);
    });
  });
}

Future<void> tapSubmit(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await pressButton(
    tester,
    find.byKey(const ValueKey('create-story.submit-action')),
    settle: settle,
  );
}

Future<void> pressButton(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  final widget = tester.widget<Widget>(finder);
  final onPressed = switch (widget) {
    FilledButton(:final onPressed) => onPressed,
    OutlinedButton(:final onPressed) => onPressed,
    IconButton(:final onPressed) => onPressed,
    _ => throw StateError('Unsupported button widget: $widget'),
  };

  onPressed?.call();

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

String textFieldValue(WidgetTester tester, Finder finder) {
  return tester.widget<TextFormField>(finder).controller?.text ?? '';
}

Future<void> pumpScreen(
  WidgetTester tester,
  FakeStoryRepository repository, {
  Locale locale = const Locale('en'),
  ValueChanged<Story>? onCreated,
  VoidCallback? onCancel,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storyRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: CreateStoryScreen(
          onCancel: onCancel,
          onCreated: onCreated,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Story story({
  String id = 'created-story-id',
  String title = 'Created story',
  String? description = 'Created description',
}) {
  return Story(
    id: id,
    title: title,
    description: description,
    createdAt: DateTime.utc(2026, 2),
    updatedAt: DateTime.utc(2026, 2, 2),
  );
}

UserStory userStory({
  String id = 'story-1',
  String title = 'First story',
  String? description = 'First description',
  StoryRole role = StoryRole.owner,
}) {
  return UserStory(
    story: Story(
      id: id,
      title: title,
      description: description,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
    role: role,
  );
}

final Story createdStory = story();
final UserStory existingStory = userStory();

final class FakeStoryRepository implements StoryRepository {
  int createCalls = 0;
  int getStoriesCalls = 0;
  int getStoryCalls = 0;
  int updateStoryCalls = 0;

  String? createdTitle;
  String? createdDescription;
  Story? createResult;
  Object? createFailure;
  Completer<Story>? createCompleter;
  List<UserStory> storiesResult = <UserStory>[existingStory];
  final List<Object> getStoriesFailures = <Object>[];
  final List<String> operations = <String>[];

  @override
  Future<Story> createStory({
    required String title,
    String? description,
  }) async {
    createCalls += 1;
    createdTitle = title;
    createdDescription = description;
    operations.add('createStory');

    final completer = createCompleter;
    if (completer != null) {
      createCompleter = null;
      return completer.future;
    }

    final failure = createFailure;
    if (failure != null) {
      throw failure;
    }

    return createResult ?? createdStory;
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    getStoryCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<List<UserStory>> getStories() async {
    getStoriesCalls += 1;
    operations.add('getStories');

    if (getStoriesFailures.isNotEmpty) {
      throw getStoriesFailures.removeAt(0);
    }

    return storiesResult;
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) async {
    updateStoryCalls += 1;
    throw UnimplementedError();
  }
}

final class UnexpectedStoryException implements Exception {
  const UnexpectedStoryException();
}
