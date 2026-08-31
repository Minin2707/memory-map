import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
import 'package:memory_map/features/story/application/story_application_exception.dart';
import 'package:memory_map/features/story/application/story_application_providers.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';
import 'package:memory_map/features/story/domain/story_repository.dart';
import 'package:memory_map/features/story/domain/story_role.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/features/story/presentation/edit_story_route.dart';
import 'package:memory_map/features/story/presentation/edit_story_screen.dart';
import 'package:memory_map/l10n/app_localizations.dart';

import '../../media/media_test_fixtures.dart' as media_fixtures;

void main() {
  group('EditStoryScreen rendering', () {
    testWidgets('shouldRenderEnglishContentAndPrefilledValues', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, FakeStoryRepository(), userStory: ownerStory);

      expect(find.text('Edit story'), findsOneWidget);
      expect(find.text('Story details'), findsOneWidget);
      expect(find.text('Cover'), findsOneWidget);
      expect(find.text('No cover photo'), findsOneWidget);
      expect(find.text('Choose cover'), findsOneWidget);
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
      expect(find.text('Обложка'), findsOneWidget);
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

  group('EditStoryScreen cover rendering', () {
    testWidgets('shouldRenderNoCoverPlaceholderAndChooseAction', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, FakeStoryRepository(), userStory: ownerStory);

      expect(
        find.byKey(const ValueKey('edit-story.cover.no-photo')),
        findsOneWidget,
      );
      expect(find.text('Choose cover'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('edit-story.cover.remove-action')),
        findsNothing,
      );
    });

    testWidgets('shouldRenderAutomaticFallbackWithoutRemoveAction', (
      WidgetTester tester,
    ) async {
      final mediaRepository = media_fixtures.FakeMediaRepository();
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        userStory: userStory(previewPhoto: automaticPreview),
        mediaRepository: mediaRepository,
      );

      final image = tester.widget<AuthenticatedMediaPathImage>(
        find.byKey(
          ValueKey(
            'edit-story.cover-image.${automaticPreview.displayPath}',
          ),
        ),
      );
      expect(image.thumbnailPath, automaticPreview.displayPath);
      expect(image.representation, AuthenticatedMediaRepresentation.display);
      expect(mediaRepository.receivedBinaryPaths, <String>[
        automaticPreview.displayPath,
      ]);
      expect(find.text('Change cover'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('edit-story.cover.remove-action')),
        findsNothing,
      );
    });

    testWidgets('shouldRenderExplicitCoverWithRemoveAction', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        FakeStoryRepository(),
        userStory: userStory(previewPhoto: explicitCoverPreview),
        mediaRepository: media_fixtures.FakeMediaRepository(),
      );

      expect(
        find.byKey(
          ValueKey(
            'edit-story.cover-image.${explicitCoverPreview.displayPath}',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Change cover'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('edit-story.cover.remove-action')),
        findsOneWidget,
      );
    });
  });

  group('EditStoryScreen cover mutations', () {
    testWidgets('shouldQuietlyReturnWhenGallerySelectionIsCancelled', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository();
      final gateway = media_fixtures.FakePhotoSelectionGateway()
        ..selectedPhotoResult = null;
      final preprocessor = media_fixtures.FakePhotoPreprocessor();
      await pumpScreen(
        tester,
        repository,
        userStory: ownerStory,
        photoSelectionGateway: gateway,
        photoPreprocessor: preprocessor,
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cover.choose-action')),
      );

      expect(gateway.selectPhotoCalls, 1);
      expect(preprocessor.processCalls, 0);
      expect(repository.uploadCoverCalls, 0);
      expect(find.textContaining('Something went wrong'), findsNothing);
    });

    testWidgets('shouldUploadPreparedPhotoAndRefreshAuthoritativeCover', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..storyResult = userStory(previewPhoto: automaticPreview)
        ..uploadCoverResult = userStory(previewPhoto: explicitCoverPreview);
      final gateway = media_fixtures.FakePhotoSelectionGateway();
      final preprocessor = media_fixtures.FakePhotoPreprocessor()
        ..result = media_fixtures.preparedPhotoUpload(bytes: <int>[7, 8, 9]);
      await pumpRoute(
        tester,
        repository,
        initialUserStory: userStory(previewPhoto: automaticPreview),
        photoSelectionGateway: gateway,
        photoPreprocessor: preprocessor,
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cover.choose-action')),
      );

      expect(gateway.selectPhotoCalls, 1);
      expect(preprocessor.processCalls, 1);
      expect(repository.uploadCoverCalls, 1);
      expect(repository.receivedUploadCoverStoryId, defaultStoryId);
      expect(repository.receivedUploadCoverPhoto?.bytes, <int>[7, 8, 9]);
      expect(
        find.byKey(
          ValueKey(
            'edit-story.cover-image.${explicitCoverPreview.displayPath}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('edit-story.cover.remove-action')),
        findsOneWidget,
      );
      expect(find.text('Cover updated'), findsOneWidget);
      expect(
        find.text('Cover changes are saved automatically.'),
        findsOneWidget,
      );
      expect(
        buttonOnPressed(
          tester,
          find.byKey(const ValueKey('edit-story.save-action')),
        ),
        isNull,
      );
    });

    testWidgets('shouldRemoveExplicitCoverAndShowAutomaticFallback', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..storyResult = userStory(previewPhoto: explicitCoverPreview)
        ..removeCoverResult = userStory(previewPhoto: automaticPreview);
      await pumpRoute(
        tester,
        repository,
        initialUserStory: userStory(previewPhoto: explicitCoverPreview),
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cover.remove-action')),
      );

      expect(repository.removeCoverCalls, 1);
      expect(repository.receivedRemoveCoverStoryId, defaultStoryId);
      expect(
        find.byKey(
          ValueKey(
            'edit-story.cover-image.${automaticPreview.displayPath}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('edit-story.cover.remove-action')),
        findsNothing,
      );
      expect(find.text('Cover removed'), findsOneWidget);
      expect(
        find.text('Cover changes are saved automatically.'),
        findsOneWidget,
      );
      expect(
        buttonOnPressed(
          tester,
          find.byKey(const ValueKey('edit-story.save-action')),
        ),
        isNull,
      );
    });

    testWidgets('shouldRemoveExplicitCoverAndShowNoCoverState', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..storyResult = userStory(previewPhoto: explicitCoverPreview)
        ..removeCoverResult = userStory();
      await pumpRoute(
        tester,
        repository,
        initialUserStory: userStory(previewPhoto: explicitCoverPreview),
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cover.remove-action')),
      );

      expect(
        find.byKey(const ValueKey('edit-story.cover.no-photo')),
        findsOneWidget,
      );
      expect(find.text('Choose cover'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('edit-story.cover.remove-action')),
        findsNothing,
      );
      expect(find.text('Cover removed'), findsOneWidget);
      expect(
        find.text('Cover changes are saved automatically.'),
        findsOneWidget,
      );
      expect(
        buttonOnPressed(
          tester,
          find.byKey(const ValueKey('edit-story.save-action')),
        ),
        isNull,
      );
    });

    testWidgets('shouldDisableCoverActionsWhileUploadIsPending', (
      WidgetTester tester,
    ) async {
      final completer = Completer<UserStory>();
      final repository = FakeStoryRepository()
        ..storyResult = userStory(previewPhoto: explicitCoverPreview)
        ..uploadCoverCompleter = completer;
      await pumpRoute(
        tester,
        repository,
        initialUserStory: userStory(previewPhoto: explicitCoverPreview),
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cover.choose-action')),
        settle: false,
      );
      await tester.pump();
      await tester.pump();
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cover.choose-action')),
        settle: false,
      );

      expect(find.text('Updating cover...'), findsOneWidget);
      expect(
        buttonOnPressed(
          tester,
          find.byKey(const ValueKey('edit-story.cover.choose-action')),
        ),
        isNull,
      );
      expect(
        buttonOnPressed(
          tester,
          find.byKey(const ValueKey('edit-story.cover.remove-action')),
        ),
        isNull,
      );
      expect(repository.uploadCoverCalls, 1);

      completer.complete(userStory(previewPhoto: explicitCoverPreviewV2));
      await tester.pumpAndSettle();
    });

    testWidgets('shouldDisableCoverActionsWhileRemoveIsPending', (
      WidgetTester tester,
    ) async {
      final completer = Completer<UserStory>();
      final repository = FakeStoryRepository()
        ..storyResult = userStory(previewPhoto: explicitCoverPreview)
        ..removeCoverCompleter = completer;
      await pumpRoute(
        tester,
        repository,
        initialUserStory: userStory(previewPhoto: explicitCoverPreview),
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cover.remove-action')),
        settle: false,
      );
      await tester.pump();
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cover.remove-action')),
        settle: false,
      );

      expect(find.text('Removing cover...'), findsOneWidget);
      expect(
        buttonOnPressed(
          tester,
          find.byKey(const ValueKey('edit-story.cover.choose-action')),
        ),
        isNull,
      );
      expect(
        buttonOnPressed(
          tester,
          find.byKey(const ValueKey('edit-story.cover.remove-action')),
        ),
        isNull,
      );
      expect(repository.removeCoverCalls, 1);

      completer.complete(userStory(previewPhoto: automaticPreview));
      await tester.pumpAndSettle();
    });

    testWidgets('shouldKeepPreviewAndShowUploadFailure', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..storyResult = userStory(previewPhoto: automaticPreview)
        ..uploadCoverFailure = const StoryApplicationException(
          StoryNetworkUnavailable(),
        );
      await pumpRoute(
        tester,
        repository,
        initialUserStory: userStory(previewPhoto: automaticPreview),
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cover.choose-action')),
      );

      expect(
        find.byKey(
          ValueKey(
            'edit-story.cover-image.${automaticPreview.displayPath}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text('No network connection. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('Cover updated'), findsNothing);
      expect(
        find.text('Cover changes are saved automatically.'),
        findsNothing,
      );
      expect(find.textContaining('StoryApplicationException'), findsNothing);
    });

    testWidgets('shouldKeepPreviewAndShowRemoveFailure', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..storyResult = userStory(previewPhoto: explicitCoverPreview)
        ..removeCoverFailure = const StoryApplicationException(
          StoryNetworkUnavailable(),
        );
      await pumpRoute(
        tester,
        repository,
        initialUserStory: userStory(previewPhoto: explicitCoverPreview),
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cover.remove-action')),
      );

      expect(
        find.byKey(
          ValueKey(
            'edit-story.cover-image.${explicitCoverPreview.displayPath}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('edit-story.cover.remove-action')),
        findsOneWidget,
      );
      expect(
        find.text('No network connection. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('Cover removed'), findsNothing);
      expect(
        find.text('Cover changes are saved automatically.'),
        findsNothing,
      );
    });

    testWidgets('shouldKeepMetadataSaveEnabledAfterCoverSuccessWhenDirty', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..storyResult = userStory(previewPhoto: automaticPreview)
        ..uploadCoverResult = userStory(previewPhoto: explicitCoverPreview);
      await pumpRoute(
        tester,
        repository,
        initialUserStory: userStory(previewPhoto: automaticPreview),
      );

      await tester.enterText(
        find.byKey(const ValueKey('edit-story.title-field')),
        'Updated story',
      );
      await tester.pump();
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cover.choose-action')),
      );

      expect(find.text('Cover updated'), findsOneWidget);
      expect(
        find.text('Cover changes are saved automatically.'),
        findsNothing,
      );
      expect(
        buttonOnPressed(
          tester,
          find.byKey(const ValueKey('edit-story.save-action')),
        ),
        isNotNull,
      );
    });

    testWidgets('shouldClearPreviousCoverFeedbackBeforeNextFailedMutation', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository()
        ..storyResult = userStory(previewPhoto: automaticPreview)
        ..uploadCoverResult = userStory(previewPhoto: explicitCoverPreview);
      await pumpRoute(
        tester,
        repository,
        initialUserStory: userStory(previewPhoto: automaticPreview),
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cover.choose-action')),
      );

      expect(find.text('Cover updated'), findsOneWidget);
      expect(
        find.text('Cover changes are saved automatically.'),
        findsOneWidget,
      );

      repository.uploadCoverFailure = const StoryApplicationException(
        StoryNetworkUnavailable(),
      );
      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cover.choose-action')),
      );

      expect(find.text('Cover updated'), findsNothing);
      expect(
        find.text('Cover changes are saved automatically.'),
        findsNothing,
      );
      expect(
        find.text('No network connection. Check your connection and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('shouldShowPreprocessingFailureWithoutUpload', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository();
      final preprocessor = media_fixtures.FakePhotoPreprocessor()
        ..failure = const MediaApplicationException(
          MediaPreprocessingFailure(),
        );
      await pumpScreen(
        tester,
        repository,
        userStory: ownerStory,
        photoPreprocessor: preprocessor,
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cover.choose-action')),
      );

      expect(preprocessor.processCalls, 1);
      expect(repository.uploadCoverCalls, 0);
      expect(
        find.text('Could not prepare this photo. Choose another image.'),
        findsOneWidget,
      );
      expect(find.textContaining('MediaApplicationException'), findsNothing);
    });

    testWidgets('shouldShowSelectionFailureWithoutPreprocessOrUpload', (
      WidgetTester tester,
    ) async {
      final repository = FakeStoryRepository();
      final gateway = media_fixtures.FakePhotoSelectionGateway()
        ..failure = const MediaApplicationException(MediaUnavailable());
      final preprocessor = media_fixtures.FakePhotoPreprocessor();
      await pumpScreen(
        tester,
        repository,
        userStory: ownerStory,
        photoSelectionGateway: gateway,
        photoPreprocessor: preprocessor,
      );

      await pressButton(
        tester,
        find.byKey(const ValueKey('edit-story.cover.choose-action')),
      );

      expect(gateway.selectPhotoCalls, 1);
      expect(preprocessor.processCalls, 0);
      expect(repository.uploadCoverCalls, 0);
      expect(find.text('Photos are unavailable.'), findsOneWidget);
      expect(find.textContaining('MediaApplicationException'), findsNothing);
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

VoidCallback? buttonOnPressed(WidgetTester tester, Finder finder) {
  final widget = tester.widget<Widget>(finder);
  return switch (widget) {
    FilledButton(:final onPressed) => onPressed,
    OutlinedButton(:final onPressed) => onPressed,
    IconButton(:final onPressed) => onPressed,
    TextButton(:final onPressed) => onPressed,
    _ => throw StateError('Unsupported button widget: $widget'),
  };
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
  media_fixtures.FakeMediaRepository? mediaRepository,
  media_fixtures.FakePhotoSelectionGateway? photoSelectionGateway,
  media_fixtures.FakePhotoPreprocessor? photoPreprocessor,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storyRepositoryProvider.overrideWithValue(repository),
        mediaRepositoryProvider.overrideWithValue(
          mediaRepository ?? media_fixtures.FakeMediaRepository(),
        ),
        photoSelectionGatewayProvider.overrideWithValue(
          photoSelectionGateway ??
              media_fixtures.FakePhotoSelectionGateway(),
        ),
        photoPreprocessorProvider.overrideWithValue(
          photoPreprocessor ?? media_fixtures.FakePhotoPreprocessor(),
        ),
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

Future<void> pumpRoute(
  WidgetTester tester,
  FakeStoryRepository repository, {
  required UserStory initialUserStory,
  Locale locale = const Locale('en'),
  ValueChanged<UserStory>? onUpdated,
  VoidCallback? onCancel,
  TextScaler textScaler = TextScaler.noScaling,
  media_fixtures.FakeMediaRepository? mediaRepository,
  media_fixtures.FakePhotoSelectionGateway? photoSelectionGateway,
  media_fixtures.FakePhotoPreprocessor? photoPreprocessor,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storyRepositoryProvider.overrideWithValue(repository),
        mediaRepositoryProvider.overrideWithValue(
          mediaRepository ?? media_fixtures.FakeMediaRepository(),
        ),
        photoSelectionGatewayProvider.overrideWithValue(
          photoSelectionGateway ??
              media_fixtures.FakePhotoSelectionGateway(),
        ),
        photoPreprocessorProvider.overrideWithValue(
          photoPreprocessor ?? media_fixtures.FakePhotoPreprocessor(),
        ),
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
        home: EditStoryRoute(
          storyId: initialUserStory.story.id,
          initialUserStory: initialUserStory,
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
  StoryPhotoPreview? previewPhoto,
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
    previewPhoto: previewPhoto,
  );
}

final UserStory ownerStory = userStory();
final UserStory updatedOwnerStory = userStory(
  title: 'Updated story',
  description: 'Updated description',
);

const String defaultStoryId = 'story-1';

final StoryPhotoPreview automaticPreview = StoryPhotoPreview(
  thumbnailPath: '/api/v1/media/media-a/thumbnail',
  displayPath: '/api/v1/media/media-a/display',
);

final StoryPhotoPreview explicitCoverPreview = StoryPhotoPreview(
  thumbnailPath: '/api/v1/stories/story-1/cover/thumbnail/111',
  displayPath: '/api/v1/stories/story-1/cover/display/111',
);

final StoryPhotoPreview explicitCoverPreviewV2 = StoryPhotoPreview(
  thumbnailPath: '/api/v1/stories/story-1/cover/thumbnail/222',
  displayPath: '/api/v1/stories/story-1/cover/display/222',
);

final class FakeStoryRepository implements StoryRepository {
  int createCalls = 0;
  int getStoriesCalls = 0;
  int getStoryCalls = 0;
  int updateStoryCalls = 0;
  int uploadCoverCalls = 0;
  int removeCoverCalls = 0;

  UpdateStoryInput? receivedInput;
  String? receivedUploadCoverStoryId;
  PreparedPhotoUpload? receivedUploadCoverPhoto;
  String? receivedRemoveCoverStoryId;
  UserStory storyResult = ownerStory;
  UserStory updateStoryResult = updatedOwnerStory;
  UserStory uploadCoverResult = userStory(previewPhoto: explicitCoverPreview);
  UserStory removeCoverResult = userStory(previewPhoto: automaticPreview);
  Object? updateStoryFailure;
  Object? uploadCoverFailure;
  Object? removeCoverFailure;
  Completer<UserStory>? updateStoryCompleter;
  Completer<UserStory>? uploadCoverCompleter;
  Completer<UserStory>? removeCoverCompleter;

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
    return storyResult;
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

  @override
  Future<UserStory> uploadStoryCover({
    required String storyId,
    required PreparedPhotoUpload photo,
  }) async {
    uploadCoverCalls += 1;
    receivedUploadCoverStoryId = storyId;
    receivedUploadCoverPhoto = photo;

    final completer = uploadCoverCompleter;
    if (completer != null) {
      uploadCoverCompleter = null;
      return completer.future;
    }

    final failure = uploadCoverFailure;
    if (failure != null) {
      throw failure;
    }

    storyResult = uploadCoverResult;
    return uploadCoverResult;
  }

  @override
  Future<UserStory> removeStoryCover({
    required String storyId,
  }) async {
    removeCoverCalls += 1;
    receivedRemoveCoverStoryId = storyId;

    final completer = removeCoverCompleter;
    if (completer != null) {
      removeCoverCompleter = null;
      return completer.future;
    }

    final failure = removeCoverFailure;
    if (failure != null) {
      throw failure;
    }

    storyResult = removeCoverResult;
    return removeCoverResult;
  }
}

final class UnexpectedStoryException implements Exception {
  const UnexpectedStoryException();
}
