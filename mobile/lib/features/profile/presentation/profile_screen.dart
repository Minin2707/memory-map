import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/app/language/app_language_preference.dart';
import 'package:memory_map/app/language/app_language_preference_notifier.dart';
import 'package:memory_map/features/auth/application/auth_notifier.dart';
import 'package:memory_map/features/auth/application/auth_state.dart';
import 'package:memory_map/features/auth/domain/auth_session.dart';
import 'package:memory_map/features/auth/presentation/auth_failure_message.dart';
import 'package:memory_map/features/auth/presentation/auth_user_avatar.dart';
import 'package:memory_map/features/profile/application/delete_profile_notifier.dart';
import 'package:memory_map/features/profile/application/delete_profile_state.dart';
import 'package:memory_map/features/profile/application/profile_avatar_notifier.dart';
import 'package:memory_map/features/profile/application/profile_avatar_state.dart';
import 'package:memory_map/features/profile/application/profile_display_name_notifier.dart';
import 'package:memory_map/features/profile/application/profile_display_name_state.dart';
import 'package:memory_map/features/profile/domain/account_avatar_failure.dart';
import 'package:memory_map/features/profile/domain/account_deletion_failure.dart';
import 'package:memory_map/features/profile/domain/account_display_name_failure.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({
    required this.onBack,
    required this.onProfilePhoto,
    required this.onDisplayName,
    required this.onLanguage,
    required this.onPrivacyPolicy,
    required this.onTermsOfUse,
    required this.onHelpSupport,
    required this.onAbout,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onProfilePhoto;
  final VoidCallback onDisplayName;
  final VoidCallback onLanguage;
  final VoidCallback onPrivacyPolicy;
  final VoidCallback onTermsOfUse;
  final VoidCallback onHelpSupport;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authValue = ref.watch(authNotifierProvider);
    final authState = authValue.asData?.value;
    final session = _sessionFor(authState);
    final deleteProfileValue = ref.watch(deleteProfileProvider);
    final avatarValue = ref.watch(profileAvatarProvider);
    final displayNameValue = ref.watch(profileDisplayNameProvider);
    final languagePreference = ref
            .watch(appLanguagePreferenceProvider)
            .asData
            ?.value
            .preference ??
        AppLanguagePreference.system;
    final deleteProfileState =
        deleteProfileValue.asData?.value ?? const DeleteProfileState();
    final avatarState = avatarValue.asData?.value;
    final displayNameState = displayNameValue.asData?.value ??
        const ProfileDisplayNameState();
    final displayName = _displayNameFor(l10n, session);
    final avatarUrl = session?.user.avatarUrl;
    final hasCustomAvatar = session?.user.hasCustomAvatar ?? false;
    final isAvatarBusy = avatarState?.isBusy ?? false;
    final isDisplayNameBusy = displayNameState.isBusy;
    final isLoggingOut = authState is AuthLoggingOut;
    final logoutFailure = authState is AuthLogoutFailure
        ? authFailureMessage(l10n, authState.failure)
        : null;
    final deleteFailure = deleteProfileState.failure == null
        ? null
        : _deleteFailureMessage(l10n, deleteProfileState.failure!);
    final avatarFailure = avatarState?.failure == null
        ? null
        : _avatarFailureMessage(l10n, avatarState!.failure!);
    final accountActionBusy = isLoggingOut || deleteProfileState.isDeleting;
    final VoidCallback? profilePhotoAction;
    if (isAvatarBusy) {
      profilePhotoAction = null;
    } else if (session == null) {
      profilePhotoAction = onProfilePhoto;
    } else {
      profilePhotoAction = () {
        _showAvatarActions(context, session);
      };
    }

    return Scaffold(
      key: const ValueKey('profile.screen'),
      backgroundColor: const Color(0xFFFFF8F6),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _ProfileHero(
                displayName: displayName,
                avatarUrl: avatarUrl,
                onBack: onBack,
                onProfilePhoto: profilePhotoAction,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    _SectionLabel(text: l10n.profileAccountSection),
                    const SizedBox(height: 10),
                    _ProfileSectionCard(
                      children: [
                        if (avatarFailure != null) ...[
                          _ProfileFailureBanner(message: avatarFailure),
                          _ProfileMenuDivider(),
                        ],
                        _ProfileMenuRow(
                          key: const ValueKey('profile.photo-action'),
                          icon: Icons.photo_camera_outlined,
                          title: isAvatarBusy
                              ? l10n.profileAvatarUploading
                              : l10n.profilePhotoTitle,
                          subtitle: hasCustomAvatar
                              ? l10n.profilePhotoCustomSubtitle
                              : l10n.profilePhotoSubtitle,
                          isBusy: isAvatarBusy,
                          onTap: profilePhotoAction,
                        ),
                        _ProfileMenuDivider(),
                        _ProfileMenuRow(
                          key: const ValueKey('profile.display-name-action'),
                          icon: Icons.badge_outlined,
                          title: isDisplayNameBusy
                              ? l10n.profileDisplayNameSaving
                              : l10n.profileDisplayNameTitle,
                          subtitle: displayName,
                          isBusy: isDisplayNameBusy,
                          onTap: isDisplayNameBusy
                              ? null
                              : session == null
                                  ? onDisplayName
                                  : () {
                                      _showDisplayNameEditor(context, session);
                                  },
                        ),
                        _ProfileMenuDivider(),
                        _ProfileMenuRow(
                          key: const ValueKey('profile.language-action'),
                          icon: Icons.language_rounded,
                          title: l10n.profileLanguageTitle,
                          subtitle: l10n.profileLanguageSubtitle,
                          value: _languagePreferenceLabel(
                            l10n,
                            languagePreference,
                          ),
                          onTap: onLanguage,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(text: l10n.profileLegalSupportSection),
                    const SizedBox(height: 10),
                    _ProfileSectionCard(
                      children: [
                        _ProfileMenuRow(
                          key: const ValueKey('profile.privacy-action'),
                          icon: Icons.lock_outline_rounded,
                          title: l10n.profilePrivacyPolicyTitle,
                          subtitle: l10n.profilePrivacyPolicySubtitle,
                          onTap: onPrivacyPolicy,
                        ),
                        _ProfileMenuDivider(),
                        _ProfileMenuRow(
                          key: const ValueKey('profile.terms-action'),
                          icon: Icons.description_outlined,
                          title: l10n.profileTermsOfUseTitle,
                          subtitle: l10n.profileTermsOfUseSubtitle,
                          onTap: onTermsOfUse,
                        ),
                        _ProfileMenuDivider(),
                        _ProfileMenuRow(
                          key: const ValueKey('profile.help-action'),
                          icon: Icons.help_outline_rounded,
                          title: l10n.profileHelpSupportTitle,
                          subtitle: l10n.profileHelpSupportSubtitle,
                          onTap: onHelpSupport,
                        ),
                        _ProfileMenuDivider(),
                        _ProfileMenuRow(
                          key: const ValueKey('profile.about-action'),
                          icon: Icons.info_outline_rounded,
                          title: l10n.profileAboutTitle,
                          subtitle: l10n.profileAboutSubtitle,
                          onTap: onAbout,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SectionLabel(text: l10n.profileAccountActionsSection),
                    const SizedBox(height: 10),
                    _ProfileSectionCard(
                      children: [
                        if (logoutFailure != null) ...[
                          _ProfileFailureBanner(message: logoutFailure),
                          _ProfileMenuDivider(),
                        ],
                        if (deleteFailure != null) ...[
                          _ProfileFailureBanner(message: deleteFailure),
                          _ProfileMenuDivider(),
                        ],
                        _ProfileMenuRow(
                          key: const ValueKey('profile.logout-action'),
                          icon: Icons.logout_rounded,
                          title: isLoggingOut ? l10n.loggingOut : l10n.logOut,
                          subtitle: l10n.profileLogoutSubtitle,
                          isBusy: isLoggingOut,
                          onTap: accountActionBusy
                              ? null
                              : () {
                                  ref
                                      .read(authNotifierProvider.notifier)
                                      .logout();
                                },
                        ),
                        _ProfileMenuDivider(),
                        _ProfileMenuRow(
                          key: const ValueKey('profile.delete-action'),
                          icon: Icons.delete_outline_rounded,
                          title: l10n.profileDeleteTitle,
                          subtitle: l10n.profileDeleteSubtitle,
                          destructive: true,
                          isBusy: deleteProfileState.isDeleting,
                          onTap: accountActionBusy || session == null
                              ? null
                              : () {
                                  _showDeleteProfileSheet(
                                    context,
                                    session,
                                  );
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AuthSession? _sessionFor(AuthState? authState) {
    return switch (authState) {
      AuthAuthenticated(:final session) => session,
      AuthLoggingOut(:final session) => session,
      AuthLogoutFailure(:final session) => session,
      _ => null,
    };
  }

  String _displayNameFor(AppLocalizations l10n, AuthSession? session) {
    final displayName = session?.user.displayName.trim();
    if (displayName == null || displayName.isEmpty) {
      return l10n.fallbackDisplayName;
    }

    return displayName;
  }

  String _languagePreferenceLabel(
    AppLocalizations l10n,
    AppLanguagePreference preference,
  ) {
    return switch (preference) {
      AppLanguagePreference.system => l10n.languageSystemOption,
      AppLanguagePreference.russian => l10n.languageRussianOption,
      AppLanguagePreference.english => l10n.languageEnglishOption,
    };
  }

  String _deleteFailureMessage(
    AppLocalizations l10n,
    AccountDeletionFailure failure,
  ) {
    return switch (failure) {
      AccountDeletionOwnershipConflict() =>
        l10n.profileDeleteOwnershipConflict,
      AccountDeletionUnauthorized() => l10n.profileDeleteUnauthorized,
      AccountDeletionNetworkUnavailable() ||
      AccountDeletionRequestTimedOut() ||
      AccountDeletionServerFailure() ||
      AccountDeletionUnknownFailure() =>
        l10n.profileDeleteFailure,
    };
  }

  String _avatarFailureMessage(
    AppLocalizations l10n,
    AccountAvatarFailure failure,
  ) {
    return switch (failure) {
      AccountAvatarCancelled() => '',
      AccountAvatarValidationFailure() => l10n.profileAvatarInvalidFailure,
      AccountAvatarUnauthorized() => l10n.profileAvatarUnauthorizedFailure,
      AccountAvatarNetworkUnavailable() ||
      AccountAvatarRequestTimedOut() ||
      AccountAvatarServerFailure() ||
      AccountAvatarLocalPersistenceFailure() ||
      AccountAvatarUnknownFailure() => l10n.profileAvatarFailure,
    };
  }

  void _showDisplayNameEditor(
    BuildContext context,
    AuthSession session,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _DisplayNameEditorSheet(session: session);
      },
    );
  }

  void _showAvatarActions(
    BuildContext context,
    AuthSession session,
  ) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final avatarState =
                ref.watch(profileAvatarProvider).asData?.value ??
                    const ProfileAvatarState();
            final isBusy = avatarState.isBusy;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AvatarActionTile(
                      key: const ValueKey('profile.avatar.choose-action'),
                      icon: Icons.photo_library_rounded,
                      title: session.user.hasCustomAvatar
                          ? l10n.profileAvatarReplaceAction
                          : l10n.profileAvatarChooseAction,
                      isBusy: avatarState.isUploading,
                      onTap: isBusy
                          ? null
                          : () async {
                              final succeeded = await ref
                                  .read(profileAvatarProvider.notifier)
                                  .chooseAndUploadAvatar(session);
                              if (succeeded && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                    ),
                    if (session.user.hasCustomAvatar) ...[
                      const SizedBox(height: 8),
                      _AvatarActionTile(
                        key: const ValueKey('profile.avatar.remove-action'),
                        icon: Icons.delete_outline_rounded,
                        title: l10n.profileAvatarRemoveAction,
                        destructive: true,
                        isBusy: avatarState.isRemoving,
                        onTap: isBusy
                            ? null
                            : () async {
                                final succeeded = await ref
                                    .read(profileAvatarProvider.notifier)
                                    .removeAvatar(session);
                                if (succeeded && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteProfileSheet(
    BuildContext context,
    AuthSession session,
  ) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final deleteProfileState =
                ref.watch(deleteProfileProvider).asData?.value ??
                    const DeleteProfileState();
            final failureMessage = deleteProfileState.failure == null
                ? null
                : _deleteFailureMessage(l10n, deleteProfileState.failure!);
            final isDeleting = deleteProfileState.isDeleting;

            return PopScope(
              canPop: !isDeleting,
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.profileDeleteConfirmTitle,
                          style: const TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.profileDeleteConfirmBody,
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 15,
                            height: 1.45,
                            letterSpacing: 0,
                          ),
                        ),
                        if (failureMessage != null) ...[
                          const SizedBox(height: 14),
                          _ProfileFailureBanner(message: failureMessage),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          key: const ValueKey('profile.delete.confirm-action'),
                          onPressed: isDeleting
                              ? null
                              : () async {
                                  final succeeded = await ref
                                      .read(deleteProfileProvider.notifier)
                                      .deleteProfile(session);
                                  if (succeeded && context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD92D20),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: isDeleting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(l10n.profileDeletingAction),
                                  ],
                                )
                              : Text(l10n.profileDeleteConfirmAction),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          key: const ValueKey('profile.delete.cancel-action'),
                          onPressed: isDeleting
                              ? null
                              : () {
                                  Navigator.of(context).pop();
                                },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: Text(l10n.cancel),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DisplayNameEditorSheet extends ConsumerStatefulWidget {
  const _DisplayNameEditorSheet({required this.session});

  final AuthSession session;

  @override
  ConsumerState<_DisplayNameEditorSheet> createState() =>
      _DisplayNameEditorSheetState();
}

class _DisplayNameEditorSheetState
    extends ConsumerState<_DisplayNameEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.session.user.displayName.trim(),
    )..addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(profileDisplayNameProvider).asData?.value ??
        const ProfileDisplayNameState();
    final normalized = _controller.text.trim();
    final validationFailure =
        ProfileDisplayNameNotifier.validate(normalized);
    final hasChanged = normalized != widget.session.user.displayName.trim();
    final canSave = !state.isSaving &&
        validationFailure == null &&
        hasChanged;
    final failureMessage = state.failure == null
        ? null
        : _failureMessage(l10n, state.failure!);
    final validationMessage = _validationMessage(
      l10n,
      normalized,
      validationFailure,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileDisplayNameEditTitle,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('profile.display-name.input'),
              controller: _controller,
              autofocus: true,
              enabled: !state.isSaving,
              maxLength: ProfileDisplayNameNotifier.displayNameMaxLength,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.profileDisplayNameFieldLabel,
                errorText: validationMessage,
              ),
              onSubmitted: (_) {
                if (canSave) {
                  _save();
                }
              },
            ),
            if (failureMessage != null) ...[
              const SizedBox(height: 10),
              _ProfileFailureBanner(message: failureMessage),
            ],
            const SizedBox(height: 18),
            FilledButton(
              key: const ValueKey('profile.display-name.save-action'),
              onPressed: canSave ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5D72),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: state.isSaving
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(l10n.profileDisplayNameSaving),
                      ],
                    )
                  : Text(l10n.profileDisplayNameSaveAction),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              key: const ValueKey('profile.display-name.cancel-action'),
              onPressed: state.isSaving
                  ? null
                  : () {
                      Navigator.of(context).pop();
                    },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }

  String? _validationMessage(
    AppLocalizations l10n,
    String normalized,
    AccountDisplayNameFailure? failure,
  ) {
    if (normalized.isEmpty) {
      return null;
    }

    if (failure is! AccountDisplayNameValidationFailure) {
      return null;
    }

    if (normalized.length >
        ProfileDisplayNameNotifier.displayNameMaxLength) {
      return l10n.profileDisplayNameTooLongFailure;
    }

    if (normalized.runes.any((codePoint) {
      return codePoint <= 0x1F || codePoint == 0x7F;
    })) {
      return l10n.profileDisplayNameControlCharacterFailure;
    }

    return l10n.profileDisplayNameInvalidFailure;
  }

  String _failureMessage(
    AppLocalizations l10n,
    AccountDisplayNameFailure failure,
  ) {
    return switch (failure) {
      AccountDisplayNameValidationFailure() =>
        l10n.profileDisplayNameInvalidFailure,
      AccountDisplayNameUnauthorized() =>
        l10n.profileDisplayNameUnauthorizedFailure,
      AccountDisplayNameLocalPersistenceFailure() =>
        l10n.profileDisplayNameLocalPersistenceFailure,
      AccountDisplayNameNetworkUnavailable() ||
      AccountDisplayNameRequestTimedOut() ||
      AccountDisplayNameServerFailure() ||
      AccountDisplayNameUnknownFailure() =>
        l10n.profileDisplayNameFailure,
    };
  }

  void _handleTextChanged() {
    setState(() {});
  }

  Future<void> _save() async {
    final succeeded = await ref
        .read(profileDisplayNameProvider.notifier)
        .saveDisplayName(widget.session, _controller.text);
    if (succeeded && mounted) {
      Navigator.of(context).pop();
    }
  }
}

class ProfilePlaceholderScreen extends StatelessWidget {
  const ProfilePlaceholderScreen({
    required this.title,
    required this.body,
    required this.onBack,
    super.key,
  });

  final String title;
  final String body;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('profile.placeholder.screen'),
      backgroundColor: const Color(0xFFFFF8F6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton.filledTonal(
                key: const ValueKey('profile.placeholder.back-action'),
                onPressed: onBack,
                tooltip: AppLocalizations.of(context).profileBackLabel,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Spacer(),
              Icon(
                Icons.auto_awesome_rounded,
                color: const Color(0xFFFF5D72).withValues(alpha: 0.9),
                size: 38,
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontSize: 16,
                  height: 1.45,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.displayName,
    required this.avatarUrl,
    required this.onBack,
    required this.onProfilePhoto,
  });

  final String displayName;
  final String? avatarUrl;
  final VoidCallback onBack;
  final VoidCallback? onProfilePhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE7DC),
            Color(0xFFFFF3E7),
            Color(0xFFFFD5DF),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(34),
          bottomRight: Radius.circular(34),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('profile.back-action'),
                onPressed: onBack,
                tooltip: l10n.profileBackLabel,
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1F2937),
                ),
              ),
              Expanded(
                child: Text(
                  l10n.profileTitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 20),
          _ProfileAvatar(
            displayName: displayName,
            avatarUrl: avatarUrl,
            onProfilePhoto: onProfilePhoto,
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 27,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.profileCreatorLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFF5D72),
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.profileQuote,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF5D6470),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.displayName,
    required this.avatarUrl,
    required this.onProfilePhoto,
  });

  final String displayName;
  final String? avatarUrl;
  final VoidCallback? onProfilePhoto;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 122,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AuthUserAvatar(
            key: const ValueKey('profile.avatar'),
            displayName: displayName,
            avatarUrl: avatarUrl,
            radius: 58,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFFFF5D72),
            cacheDimension: 256,
          ),
          Positioned(
            right: 5,
            bottom: 7,
            child: SizedBox.square(
              dimension: 38,
              child: IconButton.filled(
                key: const ValueKey('profile.photo.camera-action'),
                onPressed: onProfilePhoto,
                tooltip: AppLocalizations.of(context).profilePhotoTitle,
                icon: const Icon(Icons.photo_camera_rounded, size: 19),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5D72),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarActionTile extends StatelessWidget {
  const _AvatarActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
    this.isBusy = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool destructive;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive
        ? const Color(0xFFD92D20)
        : const Color(0xFF1F2937);
    final iconBackground = destructive
        ? const Color(0xFFFFE4E2)
        : const Color(0xFFFFF0F2);
    final iconForeground = destructive
        ? const Color(0xFFD92D20)
        : const Color(0xFFFF5D72);

    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      leading: CircleAvatar(
        backgroundColor: iconBackground,
        foregroundColor: iconForeground,
        child: Icon(icon),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: foreground,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      trailing: isBusy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFF5D72),
              ),
            )
          : null,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF9AA0AA),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  const _ProfileMenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.value,
    this.isBusy = false,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? value;
  final bool isBusy;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive
        ? const Color(0xFFD92D20)
        : const Color(0xFF1F2937);
    final iconForeground = destructive
        ? const Color(0xFFD92D20)
        : const Color(0xFFFF5D72);
    final iconBackground = destructive
        ? const Color(0xFFFFE4E2)
        : const Color(0xFFFFF0F2);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconForeground, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isBusy)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFF5D72),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value != null) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Icon(
                    Icons.chevron_right_rounded,
                    color: destructive
                        ? const Color(0xFFF97066)
                        : const Color(0xFFB8BEC7),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 74,
      color: Color(0xFFF2F4F7),
    );
  }
}

class _ProfileFailureBanner extends StatelessWidget {
  const _ProfileFailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD6DC)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFFF5D72),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF854052),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
