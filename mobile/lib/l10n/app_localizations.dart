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

  /// No description provided for @checkingSession.
  ///
  /// In en, this message translates to:
  /// **'Checking your session…'**
  String get checkingSession;

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

  /// No description provided for @storiesNotificationUnavailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Notifications are not available yet'**
  String get storiesNotificationUnavailableLabel;

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

  /// No description provided for @storyDetailsMapAction.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get storyDetailsMapAction;

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
