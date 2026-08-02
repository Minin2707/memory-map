// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Memory Map';

  @override
  String get loginHeadline => 'Every place has a story';

  @override
  String get loginDescription =>
      'Create your private map of memories and share it with the people you love.';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get loginLegalPrefix => 'By continuing, you agree to our';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfUse => 'Terms of Use';

  @override
  String get legalSeparator => 'and';

  @override
  String get authCancelled => 'Sign-in was cancelled.';

  @override
  String get googleAuthenticationUnavailable =>
      'Google sign-in is unavailable on this device.';

  @override
  String get googleAuthenticationFailed =>
      'Could not sign in with Google. Please try again.';

  @override
  String get backendUnauthorized =>
      'Authentication was rejected. Please try again.';

  @override
  String get requestValidationFailed =>
      'The request was invalid. Please try again.';

  @override
  String get networkUnavailable =>
      'No network connection. Check your connection and try again.';

  @override
  String get requestTimedOut => 'The request timed out. Please try again.';

  @override
  String get serverFailure =>
      'The server is temporarily unavailable. Please try again.';

  @override
  String get secureStorageFailure =>
      'Could not securely save your session. Please try again.';

  @override
  String get corruptSession =>
      'Local session data was invalid. Please try again.';

  @override
  String get unknownAuthFailure => 'Something went wrong. Please try again.';

  @override
  String get checkingSession => 'Checking your session…';

  @override
  String get restoreSessionTitle => 'Could not restore your session';

  @override
  String get retry => 'Retry';

  @override
  String get unexpectedErrorTitle => 'Something went wrong';

  @override
  String get unexpectedErrorDescription =>
      'Please restart the app or try again.';

  @override
  String get tryAgain => 'Try again';

  @override
  String welcomeUser(String displayName) {
    return 'Welcome, $displayName';
  }

  @override
  String get fallbackDisplayName => 'friend';

  @override
  String get authenticatedSessionReady => 'Authenticated session is ready';

  @override
  String get logOut => 'Log out';

  @override
  String get loggingOut => 'Logging out…';

  @override
  String get tryLogoutAgain => 'Try to log out again';

  @override
  String storiesGreeting(String displayName) {
    return 'Hi, $displayName! 👋';
  }

  @override
  String get storiesSubtitle => 'Your shared memories live here';

  @override
  String get storiesSectionTitle => 'Your stories';

  @override
  String get storiesCreateAction => 'Create story';

  @override
  String get storiesEmptyTitle => 'No stories yet';

  @override
  String get storiesEmptyDescription =>
      'Create your first story and save important moments together';

  @override
  String get storiesLoadFailureTitle => 'Could not load stories';

  @override
  String get storiesRefreshFailureTitle => 'Could not refresh stories';

  @override
  String get storyFailureValidation =>
      'The request was invalid. Please try again.';

  @override
  String get storyFailureUnauthorized =>
      'Your session needs attention. Please try again.';

  @override
  String get storyFailureNotFound => 'Story is unavailable.';

  @override
  String get storyFailureNetworkUnavailable =>
      'No network connection. Check your connection and try again.';

  @override
  String get storyFailureRequestTimedOut =>
      'The request timed out. Please try again.';

  @override
  String get storyFailureServerFailure =>
      'The server is temporarily unavailable. Please try again.';

  @override
  String get storyFailureUnknown => 'Something went wrong. Please try again.';

  @override
  String get storyRoleOwner => 'Owner';

  @override
  String get storyRoleCoOwner => 'Co-owner';

  @override
  String get storyRoleEditor => 'Editor';

  @override
  String get storyRoleViewer => 'Viewer';

  @override
  String get storiesNotificationUnavailableLabel =>
      'Notifications are not available yet';

  @override
  String storiesAvatarLabel(String displayName) {
    return '$displayName\'s avatar';
  }

  @override
  String storiesOpenStoryLabel(String title) {
    return 'Open story $title';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get createStoryPageTitle => 'Create story';

  @override
  String get createStoryBackLabel => 'Back to stories';

  @override
  String get createStoryHeroTitle => 'New story';

  @override
  String get createStoryHeroSubtitle =>
      'Create a space for your shared memories';

  @override
  String get createStoryTitleLabel => 'Story title';

  @override
  String get createStoryTitleHint => 'Example: Our story';

  @override
  String get createStoryTitleHelp =>
      'The title will be visible to every story participant';

  @override
  String get createStoryTitleRequired => 'Enter a story title.';

  @override
  String get createStoryTitleBlank => 'Story title cannot be blank.';

  @override
  String get createStoryDescriptionLabel => 'Description';

  @override
  String get createStoryDescriptionOptional => 'optional';

  @override
  String get createStoryDescriptionHint => 'Add a short note about this story';

  @override
  String get createStoryWhyTitle => 'Why does a title matter?';

  @override
  String get createStoryWhyDescription =>
      'A good title helps everyone remember what makes this story special.';

  @override
  String get createStoryIdeasTitle => 'Title ideas';

  @override
  String get createStoryIdeaOne => 'Our story';

  @override
  String get createStoryIdeaTwo => 'Best moments together';

  @override
  String get createStoryIdeaThree => 'Travels and adventures';

  @override
  String get createStorySubmitButton => 'Create story';

  @override
  String get createStoryCreatingButton => 'Creating story...';

  @override
  String get storyDetailsPageTitle => 'Story';

  @override
  String get storyDetailsBackLabel => 'Back to stories';

  @override
  String get storyDetailsEditAction => 'Edit story';

  @override
  String get storyDetailsLoadFailureTitle => 'Could not load story';

  @override
  String get storyDetailsDescriptionTitle => 'About this story';

  @override
  String get storyDetailsNoDescription => 'No description yet.';

  @override
  String get storyDetailsInfoTitle => 'Story info';

  @override
  String get storyDetailsCreatedLabel => 'Created';

  @override
  String get storyDetailsUpdatedLabel => 'Updated';

  @override
  String get storyDetailsRefreshFailureTitle => 'Could not refresh story';

  @override
  String get storyDetailsSectionsTitle => 'Explore';

  @override
  String get storyDetailsMemoriesAction => 'Memories';

  @override
  String get storyDetailsParticipantsAction => 'Participants';

  @override
  String get storyDetailsMapAction => 'Map';

  @override
  String get editStoryPageTitle => 'Edit story';

  @override
  String get editStoryBackLabel => 'Back to story';

  @override
  String get editStoryHeroTitle => 'Story details';

  @override
  String get editStoryHeroSubtitle =>
      'Update the name and note shown to story participants';

  @override
  String get editStoryTitleLabel => 'Story title';

  @override
  String get editStoryTitleHint => 'Example: Our story';

  @override
  String get editStoryTitleHelp =>
      'The title remains visible to every story participant';

  @override
  String get editStoryTitleRequired => 'Enter a story title.';

  @override
  String get editStoryTitleBlank => 'Story title cannot be blank.';

  @override
  String get editStoryDescriptionLabel => 'Description';

  @override
  String get editStoryDescriptionOptional => 'optional';

  @override
  String get editStoryDescriptionHint => 'Add a short note about this story';

  @override
  String get editStoryDescriptionHelp =>
      'Clear the field to remove the existing description';

  @override
  String get editStorySaveButton => 'Save changes';

  @override
  String get editStorySavingButton => 'Saving changes...';

  @override
  String get editStoryNoChangesHint => 'Make a change to save.';

  @override
  String get editStoryUnavailableTitle => 'Editing is unavailable';

  @override
  String get editStoryUnavailableDescription =>
      'This story cannot be edited from here.';

  @override
  String get editStoryUnavailableBackAction => 'Back to story';
}
