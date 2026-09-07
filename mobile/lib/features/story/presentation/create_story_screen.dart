import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/features/media/domain/prepared_photo_upload.dart';
import 'package:memory_map/features/media/presentation/media_failure_message.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/application/stories_state.dart';
import 'package:memory_map/features/story/application/story_cover_notifier.dart';
import 'package:memory_map/features/story/application/story_cover_state.dart';
import 'package:memory_map/features/story/domain/story.dart';
import 'package:memory_map/features/story/domain/story_failure.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/features/story/presentation/story_failure_message.dart';
import 'package:memory_map/features/story/presentation/widgets/story_form_failure_banner.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const _createStoryBackground = Color(0xFFFBF6F1);
const _createStoryInk = Color(0xFF182331);
const _createStoryMuted = Color(0xFF747B86);
const _createStoryAccent = Color(0xFFE05D6E);
const _createStoryAccentSoft = Color(0xFFFFEEF0);
const _createStoryBorder = Color(0x1FEA6D7A);
const _createStoryInputFill = Color(0xFFFFFDFB);
const _createStoryDisplayFontFamily = 'NotoSerif';
const _createStoryHeroAsset = 'assets/hero_create_story.png';

class CreateStoryScreen extends ConsumerStatefulWidget {
  const CreateStoryScreen({
    this.onCancel,
    this.onCreated,
    super.key,
  });

  final VoidCallback? onCancel;
  final ValueChanged<Story>? onCreated;

  @override
  ConsumerState<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends ConsumerState<CreateStoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  bool _submitInFlight = false;
  bool _createdCallbackCalled = false;
  bool _isSelectingCover = false;
  bool _isPreparingCover = false;
  bool _isUploadingCover = false;
  bool _coverUploadFailed = false;
  PreparedPhotoUpload? _preparedCover;
  MediaFailure? _coverMediaFailure;
  StoryFailure? _coverUploadFailure;
  Story? _createdStoryAwaitingCover;
  ProviderSubscription<AsyncValue<StoryCoverState>>? _coverSubscription;

  @override
  void dispose() {
    _coverSubscription?.close();
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final storiesValue = ref.watch(storiesNotifierProvider);
    final storiesState = storiesValue.asData?.value;
    final isCreatingStory =
        _submitInFlight || (storiesState?.isCreating ?? false);
    final isCoverBusy = _isSelectingCover || _isPreparingCover ||
        _isUploadingCover;
    final isBusy = isCreatingStory || isCoverBusy;
    final hasPersistedStory = _createdStoryAwaitingCover != null;
    final hasPartialCoverFailure = hasPersistedStory && _coverUploadFailed;
    final hasLocalCoverState = _preparedCover != null ||
        _coverMediaFailure != null;
    final failureMessage = _failureMessage(l10n, storiesValue, storiesState);
    final coverFailureMessage = _coverFailureMessage(l10n);
    final mediaPadding = MediaQuery.paddingOf(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || isBusy) {
          return;
        }

        if (hasPersistedStory) {
          _continueWithoutCover();
        } else {
          widget.onCancel?.call();
        }
      },
      child: Scaffold(
        backgroundColor: _createStoryBackground,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: _CreateStoryHero(
                  title: l10n.createStoryPageTitle,
                  subtitle: l10n.createStoryHeroSubtitle,
                  isBusy: isBusy,
                  onCancel: hasPersistedStory
                      ? _continueWithoutCover
                      : widget.onCancel,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  28,
                  24,
                  32 +
                      MediaQuery.viewInsetsOf(context).bottom +
                      mediaPadding.bottom,
                ),
                sliver: SliverToBoxAdapter(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CreateStoryFormCard(
                          titleController: _titleController,
                          descriptionController: _descriptionController,
                          titleFocusNode: _titleFocusNode,
                          descriptionFocusNode: _descriptionFocusNode,
                          enabled: !isBusy && !hasPersistedStory,
                          preparedCover: _preparedCover,
                          isCoverSelecting: _isSelectingCover,
                          isCoverPreparing: _isPreparingCover,
                          isCoverUploading: _isUploadingCover,
                          coverFailureMessage: coverFailureMessage,
                          onChooseCover:
                              isBusy || hasPersistedStory ? null : _chooseCover,
                          onRemoveSelectedCover:
                              isBusy || hasPersistedStory || !hasLocalCoverState
                                  ? null
                                  : _removeSelectedCover,
                        ),
                        if (failureMessage != null) ...[
                          const SizedBox(height: 16),
                          StoryFormFailureBanner(message: failureMessage),
                        ],
                        if (hasPartialCoverFailure) ...[
                          const SizedBox(height: 16),
                          _CreateStoryCoverPartialSuccessPanel(
                            failureMessage: _partialCoverFailureMessage(l10n),
                            isRetrying: _isUploadingCover,
                            onRetry:
                                _isUploadingCover ? null : _retryCoverUpload,
                            onContinue: _isUploadingCover
                                ? null
                                : _continueWithoutCover,
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (!hasPartialCoverFailure) ...[
                          _CreateStoryButton(
                            isCreating: isCreatingStory,
                            isUploadingCover: _isUploadingCover,
                            onPressed:
                                isBusy || hasPersistedStory ? null : _submit,
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            key: const ValueKey('create-story.cancel-action'),
                            onPressed: isBusy ? null : widget.onCancel,
                            style: TextButton.styleFrom(
                              foregroundColor: _createStoryAccent,
                              minimumSize: const Size.fromHeight(48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                            child: Text(l10n.cancel),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _failureMessage(
    AppLocalizations l10n,
    AsyncValue<StoriesState> storiesValue,
    StoriesState? storiesState,
  ) {
    if (storiesValue.hasError) {
      return l10n.storyFailureUnknown;
    }

    final failure = storiesState?.createFailure;
    if (failure == null) {
      return null;
    }

    return storyFailureMessage(l10n, failure);
  }

  String? _coverFailureMessage(AppLocalizations l10n) {
    final failure = _coverMediaFailure;
    if (failure == null) {
      return null;
    }

    return mediaFailureMessage(l10n, failure);
  }

  String? _partialCoverFailureMessage(AppLocalizations l10n) {
    final failure = _coverUploadFailure;
    if (failure == null) {
      return null;
    }

    return storyFailureMessage(l10n, failure);
  }

  Future<void> _chooseCover() async {
    if (_isCoverFlowBusy || _createdStoryAwaitingCover != null) {
      return;
    }

    setState(() {
      _coverMediaFailure = null;
      _coverUploadFailure = null;
      _coverUploadFailed = false;
      _isSelectingCover = true;
    });

    try {
      final selected = await ref.read(photoSelectionGatewayProvider)
          .selectPhoto();
      if (!mounted) {
        return;
      }

      if (selected == null) {
        setState(() {
          _isSelectingCover = false;
        });
        return;
      }

      setState(() {
        _isSelectingCover = false;
        _isPreparingCover = true;
      });

      final prepared = await ref.read(photoPreprocessorProvider).process(
            selected,
          );
      if (!mounted) {
        return;
      }

      setState(() {
        _preparedCover = prepared;
        _coverMediaFailure = null;
        _isPreparingCover = false;
      });
    } on MediaApplicationException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSelectingCover = false;
        _isPreparingCover = false;
        _coverMediaFailure = error.failure;
      });
    } on Object {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSelectingCover = false;
        _isPreparingCover = false;
        _coverMediaFailure = const UnknownMediaFailure();
      });
    }
  }

  void _removeSelectedCover() {
    if (_isCoverFlowBusy || _createdStoryAwaitingCover != null) {
      return;
    }

    setState(() {
      _preparedCover = null;
      _coverMediaFailure = null;
      _coverUploadFailure = null;
      _coverUploadFailed = false;
    });
  }

  Future<void> _submit() async {
    if (_submitInFlight ||
        _isCoverFlowBusy ||
        _createdStoryAwaitingCover != null ||
        _coverMediaFailure != null) {
      return;
    }

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _coverMediaFailure = null;
      _coverUploadFailure = null;
      _coverUploadFailed = false;
      _submitInFlight = true;
    });

    final createdStory = await ref.read(storiesNotifierProvider.notifier)
        .createStory(
          title: _titleController.text,
          description: _descriptionForSubmit(),
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _submitInFlight = false;
    });

    if (createdStory == null) {
      return;
    }

    if (_preparedCover == null) {
      _finishCreated(createdStory);
      return;
    }

    setState(() {
      _createdStoryAwaitingCover = createdStory;
    });

    final uploadedStory = await _uploadCover(createdStory);
    if (uploadedStory != null && !_createdCallbackCalled) {
      ref.read(storiesNotifierProvider.notifier).upsertUserStory(uploadedStory);
      _finishCreated(uploadedStory.story);
    }
  }

  Future<void> _retryCoverUpload() async {
    if (_isCoverFlowBusy) {
      return;
    }

    final createdStory = _createdStoryAwaitingCover;
    if (createdStory == null || _preparedCover == null) {
      return;
    }

    final uploadedStory = await _uploadCover(createdStory);
    if (uploadedStory != null && !_createdCallbackCalled) {
      ref.read(storiesNotifierProvider.notifier).upsertUserStory(uploadedStory);
      _finishCreated(uploadedStory.story);
    }
  }

  void _continueWithoutCover() {
    final createdStory = _createdStoryAwaitingCover;
    if (createdStory == null || _createdCallbackCalled) {
      return;
    }

    _releaseCoverSubscription();
    _finishCreated(createdStory);
  }

  Future<UserStory?> _uploadCover(Story createdStory) async {
    final preparedCover = _preparedCover;
    if (preparedCover == null) {
      return null;
    }

    final coverProvider = storyCoverProvider(createdStory.id);
    _coverSubscription ??= ref.listenManual(
      coverProvider,
      (_, __) {},
    );
    setState(() {
      _isUploadingCover = true;
      _coverUploadFailure = null;
      _coverUploadFailed = false;
    });

    await ref.read(coverProvider.future);
    if (!mounted) {
      return null;
    }

    final uploadedStory = await ref
        .read(coverProvider.notifier)
        .uploadStoryCover(preparedCover);
    if (!mounted) {
      return null;
    }

    if (uploadedStory == null) {
      final coverValue = ref.read(coverProvider);
      setState(() {
        _isUploadingCover = false;
        _coverUploadFailed = true;
        _coverUploadFailure = coverValue.asData?.value.failure;
      });
      return null;
    }

    setState(() {
      _isUploadingCover = false;
      _coverUploadFailed = false;
      _coverUploadFailure = null;
      _createdStoryAwaitingCover = null;
    });
    _releaseCoverSubscription();
    return uploadedStory;
  }

  void _finishCreated(Story createdStory) {
    if (_createdCallbackCalled) {
      return;
    }

    _createdCallbackCalled = true;
    widget.onCreated?.call(createdStory);
  }

  void _releaseCoverSubscription() {
    _coverSubscription?.close();
    _coverSubscription = null;
  }

  String? _descriptionForSubmit() {
    final description = _descriptionController.text;
    if (description.isEmpty) {
      return null;
    }

    return description;
  }

  bool get _isCoverFlowBusy {
    return _isSelectingCover || _isPreparingCover || _isUploadingCover;
  }
}

class _CreateStoryHero extends StatelessWidget {
  const _CreateStoryHero({
    required this.title,
    required this.subtitle,
    required this.isBusy,
    required this.onCancel,
  });

  final String title;
  final String subtitle;
  final bool isBusy;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CreateStoryHeroImage(
          isBusy: isBusy,
          onCancel: onCancel,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _createStoryInk,
              fontFamily: _createStoryDisplayFontFamily,
              fontFamilyFallback: <String>['NotoSerifGeorgian'],
              fontSize: 33,
              fontWeight: FontWeight.w500,
              height: 1.08,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _createStoryMuted,
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateStoryHeroImage extends StatelessWidget {
  const _CreateStoryHeroImage({
    required this.isBusy,
    required this.onCancel,
  });

  final bool isBusy;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = (width * 0.72).clamp(220.0, 280.0).toDouble();

        return SizedBox(
          width: double.infinity,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: Image.asset(
                    _createStoryHeroAsset,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _createStoryBackground.withValues(alpha: 0),
                        _createStoryBackground.withValues(alpha: 0.18),
                        _createStoryBackground.withValues(alpha: 0.72),
                        _createStoryBackground,
                      ],
                      stops: const [0.58, 0.74, 0.91, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: MediaQuery.paddingOf(context).top + 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _createStoryBackground.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: IconButton(
                    key: const ValueKey('create-story.back-action'),
                    onPressed: isBusy ? null : onCancel,
                    tooltip: l10n.createStoryBackLabel,
                    color: _createStoryInk,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CreateStoryFormCard extends StatelessWidget {
  const _CreateStoryFormCard({
    required this.titleController,
    required this.descriptionController,
    required this.titleFocusNode,
    required this.descriptionFocusNode,
    required this.enabled,
    required this.preparedCover,
    required this.isCoverSelecting,
    required this.isCoverPreparing,
    required this.isCoverUploading,
    required this.coverFailureMessage,
    required this.onChooseCover,
    required this.onRemoveSelectedCover,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final FocusNode titleFocusNode;
  final FocusNode descriptionFocusNode;
  final bool enabled;
  final PreparedPhotoUpload? preparedCover;
  final bool isCoverSelecting;
  final bool isCoverPreparing;
  final bool isCoverUploading;
  final String? coverFailureMessage;
  final VoidCallback? onChooseCover;
  final VoidCallback? onRemoveSelectedCover;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CreateStoryCoverSection(
          preparedCover: preparedCover,
          isSelecting: isCoverSelecting,
          isPreparing: isCoverPreparing,
          isUploading: isCoverUploading,
          failureMessage: coverFailureMessage,
          onChooseCover: onChooseCover,
          onRemoveSelectedCover: onRemoveSelectedCover,
        ),
        const SizedBox(height: 28),
        _FieldLabel(
          label: l10n.createStoryTitleLabel,
          required: true,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('create-story.title-field'),
          controller: titleController,
          focusNode: titleFocusNode,
          enabled: enabled,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) {
            descriptionFocusNode.requestFocus();
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.createStoryTitleRequired;
            }

            if (value.trim().isEmpty) {
              return l10n.createStoryTitleBlank;
            }

            return null;
          },
          decoration: _inputDecoration(
            hintText: l10n.createStoryTitleHint,
          ),
        ),
        const SizedBox(height: 24),
        _FieldLabel(
          label: l10n.createStoryDescriptionLabel,
          optionalText: l10n.createStoryDescriptionOptional,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('create-story.description-field'),
          controller: descriptionController,
          focusNode: descriptionFocusNode,
          enabled: enabled,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
          decoration: _inputDecoration(
            hintText: l10n.createStoryDescriptionHint,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFA0A7B1),
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: _createStoryInputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFEFE5E1), width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xB8E05D6E), width: 1.1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _createStoryAccent, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _createStoryAccent, width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFF2EBE8), width: 0.8),
      ),
    );
  }
}

class _CreateStoryCoverSection extends StatelessWidget {
  const _CreateStoryCoverSection({
    required this.preparedCover,
    required this.isSelecting,
    required this.isPreparing,
    required this.isUploading,
    required this.failureMessage,
    required this.onChooseCover,
    required this.onRemoveSelectedCover,
  });

  final PreparedPhotoUpload? preparedCover;
  final bool isSelecting;
  final bool isPreparing;
  final bool isUploading;
  final String? failureMessage;
  final VoidCallback? onChooseCover;
  final VoidCallback? onRemoveSelectedCover;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasCover = preparedCover != null;
    final hasLocalSelectionState = hasCover || failureMessage != null;
    final chooseLabel = hasCover
        ? l10n.editStoryCoverChangeAction
        : l10n.editStoryCoverChooseAction;
    final statusMessage = _statusMessage(l10n);

    return Column(
      key: const ValueKey('create-story.cover-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: l10n.editStoryCoverLabel),
        const SizedBox(height: 12),
        _LocalStoryCoverPreview(
          preparedCover: preparedCover,
          photoLabel: l10n.editStoryCoverPhotoLabel,
          emptyLabel: l10n.editStoryCoverNoPhoto,
          chooseLabel: chooseLabel,
          isBusy: isSelecting || isPreparing || isUploading,
          statusMessage: statusMessage,
          onChooseCover: onChooseCover,
        ),
        if (hasLocalSelectionState) ...[
          const SizedBox(height: 14),
          if (hasCover)
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: OutlinedButton.icon(
                    key: const ValueKey('create-story.cover.choose-action'),
                    onPressed: onChooseCover,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _createStoryAccent,
                      side: const BorderSide(color: _createStoryBorder),
                      backgroundColor: _createStoryInputFill,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    icon: isSelecting || isPreparing || isUploading
                        ? const _ButtonProgressIndicator()
                        : const Icon(Icons.photo_library_rounded),
                    label: Text(
                      chooseLabel,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: TextButton.icon(
                    key: const ValueKey(
                      'create-story.cover.remove-selection-action',
                    ),
                    onPressed: onRemoveSelectedCover,
                    style: TextButton.styleFrom(
                      foregroundColor: _createStoryMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      l10n.createStoryCoverRemoveSelectionAction,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            )
          else
            TextButton.icon(
              key: const ValueKey(
                'create-story.cover.remove-selection-action',
              ),
              onPressed: onRemoveSelectedCover,
              style: TextButton.styleFrom(
                foregroundColor: _createStoryMuted,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
              ),
              label: Text(l10n.createStoryCoverRemoveSelectionAction),
            ),
        ],
        if (failureMessage != null) ...[
          const SizedBox(height: 12),
          StoryFormFailureBanner(message: failureMessage!),
        ],
      ],
    );
  }

  String? _statusMessage(AppLocalizations l10n) {
    if (isSelecting) {
      return l10n.editStoryCoverSelecting;
    }

    if (isPreparing) {
      return l10n.editStoryCoverPreparing;
    }

    if (isUploading) {
      return l10n.createStoryCoverUploading;
    }

    return null;
  }
}

class _LocalStoryCoverPreview extends StatelessWidget {
  const _LocalStoryCoverPreview({
    required this.preparedCover,
    required this.photoLabel,
    required this.emptyLabel,
    required this.chooseLabel,
    required this.isBusy,
    required this.statusMessage,
    required this.onChooseCover,
  });

  final PreparedPhotoUpload? preparedCover;
  final String photoLabel;
  final String emptyLabel;
  final String chooseLabel;
  final bool isBusy;
  final String? statusMessage;
  final VoidCallback? onChooseCover;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(20));
    final cover = preparedCover;

    return Semantics(
      liveRegion: statusMessage != null,
      label: statusMessage,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          height: cover == null ? 132.0 : 176.0,
          width: double.infinity,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: _createStoryAccentSoft,
              borderRadius: borderRadius,
            ),
            child: cover == null
                ? Semantics(
                    button: true,
                    enabled: onChooseCover != null,
                    label: chooseLabel,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        key: const ValueKey('create-story.cover.choose-action'),
                        onTap: onChooseCover,
                        child: _StoryCoverEmptyState(
                          key: const ValueKey('create-story.cover.no-photo'),
                          message: emptyLabel,
                          actionLabel: chooseLabel,
                          isBusy: isBusy,
                        ),
                      ),
                    ),
                  )
                : Semantics(
                    image: true,
                    label: photoLabel,
                    child: ExcludeSemantics(
                      child: Image.memory(
                        cover.bytes,
                        key: const ValueKey(
                          'create-story.cover.local-preview-image',
                        ),
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _StoryCoverEmptyState extends StatelessWidget {
  const _StoryCoverEmptyState({
    required this.message,
    required this.actionLabel,
    required this.isBusy,
    super.key,
  });

  final String message;
  final String actionLabel;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _createStoryInputFill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: isBusy
                  ? const _ButtonProgressIndicator()
                  : const Icon(
                      Icons.image_outlined,
                      color: _createStoryAccent,
                      size: 26,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _createStoryMuted,
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            actionLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _createStoryAccent,
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateStoryCoverPartialSuccessPanel extends StatelessWidget {
  const _CreateStoryCoverPartialSuccessPanel({
    required this.failureMessage,
    required this.isRetrying,
    required this.onRetry,
    required this.onContinue,
  });

  final String? failureMessage;
  final bool isRetrying;
  final VoidCallback? onRetry;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: const ValueKey('create-story.cover.partial-success-panel'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFF97316),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.createStoryCoverPartialTitle,
                      style: const TextStyle(
                        color: _createStoryInk,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.createStoryCoverPartialMessage,
                      style: const TextStyle(
                        color: _createStoryMuted,
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                    if (failureMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        failureMessage!,
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('create-story.cover.retry-action'),
                onPressed: onRetry,
                icon: isRetrying
                    ? const _ButtonProgressIndicator(color: Colors.white)
                    : const Icon(Icons.refresh_rounded),
                label: Text(l10n.createStoryCoverRetryAction),
              ),
              TextButton(
                key: const ValueKey('create-story.cover.continue-action'),
                onPressed: onContinue,
                child: Text(l10n.createStoryCoverContinueAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.label,
    this.required = false,
    this.optionalText,
  });

  final String label;
  final bool required;
  final String? optionalText;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _createStoryInk,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        if (required)
          const Text(
            '*',
            style: TextStyle(
              color: _createStoryAccent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        if (optionalText != null)
          Text(
            optionalText!,
            style: const TextStyle(
              color: _createStoryMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
      ],
    );
  }
}

class _CreateStoryButton extends StatelessWidget {
  const _CreateStoryButton({
    required this.isCreating,
    required this.isUploadingCover,
    required this.onPressed,
  });

  final bool isCreating;
  final bool isUploadingCover;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FilledButton(
      key: const ValueKey('create-story.submit-action'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFD16A74),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE9A5AD),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      child: isCreating || isUploadingCover
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isUploadingCover
                      ? l10n.createStoryCoverUploading
                      : l10n.createStoryCreatingButton,
                ),
              ],
            )
          : Text(l10n.createStorySubmitButton),
    );
  }
}

class _ButtonProgressIndicator extends StatelessWidget {
  const _ButtonProgressIndicator({
    this.color = _createStoryAccent,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: color,
      ),
    );
  }
}
