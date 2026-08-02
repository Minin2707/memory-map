import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/story/application/edit_story_notifier.dart';
import 'package:memory_map/features/story/application/edit_story_state.dart';
import 'package:memory_map/features/story/domain/story_update_field.dart';
import 'package:memory_map/features/story/domain/update_story_input.dart';
import 'package:memory_map/features/story/domain/user_story.dart';
import 'package:memory_map/features/story/presentation/story_failure_message.dart';
import 'package:memory_map/features/story/presentation/widgets/story_form_failure_banner.dart';
import 'package:memory_map/l10n/app_localizations.dart';

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

class _EditStoryScreenState extends ConsumerState<EditStoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  late String _originalTitle;
  late String? _originalDescription;
  bool _updatedCallbackCalled = false;

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

    final failureMessage = _failureMessage(l10n, editValue, editState);
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
            _EditStoryHero(
              title: l10n.editStoryHeroTitle,
              subtitle: l10n.editStoryHeroSubtitle,
            ),
            const SizedBox(height: 24),
            _EditStoryFormCard(
              titleController: _titleController,
              descriptionController: _descriptionController,
              titleFocusNode: _titleFocusNode,
              descriptionFocusNode: _descriptionFocusNode,
              enabled: !isSaving,
            ),
            if (failureMessage != null) ...[
              const SizedBox(height: 16),
              StoryFormFailureBanner(message: failureMessage),
            ],
            if (!hasChanges) ...[
              const SizedBox(height: 14),
              _NoChangesHint(message: l10n.editStoryNoChangesHint),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('edit-story.save-action'),
              onPressed: canSave ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5D72),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFFFC8D0),
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
                        const SizedBox(
                          width: 18,
                          height: 18,
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
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const ValueKey('edit-story.cancel-action'),
              onPressed: isSaving ? null : widget.onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF5D72),
                side: const BorderSide(color: Color(0xFFFF8A99)),
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
                    child: _EditStoryAppBar(
                      isSaving: isSaving,
                      onCancel: onCancel,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    24,
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

class _EditStoryAppBar extends StatelessWidget {
  const _EditStoryAppBar({
    required this.isSaving,
    required this.onCancel,
  });

  final bool isSaving;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        IconButton(
          key: const ValueKey('edit-story.back-action'),
          onPressed: isSaving ? null : onCancel,
          tooltip: l10n.editStoryBackLabel,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        Expanded(
          child: Text(
            l10n.editStoryPageTitle,
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

class _EditStoryHero extends StatelessWidget {
  const _EditStoryHero({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: const Color(0xFFFFE6EA),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1FFF5D72),
                offset: Offset(0, 14),
                blurRadius: 28,
              ),
            ],
          ),
          child: const Icon(
            Icons.edit_location_alt_rounded,
            color: Color(0xFFFF5D72),
            size: 38,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 32,
            fontWeight: FontWeight.w900,
            height: 1.12,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 17,
            height: 1.45,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
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
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final FocusNode titleFocusNode;
  final FocusNode descriptionFocusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _FormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(
            label: l10n.editStoryTitleLabel,
            required: true,
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 10),
          Text(
            l10n.editStoryTitleHelp,
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
            label: l10n.editStoryDescriptionLabel,
            optionalText: l10n.editStoryDescriptionOptional,
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 10),
          Text(
            l10n.editStoryDescriptionHelp,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
        ],
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

    return _FormCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE6EA),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFFFF5D72),
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.editStoryUnavailableTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.editStoryUnavailableDescription,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton(
            key: const ValueKey('edit-story.unavailable.back-action'),
            onPressed: onCancel,
            child: Text(l10n.editStoryUnavailableBackAction),
          ),
        ],
      ),
    );
  }
}

class _NoChangesHint extends StatelessWidget {
  const _NoChangesHint({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        key: const ValueKey('edit-story.no-changes-hint'),
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFF8A93A3),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 14,
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

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: child,
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
