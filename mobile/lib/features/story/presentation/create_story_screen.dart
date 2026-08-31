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
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  sliver: SliverToBoxAdapter(
                    child: _CreateStoryAppBar(
                      isBusy: isBusy,
                      onCancel: hasPersistedStory
                          ? _continueWithoutCover
                          : widget.onCancel,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: _CreateStoryHero(
                      title: l10n.createStoryHeroTitle,
                      subtitle: l10n.createStoryHeroSubtitle,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    30,
                    24,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
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
                              onRetry: _isUploadingCover
                                  ? null
                                  : _retryCoverUpload,
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
                              onPressed: isBusy || hasPersistedStory
                                  ? null
                                  : _submit,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              key: const ValueKey('create-story.cancel-action'),
                              onPressed: isBusy ? null : widget.onCancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFF5D72),
                                side: const BorderSide(
                                  color: Color(0xFFFF8A99),
                                ),
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

class _CreateStoryAppBar extends StatelessWidget {
  const _CreateStoryAppBar({
    required this.isBusy,
    required this.onCancel,
  });

  final bool isBusy;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        IconButton(
          key: const ValueKey('create-story.back-action'),
          onPressed: isBusy ? null : onCancel,
          tooltip: l10n.createStoryBackLabel,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        Expanded(
          child: Text(
            l10n.createStoryPageTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _CreateStoryHero extends StatelessWidget {
  const _CreateStoryHero({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _CreateStoryIllustration(),
        const SizedBox(height: 28),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.1,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 18,
            height: 1.45,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _CreateStoryIllustration extends StatelessWidget {
  const _CreateStoryIllustration();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 220,
        height: 154,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 26,
              left: 14,
              child: _SoftHill(
                width: 88,
                height: 56,
                color: const Color(0xFFE9E5EA),
              ),
            ),
            Positioned(
              bottom: 20,
              right: 10,
              child: _SoftHill(
                width: 118,
                height: 76,
                color: const Color(0xFFF0ECEF),
              ),
            ),
            Positioned(
              top: 18,
              child: Container(
                width: 78,
                height: 98,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5D72),
                  borderRadius: BorderRadius.circular(42),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33FF5D72),
                      offset: Offset(0, 12),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
            const Positioned(
              top: 28,
              right: 38,
              child: Icon(
                Icons.favorite_rounded,
                color: Color(0x33FF5D72),
                size: 24,
              ),
            ),
            const Positioned(
              top: 48,
              left: 54,
              child: Icon(
                Icons.favorite_rounded,
                color: Color(0x33FF5D72),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftHill extends StatelessWidget {
  const _SoftHill({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
      ),
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            offset: Offset(0, 12),
            blurRadius: 28,
          ),
        ],
      ),
      child: Column(
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
          const SizedBox(height: 24),
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
          const SizedBox(height: 10),
          Text(
            l10n.createStoryTitleHelp,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 22),
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
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE8EBEF)),
          const SizedBox(height: 22),
          _NameIdeas(l10n: l10n),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFA8AFBA),
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD8DDE5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFFF6B7D), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFFF5D72), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFFF5D72), width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
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
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('create-story.cover.choose-action'),
              onPressed: onChooseCover,
              icon: isSelecting || isPreparing || isUploading
                  ? const _ButtonProgressIndicator()
                  : const Icon(Icons.photo_library_rounded),
              label: Text(chooseLabel),
            ),
            if (hasLocalSelectionState)
              TextButton.icon(
                key: const ValueKey(
                  'create-story.cover.remove-selection-action',
                ),
                onPressed: onRemoveSelectedCover,
                icon: const Icon(Icons.close_rounded),
                label: Text(l10n.createStoryCoverRemoveSelectionAction),
              ),
          ],
        ),
        if (statusMessage != null) ...[
          const SizedBox(height: 10),
          _CoverStatusMessage(message: statusMessage),
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
  });

  final PreparedPhotoUpload? preparedCover;
  final String photoLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(20));
    final cover = preparedCover;

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: 176,
        width: double.infinity,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFFFFF1F3),
            borderRadius: borderRadius,
          ),
          child: cover == null
              ? _StoryCoverEmptyState(
                  key: const ValueKey('create-story.cover.no-photo'),
                  message: emptyLabel,
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
    );
  }
}

class _StoryCoverEmptyState extends StatelessWidget {
  const _StoryCoverEmptyState({
    required this.message,
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.image_outlined,
              color: Color(0xFFFF5D72),
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverStatusMessage extends StatelessWidget {
  const _CoverStatusMessage({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const ValueKey('create-story.cover.status'),
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFFF5D72),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
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
                        color: Color(0xFF1F2937),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.createStoryCoverPartialMessage,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
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
            color: Color(0xFF1F2937),
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        if (required)
          const Text(
            '*',
            style: TextStyle(
              color: Color(0xFFFF5D72),
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        if (optionalText != null)
          Text(
            optionalText!,
            style: const TextStyle(
              color: Color(0xFF8A93A3),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
      ],
    );
  }
}

class _NameIdeas extends StatelessWidget {
  const _NameIdeas({
    required this.l10n,
  });

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F3),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: Color(0xFFFF5D72),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.createStoryWhyTitle,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.createStoryWhyDescription,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 15,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            l10n.createStoryIdeasTitle,
            style: const TextStyle(
              color: Color(0xFFFF5D72),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          _IdeaText(l10n.createStoryIdeaOne),
          _IdeaText(l10n.createStoryIdeaTwo),
          _IdeaText(l10n.createStoryIdeaThree),
        ],
      ),
    );
  }
}

class _IdeaText extends StatelessWidget {
  const _IdeaText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.favorite_rounded,
            color: Color(0xFFFF7D8D),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 15,
                height: 1.35,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
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
        backgroundColor: const Color(0xFFFF5D72),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFFFB3BD),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(58),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w900,
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
    this.color = const Color(0xFFFF5D72),
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
