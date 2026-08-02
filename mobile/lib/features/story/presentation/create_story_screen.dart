import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/story/application/stories_notifier.dart';
import 'package:memory_map/features/story/application/stories_state.dart';
import 'package:memory_map/features/story/domain/story.dart';
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

  @override
  void dispose() {
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
    final isCreating = _submitInFlight || (storiesState?.isCreating ?? false);
    final failureMessage = _failureMessage(l10n, storiesValue, storiesState);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || isCreating) {
          return;
        }

        widget.onCancel?.call();
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
                      isCreating: isCreating,
                      onCancel: widget.onCancel,
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
                            enabled: !isCreating,
                          ),
                          if (failureMessage != null) ...[
                            const SizedBox(height: 16),
                            StoryFormFailureBanner(message: failureMessage),
                          ],
                          const SizedBox(height: 24),
                          _CreateStoryButton(
                            isCreating: isCreating,
                            onPressed: isCreating ? null : _submit,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            key: const ValueKey('create-story.cancel-action'),
                            onPressed: isCreating ? null : widget.onCancel,
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

  Future<void> _submit() async {
    if (_submitInFlight) {
      return;
    }

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
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

    if (createdStory != null && !_createdCallbackCalled) {
      _createdCallbackCalled = true;
      widget.onCreated?.call(createdStory);
    }
  }

  String? _descriptionForSubmit() {
    final description = _descriptionController.text;
    if (description.isEmpty) {
      return null;
    }

    return description;
  }
}

class _CreateStoryAppBar extends StatelessWidget {
  const _CreateStoryAppBar({
    required this.isCreating,
    required this.onCancel,
  });

  final bool isCreating;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        IconButton(
          key: const ValueKey('create-story.back-action'),
          onPressed: isCreating ? null : onCancel,
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
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final FocusNode titleFocusNode;
  final FocusNode descriptionFocusNode;
  final bool enabled;

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
    required this.onPressed,
  });

  final bool isCreating;
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
      child: isCreating
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
                Text(l10n.createStoryCreatingButton),
              ],
            )
          : Text(l10n.createStorySubmitButton),
    );
  }
}
