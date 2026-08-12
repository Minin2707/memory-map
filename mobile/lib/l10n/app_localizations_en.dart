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
  String get participantsPageTitle => 'Participants';

  @override
  String get participantsBack => 'Back to story';

  @override
  String get participantsHeaderTitle => 'People in this story';

  @override
  String participantsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
      zero: 'No participants',
    );
    return '$_temp0';
  }

  @override
  String get participantsSectionTitle => 'Participants';

  @override
  String get participantsSectionSubtitle =>
      'Roles shape what each participant can do in this story.';

  @override
  String get participantsInvite => 'Invite participant';

  @override
  String get participantsLeaveStory => 'Leave story';

  @override
  String get participantsLeaveConfirmTitle => 'Leave story?';

  @override
  String get participantsLeaveConfirmBody =>
      'You will lose access to this story. To join again, you will need a new invitation. If you are the last owner, the server may reject this action.';

  @override
  String get participantsLeaveConfirmAction => 'Leave';

  @override
  String get participantsLeaveCancel => 'Cancel';

  @override
  String get participantsLeaving => 'Leaving story...';

  @override
  String get participantsCurrentUser => 'You';

  @override
  String get participantsEmptyTitle => 'No participants to show';

  @override
  String get participantsEmptyBody =>
      'The participant list is empty right now. Try refreshing in a moment.';

  @override
  String get participantsRetry => 'Retry';

  @override
  String get participantsRefreshFailed => 'Could not refresh participants';

  @override
  String get participantsLoadFailed => 'Could not load participants';

  @override
  String get participantsRemoveAction => 'Remove';

  @override
  String participantsRemoveConfirmTitle(String displayName) {
    return 'Remove $displayName?';
  }

  @override
  String participantsRemoveConfirmBody(String displayName) {
    return '$displayName will lose access to this story. They can join again with a new invitation.';
  }

  @override
  String get participantsRemoveConfirmAction => 'Remove';

  @override
  String get participantsRemoveCancel => 'Cancel';

  @override
  String get participantsRemoving => 'Removing participant...';

  @override
  String participantsRemoveSuccess(String displayName) {
    return '$displayName was removed.';
  }

  @override
  String participantsAvatarLabel(String displayName) {
    return '$displayName\'s avatar';
  }

  @override
  String participantsRemoveParticipantLabel(String displayName) {
    return 'Remove $displayName';
  }

  @override
  String get participantFailureValidation =>
      'The request was invalid. Please try again.';

  @override
  String get participantFailureUnauthorized =>
      'Your session needs attention. Please try again.';

  @override
  String get participantFailureNotFound => 'Participants are unavailable.';

  @override
  String get participantFailureLastOwner =>
      'The last owner cannot leave this story.';

  @override
  String get participantFailureCannotRemoveSelf =>
      'Use Leave story to remove yourself.';

  @override
  String get participantFailureOwnerCannotBeRemoved =>
      'Owners cannot be removed from here.';

  @override
  String get participantFailureNetwork =>
      'No network connection. Check your connection and try again.';

  @override
  String get participantFailureTimeout =>
      'The request timed out. Please try again.';

  @override
  String get participantFailureServer =>
      'The server is temporarily unavailable. Please try again.';

  @override
  String get participantFailureUnknown =>
      'Something went wrong. Please try again.';

  @override
  String get storyMemoriesPageTitle => 'Memories';

  @override
  String get storyMemoriesBackLabel => 'Back to story';

  @override
  String get storyMemoriesRefreshAction => 'Refresh memories';

  @override
  String get storyMemoriesHeaderTitle => 'Story memories';

  @override
  String storyMemoriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count memories',
      one: '1 memory',
      zero: 'No memories',
    );
    return '$_temp0';
  }

  @override
  String get storyMemoriesCreate => 'Add memory';

  @override
  String get storyMemoriesEmptyTitle => 'No memories yet';

  @override
  String get storyMemoriesEmptyBody =>
      'Add the first memory when something worth saving happens.';

  @override
  String get storyMemoriesLoadFailureTitle => 'Could not load memories';

  @override
  String get storyMemoriesRefreshFailureTitle => 'Could not refresh memories';

  @override
  String get storyMapPageTitle => 'Map';

  @override
  String get storyMapBackLabel => 'Back to story';

  @override
  String get storyMapShowAllAction => 'Show all';

  @override
  String get storyMapRefreshAction => 'Refresh map';

  @override
  String get storyMapEmptyTitle => 'No memories on the map yet';

  @override
  String get storyMapEmptyBody =>
      'Memories with saved places will appear here.';

  @override
  String get storyMapLoadFailureTitle => 'Could not load map';

  @override
  String get storyMapRefreshFailureTitle => 'Could not refresh map';

  @override
  String memoryOpenLabel(String title) {
    return 'Open memory $title';
  }

  @override
  String get memoryFailureValidation =>
      'The request was invalid. Please try again.';

  @override
  String get memoryFailureUnauthorized =>
      'Your session needs attention. Please try again.';

  @override
  String get memoryFailureStoryUnavailable => 'Story memories are unavailable.';

  @override
  String get memoryFailureNotFound => 'Memory is unavailable.';

  @override
  String get memoryFailureCreationUnavailable =>
      'Memory cannot be created from here.';

  @override
  String get memoryFailureUpdateUnavailable =>
      'Memory cannot be updated from here.';

  @override
  String get memoryFailureDeletionUnavailable =>
      'Memory cannot be deleted from here.';

  @override
  String get memoryFailureNetworkUnavailable =>
      'No network connection. Check your connection and try again.';

  @override
  String get memoryFailureRequestTimedOut =>
      'The request timed out. Please try again.';

  @override
  String get memoryFailureServerFailure =>
      'The server is temporarily unavailable. Please try again.';

  @override
  String get memoryFailureUnknown => 'Something went wrong. Please try again.';

  @override
  String get createMemoryPageTitle => 'Add memory';

  @override
  String get createMemoryBackLabel => 'Back to memories';

  @override
  String get createMemoryTitleLabel => 'Title';

  @override
  String get createMemoryTitleHint => 'Example: Sunset in Bali';

  @override
  String get createMemoryTitleRequired => 'Enter a memory title.';

  @override
  String get createMemoryTitleBlank => 'Memory title cannot be blank.';

  @override
  String get createMemoryTitleMax =>
      'Memory title must be 255 characters or fewer.';

  @override
  String get createMemoryDescriptionLabel => 'Description';

  @override
  String get createMemoryDescriptionHint => 'Add a note about this moment';

  @override
  String get createMemoryPlaceNameLabel => 'Place name';

  @override
  String get createMemoryPlaceNameHint => 'Example: Seminyak Beach';

  @override
  String get createMemoryPlaceNameMax =>
      'Place name must be 255 characters or fewer.';

  @override
  String get createMemoryOptionalLabel => 'optional';

  @override
  String get createMemoryEventDateLabel => 'Event date';

  @override
  String get createMemoryEventDateEmpty => 'No date selected';

  @override
  String get createMemoryChooseDate => 'Choose';

  @override
  String get createMemoryChangeDate => 'Change';

  @override
  String get createMemoryDateRequired => 'Choose an event date.';

  @override
  String get createMemoryLocationLabel => 'Location';

  @override
  String get createMemoryLocationEmpty => 'No location selected';

  @override
  String get createMemoryLocationSelected => 'Location selected';

  @override
  String get createMemoryChooseLocation => 'Choose';

  @override
  String get createMemoryChangeLocation => 'Change';

  @override
  String get createMemoryLocationRequired => 'Choose a location.';

  @override
  String get createMemorySubmitButton => 'Create memory';

  @override
  String get createMemorySubmittingButton => 'Creating memory...';

  @override
  String get editMemoryPageTitle => 'Edit memory';

  @override
  String get editMemoryBackLabel => 'Back to memory';

  @override
  String get editMemorySaveButton => 'Save changes';

  @override
  String get editMemorySavingButton => 'Saving changes...';

  @override
  String get editMemoryNoChangesHint => 'Make a change to save.';

  @override
  String get memoryDetailsPageTitle => 'Memory';

  @override
  String get memoryDetailsBackLabel => 'Back to memories';

  @override
  String get memoryDetailsRefreshAction => 'Refresh memory';

  @override
  String get memoryDetailsEditAction => 'Edit memory';

  @override
  String get memoryDetailsDeleteAction => 'Delete memory';

  @override
  String get memoryDetailsLoadFailureTitle => 'Could not load memory';

  @override
  String get memoryDetailsRefreshFailureTitle => 'Could not refresh memory';

  @override
  String get memoryDetailsDescriptionTitle => 'Memory note';

  @override
  String get memoryDetailsNoDescription => 'No description yet.';

  @override
  String get memoryDetailsPlaceTitle => 'Place';

  @override
  String get memoryDetailsNoPlace => 'No place name yet.';

  @override
  String get deleteMemoryDialogTitle => 'Delete memory?';

  @override
  String get deleteMemoryDialogBody =>
      'This memory will be permanently deleted. This action cannot be undone.';

  @override
  String get deleteMemoryCancel => 'Cancel';

  @override
  String get deleteMemoryConfirm => 'Delete';

  @override
  String get deleteMemoryDeleting => 'Deleting memory...';

  @override
  String get locationPickerTitle => 'Choose a place';

  @override
  String get locationPickerBackLabel => 'Back';

  @override
  String get locationPickerInstruction =>
      'Tap the map to choose the exact point for this memory.';

  @override
  String get locationPickerSelectedTitle => 'Location selected';

  @override
  String get locationPickerSelectedDescription =>
      'Confirm when the pin marks the place you want to save.';

  @override
  String get locationPickerNoSelectionTitle => 'No location selected';

  @override
  String get locationPickerNoSelectionDescription =>
      'Choose a point on the map before confirming.';

  @override
  String get locationPickerConfirmAction => 'Confirm location';

  @override
  String get locationPickerMapLoading => 'Loading map...';

  @override
  String get locationPickerMapUnavailable =>
      'Map is unavailable. Please try again later.';

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

  @override
  String get invitePageTitle => 'Invite participant';

  @override
  String get inviteCreatedPageTitle => 'Invite created';

  @override
  String get inviteBackLabel => 'Back to story';

  @override
  String get inviteHeroTitle => 'Invite someone close';

  @override
  String get inviteHeroSubtitle =>
      'Share a one-time invitation link so they can join your story.';

  @override
  String get inviteLinkLabel => 'Invite link';

  @override
  String get inviteSingleUseDescription =>
      'One-time use. After it is accepted, the link stops working.';

  @override
  String get inviteExpirationLabel => 'Expires';

  @override
  String get inviteExpirationDescription =>
      'The invite remains valid until the date returned by the server.';

  @override
  String get inviteWhatCanDoTitle => 'What can you do with this link?';

  @override
  String get inviteInstructionShare => 'Share it in any messenger.';

  @override
  String get inviteInstructionCopy => 'Copy it and send it yourself.';

  @override
  String get inviteInstructionOneUse =>
      'Ask the recipient to use it only once.';

  @override
  String get inviteCreateButton => 'Create invite';

  @override
  String get inviteCreatingButton => 'Creating invite...';

  @override
  String get inviteSuccessTitle => 'Invite is ready!';

  @override
  String get inviteSuccessSubtitle =>
      'Share the link with someone close. It is one-time and secure.';

  @override
  String get inviteLinkSemanticsLabel => 'Invite link';

  @override
  String get inviteCopyAction => 'Copy';

  @override
  String get inviteCopiedFeedback => 'Invite link copied.';

  @override
  String get inviteCopyFailure => 'Could not copy the invite link.';

  @override
  String get inviteShareAction => 'Share';

  @override
  String get inviteShareReadyFeedback => 'Share options opened.';

  @override
  String get inviteShareFailure => 'Could not share the invite link.';

  @override
  String get inviteLinkCannotBeRestoredWarning =>
      'Copy or share this link before leaving this screen. It cannot be shown again.';

  @override
  String get inviteImportantTitle => 'Important';

  @override
  String get inviteImportantSingleUse => 'This link can be used only once.';

  @override
  String get inviteImportantAfterAccept =>
      'After the invitation is accepted, the link becomes invalid.';

  @override
  String get inviteImportantExpiration =>
      'The invitation automatically expires after its expiration date.';

  @override
  String get inviteDoneAction => 'Done';

  @override
  String get inviteFailureValidation =>
      'The invite request was invalid. Please try again.';

  @override
  String get inviteFailureUnauthorized =>
      'Your session needs attention. Please try again.';

  @override
  String get inviteFailureNotFound => 'This story is unavailable for invites.';

  @override
  String get inviteFailureNetworkUnavailable =>
      'No network connection. Check your connection and try again.';

  @override
  String get inviteFailureRequestTimedOut =>
      'The request timed out. Please try again.';

  @override
  String get inviteFailureServerFailure =>
      'The server is temporarily unavailable. Please try again.';

  @override
  String get inviteFailureUnknown => 'Something went wrong. Please try again.';

  @override
  String get acceptInvitePageTitle => 'Invitation';

  @override
  String get acceptInviteBackLabel => 'Back to stories';

  @override
  String get acceptInviteHeroTitle => 'You were invited to a story';

  @override
  String get acceptInviteHeroDescription =>
      'Accept the invitation to join. We will show the story after the server confirms access.';

  @override
  String get acceptInviteDetailsAccessTitle => 'Private access';

  @override
  String get acceptInviteDetailsAccessBody =>
      'Story details are hidden until you accept the invite.';

  @override
  String get acceptInviteDetailsSingleUseTitle => 'One-time link';

  @override
  String get acceptInviteDetailsSingleUseBody =>
      'The invite can be accepted only once and may expire.';

  @override
  String get acceptInviteAcceptAction => 'Accept invite';

  @override
  String get acceptInviteAcceptingAction => 'Accepting invite...';

  @override
  String get acceptInviteRetryAction => 'Try again';

  @override
  String get acceptInviteCancelAction => 'Cancel';

  @override
  String get acceptInviteBackToStoriesAction => 'Back to stories';

  @override
  String get acceptInviteInvalidLinkTitle => 'Invite link is unavailable';

  @override
  String get acceptInviteInvalidLinkDescription =>
      'This invitation cannot be opened.';

  @override
  String get acceptInviteUnavailable => 'This invitation cannot be accepted.';

  @override
  String get acceptInviteFailureUnauthorized =>
      'Your session needs attention. Please sign in again.';

  @override
  String get acceptInviteFailureUnknown =>
      'Something went wrong. Please try again.';

  @override
  String get acceptInviteAcceptSemanticsLabel => 'Accept invitation';

  @override
  String get acceptInviteCancelSemanticsLabel => 'Cancel invitation';

  @override
  String get acceptInviteErrorSemanticsLabel => 'Invitation error';
}
