import 'package:memory_map/features/invite/domain/invite_failure.dart';
import 'package:memory_map/l10n/app_localizations.dart';

String inviteFailureMessage(
  AppLocalizations l10n,
  InviteFailure failure,
) {
  return switch (failure) {
    InviteValidationFailure() => l10n.inviteFailureValidation,
    InviteUnauthorized() => l10n.inviteFailureUnauthorized,
    InviteNotFound() => l10n.inviteFailureNotFound,
    InviteNetworkUnavailable() => l10n.inviteFailureNetworkUnavailable,
    InviteRequestTimedOut() => l10n.inviteFailureRequestTimedOut,
    InviteServerFailure() => l10n.inviteFailureServerFailure,
    UnknownInviteFailure() => l10n.inviteFailureUnknown,
  };
}
