import 'package:memory_map/features/participant/domain/participant_failure.dart';
import 'package:memory_map/l10n/app_localizations.dart';

String participantFailureMessage(
  AppLocalizations l10n,
  ParticipantFailure failure,
) {
  return switch (failure) {
    ParticipantValidationFailure() => l10n.participantFailureValidation,
    ParticipantUnauthorized() => l10n.participantFailureUnauthorized,
    ParticipantNotFound() => l10n.participantFailureNotFound,
    ParticipantLastOwnerConflict() => l10n.participantFailureLastOwner,
    ParticipantCannotRemoveSelf() => l10n.participantFailureCannotRemoveSelf,
    ParticipantOwnerCannotBeRemoved() =>
      l10n.participantFailureOwnerCannotBeRemoved,
    ParticipantNetworkUnavailable() => l10n.participantFailureNetwork,
    ParticipantRequestTimedOut() => l10n.participantFailureTimeout,
    ParticipantServerFailure() => l10n.participantFailureServer,
    UnknownParticipantFailure() => l10n.participantFailureUnknown,
  };
}
