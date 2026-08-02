import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/l10n/app_localizations.dart';

String storyFailureMessage(
  AppLocalizations l10n,
  StoryFailure failure,
) {
  return switch (failure) {
    StoryValidationFailure() => l10n.storyFailureValidation,
    StoryUnauthorized() => l10n.storyFailureUnauthorized,
    StoryNotFound() => l10n.storyFailureNotFound,
    StoryNetworkUnavailable() => l10n.storyFailureNetworkUnavailable,
    StoryRequestTimedOut() => l10n.storyFailureRequestTimedOut,
    StoryServerFailure() => l10n.storyFailureServerFailure,
    UnknownStoryFailure() => l10n.storyFailureUnknown,
  };
}
