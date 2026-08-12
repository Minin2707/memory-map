import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/l10n/app_localizations.dart';

String mediaFailureMessage(
  AppLocalizations l10n,
  MediaFailure failure,
) {
  return switch (failure) {
    MediaValidationFailure() => l10n.mediaFailureValidation,
    MediaUnauthorized() => l10n.mediaFailureUnauthorized,
    MediaUnavailable() => l10n.mediaFailureUnavailable,
    MediaUploadUnavailable() => l10n.mediaFailureUploadUnavailable,
    MediaNetworkUnavailable() => l10n.mediaFailureNetworkUnavailable,
    MediaRequestTimedOut() => l10n.mediaFailureRequestTimedOut,
    MediaServerFailure() => l10n.mediaFailureServerFailure,
    MediaPreprocessingFailure() => l10n.mediaFailurePreprocessing,
    UnknownMediaFailure() => l10n.mediaFailureUnknown,
  };
}
