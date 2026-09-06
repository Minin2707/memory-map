// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Georgian (`ka`).
class AppLocalizationsKa extends AppLocalizations {
  AppLocalizationsKa([String locale = 'ka']) : super(locale);

  @override
  String get appName => 'Memory Map';

  @override
  String get loginHeadline => 'ყოველ ადგილს თავისი ისტორია აქვს';

  @override
  String get loginDescription =>
      'შექმენით მოგონებების პირადი რუკა და გაუზიარეთ ის საყვარელ ადამიანებს.';

  @override
  String get continueWithGoogle => 'Google-ით გაგრძელება';

  @override
  String get signingIn => 'შესვლა…';

  @override
  String get loginLegalPrefix => 'გაგრძელებით თქვენ ეთანხმებით ჩვენს';

  @override
  String get privacyPolicy => 'კონფიდენციალურობის პოლიტიკას';

  @override
  String get termsOfUse => 'გამოყენების პირობებს';

  @override
  String get legalSeparator => 'და';

  @override
  String get authCancelled => 'შესვლა გაუქმდა.';

  @override
  String get googleAuthenticationUnavailable =>
      'ამ მოწყობილობაზე Google-ით შესვლა მიუწვდომელია.';

  @override
  String get googleAuthenticationFailed =>
      'Google-ით შესვლა ვერ მოხერხდა. სცადეთ ხელახლა.';

  @override
  String get backendUnauthorized =>
      'ავთენტიფიკაცია უარყოფილია. სცადეთ ხელახლა.';

  @override
  String get requestValidationFailed => 'მოთხოვნა არასწორია. სცადეთ ხელახლა.';

  @override
  String get networkUnavailable =>
      'ქსელთან კავშირი არ არის. შეამოწმეთ კავშირი და სცადეთ ხელახლა.';

  @override
  String get requestTimedOut => 'მოთხოვნის დრო ამოიწურა. სცადეთ ხელახლა.';

  @override
  String get serverFailure => 'სერვერი დროებით მიუწვდომელია. სცადეთ ხელახლა.';

  @override
  String get secureStorageFailure =>
      'სესიის უსაფრთხოდ შენახვა ვერ მოხერხდა. სცადეთ ხელახლა.';

  @override
  String get corruptSession =>
      'ლოკალური სესიის მონაცემები არასწორია. სცადეთ ხელახლა.';

  @override
  String get unknownAuthFailure => 'რაღაც არასწორად წავიდა. სცადეთ ხელახლა.';

  @override
  String get restoreSessionTitle => 'სესიის აღდგენა ვერ მოხერხდა';

  @override
  String get retry => 'ხელახლა ცდა';

  @override
  String get unexpectedErrorTitle => 'რაღაც არასწორად წავიდა';

  @override
  String get unexpectedErrorDescription => 'გადატვირთეთ აპი ან სცადეთ ხელახლა.';

  @override
  String get tryAgain => 'სცადეთ ხელახლა';

  @override
  String welcomeUser(String displayName) {
    return 'მოგესალმებით, $displayName';
  }

  @override
  String get fallbackDisplayName => 'მეგობარო';

  @override
  String get authenticatedSessionReady => 'ავთენტიფიცირებული სესია მზადაა';

  @override
  String get logOut => 'გასვლა';

  @override
  String get loggingOut => 'გასვლა…';

  @override
  String get tryLogoutAgain => 'გასვლის ხელახლა ცდა';

  @override
  String storiesGreeting(String displayName) {
    return 'გამარჯობა, $displayName! 👋';
  }

  @override
  String get storiesSubtitle => 'თქვენი გაზიარებული მოგონებები აქ ცხოვრობს';

  @override
  String get storiesSectionTitle => 'თქვენი ისტორიები';

  @override
  String get storiesCreateAction => 'ისტორიის შექმნა';

  @override
  String get storiesEmptyTitle => 'ისტორიები ჯერ არ არის';

  @override
  String get storiesEmptyDescription =>
      'შექმენით პირველი ისტორია და ერთად შეინახეთ მნიშვნელოვანი მომენტები';

  @override
  String get storiesLoadFailureTitle => 'ისტორიების ჩატვირთვა ვერ მოხერხდა';

  @override
  String get storiesRefreshFailureTitle => 'ისტორიების განახლება ვერ მოხერხდა';

  @override
  String get storyFailureValidation => 'მოთხოვნა არასწორია. სცადეთ ხელახლა.';

  @override
  String get storyFailureUnauthorized =>
      'სესიას ყურადღება სჭირდება. სცადეთ ხელახლა.';

  @override
  String get storyFailureNotFound => 'ისტორია მიუწვდომელია.';

  @override
  String get storyFailureNetworkUnavailable =>
      'ქსელთან კავშირი არ არის. შეამოწმეთ კავშირი და სცადეთ ხელახლა.';

  @override
  String get storyFailureRequestTimedOut =>
      'მოთხოვნის დრო ამოიწურა. სცადეთ ხელახლა.';

  @override
  String get storyFailureServerFailure =>
      'სერვერი დროებით მიუწვდომელია. სცადეთ ხელახლა.';

  @override
  String get storyFailureUnknown => 'რაღაც არასწორად წავიდა. სცადეთ ხელახლა.';

  @override
  String get storyRoleOwner => 'მფლობელი';

  @override
  String get storyRoleCoOwner => 'თანამფლობელი';

  @override
  String get storyRoleEditor => 'რედაქტორი';

  @override
  String get storyRoleViewer => 'მნახველი';

  @override
  String storyMemoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count მოგონება',
      one: '1 მოგონება',
      zero: 'მოგონებები არ არის',
    );
    return '$_temp0';
  }

  @override
  String storyParticipantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count მონაწილე',
      one: '1 მონაწილე',
    );
    return '$_temp0';
  }

  @override
  String get storyThumbnailLabel => 'ისტორიის ფოტო';

  @override
  String get storyThumbnailUnavailableLabel => 'ისტორიის ფოტო მიუწვდომელია';

  @override
  String get storiesNotificationUnavailableLabel =>
      'შეტყობინებები ჯერ მიუწვდომელია';

  @override
  String get storiesOpenNotificationsLabel => 'შეტყობინებების გახსნა';

  @override
  String storiesAvatarLabel(String displayName) {
    return '$displayName-ის ავატარი';
  }

  @override
  String storiesOpenStoryLabel(String title) {
    return 'ისტორიის გახსნა: $title';
  }

  @override
  String get cancel => 'გაუქმება';

  @override
  String get createStoryPageTitle => 'ისტორიის შექმნა';

  @override
  String get createStoryBackLabel => 'ისტორიებზე დაბრუნება';

  @override
  String get createStoryHeroTitle => 'ახალი ისტორია';

  @override
  String get createStoryHeroSubtitle =>
      'შექმენით სივრცე თქვენი საერთო მოგონებებისთვის';

  @override
  String get createStoryTitleLabel => 'ისტორიის სათაური';

  @override
  String get createStoryTitleHint => 'მაგალითი: ჩვენი ისტორია';

  @override
  String get createStoryTitleHelp =>
      'სათაური ხილული იქნება ისტორიის ყველა მონაწილისთვის';

  @override
  String get createStoryTitleRequired => 'შეიყვანეთ ისტორიის სათაური.';

  @override
  String get createStoryTitleBlank => 'ისტორიის სათაური ცარიელი ვერ იქნება.';

  @override
  String get createStoryDescriptionLabel => 'აღწერა';

  @override
  String get createStoryDescriptionOptional => 'არასავალდებულო';

  @override
  String get createStoryDescriptionHint =>
      'დაამატეთ მოკლე ჩანაწერი ამ ისტორიაზე';

  @override
  String get createStoryWhyTitle => 'რატომ არის სათაური მნიშვნელოვანი?';

  @override
  String get createStoryWhyDescription =>
      'კარგი სათაური ყველას ეხმარება გაიხსენოს, რატომ არის ეს ისტორია განსაკუთრებული.';

  @override
  String get createStoryIdeasTitle => 'სათაურის იდეები';

  @override
  String get createStoryIdeaOne => 'ჩვენი ისტორია';

  @override
  String get createStoryIdeaTwo => 'საუკეთესო მომენტები ერთად';

  @override
  String get createStoryIdeaThree => 'მოგზაურობები და თავგადასავლები';

  @override
  String get createStorySubmitButton => 'ისტორიის შექმნა';

  @override
  String get createStoryCreatingButton => 'ისტორია იქმნება...';

  @override
  String get createStoryCoverRemoveSelectionAction => 'არჩეული ყდის წაშლა';

  @override
  String get createStoryCoverUploading => 'ყდა იტვირთება...';

  @override
  String get createStoryCoverPartialTitle => 'ისტორია შეიქმნა';

  @override
  String get createStoryCoverPartialMessage =>
      'ისტორია შეიქმნა, მაგრამ ყდის ატვირთვა ვერ მოხერხდა.';

  @override
  String get createStoryCoverRetryAction => 'ყდის ატვირთვის ხელახლა ცდა';

  @override
  String get createStoryCoverContinueAction => 'გაგრძელება ყდის გარეშე';

  @override
  String get storyDetailsPageTitle => 'ისტორია';

  @override
  String get storyDetailsBackLabel => 'ისტორიებზე დაბრუნება';

  @override
  String get storyDetailsEditAction => 'ისტორიის რედაქტირება';

  @override
  String get storyDetailsLoadFailureTitle => 'ისტორიის ჩატვირთვა ვერ მოხერხდა';

  @override
  String get storyDetailsDescriptionTitle => 'ამ ისტორიის შესახებ';

  @override
  String get storyDetailsNoDescription => 'აღწერა ჯერ არ არის.';

  @override
  String get storyDetailsInfoTitle => 'ისტორიის ინფორმაცია';

  @override
  String get storyDetailsCreatedLabel => 'შექმნილია';

  @override
  String get storyDetailsUpdatedLabel => 'განახლებულია';

  @override
  String get storyDetailsRefreshFailureTitle =>
      'ისტორიის განახლება ვერ მოხერხდა';

  @override
  String get storyDetailsPeriodPresent => 'დღემდე';

  @override
  String get storyDetailsSectionsTitle => 'დათვალიერება';

  @override
  String get storyDetailsMemoriesAction => 'მოგონებები';

  @override
  String get storyDetailsParticipantsAction => 'მონაწილეები';

  @override
  String get storyDetailsParticipantsManageAction => 'მართვა';

  @override
  String get storyDetailsMapAction => 'რუკა';

  @override
  String get storyDetailsTimelineAction => 'ქრონოლოგია';

  @override
  String get storyDetailsRecentMemoriesTitle => 'ბოლო მოგონებები';

  @override
  String get storyDetailsSeeAllAction => 'ყველას ნახვა';

  @override
  String get storyDetailsPlaybackStoryAction => 'ისტორიის დაკვრა';

  @override
  String get deleteStoryAction => 'ისტორიის წაშლა';

  @override
  String get deleteStoryDialogTitle => 'წავშალოთ ისტორია?';

  @override
  String get deleteStoryDialogBody =>
      'ეს ისტორია და მისი მოგონებები სამუდამოდ წაიშლება. მოქმედების გაუქმება შეუძლებელია.';

  @override
  String get deleteStoryCancel => 'გაუქმება';

  @override
  String get deleteStoryConfirm => 'წაშლა';

  @override
  String get deleteStoryDeleting => 'ისტორია იშლება...';

  @override
  String get soundtrackTitle => 'საუნდტრეკი';

  @override
  String get soundtrackNoMusic => 'მუსიკის გარეშე';

  @override
  String get soundtrackLoading => 'საუნდტრეკი იტვირთება...';

  @override
  String get soundtrackLoadFailureTitle => 'საუნდტრეკის ჩატვირთვა ვერ მოხერხდა';

  @override
  String get soundtrackChooseTitle => 'საუნდტრეკის არჩევა';

  @override
  String get soundtrackReadOnly => 'მხოლოდ წაკითხვა';

  @override
  String get soundtrackCurrentSelection => 'მიმდინარე არჩევანი';

  @override
  String get soundtrackCurrentlyUnavailable => 'ამჟამად მიუწვდომელია';

  @override
  String get soundtrackUnavailableEditable =>
      'ამჟამად მიუწვდომელია. აირჩიეთ სხვა ტრეკი ან მუსიკის გარეშე.';

  @override
  String get soundtrackCatalogTitle => 'ხელმისაწვდომი საუნდტრეკები';

  @override
  String get soundtrackCatalogLoadFailureTitle =>
      'საუნდტრეკების ჩატვირთვა ვერ მოხერხდა';

  @override
  String get soundtrackCatalogEmpty =>
      'საუნდტრეკები ამჟამად ხელმისაწვდომი არ არის.';

  @override
  String get soundtrackSelected => 'არჩეულია';

  @override
  String get soundtrackUpdateFailure =>
      'საუნდტრეკის განახლება ვერ მოხერხდა. სცადეთ ხელახლა.';

  @override
  String get musicFailureUnavailable => 'მუსიკა მიუწვდომელია. სცადეთ ხელახლა.';

  @override
  String get musicFailureNetworkUnavailable =>
      'ქსელთან კავშირი არ არის. შეამოწმეთ კავშირი და სცადეთ ხელახლა.';

  @override
  String get musicFailureRequestTimedOut =>
      'მოთხოვნის დრო ამოიწურა. სცადეთ ხელახლა.';

  @override
  String get musicFailureUnknown => 'რაღაც არასწორად წავიდა. სცადეთ ხელახლა.';

  @override
  String get participantsPageTitle => 'მონაწილეები';

  @override
  String get participantsBack => 'ისტორიაზე დაბრუნება';

  @override
  String get participantsHeaderTitle => 'ადამიანები ამ ისტორიაში';

  @override
  String participantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count მონაწილე',
      one: '1 მონაწილე',
      zero: 'მონაწილეები არ არის',
    );
    return '$_temp0';
  }

  @override
  String get participantsSectionTitle => 'მონაწილეები';

  @override
  String get participantsSectionSubtitle =>
      'როლები განსაზღვრავს, რისი გაკეთება შეუძლია თითოეულ მონაწილეს ამ ისტორიაში.';

  @override
  String get participantsInvite => 'მონაწილის მოწვევა';

  @override
  String get participantsLeaveStory => 'ისტორიის დატოვება';

  @override
  String get participantsLeaveConfirmTitle => 'დატოვოთ ისტორია?';

  @override
  String get participantsLeaveConfirmBody =>
      'თქვენ დაკარგავთ წვდომას ამ ისტორიაზე. ხელახლა შესაერთებლად ახალი მოწვევა დაგჭირდებათ. თუ ბოლო მფლობელი ხართ, სერვერმა შეიძლება უარყოს ეს მოქმედება.';

  @override
  String get participantsLeaveConfirmAction => 'დატოვება';

  @override
  String get participantsLeaveCancel => 'გაუქმება';

  @override
  String get participantsLeaving => 'ისტორია იტოვება...';

  @override
  String get participantsCurrentUser => 'თქვენ';

  @override
  String get participantsEmptyTitle => 'საჩვენებელი მონაწილეები არ არის';

  @override
  String get participantsEmptyBody =>
      'მონაწილეთა სია ახლა ცარიელია. სცადეთ განახლება ცოტა ხანში.';

  @override
  String get participantsRetry => 'ხელახლა ცდა';

  @override
  String get participantsRefreshFailed => 'მონაწილეთა განახლება ვერ მოხერხდა';

  @override
  String get participantsLoadFailed => 'მონაწილეთა ჩატვირთვა ვერ მოხერხდა';

  @override
  String get participantsRemoveAction => 'წაშლა';

  @override
  String participantsRemoveConfirmTitle(String displayName) {
    return 'წავშალოთ $displayName?';
  }

  @override
  String participantsRemoveConfirmBody(String displayName) {
    return '$displayName დაკარგავს წვდომას ამ ისტორიაზე. ხელახლა შემოერთება ახალი მოწვევით შეეძლება.';
  }

  @override
  String get participantsRemoveConfirmAction => 'წაშლა';

  @override
  String get participantsRemoveCancel => 'გაუქმება';

  @override
  String get participantsRemoving => 'მონაწილე იშლება...';

  @override
  String participantsRemoveSuccess(String displayName) {
    return '$displayName წაიშალა.';
  }

  @override
  String participantsAvatarLabel(String displayName) {
    return '$displayName-ის ავატარი';
  }

  @override
  String participantsRemoveParticipantLabel(String displayName) {
    return '$displayName-ის წაშლა';
  }

  @override
  String get participantFailureValidation =>
      'მოთხოვნა არასწორია. სცადეთ ხელახლა.';

  @override
  String get participantFailureUnauthorized =>
      'სესიას ყურადღება სჭირდება. სცადეთ ხელახლა.';

  @override
  String get participantFailureNotFound => 'მონაწილეები მიუწვდომელია.';

  @override
  String get participantFailureLastOwner =>
      'ბოლო მფლობელი ვერ დატოვებს ამ ისტორიას.';

  @override
  String get participantFailureCannotRemoveSelf =>
      'საკუთარი თავის წასაშლელად გამოიყენეთ „ისტორიის დატოვება“.';

  @override
  String get participantFailureOwnerCannotBeRemoved =>
      'მფლობელების წაშლა აქედან შეუძლებელია.';

  @override
  String get participantFailureNetwork =>
      'ქსელთან კავშირი არ არის. შეამოწმეთ კავშირი და სცადეთ ხელახლა.';

  @override
  String get participantFailureTimeout =>
      'მოთხოვნის დრო ამოიწურა. სცადეთ ხელახლა.';

  @override
  String get participantFailureServer =>
      'სერვერი დროებით მიუწვდომელია. სცადეთ ხელახლა.';

  @override
  String get participantFailureUnknown =>
      'რაღაც არასწორად წავიდა. სცადეთ ხელახლა.';

  @override
  String get storyMemoriesPageTitle => 'მოგონებები';

  @override
  String get storyMemoriesBackLabel => 'ისტორიაზე დაბრუნება';

  @override
  String get storyMemoriesRefreshAction => 'მოგონებების განახლება';

  @override
  String get storyMemoriesHeaderTitle => 'ისტორიის მოგონებები';

  @override
  String storyMemoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count მოგონება',
      one: '1 მოგონება',
      zero: 'მოგონებები არ არის',
    );
    return '$_temp0';
  }

  @override
  String get storyMemoriesCreate => 'მოგონების დამატება';

  @override
  String get storyMemoriesEmptyTitle => 'მოგონებები ჯერ არ არის';

  @override
  String get storyMemoriesEmptyBody =>
      'დაამატეთ პირველი მოგონება, როცა შესანახი რამ მოხდება.';

  @override
  String get storyMemoriesLoadFailureTitle =>
      'მოგონებების ჩატვირთვა ვერ მოხერხდა';

  @override
  String get storyMemoriesRefreshFailureTitle =>
      'მოგონებების განახლება ვერ მოხერხდა';

  @override
  String get storyTimelinePageTitle => 'ქრონოლოგია';

  @override
  String get storyTimelineBackLabel => 'ისტორიაზე დაბრუნება';

  @override
  String get storyTimelineRefreshAction => 'ქრონოლოგიის განახლება';

  @override
  String get storyTimelineCreate => 'მოგონების დამატება';

  @override
  String get storyTimelineEmptyTitle => 'ქრონოლოგია ჯერ არ არის';

  @override
  String get storyTimelineEmptyBody =>
      'დაამატეთ მოგონებები ამ ისტორიის ქრონოლოგიის შესაქმნელად.';

  @override
  String get storyTimelineLoadFailureTitle =>
      'ქრონოლოგიის ჩატვირთვა ვერ მოხერხდა';

  @override
  String get storyTimelineRefreshFailureTitle =>
      'ქრონოლოგიის განახლება ვერ მოხერხდა';

  @override
  String get storyMapPageTitle => 'რუკა';

  @override
  String get storyMapBackLabel => 'ისტორიაზე დაბრუნება';

  @override
  String get storyMapShowAllAction => 'ყველას ჩვენება';

  @override
  String get storyMapRefreshAction => 'რუკის განახლება';

  @override
  String get storyMapShowDetailsAction => 'დეტალების ჩვენება';

  @override
  String get storyMapEmptyTitle => 'რუკაზე მოგონებები ჯერ არ არის';

  @override
  String get storyMapEmptyBody =>
      'შენახული ადგილების მქონე მოგონებები აქ გამოჩნდება.';

  @override
  String get storyMapLoadFailureTitle => 'რუკის ჩატვირთვა ვერ მოხერხდა';

  @override
  String get storyMapRefreshFailureTitle => 'რუკის განახლება ვერ მოხერხდა';

  @override
  String memoryOpenLabel(String title) {
    return 'მოგონების გახსნა: $title';
  }

  @override
  String get memoryFailureValidation => 'მოთხოვნა არასწორია. სცადეთ ხელახლა.';

  @override
  String get memoryFailureUnauthorized =>
      'სესიას ყურადღება სჭირდება. სცადეთ ხელახლა.';

  @override
  String get memoryFailureStoryUnavailable =>
      'ისტორიის მოგონებები მიუწვდომელია.';

  @override
  String get memoryFailureNotFound => 'მოგონება მიუწვდომელია.';

  @override
  String get memoryFailureCreationUnavailable =>
      'აქედან მოგონების შექმნა შეუძლებელია.';

  @override
  String get memoryFailureUpdateUnavailable =>
      'აქედან მოგონების განახლება შეუძლებელია.';

  @override
  String get memoryFailureDeletionUnavailable =>
      'აქედან მოგონების წაშლა შეუძლებელია.';

  @override
  String get memoryFailureNetworkUnavailable =>
      'ქსელთან კავშირი არ არის. შეამოწმეთ კავშირი და სცადეთ ხელახლა.';

  @override
  String get memoryFailureRequestTimedOut =>
      'მოთხოვნის დრო ამოიწურა. სცადეთ ხელახლა.';

  @override
  String get memoryFailureServerFailure =>
      'სერვერი დროებით მიუწვდომელია. სცადეთ ხელახლა.';

  @override
  String get memoryFailureUnknown => 'რაღაც არასწორად წავიდა. სცადეთ ხელახლა.';

  @override
  String get createMemoryPageTitle => 'მოგონების დამატება';

  @override
  String get createMemoryBackLabel => 'მოგონებებზე დაბრუნება';

  @override
  String get createMemoryTitleLabel => 'სათაური';

  @override
  String get createMemoryTitleHint => 'მაგალითი: მზის ჩასვლა ბალიზე';

  @override
  String get createMemoryTitleRequired => 'შეიყვანეთ მოგონების სათაური.';

  @override
  String get createMemoryTitleBlank => 'მოგონების სათაური ცარიელი ვერ იქნება.';

  @override
  String get createMemoryTitleMax =>
      'მოგონების სათაური უნდა იყოს 255 სიმბოლო ან ნაკლები.';

  @override
  String get createMemoryDescriptionLabel => 'აღწერა';

  @override
  String get createMemoryDescriptionHint => 'დაამატეთ ჩანაწერი ამ მომენტზე';

  @override
  String get createMemoryPlaceNameLabel => 'ადგილის სახელი';

  @override
  String get createMemoryPlaceNameHint => 'მაგალითი: სემინიაკის პლაჟი';

  @override
  String get createMemoryPlaceNameMax =>
      'ადგილის სახელი უნდა იყოს 255 სიმბოლო ან ნაკლები.';

  @override
  String get createMemoryOptionalLabel => 'არასავალდებულო';

  @override
  String get createMemoryEventDateLabel => 'თარიღი';

  @override
  String get createMemoryEventDateEmpty => 'თარიღი არჩეული არ არის';

  @override
  String get createMemoryChooseDate => 'არჩევა';

  @override
  String get createMemoryChangeDate => 'შეცვლა';

  @override
  String get createMemoryDateRequired => 'აირჩიეთ თარიღი.';

  @override
  String get createMemoryLocationLabel => 'მდებარეობა';

  @override
  String get createMemoryLocationEmpty => 'მდებარეობა არჩეული არ არის';

  @override
  String get createMemoryLocationSelected => 'მდებარეობა არჩეულია';

  @override
  String get createMemoryChooseLocation => 'არჩევა';

  @override
  String get createMemoryChangeLocation => 'შეცვლა';

  @override
  String get createMemoryLocationRequired => 'აირჩიეთ მდებარეობა.';

  @override
  String get createMemorySubmitButton => 'მოგონების შექმნა';

  @override
  String get createMemorySubmittingButton => 'მოგონება იქმნება...';

  @override
  String get editMemoryPageTitle => 'მოგონების რედაქტირება';

  @override
  String get editMemoryBackLabel => 'მოგონებაზე დაბრუნება';

  @override
  String get editMemorySaveButton => 'ცვლილებების შენახვა';

  @override
  String get editMemorySavingButton => 'ინახება...';

  @override
  String get editMemoryNoChangesHint => 'შესანახად შეიტანეთ ცვლილება.';

  @override
  String get memoryDetailsPageTitle => 'მოგონება';

  @override
  String get memoryDetailsBackLabel => 'მოგონებებზე დაბრუნება';

  @override
  String get memoryDetailsRefreshAction => 'მოგონების განახლება';

  @override
  String get memoryDetailsEditAction => 'მოგონების რედაქტირება';

  @override
  String get memoryDetailsDeleteAction => 'მოგონების წაშლა';

  @override
  String get memoryDetailsLoadFailureTitle =>
      'მოგონების ჩატვირთვა ვერ მოხერხდა';

  @override
  String get memoryDetailsRefreshFailureTitle =>
      'მოგონების განახლება ვერ მოხერხდა';

  @override
  String get memoryDetailsDescriptionTitle => 'მოგონების ჩანაწერი';

  @override
  String get memoryDetailsNoDescription => 'აღწერა ჯერ არ არის.';

  @override
  String get memoryDetailsPlaceTitle => 'ადგილი';

  @override
  String get memoryDetailsNoPlace => 'ადგილის სახელი ჯერ არ არის.';

  @override
  String get memoryDetailsOpenOnMapAction => 'რუკაზე გახსნა';

  @override
  String get memoryDetailsMapUnavailable =>
      'რუკის წინასწარი ნახვა მიუწვდომელია.';

  @override
  String get memoryMediaTitle => 'ფოტოები';

  @override
  String get memoryMediaRefreshAction => 'ფოტოების განახლება';

  @override
  String get memoryMediaAddPhotoAction => 'ფოტოს დამატება';

  @override
  String get memoryMediaEmpty => 'ფოტოები ჯერ არ არის.';

  @override
  String get memoryMediaSelectingPhoto => 'ფოტოს არჩევა...';

  @override
  String get memoryMediaPreparingPhoto => 'ფოტო მზადდება...';

  @override
  String get memoryMediaUploadingPhoto => 'ფოტო იტვირთება...';

  @override
  String get memoryMediaOpenPhotoLabel => 'ფოტოს გახსნა';

  @override
  String get memoryMediaClosePhotoAction => 'ფოტოს დახურვა';

  @override
  String get deletePhotoAction => 'ფოტოს წაშლა';

  @override
  String get deletePhotoDialogTitle => 'წავშალოთ ფოტო?';

  @override
  String get deletePhotoDialogBody => 'ეს ფოტო სამუდამოდ წაიშლება.';

  @override
  String get deletePhotoCancel => 'გაუქმება';

  @override
  String get deletePhotoConfirm => 'წაშლა';

  @override
  String get deletePhotoFailure => 'ფოტოს წაშლა ვერ მოხერხდა. სცადეთ ხელახლა.';

  @override
  String get mediaFailureValidation =>
      'ფოტოს მოთხოვნა არასწორია. სცადეთ ხელახლა.';

  @override
  String get mediaFailureUnauthorized =>
      'სესიას ყურადღება სჭირდება. სცადეთ ხელახლა.';

  @override
  String get mediaFailureUnavailable => 'ფოტოები მიუწვდომელია.';

  @override
  String get mediaFailureUploadUnavailable =>
      'აქედან ფოტოს ატვირთვა შეუძლებელია.';

  @override
  String get mediaFailureNetworkUnavailable =>
      'ქსელთან კავშირი არ არის. შეამოწმეთ კავშირი და სცადეთ ხელახლა.';

  @override
  String get mediaFailureRequestTimedOut =>
      'მოთხოვნის დრო ამოიწურა. სცადეთ ხელახლა.';

  @override
  String get mediaFailureServerFailure =>
      'სერვერი დროებით მიუწვდომელია. სცადეთ ხელახლა.';

  @override
  String get mediaFailurePreprocessing =>
      'ამ ფოტოს მომზადება ვერ მოხერხდა. აირჩიეთ სხვა სურათი.';

  @override
  String get mediaFailureUnknown => 'რაღაც არასწორად წავიდა. სცადეთ ხელახლა.';

  @override
  String get deleteMemoryDialogTitle => 'წავშალოთ მოგონება?';

  @override
  String get deleteMemoryDialogBody =>
      'ეს მოგონება სამუდამოდ წაიშლება. მოქმედების გაუქმება შეუძლებელია.';

  @override
  String get deleteMemoryCancel => 'გაუქმება';

  @override
  String get deleteMemoryConfirm => 'წაშლა';

  @override
  String get deleteMemoryDeleting => 'მოგონება იშლება...';

  @override
  String get locationPickerTitle => 'ადგილის არჩევა';

  @override
  String get locationPickerBackLabel => 'უკან';

  @override
  String get locationPickerInstruction =>
      'შეეხეთ რუკას, რათა აირჩიოთ ზუსტი წერტილი ამ მოგონებისთვის.';

  @override
  String get locationPickerSelectedTitle => 'მდებარეობა არჩეულია';

  @override
  String get locationPickerSelectedDescription =>
      'დაადასტურეთ, როცა პინი იმ ადგილს აღნიშნავს, რომლის შენახვაც გსურთ.';

  @override
  String get locationPickerNoSelectionTitle => 'მდებარეობა არჩეული არ არის';

  @override
  String get locationPickerNoSelectionDescription =>
      'დადასტურებამდე აირჩიეთ წერტილი რუკაზე.';

  @override
  String get locationPickerConfirmAction => 'მდებარეობის დადასტურება';

  @override
  String get locationPickerMapLoading => 'რუკა იტვირთება...';

  @override
  String get locationPickerMapUnavailable =>
      'რუკა მიუწვდომელია. სცადეთ მოგვიანებით.';

  @override
  String get editStoryPageTitle => 'ისტორიის რედაქტირება';

  @override
  String get editStoryBackLabel => 'ისტორიაზე დაბრუნება';

  @override
  String get editStoryHeroTitle => 'ისტორიის დეტალები';

  @override
  String get editStoryHeroSubtitle =>
      'განაახლეთ სახელი და ჩანაწერი, რომელსაც ისტორიის მონაწილეები ხედავენ';

  @override
  String get editStoryCoverLabel => 'ყდა';

  @override
  String get editStoryCoverNoPhoto => 'ყდის ფოტო არ არის';

  @override
  String get editStoryCoverPhotoLabel => 'ისტორიის ყდის ფოტო';

  @override
  String get editStoryCoverChooseAction => 'ყდის არჩევა';

  @override
  String get editStoryCoverChangeAction => 'ყდის შეცვლა';

  @override
  String get editStoryCoverRemoveAction => 'ყდის წაშლა';

  @override
  String get editStoryCoverSelecting => 'ფოტოს არჩევა...';

  @override
  String get editStoryCoverPreparing => 'ფოტო მზადდება...';

  @override
  String get editStoryCoverUploading => 'ყდა განახლდება...';

  @override
  String get editStoryCoverRemoving => 'ყდა იშლება...';

  @override
  String get editStoryCoverUpdatedFeedback => 'ყდა განახლდა';

  @override
  String get editStoryCoverRemovedFeedback => 'ყდა წაიშალა';

  @override
  String get editStoryCoverAutosaveHint =>
      'ყდის ცვლილებები ავტომატურად ინახება.';

  @override
  String get editStoryTitleLabel => 'ისტორიის სათაური';

  @override
  String get editStoryTitleHint => 'მაგალითი: ჩვენი ისტორია';

  @override
  String get editStoryTitleHelp =>
      'სათაური ხილული რჩება ისტორიის ყველა მონაწილისთვის';

  @override
  String get editStoryTitleRequired => 'შეიყვანეთ ისტორიის სათაური.';

  @override
  String get editStoryTitleBlank => 'ისტორიის სათაური ცარიელი ვერ იქნება.';

  @override
  String get editStoryDescriptionLabel => 'აღწერა';

  @override
  String get editStoryDescriptionOptional => 'არასავალდებულო';

  @override
  String get editStoryDescriptionHint => 'დაამატეთ მოკლე ჩანაწერი ამ ისტორიაზე';

  @override
  String get editStoryDescriptionHelp =>
      'გაასუფთავეთ ველი არსებული აღწერის მოსაშორებლად';

  @override
  String get editStorySaveButton => 'ცვლილებების შენახვა';

  @override
  String get editStorySavingButton => 'ინახება...';

  @override
  String get editStoryNoChangesHint => 'შესანახად შეიტანეთ ცვლილება.';

  @override
  String get editStoryUnavailableTitle => 'რედაქტირება მიუწვდომელია';

  @override
  String get editStoryUnavailableDescription =>
      'ამ ისტორიის რედაქტირება აქედან შეუძლებელია.';

  @override
  String get editStoryUnavailableBackAction => 'ისტორიაზე დაბრუნება';

  @override
  String get invitePageTitle => 'მონაწილის მოწვევა';

  @override
  String get inviteCreatedPageTitle => 'მოწვევა შეიქმნა';

  @override
  String get inviteBackLabel => 'ისტორიაზე დაბრუნება';

  @override
  String get inviteHeroTitle => 'მოიწვიეთ ახლობელი ადამიანი';

  @override
  String get inviteHeroSubtitle =>
      'გაუზიარეთ ერთჯერადი მოწვევის ბმული, რათა თქვენს ისტორიას შეუერთდეს.';

  @override
  String get inviteLinkLabel => 'მოწვევის ბმული';

  @override
  String get inviteSingleUseDescription =>
      'ერთჯერადი გამოყენება. მიღების შემდეგ ბმული აღარ იმუშავებს.';

  @override
  String get inviteExpirationLabel => 'ვადა იწურება';

  @override
  String get inviteExpirationDescription =>
      'მოწვევა ძალაშია სერვერის მიერ დაბრუნებულ თარიღამდე.';

  @override
  String get inviteTargetRoleTitle => 'წვდომის არჩევა';

  @override
  String get inviteRoleCoOwnerLabel => 'თანაავტორი';

  @override
  String get inviteRoleCoOwnerDescription =>
      'შეუძლია ისტორიისა და მოგონებების მართვა.';

  @override
  String get inviteRoleEditorLabel => 'რედაქტორი';

  @override
  String get inviteRoleEditorDescription =>
      'შეუძლია მოგონებების დამატება და საკუთარი მოგონებების რედაქტირება.';

  @override
  String get inviteRoleViewerLabel => 'მხოლოდ ნახვა';

  @override
  String get inviteRoleViewerDescription =>
      'შეუძლია ისტორიისა და მოგონებების ნახვა.';

  @override
  String get inviteWhatCanDoTitle => 'რა შეგიძლიათ გააკეთოთ ამ ბმულით?';

  @override
  String get inviteInstructionShare => 'გააზიარეთ ნებისმიერ მესენჯერში.';

  @override
  String get inviteInstructionCopy => 'დააკოპირეთ და თავად გაუგზავნეთ.';

  @override
  String get inviteInstructionOneUse =>
      'სთხოვეთ მიმღებს გამოიყენოს მხოლოდ ერთხელ.';

  @override
  String get inviteCreateButton => 'მოწვევის შექმნა';

  @override
  String get inviteCreatingButton => 'მოწვევა იქმნება...';

  @override
  String get inviteSuccessTitle => 'მოწვევა მზადაა!';

  @override
  String get inviteSuccessSubtitle =>
      'გაუზიარეთ ბმული ახლობელ ადამიანს. ის ერთჯერადი და უსაფრთხოა.';

  @override
  String get inviteLinkSemanticsLabel => 'მოწვევის ბმული';

  @override
  String get inviteCopyAction => 'კოპირება';

  @override
  String get inviteCopiedFeedback => 'მოწვევის ბმული დაკოპირდა.';

  @override
  String get inviteCopyFailure => 'მოწვევის ბმულის კოპირება ვერ მოხერხდა.';

  @override
  String get inviteShareAction => 'გაზიარება';

  @override
  String get inviteShareReadyFeedback => 'გაზიარების ვარიანტები გაიხსნა.';

  @override
  String get inviteShareFailure => 'მოწვევის ბმულის გაზიარება ვერ მოხერხდა.';

  @override
  String get inviteLinkCannotBeRestoredWarning =>
      'ამ ეკრანიდან გასვლამდე დააკოპირეთ ან გააზიარეთ ბმული. მოგვიანებით მისი ჩვენება შეუძლებელი იქნება.';

  @override
  String get inviteImportantTitle => 'მნიშვნელოვანი';

  @override
  String get inviteImportantSingleUse => 'ეს ბმული მხოლოდ ერთხელ გამოიყენება.';

  @override
  String get inviteImportantAfterAccept =>
      'მოწვევის მიღების შემდეგ ბმული არავალიდური ხდება.';

  @override
  String get inviteImportantExpiration =>
      'მოწვევა ავტომატურად იწურება ვადის გასვლის შემდეგ.';

  @override
  String get inviteDoneAction => 'დასრულება';

  @override
  String get inviteFailureValidation =>
      'მოწვევის მოთხოვნა არასწორია. სცადეთ ხელახლა.';

  @override
  String get inviteFailureUnauthorized =>
      'სესიას ყურადღება სჭირდება. სცადეთ ხელახლა.';

  @override
  String get inviteFailureNotFound => 'ეს ისტორია მოწვევებისთვის მიუწვდომელია.';

  @override
  String get inviteFailureNetworkUnavailable =>
      'ქსელთან კავშირი არ არის. შეამოწმეთ კავშირი და სცადეთ ხელახლა.';

  @override
  String get inviteFailureRequestTimedOut =>
      'მოთხოვნის დრო ამოიწურა. სცადეთ ხელახლა.';

  @override
  String get inviteFailureServerFailure =>
      'სერვერი დროებით მიუწვდომელია. სცადეთ ხელახლა.';

  @override
  String get inviteFailureUnknown => 'რაღაც არასწორად წავიდა. სცადეთ ხელახლა.';

  @override
  String get acceptInvitePageTitle => 'მოწვევა';

  @override
  String get acceptInviteBackLabel => 'ისტორიებზე დაბრუნება';

  @override
  String get acceptInviteHeroTitle => 'თქვენ მიგიწვიეს ისტორიაში';

  @override
  String get acceptInviteHeroDescription =>
      'მიიღეთ მოწვევა შესაერთებლად. წვდომის დადასტურების შემდეგ ისტორიას გაჩვენებთ.';

  @override
  String get acceptInviteDetailsAccessTitle => 'პირადი წვდომა';

  @override
  String get acceptInviteDetailsAccessBody =>
      'ისტორიის დეტალები დამალულია, სანამ მოწვევას მიიღებთ.';

  @override
  String get acceptInviteDetailsSingleUseTitle => 'ერთჯერადი ბმული';

  @override
  String get acceptInviteDetailsSingleUseBody =>
      'მოწვევის მიღება მხოლოდ ერთხელ შეიძლება და მას შეიძლება ვადა გაუვიდეს.';

  @override
  String get acceptInviteAcceptAction => 'მოწვევის მიღება';

  @override
  String get acceptInviteAcceptingAction => 'მოწვევა მიიღება...';

  @override
  String get acceptInviteRetryAction => 'ხელახლა ცდა';

  @override
  String get acceptInviteCancelAction => 'გაუქმება';

  @override
  String get acceptInviteBackToStoriesAction => 'ისტორიებზე დაბრუნება';

  @override
  String get acceptInviteInvalidLinkTitle => 'მოწვევის ბმული მიუწვდომელია';

  @override
  String get acceptInviteInvalidLinkDescription =>
      'ამ მოწვევის გახსნა შეუძლებელია.';

  @override
  String get acceptInviteUnavailable => 'ამ მოწვევის მიღება შეუძლებელია.';

  @override
  String get acceptInviteFailureUnauthorized =>
      'სესიას ყურადღება სჭირდება. გთხოვთ, ხელახლა შეხვიდეთ.';

  @override
  String get acceptInviteFailureUnknown =>
      'რაღაც არასწორად წავიდა. სცადეთ ხელახლა.';

  @override
  String get acceptInviteAcceptSemanticsLabel => 'მოწვევის მიღება';

  @override
  String get acceptInviteCancelSemanticsLabel => 'მოწვევის გაუქმება';

  @override
  String get acceptInviteErrorSemanticsLabel => 'მოწვევის შეცდომა';

  @override
  String get playbackTitle => 'დაკვრა';

  @override
  String get playbackContextLabel => 'ისტორიის დაკვრა';

  @override
  String playbackProgressLabel(int current, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total მოგონება',
      one: '1 მოგონება',
    );
    return '$current / $_temp0';
  }

  @override
  String get playbackPreviousAction => 'წინა';

  @override
  String get playbackNextAction => 'შემდეგი';

  @override
  String get playbackPauseAction => 'პაუზა';

  @override
  String get playbackResumeAction => 'გაგრძელება';

  @override
  String get playbackReplayAction => 'ხელახლა დაკვრა';

  @override
  String get playbackCloseAction => 'დახურვა';

  @override
  String get playbackRetryAction => 'ხელახლა ცდა';

  @override
  String get playbackEmptyTitle => 'დასაკრავი მოგონებები ჯერ არ არის';

  @override
  String get playbackEmptyBody =>
      'დაამატეთ მოგონებები ამ ისტორიაში და შემდეგ დაბრუნდით მოგზაურობისთვის.';

  @override
  String get playbackLoadFailureTitle => 'დაკვრა მიუწვდომელია';

  @override
  String get playbackLoadFailureBody =>
      'ამ ისტორიის მოგონებების ჩატვირთვა ვერ შევძელით.';

  @override
  String get playbackCameraFailureTitle => 'რუკის მოძრაობა შეჩერდა';

  @override
  String get playbackCameraFailureBody =>
      'რუკა შემდეგ მოგონებაზე ვერ გადავიდა. შეგიძლიათ სცადოთ ხელახლა ან დახუროთ დაკვრა.';

  @override
  String get playbackFinishedTitle => 'დაკვრა დასრულდა';

  @override
  String get playbackFinishedBody =>
      'გაიმეორეთ ამ ისტორიის მოგზაურობა ან დახურეთ დაკვრა.';

  @override
  String get playbackNoPhotoTitle => 'ფოტო არ არის';

  @override
  String get playbackPhotoUnavailable => 'ფოტო მიუწვდომელია';

  @override
  String get playbackMemoryPhotoLabel => 'მოგონების ფოტო';

  @override
  String get notificationsTitle => 'შეტყობინებები';

  @override
  String get notificationsBackLabel => 'ისტორიებზე დაბრუნება';

  @override
  String get notificationsMarkAllReadAction => 'ყველას წაკითხულად მონიშვნა';

  @override
  String get notificationsRetryAction => 'ხელახლა ცდა';

  @override
  String get notificationsEmptyTitle => 'შეტყობინებები ჯერ არ არის';

  @override
  String get notificationsEmptyBody =>
      'ისტორიის განახლებები აქ გამოჩნდება, როცა რამე ახალი მოხდება.';

  @override
  String get notificationsLoadFailureTitle =>
      'შეტყობინებების ჩატვირთვა ვერ მოხერხდა';

  @override
  String get notificationsMutationFailure =>
      'შეტყობინების განახლება ვერ მოხერხდა. სცადეთ ხელახლა.';

  @override
  String get notificationsReferenceUnavailable =>
      'ეს ისტორიის ელემენტი აღარ არის ხელმისაწვდომი';

  @override
  String notificationParticipantJoined(String actor) {
    return '$actor შეუერთდა ისტორიას';
  }

  @override
  String notificationMemoryCreated(String actor) {
    return '$actor დაამატა მოგონება';
  }

  @override
  String notificationMemoryCreatedWithTitle(String actor, String memoryTitle) {
    return '$actor დაამატა $memoryTitle';
  }

  @override
  String notificationPhotosAdded(String actor) {
    return '$actor დაამატა ფოტოები';
  }

  @override
  String notificationPhotosAddedWithTitle(String actor, String memoryTitle) {
    return '$actor დაამატა ფოტოები მოგონებაში $memoryTitle';
  }

  @override
  String get notificationFailureUnauthorized =>
      'სესიას ყურადღება სჭირდება. გთხოვთ, ხელახლა შეხვიდეთ.';

  @override
  String get notificationFailureNotFound =>
      'ეს შეტყობინება აღარ არის ხელმისაწვდომი.';

  @override
  String get notificationFailureNetwork =>
      'ქსელთან კავშირი არ არის. შეამოწმეთ კავშირი და სცადეთ ხელახლა.';

  @override
  String get notificationFailureTimeout =>
      'მოთხოვნის დრო ამოიწურა. სცადეთ ხელახლა.';

  @override
  String get notificationFailureServer =>
      'შეტყობინებები დროებით მიუწვდომელია. სცადეთ მოგვიანებით.';

  @override
  String get notificationFailureUnknown =>
      'რაღაც არასწორად წავიდა. სცადეთ ხელახლა.';

  @override
  String storiesOpenProfileLabel(String displayName) {
    return '$displayName-ის პროფილის გახსნა';
  }

  @override
  String get profileTitle => 'პროფილი';

  @override
  String get profileBackLabel => 'ისტორიებზე დაბრუნება';

  @override
  String get profileCreatorLabel => 'Memory Creator';

  @override
  String get profileQuote =>
      'ყოველი მოგონება იმსახურებს ადგილს, სადაც იცხოვრებს.';

  @override
  String get profileAccountSection => 'ანგარიში';

  @override
  String get profilePhotoTitle => 'პროფილის ფოტო';

  @override
  String get profilePhotoSubtitle => 'ჯერჯერობით Google-ის ავატარი';

  @override
  String get profilePhotoCustomSubtitle => 'Custom Memory Story ავატარი';

  @override
  String get profileAvatarChooseAction => 'ფოტოს არჩევა';

  @override
  String get profileAvatarReplaceAction => 'ფოტოს შეცვლა';

  @override
  String get profileAvatarRemoveAction => 'ფოტოს წაშლა';

  @override
  String get profileAvatarUploading => 'იტვირთება...';

  @override
  String get profileAvatarFailure =>
      'პროფილის ფოტოს განახლება ვერ მოხერხდა. შეამოწმეთ კავშირი და სცადეთ ხელახლა.';

  @override
  String get profileAvatarInvalidFailure =>
      'აირჩიეთ JPEG ან PNG ფოტო ატვირთვის ლიმიტზე ნაკლები ზომით.';

  @override
  String get profileAvatarUnauthorizedFailure =>
      'სესიის ვადა ამოიწურა. ფოტოს შესაცვლელად ხელახლა შედით.';

  @override
  String get profileDisplayNameTitle => 'საჩვენებელი სახელი';

  @override
  String get profileDisplayNameEditTitle => 'საჩვენებელი სახელის რედაქტირება';

  @override
  String get profileDisplayNameFieldLabel => 'საჩვენებელი სახელი';

  @override
  String get profileDisplayNameSaveAction => 'შენახვა';

  @override
  String get profileDisplayNameSaving => 'ინახება...';

  @override
  String get profileDisplayNameInvalidFailure =>
      'შეიყვანეთ საჩვენებელი სახელი.';

  @override
  String get profileDisplayNameTooLongFailure =>
      'საჩვენებელი სახელი უნდა იყოს 255 სიმბოლო ან ნაკლები.';

  @override
  String get profileDisplayNameControlCharacterFailure =>
      'საჩვენებელი სახელი ერთ ხაზზე უნდა დარჩეს.';

  @override
  String get profileDisplayNameFailure =>
      'სახელის შენახვა ვერ მოხერხდა. შეამოწმეთ კავშირი და სცადეთ ხელახლა.';

  @override
  String get profileDisplayNameUnauthorizedFailure =>
      'სესიის ვადა ამოიწურა. სახელის შესაცვლელად ხელახლა შედით.';

  @override
  String get profileDisplayNameLocalPersistenceFailure =>
      'სახელი შენახულია, მაგრამ ლოკალურად შენახვა ვერ მოხერხდა. თუ არ განახლდა, გადატვირთეთ აპი.';

  @override
  String get profileLanguageTitle => 'ენა';

  @override
  String get profileLanguageSubtitle => 'აირჩიეთ აპის ენა';

  @override
  String get languageSystemOption => 'სისტემური';

  @override
  String get languageSystemSubtitle => 'მოწყობილობის ენის გამოყენება';

  @override
  String get languageRussianOption => 'Русский';

  @override
  String get languageEnglishOption => 'English';

  @override
  String get languageGeorgianOption => 'ქართული';

  @override
  String get languageChangeFailure =>
      'ენის შენახვა ვერ მოხერხდა. სცადეთ ხელახლა.';

  @override
  String get profileLegalSupportSection =>
      'სამართლებრივი ინფორმაცია და მხარდაჭერა';

  @override
  String get profilePrivacyPolicyTitle => 'კონფიდენციალურობის პოლიტიკა';

  @override
  String get profilePrivacyPolicySubtitle =>
      'როგორ არის დაცული პირადი მოგონებები';

  @override
  String get profileTermsOfUseTitle => 'გამოყენების პირობები';

  @override
  String get profileTermsOfUseSubtitle => 'Memory Story-ის გამოყენების წესები';

  @override
  String get profileHelpSupportTitle => 'დახმარება და მხარდაჭერა';

  @override
  String get profileHelpSupportSubtitle => 'კითხვები და მხარდაჭერის ვარიანტები';

  @override
  String get profileAboutTitle => 'Memory Story-ის შესახებ';

  @override
  String get profileAboutSubtitle => 'აპის ინფორმაცია';

  @override
  String get profileAccountActionsSection => 'ანგარიშის მოქმედებები';

  @override
  String get profileLogoutSubtitle => 'ამ მოწყობილობაზე სესიის დასრულება';

  @override
  String get profileDeleteTitle => 'პროფილის წაშლა';

  @override
  String get profileDeleteSubtitle => 'ანგარიშის სამუდამოდ წაშლა';

  @override
  String get profileDeleteConfirmTitle => 'წავშალოთ პროფილი?';

  @override
  String get profileDeleteConfirmBody =>
      'ეს სამუდამოდ წაშლის თქვენს ანგარიშს და Memory Story-ზე წვდომას მოგიხსნით. ისტორიები, რომლებსაც ჯერ კიდევ მფლობელი სჭირდება, ჯერ უნდა მოგვარდეს.';

  @override
  String get profileDeleteConfirmAction => 'პროფილის წაშლა';

  @override
  String get profileDeletingAction => 'იშლება...';

  @override
  String get profileDeleteOwnershipConflict =>
      'თქვენს ერთ-ერთ გაზიარებულ ისტორიას ჯერ კიდევ სჭირდება მფლობელი. პროფილის წაშლამდე მოაგვარეთ ისტორიის მფლობელობა.';

  @override
  String get profileDeleteUnauthorized =>
      'სესიის ვადა ამოიწურა. პროფილის წასაშლელად ხელახლა შედით.';

  @override
  String get profileDeleteFailure =>
      'პროფილის წაშლა ვერ მოხერხდა. შეამოწმეთ კავშირი და სცადეთ ხელახლა.';

  @override
  String get profileDeleteUnavailableAction => 'წაშლა მიუწვდომელია';

  @override
  String get profilePhotoPlaceholderBody =>
      'პროფილის ფოტოს რედაქტირება ჯერ მიუწვდომელია. თქვენი Google-ის ავატარი რჩება მიმდინარე პროფილის სურათად.';

  @override
  String get profileDisplayNamePlaceholderBody =>
      'საჩვენებელი სახელის რედაქტირება ჯერ მიუწვდომელია. თქვენი Google-ის მიმდინარე სახელი ხილული რჩება.';

  @override
  String get profilePrivacyPolicyPlaceholderBody =>
      'სრული კონფიდენციალურობის პოლიტიკა დაემატება საჯარო გამოშვებამდე.';

  @override
  String get profileTermsPlaceholderBody =>
      'გამოყენების სრული პირობები დაემატება საჯარო გამოშვებამდე.';

  @override
  String get profileHelpPlaceholderBody =>
      'დახმარებისა და მხარდაჭერის ვარიანტები დაემატება საჯარო გამოშვებამდე.';

  @override
  String get profileAboutPlaceholderBody =>
      'Memory Story არის პირადი მოგონებების აპი ისტორიებისთვის, ადგილებისთვის, ფოტოებისთვის, დაკვრისთვის და ადამიანებისთვის, რომლებიც მათ იზიარებენ.';
}
