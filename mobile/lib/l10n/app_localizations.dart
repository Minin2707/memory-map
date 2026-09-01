import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'Memory Map'**
  String get appName;

  /// No description provided for @loginHeadline.
  ///
  /// In en, this message translates to:
  /// **'Every place has a story'**
  String get loginHeadline;

  /// No description provided for @loginDescription.
  ///
  /// In en, this message translates to:
  /// **'Create your private map of memories and share it with the people you love.'**
  String get loginDescription;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @loginLegalPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you agree to our'**
  String get loginLegalPrefix;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// No description provided for @legalSeparator.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get legalSeparator;

  /// No description provided for @authCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled.'**
  String get authCancelled;

  /// No description provided for @googleAuthenticationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is unavailable on this device.'**
  String get googleAuthenticationUnavailable;

  /// No description provided for @googleAuthenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in with Google. Please try again.'**
  String get googleAuthenticationFailed;

  /// No description provided for @backendUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Authentication was rejected. Please try again.'**
  String get backendUnauthorized;

  /// No description provided for @requestValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'The request was invalid. Please try again.'**
  String get requestValidationFailed;

  /// No description provided for @networkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No network connection. Check your connection and try again.'**
  String get networkUnavailable;

  /// No description provided for @requestTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get requestTimedOut;

  /// No description provided for @serverFailure.
  ///
  /// In en, this message translates to:
  /// **'The server is temporarily unavailable. Please try again.'**
  String get serverFailure;

  /// No description provided for @secureStorageFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not securely save your session. Please try again.'**
  String get secureStorageFailure;

  /// No description provided for @corruptSession.
  ///
  /// In en, this message translates to:
  /// **'Local session data was invalid. Please try again.'**
  String get corruptSession;

  /// No description provided for @unknownAuthFailure.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get unknownAuthFailure;

  /// No description provided for @restoreSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not restore your session'**
  String get restoreSessionTitle;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @unexpectedErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get unexpectedErrorTitle;

  /// No description provided for @unexpectedErrorDescription.
  ///
  /// In en, this message translates to:
  /// **'Please restart the app or try again.'**
  String get unexpectedErrorDescription;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// Greeting shown on the authenticated home screen
  ///
  /// In en, this message translates to:
  /// **'Welcome, {displayName}'**
  String welcomeUser(String displayName);

  /// No description provided for @fallbackDisplayName.
  ///
  /// In en, this message translates to:
  /// **'friend'**
  String get fallbackDisplayName;

  /// No description provided for @authenticatedSessionReady.
  ///
  /// In en, this message translates to:
  /// **'Authenticated session is ready'**
  String get authenticatedSessionReady;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @loggingOut.
  ///
  /// In en, this message translates to:
  /// **'Logging out…'**
  String get loggingOut;

  /// No description provided for @tryLogoutAgain.
  ///
  /// In en, this message translates to:
  /// **'Try to log out again'**
  String get tryLogoutAgain;

  /// Greeting shown on the Stories screen
  ///
  /// In en, this message translates to:
  /// **'Hi, {displayName}! 👋'**
  String storiesGreeting(String displayName);

  /// No description provided for @storiesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your shared memories live here'**
  String get storiesSubtitle;

  /// No description provided for @storiesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Your stories'**
  String get storiesSectionTitle;

  /// No description provided for @storiesCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create story'**
  String get storiesCreateAction;

  /// No description provided for @storiesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No stories yet'**
  String get storiesEmptyTitle;

  /// No description provided for @storiesEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Create your first story and save important moments together'**
  String get storiesEmptyDescription;

  /// No description provided for @storiesLoadFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load stories'**
  String get storiesLoadFailureTitle;

  /// No description provided for @storiesRefreshFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh stories'**
  String get storiesRefreshFailureTitle;

  /// No description provided for @storyFailureValidation.
  ///
  /// In en, this message translates to:
  /// **'The request was invalid. Please try again.'**
  String get storyFailureValidation;

  /// No description provided for @storyFailureUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your session needs attention. Please try again.'**
  String get storyFailureUnauthorized;

  /// No description provided for @storyFailureNotFound.
  ///
  /// In en, this message translates to:
  /// **'Story is unavailable.'**
  String get storyFailureNotFound;

  /// No description provided for @storyFailureNetworkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No network connection. Check your connection and try again.'**
  String get storyFailureNetworkUnavailable;

  /// No description provided for @storyFailureRequestTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get storyFailureRequestTimedOut;

  /// No description provided for @storyFailureServerFailure.
  ///
  /// In en, this message translates to:
  /// **'The server is temporarily unavailable. Please try again.'**
  String get storyFailureServerFailure;

  /// No description provided for @storyFailureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get storyFailureUnknown;

  /// No description provided for @storyRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get storyRoleOwner;

  /// No description provided for @storyRoleCoOwner.
  ///
  /// In en, this message translates to:
  /// **'Co-owner'**
  String get storyRoleCoOwner;

  /// No description provided for @storyRoleEditor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get storyRoleEditor;

  /// No description provided for @storyRoleViewer.
  ///
  /// In en, this message translates to:
  /// **'Viewer'**
  String get storyRoleViewer;

  /// Memory count shown on a Story card
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {No memories} =1 {1 memory} other {{count} memories}}'**
  String storyMemoryCount(int count);

  /// Participant count shown on a Story card
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 participant} other {{count} participants}}'**
  String storyParticipantCount(int count);

  /// No description provided for @storyThumbnailLabel.
  ///
  /// In en, this message translates to:
  /// **'Story photo'**
  String get storyThumbnailLabel;

  /// No description provided for @storyThumbnailUnavailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Story photo unavailable'**
  String get storyThumbnailUnavailableLabel;

  /// No description provided for @storiesNotificationUnavailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Notifications are not available yet'**
  String get storiesNotificationUnavailableLabel;

  /// No description provided for @storiesOpenNotificationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Open notifications'**
  String get storiesOpenNotificationsLabel;

  /// Accessibility label for the Stories screen avatar
  ///
  /// In en, this message translates to:
  /// **'{displayName}\'s avatar'**
  String storiesAvatarLabel(String displayName);

  /// Accessibility label for a tappable story card
  ///
  /// In en, this message translates to:
  /// **'Open story {title}'**
  String storiesOpenStoryLabel(String title);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @createStoryPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Create story'**
  String get createStoryPageTitle;

  /// No description provided for @createStoryBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to stories'**
  String get createStoryBackLabel;

  /// No description provided for @createStoryHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'New story'**
  String get createStoryHeroTitle;

  /// No description provided for @createStoryHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a space for your shared memories'**
  String get createStoryHeroSubtitle;

  /// No description provided for @createStoryTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Story title'**
  String get createStoryTitleLabel;

  /// No description provided for @createStoryTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Our story'**
  String get createStoryTitleHint;

  /// No description provided for @createStoryTitleHelp.
  ///
  /// In en, this message translates to:
  /// **'The title will be visible to every story participant'**
  String get createStoryTitleHelp;

  /// No description provided for @createStoryTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a story title.'**
  String get createStoryTitleRequired;

  /// No description provided for @createStoryTitleBlank.
  ///
  /// In en, this message translates to:
  /// **'Story title cannot be blank.'**
  String get createStoryTitleBlank;

  /// No description provided for @createStoryDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get createStoryDescriptionLabel;

  /// No description provided for @createStoryDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get createStoryDescriptionOptional;

  /// No description provided for @createStoryDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a short note about this story'**
  String get createStoryDescriptionHint;

  /// No description provided for @createStoryWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Why does a title matter?'**
  String get createStoryWhyTitle;

  /// No description provided for @createStoryWhyDescription.
  ///
  /// In en, this message translates to:
  /// **'A good title helps everyone remember what makes this story special.'**
  String get createStoryWhyDescription;

  /// No description provided for @createStoryIdeasTitle.
  ///
  /// In en, this message translates to:
  /// **'Title ideas'**
  String get createStoryIdeasTitle;

  /// No description provided for @createStoryIdeaOne.
  ///
  /// In en, this message translates to:
  /// **'Our story'**
  String get createStoryIdeaOne;

  /// No description provided for @createStoryIdeaTwo.
  ///
  /// In en, this message translates to:
  /// **'Best moments together'**
  String get createStoryIdeaTwo;

  /// No description provided for @createStoryIdeaThree.
  ///
  /// In en, this message translates to:
  /// **'Travels and adventures'**
  String get createStoryIdeaThree;

  /// No description provided for @createStorySubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Create story'**
  String get createStorySubmitButton;

  /// No description provided for @createStoryCreatingButton.
  ///
  /// In en, this message translates to:
  /// **'Creating story...'**
  String get createStoryCreatingButton;

  /// No description provided for @createStoryCoverRemoveSelectionAction.
  ///
  /// In en, this message translates to:
  /// **'Remove selected cover'**
  String get createStoryCoverRemoveSelectionAction;

  /// No description provided for @createStoryCoverUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading cover...'**
  String get createStoryCoverUploading;

  /// No description provided for @createStoryCoverPartialTitle.
  ///
  /// In en, this message translates to:
  /// **'Story created'**
  String get createStoryCoverPartialTitle;

  /// No description provided for @createStoryCoverPartialMessage.
  ///
  /// In en, this message translates to:
  /// **'Story was created, but cover could not be uploaded.'**
  String get createStoryCoverPartialMessage;

  /// No description provided for @createStoryCoverRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry cover upload'**
  String get createStoryCoverRetryAction;

  /// No description provided for @createStoryCoverContinueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue without cover'**
  String get createStoryCoverContinueAction;

  /// No description provided for @storyDetailsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get storyDetailsPageTitle;

  /// No description provided for @storyDetailsBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to stories'**
  String get storyDetailsBackLabel;

  /// No description provided for @storyDetailsEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit story'**
  String get storyDetailsEditAction;

  /// No description provided for @storyDetailsLoadFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load story'**
  String get storyDetailsLoadFailureTitle;

  /// No description provided for @storyDetailsDescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'About this story'**
  String get storyDetailsDescriptionTitle;

  /// No description provided for @storyDetailsNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description yet.'**
  String get storyDetailsNoDescription;

  /// No description provided for @storyDetailsInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Story info'**
  String get storyDetailsInfoTitle;

  /// No description provided for @storyDetailsCreatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get storyDetailsCreatedLabel;

  /// No description provided for @storyDetailsUpdatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get storyDetailsUpdatedLabel;

  /// No description provided for @storyDetailsRefreshFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh story'**
  String get storyDetailsRefreshFailureTitle;

  /// No description provided for @storyDetailsPeriodPresent.
  ///
  /// In en, this message translates to:
  /// **'present'**
  String get storyDetailsPeriodPresent;

  /// No description provided for @storyDetailsSectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get storyDetailsSectionsTitle;

  /// No description provided for @storyDetailsMemoriesAction.
  ///
  /// In en, this message translates to:
  /// **'Memories'**
  String get storyDetailsMemoriesAction;

  /// No description provided for @storyDetailsParticipantsAction.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get storyDetailsParticipantsAction;

  /// No description provided for @storyDetailsParticipantsManageAction.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get storyDetailsParticipantsManageAction;

  /// No description provided for @storyDetailsMapAction.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get storyDetailsMapAction;

  /// No description provided for @storyDetailsTimelineAction.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get storyDetailsTimelineAction;

  /// No description provided for @storyDetailsRecentMemoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent memories'**
  String get storyDetailsRecentMemoriesTitle;

  /// No description provided for @storyDetailsSeeAllAction.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get storyDetailsSeeAllAction;

  /// No description provided for @storyDetailsPlaybackStoryAction.
  ///
  /// In en, this message translates to:
  /// **'Playback Story'**
  String get storyDetailsPlaybackStoryAction;

  /// No description provided for @soundtrackTitle.
  ///
  /// In en, this message translates to:
  /// **'Soundtrack'**
  String get soundtrackTitle;

  /// No description provided for @soundtrackNoMusic.
  ///
  /// In en, this message translates to:
  /// **'No music'**
  String get soundtrackNoMusic;

  /// No description provided for @soundtrackLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading soundtrack...'**
  String get soundtrackLoading;

  /// No description provided for @soundtrackLoadFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load soundtrack'**
  String get soundtrackLoadFailureTitle;

  /// No description provided for @soundtrackChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose soundtrack'**
  String get soundtrackChooseTitle;

  /// No description provided for @soundtrackReadOnly.
  ///
  /// In en, this message translates to:
  /// **'Read-only'**
  String get soundtrackReadOnly;

  /// No description provided for @soundtrackCurrentSelection.
  ///
  /// In en, this message translates to:
  /// **'Current selection'**
  String get soundtrackCurrentSelection;

  /// No description provided for @soundtrackCurrentlyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Currently unavailable'**
  String get soundtrackCurrentlyUnavailable;

  /// No description provided for @soundtrackUnavailableEditable.
  ///
  /// In en, this message translates to:
  /// **'Currently unavailable. Choose another track or No music.'**
  String get soundtrackUnavailableEditable;

  /// No description provided for @soundtrackCatalogTitle.
  ///
  /// In en, this message translates to:
  /// **'Available soundtracks'**
  String get soundtrackCatalogTitle;

  /// No description provided for @soundtrackCatalogLoadFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load soundtracks'**
  String get soundtrackCatalogLoadFailureTitle;

  /// No description provided for @soundtrackCatalogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No soundtracks are available right now.'**
  String get soundtrackCatalogEmpty;

  /// No description provided for @soundtrackSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get soundtrackSelected;

  /// No description provided for @soundtrackUpdateFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not update soundtrack. Please try again.'**
  String get soundtrackUpdateFailure;

  /// No description provided for @musicFailureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Music is unavailable. Please try again.'**
  String get musicFailureUnavailable;

  /// No description provided for @musicFailureNetworkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No network connection. Check your connection and try again.'**
  String get musicFailureNetworkUnavailable;

  /// No description provided for @musicFailureRequestTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get musicFailureRequestTimedOut;

  /// No description provided for @musicFailureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get musicFailureUnknown;

  /// No description provided for @participantsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get participantsPageTitle;

  /// No description provided for @participantsBack.
  ///
  /// In en, this message translates to:
  /// **'Back to story'**
  String get participantsBack;

  /// No description provided for @participantsHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'People in this story'**
  String get participantsHeaderTitle;

  /// Participant count shown on the Participants screen
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No participants} =1{1 participant} other{{count} participants}}'**
  String participantsCount(int count);

  /// No description provided for @participantsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get participantsSectionTitle;

  /// No description provided for @participantsSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Roles shape what each participant can do in this story.'**
  String get participantsSectionSubtitle;

  /// No description provided for @participantsInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite participant'**
  String get participantsInvite;

  /// No description provided for @participantsLeaveStory.
  ///
  /// In en, this message translates to:
  /// **'Leave story'**
  String get participantsLeaveStory;

  /// No description provided for @participantsLeaveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave story?'**
  String get participantsLeaveConfirmTitle;

  /// No description provided for @participantsLeaveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will lose access to this story. To join again, you will need a new invitation. If you are the last owner, the server may reject this action.'**
  String get participantsLeaveConfirmBody;

  /// No description provided for @participantsLeaveConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get participantsLeaveConfirmAction;

  /// No description provided for @participantsLeaveCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get participantsLeaveCancel;

  /// No description provided for @participantsLeaving.
  ///
  /// In en, this message translates to:
  /// **'Leaving story...'**
  String get participantsLeaving;

  /// No description provided for @participantsCurrentUser.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get participantsCurrentUser;

  /// No description provided for @participantsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No participants to show'**
  String get participantsEmptyTitle;

  /// No description provided for @participantsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'The participant list is empty right now. Try refreshing in a moment.'**
  String get participantsEmptyBody;

  /// No description provided for @participantsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get participantsRetry;

  /// No description provided for @participantsRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh participants'**
  String get participantsRefreshFailed;

  /// No description provided for @participantsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load participants'**
  String get participantsLoadFailed;

  /// No description provided for @participantsRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get participantsRemoveAction;

  /// Title for confirming participant removal
  ///
  /// In en, this message translates to:
  /// **'Remove {displayName}?'**
  String participantsRemoveConfirmTitle(String displayName);

  /// Body for confirming participant removal
  ///
  /// In en, this message translates to:
  /// **'{displayName} will lose access to this story. They can join again with a new invitation.'**
  String participantsRemoveConfirmBody(String displayName);

  /// No description provided for @participantsRemoveConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get participantsRemoveConfirmAction;

  /// No description provided for @participantsRemoveCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get participantsRemoveCancel;

  /// No description provided for @participantsRemoving.
  ///
  /// In en, this message translates to:
  /// **'Removing participant...'**
  String get participantsRemoving;

  /// SnackBar shown after a participant is removed
  ///
  /// In en, this message translates to:
  /// **'{displayName} was removed.'**
  String participantsRemoveSuccess(String displayName);

  /// Accessibility label for a participant avatar
  ///
  /// In en, this message translates to:
  /// **'{displayName}\'s avatar'**
  String participantsAvatarLabel(String displayName);

  /// Accessibility label for removing a participant
  ///
  /// In en, this message translates to:
  /// **'Remove {displayName}'**
  String participantsRemoveParticipantLabel(String displayName);

  /// No description provided for @participantFailureValidation.
  ///
  /// In en, this message translates to:
  /// **'The request was invalid. Please try again.'**
  String get participantFailureValidation;

  /// No description provided for @participantFailureUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your session needs attention. Please try again.'**
  String get participantFailureUnauthorized;

  /// No description provided for @participantFailureNotFound.
  ///
  /// In en, this message translates to:
  /// **'Participants are unavailable.'**
  String get participantFailureNotFound;

  /// No description provided for @participantFailureLastOwner.
  ///
  /// In en, this message translates to:
  /// **'The last owner cannot leave this story.'**
  String get participantFailureLastOwner;

  /// No description provided for @participantFailureCannotRemoveSelf.
  ///
  /// In en, this message translates to:
  /// **'Use Leave story to remove yourself.'**
  String get participantFailureCannotRemoveSelf;

  /// No description provided for @participantFailureOwnerCannotBeRemoved.
  ///
  /// In en, this message translates to:
  /// **'Owners cannot be removed from here.'**
  String get participantFailureOwnerCannotBeRemoved;

  /// No description provided for @participantFailureNetwork.
  ///
  /// In en, this message translates to:
  /// **'No network connection. Check your connection and try again.'**
  String get participantFailureNetwork;

  /// No description provided for @participantFailureTimeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get participantFailureTimeout;

  /// No description provided for @participantFailureServer.
  ///
  /// In en, this message translates to:
  /// **'The server is temporarily unavailable. Please try again.'**
  String get participantFailureServer;

  /// No description provided for @participantFailureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get participantFailureUnknown;

  /// No description provided for @storyMemoriesPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Memories'**
  String get storyMemoriesPageTitle;

  /// No description provided for @storyMemoriesBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to story'**
  String get storyMemoriesBackLabel;

  /// No description provided for @storyMemoriesRefreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh memories'**
  String get storyMemoriesRefreshAction;

  /// No description provided for @storyMemoriesHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Story memories'**
  String get storyMemoriesHeaderTitle;

  /// Memory count shown on the Story Memories screen
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No memories} =1{1 memory} other{{count} memories}}'**
  String storyMemoriesCount(int count);

  /// No description provided for @storyMemoriesCreate.
  ///
  /// In en, this message translates to:
  /// **'Add memory'**
  String get storyMemoriesCreate;

  /// No description provided for @storyMemoriesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No memories yet'**
  String get storyMemoriesEmptyTitle;

  /// No description provided for @storyMemoriesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add the first memory when something worth saving happens.'**
  String get storyMemoriesEmptyBody;

  /// No description provided for @storyMemoriesLoadFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load memories'**
  String get storyMemoriesLoadFailureTitle;

  /// No description provided for @storyMemoriesRefreshFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh memories'**
  String get storyMemoriesRefreshFailureTitle;

  /// No description provided for @storyTimelinePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get storyTimelinePageTitle;

  /// No description provided for @storyTimelineBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to story'**
  String get storyTimelineBackLabel;

  /// No description provided for @storyTimelineRefreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh timeline'**
  String get storyTimelineRefreshAction;

  /// No description provided for @storyTimelineCreate.
  ///
  /// In en, this message translates to:
  /// **'Add memory'**
  String get storyTimelineCreate;

  /// No description provided for @storyTimelineEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No timeline yet'**
  String get storyTimelineEmptyTitle;

  /// No description provided for @storyTimelineEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add memories to build this story timeline.'**
  String get storyTimelineEmptyBody;

  /// No description provided for @storyTimelineLoadFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load timeline'**
  String get storyTimelineLoadFailureTitle;

  /// No description provided for @storyTimelineRefreshFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh timeline'**
  String get storyTimelineRefreshFailureTitle;

  /// No description provided for @storyMapPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get storyMapPageTitle;

  /// No description provided for @storyMapBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to story'**
  String get storyMapBackLabel;

  /// No description provided for @storyMapShowAllAction.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get storyMapShowAllAction;

  /// No description provided for @storyMapRefreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh map'**
  String get storyMapRefreshAction;

  /// No description provided for @storyMapShowDetailsAction.
  ///
  /// In en, this message translates to:
  /// **'Show details'**
  String get storyMapShowDetailsAction;

  /// No description provided for @storyMapEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No memories on the map yet'**
  String get storyMapEmptyTitle;

  /// No description provided for @storyMapEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Memories with saved places will appear here.'**
  String get storyMapEmptyBody;

  /// No description provided for @storyMapLoadFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load map'**
  String get storyMapLoadFailureTitle;

  /// No description provided for @storyMapRefreshFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh map'**
  String get storyMapRefreshFailureTitle;

  /// Accessibility label for a tappable memory item
  ///
  /// In en, this message translates to:
  /// **'Open memory {title}'**
  String memoryOpenLabel(String title);

  /// No description provided for @memoryFailureValidation.
  ///
  /// In en, this message translates to:
  /// **'The request was invalid. Please try again.'**
  String get memoryFailureValidation;

  /// No description provided for @memoryFailureUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your session needs attention. Please try again.'**
  String get memoryFailureUnauthorized;

  /// No description provided for @memoryFailureStoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Story memories are unavailable.'**
  String get memoryFailureStoryUnavailable;

  /// No description provided for @memoryFailureNotFound.
  ///
  /// In en, this message translates to:
  /// **'Memory is unavailable.'**
  String get memoryFailureNotFound;

  /// No description provided for @memoryFailureCreationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Memory cannot be created from here.'**
  String get memoryFailureCreationUnavailable;

  /// No description provided for @memoryFailureUpdateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Memory cannot be updated from here.'**
  String get memoryFailureUpdateUnavailable;

  /// No description provided for @memoryFailureDeletionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Memory cannot be deleted from here.'**
  String get memoryFailureDeletionUnavailable;

  /// No description provided for @memoryFailureNetworkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No network connection. Check your connection and try again.'**
  String get memoryFailureNetworkUnavailable;

  /// No description provided for @memoryFailureRequestTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get memoryFailureRequestTimedOut;

  /// No description provided for @memoryFailureServerFailure.
  ///
  /// In en, this message translates to:
  /// **'The server is temporarily unavailable. Please try again.'**
  String get memoryFailureServerFailure;

  /// No description provided for @memoryFailureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get memoryFailureUnknown;

  /// No description provided for @createMemoryPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Add memory'**
  String get createMemoryPageTitle;

  /// No description provided for @createMemoryBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to memories'**
  String get createMemoryBackLabel;

  /// No description provided for @createMemoryTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get createMemoryTitleLabel;

  /// No description provided for @createMemoryTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Sunset in Bali'**
  String get createMemoryTitleHint;

  /// No description provided for @createMemoryTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a memory title.'**
  String get createMemoryTitleRequired;

  /// No description provided for @createMemoryTitleBlank.
  ///
  /// In en, this message translates to:
  /// **'Memory title cannot be blank.'**
  String get createMemoryTitleBlank;

  /// No description provided for @createMemoryTitleMax.
  ///
  /// In en, this message translates to:
  /// **'Memory title must be 255 characters or fewer.'**
  String get createMemoryTitleMax;

  /// No description provided for @createMemoryDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get createMemoryDescriptionLabel;

  /// No description provided for @createMemoryDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note about this moment'**
  String get createMemoryDescriptionHint;

  /// No description provided for @createMemoryPlaceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Place name'**
  String get createMemoryPlaceNameLabel;

  /// No description provided for @createMemoryPlaceNameHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Seminyak Beach'**
  String get createMemoryPlaceNameHint;

  /// No description provided for @createMemoryPlaceNameMax.
  ///
  /// In en, this message translates to:
  /// **'Place name must be 255 characters or fewer.'**
  String get createMemoryPlaceNameMax;

  /// No description provided for @createMemoryOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get createMemoryOptionalLabel;

  /// No description provided for @createMemoryEventDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Event date'**
  String get createMemoryEventDateLabel;

  /// No description provided for @createMemoryEventDateEmpty.
  ///
  /// In en, this message translates to:
  /// **'No date selected'**
  String get createMemoryEventDateEmpty;

  /// No description provided for @createMemoryChooseDate.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get createMemoryChooseDate;

  /// No description provided for @createMemoryChangeDate.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get createMemoryChangeDate;

  /// No description provided for @createMemoryDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose an event date.'**
  String get createMemoryDateRequired;

  /// No description provided for @createMemoryLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get createMemoryLocationLabel;

  /// No description provided for @createMemoryLocationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No location selected'**
  String get createMemoryLocationEmpty;

  /// No description provided for @createMemoryLocationSelected.
  ///
  /// In en, this message translates to:
  /// **'Location selected'**
  String get createMemoryLocationSelected;

  /// No description provided for @createMemoryChooseLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get createMemoryChooseLocation;

  /// No description provided for @createMemoryChangeLocation.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get createMemoryChangeLocation;

  /// No description provided for @createMemoryLocationRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a location.'**
  String get createMemoryLocationRequired;

  /// No description provided for @createMemorySubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Create memory'**
  String get createMemorySubmitButton;

  /// No description provided for @createMemorySubmittingButton.
  ///
  /// In en, this message translates to:
  /// **'Creating memory...'**
  String get createMemorySubmittingButton;

  /// No description provided for @editMemoryPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit memory'**
  String get editMemoryPageTitle;

  /// No description provided for @editMemoryBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to memory'**
  String get editMemoryBackLabel;

  /// No description provided for @editMemorySaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get editMemorySaveButton;

  /// No description provided for @editMemorySavingButton.
  ///
  /// In en, this message translates to:
  /// **'Saving changes...'**
  String get editMemorySavingButton;

  /// No description provided for @editMemoryNoChangesHint.
  ///
  /// In en, this message translates to:
  /// **'Make a change to save.'**
  String get editMemoryNoChangesHint;

  /// No description provided for @memoryDetailsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get memoryDetailsPageTitle;

  /// No description provided for @memoryDetailsBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to memories'**
  String get memoryDetailsBackLabel;

  /// No description provided for @memoryDetailsRefreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh memory'**
  String get memoryDetailsRefreshAction;

  /// No description provided for @memoryDetailsEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit memory'**
  String get memoryDetailsEditAction;

  /// No description provided for @memoryDetailsDeleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete memory'**
  String get memoryDetailsDeleteAction;

  /// No description provided for @memoryDetailsLoadFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load memory'**
  String get memoryDetailsLoadFailureTitle;

  /// No description provided for @memoryDetailsRefreshFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not refresh memory'**
  String get memoryDetailsRefreshFailureTitle;

  /// No description provided for @memoryDetailsDescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory note'**
  String get memoryDetailsDescriptionTitle;

  /// No description provided for @memoryDetailsNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description yet.'**
  String get memoryDetailsNoDescription;

  /// No description provided for @memoryDetailsPlaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get memoryDetailsPlaceTitle;

  /// No description provided for @memoryDetailsNoPlace.
  ///
  /// In en, this message translates to:
  /// **'No place name yet.'**
  String get memoryDetailsNoPlace;

  /// No description provided for @memoryDetailsOpenOnMapAction.
  ///
  /// In en, this message translates to:
  /// **'Open on map'**
  String get memoryDetailsOpenOnMapAction;

  /// No description provided for @memoryDetailsMapUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Map preview unavailable.'**
  String get memoryDetailsMapUnavailable;

  /// No description provided for @memoryMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get memoryMediaTitle;

  /// No description provided for @memoryMediaRefreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh photos'**
  String get memoryMediaRefreshAction;

  /// No description provided for @memoryMediaAddPhotoAction.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get memoryMediaAddPhotoAction;

  /// No description provided for @memoryMediaEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos yet.'**
  String get memoryMediaEmpty;

  /// No description provided for @memoryMediaSelectingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choosing photo...'**
  String get memoryMediaSelectingPhoto;

  /// No description provided for @memoryMediaPreparingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Preparing photo...'**
  String get memoryMediaPreparingPhoto;

  /// No description provided for @memoryMediaUploadingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo...'**
  String get memoryMediaUploadingPhoto;

  /// No description provided for @memoryMediaOpenPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Open photo'**
  String get memoryMediaOpenPhotoLabel;

  /// No description provided for @memoryMediaClosePhotoAction.
  ///
  /// In en, this message translates to:
  /// **'Close photo'**
  String get memoryMediaClosePhotoAction;

  /// No description provided for @deletePhotoAction.
  ///
  /// In en, this message translates to:
  /// **'Delete photo'**
  String get deletePhotoAction;

  /// No description provided for @deletePhotoDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete photo?'**
  String get deletePhotoDialogTitle;

  /// No description provided for @deletePhotoDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This photo will be permanently removed.'**
  String get deletePhotoDialogBody;

  /// No description provided for @deletePhotoCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get deletePhotoCancel;

  /// No description provided for @deletePhotoConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deletePhotoConfirm;

  /// No description provided for @deletePhotoFailure.
  ///
  /// In en, this message translates to:
  /// **'Photo could not be deleted. Please try again.'**
  String get deletePhotoFailure;

  /// No description provided for @mediaFailureValidation.
  ///
  /// In en, this message translates to:
  /// **'The photo request was invalid. Please try again.'**
  String get mediaFailureValidation;

  /// No description provided for @mediaFailureUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your session needs attention. Please try again.'**
  String get mediaFailureUnauthorized;

  /// No description provided for @mediaFailureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photos are unavailable.'**
  String get mediaFailureUnavailable;

  /// No description provided for @mediaFailureUploadUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photo cannot be uploaded from here.'**
  String get mediaFailureUploadUnavailable;

  /// No description provided for @mediaFailureNetworkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No network connection. Check your connection and try again.'**
  String get mediaFailureNetworkUnavailable;

  /// No description provided for @mediaFailureRequestTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get mediaFailureRequestTimedOut;

  /// No description provided for @mediaFailureServerFailure.
  ///
  /// In en, this message translates to:
  /// **'The server is temporarily unavailable. Please try again.'**
  String get mediaFailureServerFailure;

  /// No description provided for @mediaFailurePreprocessing.
  ///
  /// In en, this message translates to:
  /// **'Could not prepare this photo. Choose another image.'**
  String get mediaFailurePreprocessing;

  /// No description provided for @mediaFailureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get mediaFailureUnknown;

  /// No description provided for @deleteMemoryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete memory?'**
  String get deleteMemoryDialogTitle;

  /// No description provided for @deleteMemoryDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This memory will be permanently deleted. This action cannot be undone.'**
  String get deleteMemoryDialogBody;

  /// No description provided for @deleteMemoryCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get deleteMemoryCancel;

  /// No description provided for @deleteMemoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteMemoryConfirm;

  /// No description provided for @deleteMemoryDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting memory...'**
  String get deleteMemoryDeleting;

  /// No description provided for @locationPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a place'**
  String get locationPickerTitle;

  /// No description provided for @locationPickerBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get locationPickerBackLabel;

  /// No description provided for @locationPickerInstruction.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to choose the exact point for this memory.'**
  String get locationPickerInstruction;

  /// No description provided for @locationPickerSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Location selected'**
  String get locationPickerSelectedTitle;

  /// No description provided for @locationPickerSelectedDescription.
  ///
  /// In en, this message translates to:
  /// **'Confirm when the pin marks the place you want to save.'**
  String get locationPickerSelectedDescription;

  /// No description provided for @locationPickerNoSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'No location selected'**
  String get locationPickerNoSelectionTitle;

  /// No description provided for @locationPickerNoSelectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a point on the map before confirming.'**
  String get locationPickerNoSelectionDescription;

  /// No description provided for @locationPickerConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Confirm location'**
  String get locationPickerConfirmAction;

  /// No description provided for @locationPickerMapLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading map...'**
  String get locationPickerMapLoading;

  /// No description provided for @locationPickerMapUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Map is unavailable. Please try again later.'**
  String get locationPickerMapUnavailable;

  /// No description provided for @editStoryPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit story'**
  String get editStoryPageTitle;

  /// No description provided for @editStoryBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to story'**
  String get editStoryBackLabel;

  /// No description provided for @editStoryHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Story details'**
  String get editStoryHeroTitle;

  /// No description provided for @editStoryHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update the name and note shown to story participants'**
  String get editStoryHeroSubtitle;

  /// No description provided for @editStoryCoverLabel.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get editStoryCoverLabel;

  /// No description provided for @editStoryCoverNoPhoto.
  ///
  /// In en, this message translates to:
  /// **'No cover photo'**
  String get editStoryCoverNoPhoto;

  /// No description provided for @editStoryCoverPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Story cover photo'**
  String get editStoryCoverPhotoLabel;

  /// No description provided for @editStoryCoverChooseAction.
  ///
  /// In en, this message translates to:
  /// **'Choose cover'**
  String get editStoryCoverChooseAction;

  /// No description provided for @editStoryCoverChangeAction.
  ///
  /// In en, this message translates to:
  /// **'Change cover'**
  String get editStoryCoverChangeAction;

  /// No description provided for @editStoryCoverRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove cover'**
  String get editStoryCoverRemoveAction;

  /// No description provided for @editStoryCoverSelecting.
  ///
  /// In en, this message translates to:
  /// **'Choosing photo...'**
  String get editStoryCoverSelecting;

  /// No description provided for @editStoryCoverPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing photo...'**
  String get editStoryCoverPreparing;

  /// No description provided for @editStoryCoverUploading.
  ///
  /// In en, this message translates to:
  /// **'Updating cover...'**
  String get editStoryCoverUploading;

  /// No description provided for @editStoryCoverRemoving.
  ///
  /// In en, this message translates to:
  /// **'Removing cover...'**
  String get editStoryCoverRemoving;

  /// No description provided for @editStoryCoverUpdatedFeedback.
  ///
  /// In en, this message translates to:
  /// **'Cover updated'**
  String get editStoryCoverUpdatedFeedback;

  /// No description provided for @editStoryCoverRemovedFeedback.
  ///
  /// In en, this message translates to:
  /// **'Cover removed'**
  String get editStoryCoverRemovedFeedback;

  /// No description provided for @editStoryCoverAutosaveHint.
  ///
  /// In en, this message translates to:
  /// **'Cover changes are saved automatically.'**
  String get editStoryCoverAutosaveHint;

  /// No description provided for @editStoryTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Story title'**
  String get editStoryTitleLabel;

  /// No description provided for @editStoryTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Example: Our story'**
  String get editStoryTitleHint;

  /// No description provided for @editStoryTitleHelp.
  ///
  /// In en, this message translates to:
  /// **'The title remains visible to every story participant'**
  String get editStoryTitleHelp;

  /// No description provided for @editStoryTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a story title.'**
  String get editStoryTitleRequired;

  /// No description provided for @editStoryTitleBlank.
  ///
  /// In en, this message translates to:
  /// **'Story title cannot be blank.'**
  String get editStoryTitleBlank;

  /// No description provided for @editStoryDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get editStoryDescriptionLabel;

  /// No description provided for @editStoryDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get editStoryDescriptionOptional;

  /// No description provided for @editStoryDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a short note about this story'**
  String get editStoryDescriptionHint;

  /// No description provided for @editStoryDescriptionHelp.
  ///
  /// In en, this message translates to:
  /// **'Clear the field to remove the existing description'**
  String get editStoryDescriptionHelp;

  /// No description provided for @editStorySaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get editStorySaveButton;

  /// No description provided for @editStorySavingButton.
  ///
  /// In en, this message translates to:
  /// **'Saving changes...'**
  String get editStorySavingButton;

  /// No description provided for @editStoryNoChangesHint.
  ///
  /// In en, this message translates to:
  /// **'Make a change to save.'**
  String get editStoryNoChangesHint;

  /// No description provided for @editStoryUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Editing is unavailable'**
  String get editStoryUnavailableTitle;

  /// No description provided for @editStoryUnavailableDescription.
  ///
  /// In en, this message translates to:
  /// **'This story cannot be edited from here.'**
  String get editStoryUnavailableDescription;

  /// No description provided for @editStoryUnavailableBackAction.
  ///
  /// In en, this message translates to:
  /// **'Back to story'**
  String get editStoryUnavailableBackAction;

  /// No description provided for @invitePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite participant'**
  String get invitePageTitle;

  /// No description provided for @inviteCreatedPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite created'**
  String get inviteCreatedPageTitle;

  /// No description provided for @inviteBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to story'**
  String get inviteBackLabel;

  /// No description provided for @inviteHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite someone close'**
  String get inviteHeroTitle;

  /// No description provided for @inviteHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share a one-time invitation link so they can join your story.'**
  String get inviteHeroSubtitle;

  /// No description provided for @inviteLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get inviteLinkLabel;

  /// No description provided for @inviteSingleUseDescription.
  ///
  /// In en, this message translates to:
  /// **'One-time use. After it is accepted, the link stops working.'**
  String get inviteSingleUseDescription;

  /// No description provided for @inviteExpirationLabel.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get inviteExpirationLabel;

  /// No description provided for @inviteExpirationDescription.
  ///
  /// In en, this message translates to:
  /// **'The invite remains valid until the date returned by the server.'**
  String get inviteExpirationDescription;

  /// No description provided for @inviteWhatCanDoTitle.
  ///
  /// In en, this message translates to:
  /// **'What can you do with this link?'**
  String get inviteWhatCanDoTitle;

  /// No description provided for @inviteInstructionShare.
  ///
  /// In en, this message translates to:
  /// **'Share it in any messenger.'**
  String get inviteInstructionShare;

  /// No description provided for @inviteInstructionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy it and send it yourself.'**
  String get inviteInstructionCopy;

  /// No description provided for @inviteInstructionOneUse.
  ///
  /// In en, this message translates to:
  /// **'Ask the recipient to use it only once.'**
  String get inviteInstructionOneUse;

  /// No description provided for @inviteCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create invite'**
  String get inviteCreateButton;

  /// No description provided for @inviteCreatingButton.
  ///
  /// In en, this message translates to:
  /// **'Creating invite...'**
  String get inviteCreatingButton;

  /// No description provided for @inviteSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite is ready!'**
  String get inviteSuccessTitle;

  /// No description provided for @inviteSuccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share the link with someone close. It is one-time and secure.'**
  String get inviteSuccessSubtitle;

  /// No description provided for @inviteLinkSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get inviteLinkSemanticsLabel;

  /// No description provided for @inviteCopyAction.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get inviteCopyAction;

  /// No description provided for @inviteCopiedFeedback.
  ///
  /// In en, this message translates to:
  /// **'Invite link copied.'**
  String get inviteCopiedFeedback;

  /// No description provided for @inviteCopyFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not copy the invite link.'**
  String get inviteCopyFailure;

  /// No description provided for @inviteShareAction.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get inviteShareAction;

  /// No description provided for @inviteShareReadyFeedback.
  ///
  /// In en, this message translates to:
  /// **'Share options opened.'**
  String get inviteShareReadyFeedback;

  /// No description provided for @inviteShareFailure.
  ///
  /// In en, this message translates to:
  /// **'Could not share the invite link.'**
  String get inviteShareFailure;

  /// No description provided for @inviteLinkCannotBeRestoredWarning.
  ///
  /// In en, this message translates to:
  /// **'Copy or share this link before leaving this screen. It cannot be shown again.'**
  String get inviteLinkCannotBeRestoredWarning;

  /// No description provided for @inviteImportantTitle.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get inviteImportantTitle;

  /// No description provided for @inviteImportantSingleUse.
  ///
  /// In en, this message translates to:
  /// **'This link can be used only once.'**
  String get inviteImportantSingleUse;

  /// No description provided for @inviteImportantAfterAccept.
  ///
  /// In en, this message translates to:
  /// **'After the invitation is accepted, the link becomes invalid.'**
  String get inviteImportantAfterAccept;

  /// No description provided for @inviteImportantExpiration.
  ///
  /// In en, this message translates to:
  /// **'The invitation automatically expires after its expiration date.'**
  String get inviteImportantExpiration;

  /// No description provided for @inviteDoneAction.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get inviteDoneAction;

  /// No description provided for @inviteFailureValidation.
  ///
  /// In en, this message translates to:
  /// **'The invite request was invalid. Please try again.'**
  String get inviteFailureValidation;

  /// No description provided for @inviteFailureUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your session needs attention. Please try again.'**
  String get inviteFailureUnauthorized;

  /// No description provided for @inviteFailureNotFound.
  ///
  /// In en, this message translates to:
  /// **'This story is unavailable for invites.'**
  String get inviteFailureNotFound;

  /// No description provided for @inviteFailureNetworkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No network connection. Check your connection and try again.'**
  String get inviteFailureNetworkUnavailable;

  /// No description provided for @inviteFailureRequestTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get inviteFailureRequestTimedOut;

  /// No description provided for @inviteFailureServerFailure.
  ///
  /// In en, this message translates to:
  /// **'The server is temporarily unavailable. Please try again.'**
  String get inviteFailureServerFailure;

  /// No description provided for @inviteFailureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get inviteFailureUnknown;

  /// No description provided for @acceptInvitePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Invitation'**
  String get acceptInvitePageTitle;

  /// No description provided for @acceptInviteBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to stories'**
  String get acceptInviteBackLabel;

  /// No description provided for @acceptInviteHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'You were invited to a story'**
  String get acceptInviteHeroTitle;

  /// No description provided for @acceptInviteHeroDescription.
  ///
  /// In en, this message translates to:
  /// **'Accept the invitation to join. We will show the story after the server confirms access.'**
  String get acceptInviteHeroDescription;

  /// No description provided for @acceptInviteDetailsAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Private access'**
  String get acceptInviteDetailsAccessTitle;

  /// No description provided for @acceptInviteDetailsAccessBody.
  ///
  /// In en, this message translates to:
  /// **'Story details are hidden until you accept the invite.'**
  String get acceptInviteDetailsAccessBody;

  /// No description provided for @acceptInviteDetailsSingleUseTitle.
  ///
  /// In en, this message translates to:
  /// **'One-time link'**
  String get acceptInviteDetailsSingleUseTitle;

  /// No description provided for @acceptInviteDetailsSingleUseBody.
  ///
  /// In en, this message translates to:
  /// **'The invite can be accepted only once and may expire.'**
  String get acceptInviteDetailsSingleUseBody;

  /// No description provided for @acceptInviteAcceptAction.
  ///
  /// In en, this message translates to:
  /// **'Accept invite'**
  String get acceptInviteAcceptAction;

  /// No description provided for @acceptInviteAcceptingAction.
  ///
  /// In en, this message translates to:
  /// **'Accepting invite...'**
  String get acceptInviteAcceptingAction;

  /// No description provided for @acceptInviteRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get acceptInviteRetryAction;

  /// No description provided for @acceptInviteCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get acceptInviteCancelAction;

  /// No description provided for @acceptInviteBackToStoriesAction.
  ///
  /// In en, this message translates to:
  /// **'Back to stories'**
  String get acceptInviteBackToStoriesAction;

  /// No description provided for @acceptInviteInvalidLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite link is unavailable'**
  String get acceptInviteInvalidLinkTitle;

  /// No description provided for @acceptInviteInvalidLinkDescription.
  ///
  /// In en, this message translates to:
  /// **'This invitation cannot be opened.'**
  String get acceptInviteInvalidLinkDescription;

  /// No description provided for @acceptInviteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This invitation cannot be accepted.'**
  String get acceptInviteUnavailable;

  /// No description provided for @acceptInviteFailureUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your session needs attention. Please sign in again.'**
  String get acceptInviteFailureUnauthorized;

  /// No description provided for @acceptInviteFailureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get acceptInviteFailureUnknown;

  /// No description provided for @acceptInviteAcceptSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Accept invitation'**
  String get acceptInviteAcceptSemanticsLabel;

  /// No description provided for @acceptInviteCancelSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel invitation'**
  String get acceptInviteCancelSemanticsLabel;

  /// No description provided for @acceptInviteErrorSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'Invitation error'**
  String get acceptInviteErrorSemanticsLabel;

  /// No description provided for @playbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playbackTitle;

  /// No description provided for @playbackContextLabel.
  ///
  /// In en, this message translates to:
  /// **'Story playback'**
  String get playbackContextLabel;

  /// No description provided for @playbackProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total, plural, =1{1 memory} other{{total} memories}}'**
  String playbackProgressLabel(int current, int total);

  /// No description provided for @playbackPreviousAction.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get playbackPreviousAction;

  /// No description provided for @playbackNextAction.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get playbackNextAction;

  /// No description provided for @playbackPauseAction.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playbackPauseAction;

  /// No description provided for @playbackResumeAction.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get playbackResumeAction;

  /// No description provided for @playbackReplayAction.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get playbackReplayAction;

  /// No description provided for @playbackCloseAction.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get playbackCloseAction;

  /// No description provided for @playbackRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get playbackRetryAction;

  /// No description provided for @playbackEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No memories to play yet'**
  String get playbackEmptyTitle;

  /// No description provided for @playbackEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add memories to this story, then come back for the journey.'**
  String get playbackEmptyBody;

  /// No description provided for @playbackLoadFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Playback is unavailable'**
  String get playbackLoadFailureTitle;

  /// No description provided for @playbackLoadFailureBody.
  ///
  /// In en, this message translates to:
  /// **'We could not load the memories for this story.'**
  String get playbackLoadFailureBody;

  /// No description provided for @playbackCameraFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Map movement paused'**
  String get playbackCameraFailureTitle;

  /// No description provided for @playbackCameraFailureBody.
  ///
  /// In en, this message translates to:
  /// **'The map could not move to the next memory. You can retry or close playback.'**
  String get playbackCameraFailureBody;

  /// No description provided for @playbackFinishedTitle.
  ///
  /// In en, this message translates to:
  /// **'Playback finished'**
  String get playbackFinishedTitle;

  /// No description provided for @playbackFinishedBody.
  ///
  /// In en, this message translates to:
  /// **'Replay this story journey or close playback.'**
  String get playbackFinishedBody;

  /// No description provided for @playbackNoPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'No photo'**
  String get playbackNoPhotoTitle;

  /// No description provided for @playbackPhotoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photo unavailable'**
  String get playbackPhotoUnavailable;

  /// No description provided for @playbackMemoryPhotoLabel.
  ///
  /// In en, this message translates to:
  /// **'Memory photo'**
  String get playbackMemoryPhotoLabel;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to stories'**
  String get notificationsBackLabel;

  /// No description provided for @notificationsMarkAllReadAction.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllReadAction;

  /// No description provided for @notificationsRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get notificationsRetryAction;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Story updates will appear here when something new happens.'**
  String get notificationsEmptyBody;

  /// No description provided for @notificationsLoadFailureTitle.
  ///
  /// In en, this message translates to:
  /// **'Could not load notifications'**
  String get notificationsLoadFailureTitle;

  /// No description provided for @notificationsMutationFailure.
  ///
  /// In en, this message translates to:
  /// **'Notification could not be updated. Please try again.'**
  String get notificationsMutationFailure;

  /// No description provided for @notificationsReferenceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This story item is no longer available'**
  String get notificationsReferenceUnavailable;

  /// No description provided for @notificationParticipantJoined.
  ///
  /// In en, this message translates to:
  /// **'{actor} joined a story'**
  String notificationParticipantJoined(String actor);

  /// No description provided for @notificationMemoryCreated.
  ///
  /// In en, this message translates to:
  /// **'{actor} added a memory'**
  String notificationMemoryCreated(String actor);

  /// No description provided for @notificationMemoryCreatedWithTitle.
  ///
  /// In en, this message translates to:
  /// **'{actor} added {memoryTitle}'**
  String notificationMemoryCreatedWithTitle(String actor, String memoryTitle);

  /// No description provided for @notificationPhotosAdded.
  ///
  /// In en, this message translates to:
  /// **'{actor} added photos'**
  String notificationPhotosAdded(String actor);

  /// No description provided for @notificationPhotosAddedWithTitle.
  ///
  /// In en, this message translates to:
  /// **'{actor} added photos to {memoryTitle}'**
  String notificationPhotosAddedWithTitle(String actor, String memoryTitle);

  /// No description provided for @notificationFailureUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your session needs attention. Please sign in again.'**
  String get notificationFailureUnauthorized;

  /// No description provided for @notificationFailureNotFound.
  ///
  /// In en, this message translates to:
  /// **'This notification is no longer available.'**
  String get notificationFailureNotFound;

  /// No description provided for @notificationFailureNetwork.
  ///
  /// In en, this message translates to:
  /// **'No network connection. Check your connection and try again.'**
  String get notificationFailureNetwork;

  /// No description provided for @notificationFailureTimeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out. Please try again.'**
  String get notificationFailureTimeout;

  /// No description provided for @notificationFailureServer.
  ///
  /// In en, this message translates to:
  /// **'Notifications are temporarily unavailable. Please try again later.'**
  String get notificationFailureServer;

  /// No description provided for @notificationFailureUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get notificationFailureUnknown;

  /// No description provided for @storiesOpenProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Open {displayName}\'s profile'**
  String storiesOpenProfileLabel(String displayName);

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back to stories'**
  String get profileBackLabel;

  /// No description provided for @profileCreatorLabel.
  ///
  /// In en, this message translates to:
  /// **'Memory Creator'**
  String get profileCreatorLabel;

  /// No description provided for @profileQuote.
  ///
  /// In en, this message translates to:
  /// **'Every memory deserves a place to live.'**
  String get profileQuote;

  /// No description provided for @profileAccountSection.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get profileAccountSection;

  /// No description provided for @profilePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile Photo'**
  String get profilePhotoTitle;

  /// No description provided for @profilePhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Google avatar for now'**
  String get profilePhotoSubtitle;

  /// No description provided for @profilePhotoCustomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Memory Story avatar'**
  String get profilePhotoCustomSubtitle;

  /// No description provided for @profileAvatarChooseAction.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get profileAvatarChooseAction;

  /// No description provided for @profileAvatarReplaceAction.
  ///
  /// In en, this message translates to:
  /// **'Replace photo'**
  String get profileAvatarReplaceAction;

  /// No description provided for @profileAvatarRemoveAction.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get profileAvatarRemoveAction;

  /// No description provided for @profileAvatarUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get profileAvatarUploading;

  /// No description provided for @profileAvatarFailure.
  ///
  /// In en, this message translates to:
  /// **'Profile photo could not be updated. Check your connection and try again.'**
  String get profileAvatarFailure;

  /// No description provided for @profileAvatarInvalidFailure.
  ///
  /// In en, this message translates to:
  /// **'Choose a JPEG or PNG photo under the upload limit.'**
  String get profileAvatarInvalidFailure;

  /// No description provided for @profileAvatarUnauthorizedFailure.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Sign in again before changing your photo.'**
  String get profileAvatarUnauthorizedFailure;

  /// No description provided for @profileDisplayNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get profileDisplayNameTitle;

  /// No description provided for @profileDisplayNameEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit display name'**
  String get profileDisplayNameEditTitle;

  /// No description provided for @profileDisplayNameFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get profileDisplayNameFieldLabel;

  /// No description provided for @profileDisplayNameSaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileDisplayNameSaveAction;

  /// No description provided for @profileDisplayNameSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get profileDisplayNameSaving;

  /// No description provided for @profileDisplayNameInvalidFailure.
  ///
  /// In en, this message translates to:
  /// **'Enter a display name.'**
  String get profileDisplayNameInvalidFailure;

  /// No description provided for @profileDisplayNameTooLongFailure.
  ///
  /// In en, this message translates to:
  /// **'Display name must be 255 characters or fewer.'**
  String get profileDisplayNameTooLongFailure;

  /// No description provided for @profileDisplayNameControlCharacterFailure.
  ///
  /// In en, this message translates to:
  /// **'Display name must stay on one line.'**
  String get profileDisplayNameControlCharacterFailure;

  /// No description provided for @profileDisplayNameFailure.
  ///
  /// In en, this message translates to:
  /// **'Display name could not be saved. Check your connection and try again.'**
  String get profileDisplayNameFailure;

  /// No description provided for @profileDisplayNameUnauthorizedFailure.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Sign in again before changing your name.'**
  String get profileDisplayNameUnauthorizedFailure;

  /// No description provided for @profileDisplayNameLocalPersistenceFailure.
  ///
  /// In en, this message translates to:
  /// **'Display name was saved, but could not be stored locally. Restart the app if it does not update.'**
  String get profileDisplayNameLocalPersistenceFailure;

  /// No description provided for @profileLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguageTitle;

  /// No description provided for @profileLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the app language'**
  String get profileLanguageSubtitle;

  /// No description provided for @languageSystemOption.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystemOption;

  /// No description provided for @languageSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use device language'**
  String get languageSystemSubtitle;

  /// No description provided for @languageRussianOption.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussianOption;

  /// No description provided for @languageEnglishOption.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglishOption;

  /// No description provided for @languageChangeFailure.
  ///
  /// In en, this message translates to:
  /// **'Language could not be saved. Please try again.'**
  String get languageChangeFailure;

  /// No description provided for @profileLegalSupportSection.
  ///
  /// In en, this message translates to:
  /// **'LEGAL & SUPPORT'**
  String get profileLegalSupportSection;

  /// No description provided for @profilePrivacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get profilePrivacyPolicyTitle;

  /// No description provided for @profilePrivacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How private memories are protected'**
  String get profilePrivacyPolicySubtitle;

  /// No description provided for @profileTermsOfUseTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get profileTermsOfUseTitle;

  /// No description provided for @profileTermsOfUseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The rules for using Memory Story'**
  String get profileTermsOfUseSubtitle;

  /// No description provided for @profileHelpSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get profileHelpSupportTitle;

  /// No description provided for @profileHelpSupportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Questions and support options'**
  String get profileHelpSupportSubtitle;

  /// No description provided for @profileAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Memory Story'**
  String get profileAboutTitle;

  /// No description provided for @profileAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App information'**
  String get profileAboutSubtitle;

  /// No description provided for @profileAccountActionsSection.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT ACTIONS'**
  String get profileAccountActionsSection;

  /// No description provided for @profileLogoutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'End this session on this device'**
  String get profileLogoutSubtitle;

  /// No description provided for @profileDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Profile'**
  String get profileDeleteTitle;

  /// No description provided for @profileDeleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your account'**
  String get profileDeleteSubtitle;

  /// No description provided for @profileDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete profile?'**
  String get profileDeleteConfirmTitle;

  /// No description provided for @profileDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account and removes your access to Memory Story. Stories that still need an owner must be resolved first.'**
  String get profileDeleteConfirmBody;

  /// No description provided for @profileDeleteConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get profileDeleteConfirmAction;

  /// No description provided for @profileDeletingAction.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get profileDeletingAction;

  /// No description provided for @profileDeleteOwnershipConflict.
  ///
  /// In en, this message translates to:
  /// **'One of your shared stories still needs an owner. Resolve story ownership before deleting your profile.'**
  String get profileDeleteOwnershipConflict;

  /// No description provided for @profileDeleteUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Sign in again before deleting your profile.'**
  String get profileDeleteUnauthorized;

  /// No description provided for @profileDeleteFailure.
  ///
  /// In en, this message translates to:
  /// **'Profile could not be deleted. Check your connection and try again.'**
  String get profileDeleteFailure;

  /// No description provided for @profileDeleteUnavailableAction.
  ///
  /// In en, this message translates to:
  /// **'Deletion unavailable'**
  String get profileDeleteUnavailableAction;

  /// No description provided for @profilePhotoPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'Profile photo editing is not available yet. Your Google avatar remains the current profile image.'**
  String get profilePhotoPlaceholderBody;

  /// No description provided for @profileDisplayNamePlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'Display name editing is not available yet. Your current Google display name remains visible.'**
  String get profileDisplayNamePlaceholderBody;

  /// No description provided for @profilePrivacyPolicyPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'The full privacy policy will be added before public release.'**
  String get profilePrivacyPolicyPlaceholderBody;

  /// No description provided for @profileTermsPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'The full terms of use will be added before public release.'**
  String get profileTermsPlaceholderBody;

  /// No description provided for @profileHelpPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'Help and support options will be added before public release.'**
  String get profileHelpPlaceholderBody;

  /// No description provided for @profileAboutPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'Memory Story is a private memories app for stories, places, photos, playback, and the people who share them.'**
  String get profileAboutPlaceholderBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
