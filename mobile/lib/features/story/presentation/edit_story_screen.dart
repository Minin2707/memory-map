import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/media/application/media_application_exception.dart';
import 'package:memory_map/features/media/application/media_application_providers.dart';
import 'package:memory_map/features/media/domain/media_failure.dart';
import 'package:memory_map/features/media/presentation/media_failure_message.dart';
import 'package:memory_map/features/media/presentation/widgets/authenticated_media_image.dart';
import 'package:memory_map/features/story/application/edit_story_notifier.dart';
import 'package:memory_map/features/story/application/edit_story_state.dart';
import 'package:memory_map/features/story/application/story_cover_notifier.dart';
import 'package:memory_map/features/story/application/story_cover_state.dart';
import 'package:memory_map/features/story/domain/story_cover_preview_policy.dart';
import 'package:memory_map/features/story/domain/story_photo_preview.dart';
import 'package:memory_map/features/story/domain/story_update_field.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/features/story/presentation/story_failure_message.dart';
import 'package:memory_map/features/story/presentation/widgets/story_form_failure_banner.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const _editStoryBackground = Color(0xFFFBF6F1);
const _editStoryInk = Color(0xFF182331);
const _editStoryMuted = Color(0xFF747B86);
const _editStoryAccent = Color(0xFFD16A74);
const _editStoryAccentSoft = Color(0xFFFFEEF0);
const _editStoryInputFill = Color(0xFFFFFDFB);
const _editStoryBorder = Color(0xFFEFE5E1);
const _editStoryDisplayFontFamily = 'NotoSerif';

class EditStoryScreen extends ConsumerStatefulWidget {
  const EditStoryScreen({
    required this.userStory,
    this.onCancel,
    this.onUpdated,
    super.key,
  });

  final UserStory userStory;
  final VoidCallback? onCancel;
  final ValueChanged<UserStory>? onUpdated;

  @override
  ConsumerState<EditStoryScreen> createState() => _EditStoryScreenState();
}

enum _EditStoryCoverFeedback {
  updated,
  removed,
}

class _EditStoryScreenState extends ConsumerState<EditStoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  late String _originalTitle;
  late String? _originalDescription;
  bool _updatedCallbackCalled = false;
  bool _isSelectingCover = false;
  bool _isPreparingCover = false;
  MediaFailure? _coverMediaFailure;
  _EditStoryCoverFeedback? _coverFeedback;

  @override
  void initState() {
    super.initState();
    final story = widget.userStory.story;
    _originalTitle = story.title;
    _originalDescription = story.description;
    _titleController = TextEditingController(text: story.title);
    _descriptionController = TextEditingController(
      text: story.description ?? '',
    );
    _titleController.addListener(_onDraftChanged);
    _descriptionController.addListener(_onDraftChanged);
  }

  @override
  void didUpdateWidget(EditStoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userStory.story.id == widget.userStory.story.id) {
      return;
    }

    final story = widget.userStory.story;
    _originalTitle = story.title;
    _originalDescription = story.description;
    _titleController.text = story.title;
    _descriptionController.text = story.description ?? '';
    _updatedCallbackCalled = false;
    _coverFeedback = null;
  }

  @override
  void dispose() {
    _titleController.removeListener(_onDraftChanged);
    _descriptionController.removeListener(_onDraftChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editValue = ref.watch(editStoryProvider(widget.userStory.story.id));
    final editState = editValue.asData?.value;
    final isSaving = editState?.isSaving ?? false;

    if (!widget.userStory.canUpdateStoryMetadata) {
      return _EditStoryScaffold(
        isSaving: false,
        onCancel: widget.onCancel,
        child: _UnavailableView(onCancel: widget.onCancel),
      );
    }

    final coverValue = ref.watch(storyCoverProvider(widget.userStory.story.id));
    final coverState = coverValue.asData?.value ?? const StoryCoverState();
    final isCoverBusy = coverValue.isLoading ||
        coverState.isBusy ||
        _isSelectingCover ||
        _isPreparingCover;
    final failureMessage = _failureMessage(l10n, editValue, editState);
    final coverFailureMessage = _coverFailureMessage(
      l10n,
      coverValue,
      coverState,
    );
    final coverSuccessMessage = _coverSuccessMessage(l10n);
    final hasChanges = _hasChanges;
    final canSave = hasChanges && !isSaving;

    return _EditStoryScaffold(
      isSaving: isSaving,
      onCancel: widget.onCancel,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EditStoryFormCard(
              titleController: _titleController,
              descriptionController: _descriptionController,
              titleFocusNode: _titleFocusNode,
              descriptionFocusNode: _descriptionFocusNode,
              enabled: !isSaving,
              userStory: widget.userStory,
              coverState: coverState,
              isCoverSelecting: _isSelectingCover,
              isCoverPreparing: _isPreparingCover,
              isCoverBusy: isCoverBusy,
              coverFailureMessage: coverFailureMessage,
              coverSuccessMessage: coverSuccessMessage,
              onChooseCover: isCoverBusy ? null : _chooseCover,
              onRemoveCover: isCoverBusy ? null : _removeCover,
            ),
            if (failureMessage != null) ...[
              const SizedBox(height: 16),
              StoryFormFailureBanner(message: failureMessage),
            ],
            const SizedBox(height: 24),
            _EditStorySaveButton(
              isSaving: isSaving,
              onPressed: canSave ? _submit : null,
            ),
            const SizedBox(height: 10),
            TextButton(
              key: const ValueKey('edit-story.cancel-action'),
              onPressed: isSaving ? null : widget.onCancel,
              style: TextButton.styleFrom(
                foregroundColor: _editStoryAccent,
                disabledForegroundColor: _editStoryMuted,
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
        ),
      ),
    );
  }

  String? _failureMessage(
    AppLocalizations l10n,
    AsyncValue<EditStoryState> editValue,
    EditStoryState? editState,
  ) {
    if (editValue.hasError) {
      return l10n.storyFailureUnknown;
    }

    final failure = editState?.saveFailure;
    if (failure == null) {
      return null;
    }

    return storyFailureMessage(l10n, failure);
  }

  String? _coverFailureMessage(
    AppLocalizations l10n,
    AsyncValue<StoryCoverState> coverValue,
    StoryCoverState coverState,
  ) {
    final mediaFailure = _coverMediaFailure;
    if (mediaFailure != null) {
      return mediaFailureMessage(l10n, mediaFailure);
    }

    final storyFailure = coverState.failure;
    if (storyFailure != null) {
      return storyFailureMessage(l10n, storyFailure);
    }

    if (coverValue.hasError) {
      return l10n.storyFailureUnknown;
    }

    return null;
  }

  String? _coverSuccessMessage(AppLocalizations l10n) {
    final feedback = _coverFeedback;
    if (feedback == _EditStoryCoverFeedback.updated) {
      return l10n.editStoryCoverUpdatedFeedback;
    }

    if (feedback == _EditStoryCoverFeedback.removed) {
      return l10n.editStoryCoverRemovedFeedback;
    }

    return null;
  }
  Future<void> _chooseCover() async {
    if (_isCoverFlowBusy) {
      return;
    }

    setState(() {
      _coverMediaFailure = null;
      _coverFeedback = null;
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
        _isPreparingCover = false;
      });

      final updatedStory = await ref
          .read(storyCoverProvider(widget.userStory.story.id).notifier)
          .uploadStoryCover(prepared);
      if (!mounted || updatedStory == null) {
        return;
      }

      setState(() {
        _coverFeedback = _EditStoryCoverFeedback.updated;
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

  Future<void> _removeCover() async {
    if (_isCoverFlowBusy) {
      return;
    }

    setState(() {
      _coverMediaFailure = null;
      _coverFeedback = null;
    });

    final removedStory = await ref
        .read(storyCoverProvider(widget.userStory.story.id).notifier)
        .removeStoryCover();
    if (!mounted || removedStory == null) {
      return;
    }

    setState(() {
      _coverFeedback = _EditStoryCoverFeedback.removed;
    });
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final input = _buildInput();
    if (input == null) {
      setState(() {});
      return;
    }

    FocusScope.of(context).unfocus();
    final updatedStory = await ref
        .read(editStoryProvider(widget.userStory.story.id).notifier)
        .save(input);

    if (!mounted || updatedStory == null || _updatedCallbackCalled) {
      return;
    }

    _updatedCallbackCalled = true;
    widget.onUpdated?.call(updatedStory);
  }

  UpdateStoryInput? _buildInput() {
    final title = _titleController.text;
    final titleField = title == _originalTitle
        ? const StoryUpdateField<String>.notProvided()
        : StoryUpdateField<String>.provided(title);
    final descriptionField = _descriptionField();

    if (!titleField.isProvided && !descriptionField.isProvided) {
      return null;
    }

    return UpdateStoryInput(
      storyId: widget.userStory.story.id,
      title: titleField,
      description: descriptionField,
    );
  }

  StoryUpdateField<String> _descriptionField() {
    final original = _originalDescription;
    final current = _descriptionController.text;

    if (original == null || original.isEmpty) {
      if (current.isEmpty) {
        return const StoryUpdateField<String>.notProvided();
      }

      return StoryUpdateField<String>.provided(current);
    }

    if (current == original) {
      return const StoryUpdateField<String>.notProvided();
    }

    if (current.isEmpty) {
      return const StoryUpdateField<String>.provided(null);
    }

    return StoryUpdateField<String>.provided(current);
  }

  bool get _hasChanges {
    final titleChanged = _titleController.text != _originalTitle;
    final descriptionChanged = _descriptionField().isProvided;
    return titleChanged || descriptionChanged;
  }

  bool get _isCoverFlowBusy {
    if (_isSelectingCover || _isPreparingCover) {
      return true;
    }

    final coverState = ref.read(storyCoverProvider(widget.userStory.story.id));
    return coverState.isLoading || (coverState.asData?.value.isBusy ?? false);
  }

  void _onDraftChanged() {
    setState(() {});
  }
}

class _EditStoryScaffold extends StatelessWidget {
  const _EditStoryScaffold({
    required this.isSaving,
    required this.onCancel,
    required this.child,
  });

  final bool isSaving;
  final VoidCallback? onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || isSaving) {
          return;
        }

        onCancel?.call();
      },
      child: Scaffold(
        backgroundColor: _editStoryBackground,
        body: SafeArea(
          bottom: false,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 24, 8),
                  sliver: SliverToBoxAdapter(
                    child: _EditStoryHeader(
                      isSaving: isSaving,
                      onCancel: onCancel,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    8,
                    24,
                    24 + MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  sliver: SliverToBoxAdapter(child: child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditStoryHeader extends StatelessWidget {
  const _EditStoryHeader({
    required this.isSaving,
    required this.onCancel,
  });

  final bool isSaving;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: _editStoryInputFill.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.68),
              width: 0.8,
            ),
          ),
          child: IconButton(
            key: const ValueKey('edit-story.back-action'),
            onPressed: isSaving ? null : onCancel,
            tooltip: l10n.editStoryBackLabel,
            color: _editStoryInk,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.editStoryPageTitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _editStoryInk,
                fontFamily: _editStoryDisplayFontFamily,
                fontFamilyFallback: <String>['NotoSerifGeorgian'],
                fontSize: 33,
                fontWeight: FontWeight.w500,
                height: 1.08,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditStoryFormCard extends StatelessWidget {
  const _EditStoryFormCard({
    required this.titleController,
    required this.descriptionController,
    required this.titleFocusNode,
    required this.descriptionFocusNode,
    required this.enabled,
    required this.userStory,
    required this.coverState,
    required this.isCoverSelecting,
    required this.isCoverPreparing,
    required this.isCoverBusy,
    required this.coverFailureMessage,
    required this.coverSuccessMessage,
    required this.onChooseCover,
    required this.onRemoveCover,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final FocusNode titleFocusNode;
  final FocusNode descriptionFocusNode;
  final bool enabled;
  final UserStory userStory;
  final StoryCoverState coverState;
  final bool isCoverSelecting;
  final bool isCoverPreparing;
  final bool isCoverBusy;
  final String? coverFailureMessage;
  final String? coverSuccessMessage;
  final VoidCallback? onChooseCover;
  final VoidCallback? onRemoveCover;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(text: l10n.storyDetailsDescriptionTitle),
        const SizedBox(height: 14),
        _EditStoryCoverSection(
          userStory: userStory,
          coverState: coverState,
          isSelecting: isCoverSelecting,
          isPreparing: isCoverPreparing,
          isBusy: isCoverBusy,
          failureMessage: coverFailureMessage,
          successMessage: coverSuccessMessage,
          onChooseCover: onChooseCover,
          onRemoveCover: onRemoveCover,
        ),
        const SizedBox(height: 28),
        _FieldLabel(
          label: l10n.editStoryTitleLabel,
          required: true,
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('edit-story.title-field'),
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
              return l10n.editStoryTitleRequired;
            }

            if (value.trim().isEmpty) {
              return l10n.editStoryTitleBlank;
            }

            return null;
          },
          decoration: _inputDecoration(
            hintText: l10n.editStoryTitleHint,
          ),
        ),
        const SizedBox(height: 18),
        _FieldLabel(
          label: l10n.editStoryDescriptionLabel,
          optionalText: l10n.editStoryDescriptionOptional,
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('edit-story.description-field'),
          controller: descriptionController,
          focusNode: descriptionFocusNode,
          enabled: enabled,
          minLines: 4,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
          decoration: _inputDecoration(
            hintText: l10n.editStoryDescriptionHint,
          ),
        ),
      ],
    );
  }
}

class _EditStoryCoverSection extends StatelessWidget {
  const _EditStoryCoverSection({
    required this.userStory,
    required this.coverState,
    required this.isSelecting,
    required this.isPreparing,
    required this.isBusy,
    required this.failureMessage,
    required this.successMessage,
    required this.onChooseCover,
    required this.onRemoveCover,
  });

  final UserStory userStory;
  final StoryCoverState coverState;
  final bool isSelecting;
  final bool isPreparing;
  final bool isBusy;
  final String? failureMessage;
  final String? successMessage;
  final VoidCallback? onChooseCover;
  final VoidCallback? onRemoveCover;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = userStory.previewPhoto;
    final hasPreview = preview != null;
    final hasExplicitCover = isExplicitStoryCoverPreview(
      storyId: userStory.story.id,
      preview: preview,
    );
    final chooseLabel = hasPreview
        ? l10n.editStoryCoverChangeAction
        : l10n.editStoryCoverChooseAction;
    final statusMessage = _statusMessage(l10n);

    return Column(
      key: const ValueKey('edit-story.cover-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: l10n.editStoryCoverLabel),
        const SizedBox(height: 12),
        _StoryCoverPreview(
          preview: preview,
          label: l10n.editStoryCoverPhotoLabel,
          emptyLabel: l10n.editStoryCoverNoPhoto,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            TextButton.icon(
              key: const ValueKey('edit-story.cover.choose-action'),
              onPressed: isBusy ? null : onChooseCover,
              style: TextButton.styleFrom(
                foregroundColor: _editStoryAccent,
                disabledForegroundColor: _editStoryMuted,
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              icon: isSelecting || isPreparing || coverState.isUploading
                  ? const _ButtonProgressIndicator()
                  : const Icon(Icons.photo_library_rounded, size: 18),
              label: Text(chooseLabel),
            ),
            if (hasExplicitCover)
              TextButton.icon(
                key: const ValueKey('edit-story.cover.remove-action'),
                onPressed: isBusy ? null : onRemoveCover,
                style: TextButton.styleFrom(
                  foregroundColor: _editStoryMuted,
                  disabledForegroundColor: _editStoryMuted.withValues(
                    alpha: 0.62,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                icon: coverState.isRemoving
                    ? const _ButtonProgressIndicator()
                    : const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(l10n.editStoryCoverRemoveAction),
              ),
          ],
        ),
        if (statusMessage != null)
          Semantics(
            liveRegion: true,
            label: statusMessage,
            child: const SizedBox.shrink(
              key: ValueKey('edit-story.cover.status'),
            ),
          )
        else if (successMessage != null) ...[
          const SizedBox(height: 10),
          _CoverSuccessMessage(message: successMessage!),
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

    if (coverState.isUploading) {
      return l10n.editStoryCoverUploading;
    }

    if (coverState.isRemoving) {
      return l10n.editStoryCoverRemoving;
    }

    return null;
  }
}

class _StoryCoverPreview extends StatelessWidget {
  const _StoryCoverPreview({
    required this.preview,
    required this.label,
    required this.emptyLabel,
  });

  final StoryPhotoPreview? preview;
  final String label;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(20));
    final currentPreview = preview;

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: 176,
        width: double.infinity,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: _editStoryAccentSoft,
            borderRadius: borderRadius,
          ),
          child: currentPreview == null
              ? _StoryCoverEmptyState(
                  key: const ValueKey('edit-story.cover.no-photo'),
                  message: emptyLabel,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final decodeSize = authenticatedMediaDisplayDecodeSize(
                      logicalSize: constraints.biggest,
                      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                    );

                    return Semantics(
                      image: true,
                      label: label,
                      child: ExcludeSemantics(
                        child: AuthenticatedMediaPathImage(
                          key: ValueKey(
                            'edit-story.cover-image.'
                            '${currentPreview.displayPath}',
                          ),
                          thumbnailPath: currentPreview.displayPath,
                          representation:
                              AuthenticatedMediaRepresentation.display,
                          fit: BoxFit.cover,
                          cacheWidth: decodeSize.cacheWidth,
                          cacheHeight: decodeSize.cacheHeight,
                          placeholder: _StoryCoverEmptyState(
                            key: const ValueKey('edit-story.cover.loading'),
                            message: emptyLabel,
                          ),
                          errorBuilder: (context) {
                            return _StoryCoverEmptyState(
                              key: const ValueKey('edit-story.cover.error'),
                              message: emptyLabel,
                            );
                          },
                        ),
                      ),
                    );
                  },
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
              color: _editStoryInputFill,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.image_outlined,
              color: _editStoryAccent,
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _editStoryMuted,
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

class _CoverSuccessMessage extends StatelessWidget {
  const _CoverSuccessMessage({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const ValueKey('edit-story.cover.success'),
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 18,
            color: _editStoryAccent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _editStoryMuted,
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

class _ButtonProgressIndicator extends StatelessWidget {
  const _ButtonProgressIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: _editStoryAccent,
      ),
    );
  }
}

class _UnavailableView extends StatelessWidget {
  const _UnavailableView({
    required this.onCancel,
  });

  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _editStoryAccentSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            color: _editStoryAccent,
            size: 30,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          l10n.editStoryUnavailableTitle,
          style: const TextStyle(
            color: _editStoryInk,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.editStoryUnavailableDescription,
          style: const TextStyle(
            color: _editStoryMuted,
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 22),
        TextButton(
          key: const ValueKey('edit-story.unavailable.back-action'),
          onPressed: onCancel,
          style: TextButton.styleFrom(
            foregroundColor: _editStoryAccent,
            padding: EdgeInsets.zero,
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          child: Text(l10n.editStoryUnavailableBackAction),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF9A8178),
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _EditStorySaveButton extends StatelessWidget {
  const _EditStorySaveButton({
    required this.isSaving,
    required this.onPressed,
  });

  final bool isSaving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FilledButton(
      key: const ValueKey('edit-story.save-action'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _editStoryAccent,
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
      child: isSaving
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                Text(l10n.editStorySavingButton),
              ],
            )
          : Text(l10n.editStorySaveButton),
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
            color: _editStoryInk,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        if (required)
          const Text(
            '*',
            style: TextStyle(
              color: _editStoryAccent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        if (optionalText != null)
          Text(
            optionalText!,
            style: const TextStyle(
              color: _editStoryMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
      ],
    );
  }
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
    fillColor: _editStoryInputFill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _editStoryBorder, width: 0.8),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xB8D16A74), width: 1.1),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _editStoryAccent, width: 1.4),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _editStoryAccent, width: 1.4),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFF2EBE8), width: 0.8),
    ),
  );
}
