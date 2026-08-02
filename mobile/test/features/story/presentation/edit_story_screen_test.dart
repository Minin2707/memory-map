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
import 'package:memory_map/features/story/presentation/edit_story_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

void main() {
  group('EditStoryScreen rendering', () {
    testWidgets('shouldRenderEnglishContentAndPrefilledValues', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, FakeStoryRepository(), userStory: ownerStory);

      expect(find.text('Edit story'), findsOneWidget);
      expect(find.text('Story details'), findsOneWidget);
      expect(find.text('Story title'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('optional'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(
        textFieldValue(
          tester,
          find.byKey(const ValueKey('edit-story.title-field')),
        ),
        ownerStory.story.title,
      );
      expect(
        textFieldValue(
          tester,
          find.byKey(const ValueKey('edit-story.description-field')),
        ),
        ownerStory.story.description,
      );
    });

    testWidgets('shouldRenderRussianContent', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        userStory: ownerStory,
        locale: const Locale('ru'),
      );

      expect(find.text('Редактирование истории'), findsOneWidget);
      expect(find.text('Детали истории'), findsOneWidget);
      expect(find.text('Название истории'), findsOneWidget);
      expect(find.text('Описание'), findsOneWidget);
      expect(find.text('Сохранить изменения'), findsOneWidget);
    });

    testWidgets('shouldPrefillNullDescriptionAsEmptyField', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        userStory: userStory(description: null),
      );

      expect(
        textFieldValue(
          tester,
          find.byKey(const ValueKey('edit-story.description-field')),
        ),
        '',
      );
    });
  });

  group('EditStoryScreen role capability', () {
    testWidgets('shouldAllowOwnerAndCoOwnerToEdit', (WidgetTester tester) async {
      for (final role in <StoryRole>[StoryRole.owner, StoryRole.coOwner]) {
        await pumpScreen(
          tester,
          FakeStoryRepository(),
          userStory: userStory(role: role),
        );

        expect(
          find.byKey(const ValueKey('edit-story.title-field')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('edit-story.save-action')),
          findsOneWidget,
        );
      }
    });

    testWidgets('shouldShowUnavailableStateForEditorAndViewer', (
      WidgetTester tester,
    ) async {
      for (final role in <StoryRole>[StoryRole.editor, StoryRole.viewer]) {
        final repository = FakeStoryRepository();
        await pumpScreen(
          tester,
          repository,
          userStory: userStory(role: role),
        );

        expect(find.text('Editing is unavailable'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('edit-story.title-field')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('edit-story.save-action')),
          findsNothing,
        );
        expect(repository.updateStoryCalls, 0);
      }
    });
  });

  group('EditStoryScreen partial diff', () {
    testWidgets('shouldSendTitleOnlyUpdate', (WidgetTester tester) async {
      final repository = FakeStoryRepository()
        ..updateStoryResult = updatedOwnerStory;
      await pumpScreen(tester, repository, userStory: ownerStory);

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.title-field')),
        'Updated story',
      );
      await tapSave(tester);

      expect(repository.receivedInput?.title.isProvided, isTrue);
      expect(repository.receivedInput?.title.value, 'Updated story');
      expect(repository.receivedInput?.description.isProvided, isFalse);
    });

    testWidgets('shouldSendDescriptionOnlyUpdate', (WidgetTester tester) async {
      final repository = FakeStoryRepository()
        ..updateStoryResult = updatedOwnerStory;
      await pumpScreen(tester, repository, userStory: ownerStory);

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.description-field')),
        'Updated description',
      );
      await tapSave(tester);

      expect(repository.receivedInput?.title.isProvided, isFalse);
      expect(repository.receivedInput?.description.isProvided, isTrue);
      expect(
        repository.receivedInput?.description.value,
        'Updated description',
      );
    });

    testWidgets('shouldKeepOriginalNullDescriptionWhenFieldStaysEmpty', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository();
      await pumpScreen(
        tester,
        repository,
        userStory: userStory(description: null),
      );

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.title-field')),
        'Updated story',
      );
      await tapSave(tester);

      expect(repository.receivedInput?.title.isProvided, isTrue);
      expect(repository.receivedInput?.description.isProvided, isFalse);
    });

    testWidgets('shouldSendDescriptionForOriginalNullWhenTextIsEntered', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository();
      await pumpScreen(
        tester,
        repository,
        userStory: userStory(description: null),
      );

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.description-field')),
        'New description',
      );
      await tapSave(tester);

      expect(repository.receivedInput?.title.isProvided, isFalse);
      expect(repository.receivedInput?.description.isProvided, isTrue);
      expect(repository.receivedInput?.description.value, 'New description');
    });

    testWidgets('shouldKeepOriginalEmptyDescriptionWhenFieldStaysEmpty', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository();
      await pumpScreen(
        tester,
        repository,
        userStory: userStory(description: ''),
      );

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.title-field')),
        'Updated story',
      );
      await tapSave(tester);

      expect(repository.receivedInput?.description.isProvided, isFalse);
    });

    testWidgets('shouldClearOriginalNonEmptyDescriptionWhenFieldIsEmptied', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository();
      await pumpScreen(tester, repository, userStory: ownerStory);

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.description-field')),
        '',
      );
      await tapSave(tester);

      expect(repository.receivedInput?.title.isProvided, isFalse);
      expect(repository.receivedInput?.description.isProvided, isTrue);
      expect(repository.receivedInput?.description.value, isNull);
    });

    testWidgets('shouldPreserveWhitespaceDescriptionAsValue', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository();
      await pumpScreen(tester, repository, userStory: ownerStory);

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.description-field')),
        '   ',
      );
      await tapSave(tester);

      expect(repository.receivedInput?.description.value, '   ');
    });

    testWidgets('shouldSendBothChangedFields', (WidgetTester tester) async {
      final repository = FakeStoryRepository();
      await pumpScreen(tester, repository, userStory: ownerStory);

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.title-field')),
        'Updated story',
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-story.description-field')),
        'Updated description',
      );
      await tapSave(tester);

      expect(repository.receivedInput?.title.value, 'Updated story');
      expect(repository.receivedInput?.description.value, 'Updated description');
    });

    testWidgets('shouldDisableSaveAndSkipNetworkWhenNothingChanged', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository();
      await pumpScreen(tester, repository, userStory: ownerStory);

      await tapSave(tester);

      expect(find.text('Make a change to save.'), findsOneWidget);
      expect(repository.updateStoryCalls, 0);
    });
  });

  group('EditStoryScreen validation', () {
    testWidgets('shouldRejectEmptyTitleBeforeRepositoryCall', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository();
      await pumpScreen(tester, repository, userStory: ownerStory);

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.title-field')),
        '',
      );
      await tapSave(tester);

      expect(find.text('Enter a story title.'), findsOneWidget);
      expect(repository.updateStoryCalls, 0);
    });

    testWidgets('shouldRejectWhitespaceTitleBeforeRepositoryCall', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository();
      await pumpScreen(tester, repository, userStory: ownerStory);

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.title-field')),
        '   ',
      );
      await tapSave(tester);

      expect(find.text('Story title cannot be blank.'), findsOneWidget);
      expect(repository.updateStoryCalls, 0);
    });
  });

  group('EditStoryScreen save outcomes', () {
    testWidgets('shouldCallOnUpdatedWithExactBackendResultOnce', (
      WidgetTester tester,
    ) async {
      UserStory? callbackStory;
      var callbackCalls = 0;
      final repository = FakeStoryRepository()
        ..updateStoryResult = updatedOwnerStory;
      await pumpScreen(
        tester,
        repository,
        userStory: ownerStory,
        onUpdated: (userStory) {
          callbackCalls += 1;
          callbackStory = userStory;
        },
      );

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.title-field')),
        'Updated story',
      );
      await tapSave(tester);

      expect(callbackCalls, 1);
      expect(callbackStory, updatedOwnerStory);
      expect(callbackStory?.role, updatedOwnerStory.role);
    });

    testWidgets('shouldShowLoadingAndPreventDuplicateSave', (
      WidgetTester tester,
    ) async {
      final completer = Completer<UserStory>();
      final repository = FakeStoryRepository()
        ..updateStoryCompleter = completer;
      await pumpScreen(tester, repository, userStory: ownerStory);

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.title-field')),
        'Updated story',
      );
      await tapSave(tester, settle: false);
      await tester.pump();
      await tapSave(tester, settle: false);

      expect(find.text('Saving changes...'), findsOneWidget);
      expect(repository.updateStoryCalls, 1);

      completer.complete(updatedOwnerStory);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldRenderKnownFailureAndPreserveFields', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..updateStoryFailure =
            const StoryApplicationException(StoryNetworkUnavailable());
      await pumpScreen(tester, repository, userStory: ownerStory);

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.title-field')),
        'Updated story',
      );
      await tapSave(tester);

      expect(
        find.text('No network connection. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(
        textFieldValue(
          tester,
          find.byKey(const ValueKey('edit-story.title-field')),
        ),
        'Updated story',
      );
      expect(find.textContaining('StoryApplicationException'), findsNothing);
    });

    testWidgets('shouldRenderUnexpectedFailureSafely', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..updateStoryFailure = const UnexpectedStoryException();
      await pumpScreen(tester, repository, userStory: ownerStory);

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.title-field')),
        'Updated story',
      );
      await tapSave(tester);

      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('UnexpectedStoryException'), findsNothing);
    });
  });

  group('EditStoryScreen back and security', () {
    testWidgets('shouldCallCancelFromAppBarCancelButtonAndSystemBack', (
      WidgetTester tester,
    ) async {
      var cancelCalls = 0;
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        userStory: ownerStory,
        onCancel: () {
          cancelCalls += 1;
        },
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.back-action')),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cancel-action')),
      );
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(cancelCalls, 3);
    });

    testWidgets('shouldBlockBackAndCancelDuringSave', (
      WidgetTester tester,
    ) async {
      final completer = Completer<UserStory>();
      var cancelCalls = 0;
      final repository = FakeStoryRepository()
        ..updateStoryCompleter = completer;
      await pumpScreen(
        tester,
        repository,
        userStory: ownerStory,
        onCancel: () {
          cancelCalls += 1;
        },
      );

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.title-field')),
        'Updated story',
      );
      await tapSave(tester, settle: false);
      await tester.pump();
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.back-action')),
        settle: false,
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cancel-action')),
        settle: false,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(cancelCalls, 0);

      completer.complete(updatedOwnerStory);
      await tester.pumpAndSettle();
    });

    testWidgets('shouldHandleSmallLargeTextAndLongContentWithoutLeaks', (
      WidgetTester tester,
    ) async {
      setSurface(tester, const Size(360, 640));
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        userStory: userStory(
          id: 'private-story-id',
          title: 'A very long story title that should wrap without overflow',
          description:
              'A long private description that belongs only in editable fields.',
        ),
        textScaler: const TextScaler.linear(1.35),
      );

      expect(
        find.byKey(const ValueKey('edit-story.title-field')),
        findsOneWidget,
      );
      expect(find.textContaining('private-story-id'), findsNothing);
      expect(find.textContaining('ownerId'), findsNothing);
      expect(find.textContaining('userId'), findsNothing);
      expect(find.textContaining('accessToken'), findsNothing);
      expect(find.textContaining('refreshToken'), findsNothing);
      expect(find.textContaining('Dio'), findsNothing);
      expect(find.textContaining('raw response'), findsNothing);
    });
  });
}

Future<void> tapSave(
  WidgetTester tester, {
  bool settle = true,
}) async {
  await pressButton(
    tester,
    find.byKey(const ValueKey('edit-story.save-action')),
    settle: settle,
  );
}

Future<void> pressButton(
  WidgetTester tester,
  Finder finder, {
  bool settle = true,
}) async {
  await tester.pump();
  final widget = tester.widget<Widget>(finder);
  final onPressed = switch (widget) {
    FilledButton(:final onPressed) => onPressed,
    OutlinedButton(:final onPressed) => onPressed,
    IconButton(:final onPressed) => onPressed,
    TextButton(:final onPressed) => onPressed,
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
  required UserStory userStory,
  Locale locale = const Locale('en'),
  ValueChanged<UserStory>? onUpdated,
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
        home: EditStoryScreen(
          userStory: userStory,
          onUpdated: onUpdated,
          onCancel: onCancel,
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

UserStory userStory({
  String id = 'story-1',
  String title = 'Our story',
  String? description = 'Together since 2021',
  StoryRole role = StoryRole.owner,
}) {
  return UserStory(
    story: Story(
      id: id,
      title: title,
      description: description,
      createdAt: DateTime.utc(2026, 1),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
    role: role,
  );
}

final UserStory ownerStory = userStory();
final UserStory updatedOwnerStory = userStory(
  title: 'Updated story',
  description: 'Updated description',
);

final class FakeStoryRepository implements StoryRepository {
  int createCalls = 0;
  int getStoriesCalls = 0;
  int getStoryCalls = 0;
  int updateStoryCalls = 0;

  UpdateStoryInput? receivedInput;
  UserStory updateStoryResult = updatedOwnerStory;
  Object? updateStoryFailure;
  Completer<UserStory>? updateStoryCompleter;

  @override
  Future<Story> createStory({
    required String title,
    String? description,
  }) async {
    createCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<UserStory> getStory(String storyId) async {
    getStoryCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<List<UserStory>> getStories() async {
    getStoriesCalls += 1;
    throw UnimplementedError();
  }

  @override
  Future<UserStory> updateStory(UpdateStoryInput input) async {
    updateStoryCalls += 1;
    receivedInput = input;

    final completer = updateStoryCompleter;
    if (completer != null) {
      updateStoryCompleter = null;
      return completer.future;
    }

    final failure = updateStoryFailure;
    if (failure != null) {
      throw failure;
    }

    return updateStoryResult;
  }
}

final class UnexpectedStoryException implements Exception {
  const UnexpectedStoryException();
}
