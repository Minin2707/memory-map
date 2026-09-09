import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/create_memory_notifier.dart';
import 'package:memory_map/features/memory/application/create_memory_state.dart';
import 'package:memory_map/features/memory/domain/create_memory_input.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/presentation/memory_date_format.dart';
import 'package:memory_map/features/memory/presentation/memory_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const _createMemoryBackground = Color(0xFFFBF6F1);
const _createMemoryInk = Color(0xFF182331);
const _createMemoryMuted = Color(0xFF747B86);
const _createMemoryAccent = Color(0xFFD16A74);
const _createMemoryAccentSoft = Color(0xFFFFEEF0);
const _createMemoryInputFill = Color(0xFFFFFDFB);
const _createMemoryDisplayFontFamily = 'NotoSerif';
const _createMemoryTopDecorationAsset =
    'assets/transparent_top-right_polaroid_flowers.png';
const _createMemoryBottomDecorationAsset =
    'assets/transparent_bottom-left_leaves.png';

class _CreateMemorySpacing {
  const _CreateMemorySpacing({
    required this.formTopPadding,
    required this.formBottomPadding,
    required this.headerTopPadding,
    required this.headerBackTitleGap,
    required this.headerTitleSubtitleGap,
    required this.headerBottomPadding,
    required this.sectionFirstFieldGap,
    required this.fieldLabelGap,
    required this.fieldBlockGap,
    required this.sectionTransitionGap,
    required this.whenWhereFirstFieldGap,
    required this.dateLocationGap,
    required this.locationCtaGap,
  });

  const _CreateMemorySpacing.normal()
      : this(
          formTopPadding: 8,
          formBottomPadding: 16,
          headerTopPadding: 8,
          headerBackTitleGap: 20,
          headerTitleSubtitleGap: 8,
          headerBottomPadding: 16,
          sectionFirstFieldGap: 14,
          fieldLabelGap: 8,
          fieldBlockGap: 18,
          sectionTransitionGap: 24,
          whenWhereFirstFieldGap: 14,
          dateLocationGap: 12,
          locationCtaGap: 24,
        );

  const _CreateMemorySpacing.compact()
      : this(
          formTopPadding: 4,
          formBottomPadding: 8,
          headerTopPadding: 12,
          headerBackTitleGap: 14,
          headerTitleSubtitleGap: 6,
          headerBottomPadding: 8,
          sectionFirstFieldGap: 8,
          fieldLabelGap: 8,
          fieldBlockGap: 12,
          sectionTransitionGap: 14,
          whenWhereFirstFieldGap: 8,
          dateLocationGap: 6,
          locationCtaGap: 12,
        );

  factory _CreateMemorySpacing.forAvailableHeight(double availableHeight) {
    if (availableHeight < 860) {
      return const _CreateMemorySpacing.compact();
    }

    return const _CreateMemorySpacing.normal();
  }

  final double formTopPadding;
  final double formBottomPadding;
  final double headerTopPadding;
  final double headerBackTitleGap;
  final double headerTitleSubtitleGap;
  final double headerBottomPadding;
  final double sectionFirstFieldGap;
  final double fieldLabelGap;
  final double fieldBlockGap;
  final double sectionTransitionGap;
  final double whenWhereFirstFieldGap;
  final double dateLocationGap;
  final double locationCtaGap;
}

typedef CreateMemoryLocationPicker = Future<MemoryLocation?> Function(
  MemoryLocation? initialLocation,
);

typedef CreateMemoryDatePicker = Future<MemoryDate?> Function(
  BuildContext context,
  MemoryDate? initialDate,
);

class CreateMemoryScreen extends ConsumerStatefulWidget {
  const CreateMemoryScreen({
    required this.storyId,
    this.onBack,
    this.onPickLocation,
    this.onMemoryCreated,
    this.datePicker = _defaultDatePicker,
    super.key,
  });

  final String storyId;
  final VoidCallback? onBack;
  final CreateMemoryLocationPicker? onPickLocation;
  final ValueChanged<Memory>? onMemoryCreated;
  final CreateMemoryDatePicker datePicker;

  @override
  ConsumerState<CreateMemoryScreen> createState() => _CreateMemoryScreenState();
}

class _CreateMemoryScreenState extends ConsumerState<CreateMemoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _placeNameController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _placeNameFocusNode = FocusNode();

  MemoryDate? _selectedDate;
  MemoryLocation? _selectedLocation;
  bool _dateErrorVisible = false;
  bool _locationErrorVisible = false;
  bool _inputConstructionFailed = false;
  bool _submitInFlight = false;
  bool _createdCallbackCalled = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _placeNameController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _placeNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final createValue = ref.watch(createMemoryProvider(widget.storyId));
    final createState = createValue.asData?.value ?? const CreateMemoryState();
    final isSubmitting = _submitInFlight || createState.isSubmitting;
    final failureMessage = _failureMessage(l10n, createValue, createState);
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height - mediaQuery.padding.vertical;
    final spacing = _CreateMemorySpacing.forAvailableHeight(availableHeight);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || isSubmitting) {
          return;
        }

        widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: _createMemoryBackground,
        body: Stack(
          children: [
            const Positioned(
              right: -32,
              top: -18,
              child: _CreateMemoryTopDecoration(),
            ),
            const Positioned(
              left: -32,
              bottom: -14,
              child: _CreateMemoryBottomDecoration(),
            ),
            SafeArea(
              bottom: false,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  FocusScope.of(context).unfocus();
                },
                child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: _CreateMemoryHeader(
                        isSubmitting: isSubmitting,
                        onBack: widget.onBack,
                        spacing: spacing,
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        spacing.formTopPadding,
                        24,
                        spacing.formBottomPadding +
                            mediaQuery.viewInsets.bottom,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _CreateMemoryFormCard(
                                titleController: _titleController,
                                descriptionController: _descriptionController,
                                placeNameController: _placeNameController,
                                titleFocusNode: _titleFocusNode,
                                descriptionFocusNode: _descriptionFocusNode,
                                placeNameFocusNode: _placeNameFocusNode,
                                selectedDate: _selectedDate,
                                selectedLocation: _selectedLocation,
                                showDateError: _dateErrorVisible,
                                showLocationError: _locationErrorVisible,
                                canPickLocation: widget.onPickLocation != null,
                                enabled: !isSubmitting,
                                onPickDate: _pickDate,
                                onPickLocation: _pickLocation,
                                spacing: spacing,
                              ),
                              if (failureMessage != null) ...[
                                const SizedBox(height: 16),
                                _CreateMemoryFailureBanner(
                                  message: failureMessage,
                                ),
                              ],
                              SizedBox(height: spacing.locationCtaGap),
                              _CreateMemoryButton(
                                isSubmitting: isSubmitting,
                                onPressed: isSubmitting ? null : _submit,
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
          ],
        ),
      ),
    );
  }

  String? _failureMessage(
    AppLocalizations l10n,
    AsyncValue<CreateMemoryState> createValue,
    CreateMemoryState createState,
  ) {
    if (_inputConstructionFailed) {
      return l10n.memoryFailureValidation;
    }

    if (createValue.hasError) {
      return l10n.memoryFailureUnknown;
    }

    final failure = createState.failure;
    if (failure == null) {
      return null;
    }

    return memoryFailureMessage(l10n, failure);
  }

  Future<void> _pickDate() async {
    if (_isSubmitting()) {
      return;
    }

    final selectedDate = await widget.datePicker(context, _selectedDate);
    if (!mounted || selectedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = selectedDate;
      _dateErrorVisible = false;
      _inputConstructionFailed = false;
    });
  }

  Future<void> _pickLocation() async {
    if (_isSubmitting()) {
      return;
    }

    final picker = widget.onPickLocation;
    if (picker == null) {
      return;
    }

    final selectedLocation = await picker(_selectedLocation);
    if (!mounted || selectedLocation == null) {
      return;
    }

    setState(() {
      _selectedLocation = selectedLocation;
      _locationErrorVisible = false;
      _inputConstructionFailed = false;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting()) {
      return;
    }

    setState(() {
      _inputConstructionFailed = false;
      _dateErrorVisible = _selectedDate == null;
      _locationErrorVisible = _selectedLocation == null;
    });

    final formState = _formKey.currentState;
    if (formState == null ||
        !formState.validate() ||
        _selectedDate == null ||
        _selectedLocation == null) {
      return;
    }

    late final CreateMemoryInput input;
    try {
      input = CreateMemoryInput(
        storyId: widget.storyId,
        title: _titleController.text,
        description: _optionalText(_descriptionController),
        placeName: _optionalText(_placeNameController),
        location: _selectedLocation!,
        eventDate: _selectedDate!,
      );
    } on ArgumentError {
      setState(() {
        _inputConstructionFailed = true;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitInFlight = true;
    });

    final notifier = ref.read(createMemoryProvider(widget.storyId).notifier);
    if (ref.read(createMemoryProvider(widget.storyId)).hasError) {
      notifier.reset();
    }

    final createdMemory = await notifier.submit(input);
    if (!mounted) {
      return;
    }

    setState(() {
      _submitInFlight = false;
    });

    if (createdMemory != null && !_createdCallbackCalled) {
      _createdCallbackCalled = true;
      widget.onMemoryCreated?.call(createdMemory);
    }
  }

  bool _isSubmitting() {
    final state = ref.read(createMemoryProvider(widget.storyId)).asData?.value;
    return _submitInFlight || (state?.isSubmitting ?? false);
  }

  String? _optionalText(TextEditingController controller) {
    final value = controller.text;
    if (value.trim().isEmpty) {
      return null;
    }

    return value;
  }
}

class _CreateMemoryTopDecoration extends StatelessWidget {
  const _CreateMemoryTopDecoration();

  @override
  Widget build(BuildContext context) {
    const decorationWidthFactor = 0.52;
    const decorationHeightFactor = 0.74;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final decorationViewportWidth =
        (screenWidth * 0.54).clamp(190.0, 230.0).toDouble();
    final decorationCanvasWidth =
        decorationViewportWidth / decorationWidthFactor;

    return IgnorePointer(
      child: ExcludeSemantics(
        child: ClipRect(
          child: Align(
            alignment: Alignment.topRight,
            widthFactor: decorationWidthFactor,
            heightFactor: decorationHeightFactor,
            child: Image.asset(
              _createMemoryTopDecorationAsset,
              width: decorationCanvasWidth,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateMemoryBottomDecoration extends StatelessWidget {
  const _CreateMemoryBottomDecoration();

  @override
  Widget build(BuildContext context) {
    const decorationWidthFactor = 0.45;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final decorationViewportWidth =
        (screenWidth * 0.34).clamp(118.0, 150.0).toDouble();
    final decorationCanvasWidth =
        decorationViewportWidth / decorationWidthFactor;

    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: 0.42,
          child: Align(
            alignment: Alignment.bottomLeft,
            widthFactor: decorationWidthFactor,
            child: Image.asset(
              _createMemoryBottomDecorationAsset,
              width: decorationCanvasWidth,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateMemoryHeader extends StatelessWidget {
  const _CreateMemoryHeader({
    required this.isSubmitting,
    required this.onBack,
    required this.spacing,
  });

  final bool isSubmitting;
  final VoidCallback? onBack;
  final _CreateMemorySpacing spacing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        spacing.headerTopPadding,
        24,
        spacing.headerBottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: _createMemoryInputFill.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.68),
                width: 0.8,
              ),
            ),
            child: IconButton(
              key: const ValueKey('create-memory.back-action'),
              onPressed: isSubmitting ? null : onBack,
              tooltip: l10n.createMemoryBackLabel,
              color: _createMemoryInk,
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
          ),
          SizedBox(height: spacing.headerBackTitleGap),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              l10n.createMemoryPageTitle,
              style: const TextStyle(
                color: _createMemoryInk,
                fontFamily: _createMemoryDisplayFontFamily,
                fontFamilyFallback: <String>['NotoSerifGeorgian'],
                fontSize: 33,
                fontWeight: FontWeight.w500,
                height: 1.08,
                letterSpacing: 0,
              ),
            ),
          ),
          SizedBox(height: spacing.headerTitleSubtitleGap),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                l10n.createMemorySubtitle,
                style: const TextStyle(
                  color: _createMemoryMuted,
                  fontSize: 16,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateMemoryFormCard extends StatelessWidget {
  const _CreateMemoryFormCard({
    required this.titleController,
    required this.descriptionController,
    required this.placeNameController,
    required this.titleFocusNode,
    required this.descriptionFocusNode,
    required this.placeNameFocusNode,
    required this.selectedDate,
    required this.selectedLocation,
    required this.showDateError,
    required this.showLocationError,
    required this.canPickLocation,
    required this.enabled,
    required this.onPickDate,
    required this.onPickLocation,
    required this.spacing,
  });

  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController placeNameController;
  final FocusNode titleFocusNode;
  final FocusNode descriptionFocusNode;
  final FocusNode placeNameFocusNode;
  final MemoryDate? selectedDate;
  final MemoryLocation? selectedLocation;
  final bool showDateError;
  final bool showLocationError;
  final bool canPickLocation;
  final bool enabled;
  final VoidCallback onPickDate;
  final VoidCallback onPickLocation;
  final _CreateMemorySpacing spacing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(text: l10n.createMemoryAboutSection),
        SizedBox(height: spacing.sectionFirstFieldGap),
        _FieldLabel(label: l10n.createMemoryTitleLabel, required: true),
        SizedBox(height: spacing.fieldLabelGap),
        TextFormField(
            key: const ValueKey('create-memory.title-field'),
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
                return l10n.createMemoryTitleRequired;
              }

              if (value.trim().isEmpty) {
                return l10n.createMemoryTitleBlank;
              }

              if (value.length > Memory.maxTitleLength) {
                return l10n.createMemoryTitleMax;
              }

              return null;
            },
            decoration: _inputDecoration(hintText: l10n.createMemoryTitleHint),
        ),
        SizedBox(height: spacing.fieldBlockGap),
        _FieldLabel(
          label: l10n.createMemoryDescriptionLabel,
          optionalText: l10n.createMemoryOptionalLabel,
        ),
        SizedBox(height: spacing.fieldLabelGap),
        TextFormField(
          key: const ValueKey('create-memory.description-field'),
          controller: descriptionController,
          focusNode: descriptionFocusNode,
          enabled: enabled,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
          decoration: _inputDecoration(
            hintText: l10n.createMemoryDescriptionHint,
          ),
        ),
        SizedBox(height: spacing.fieldBlockGap),
        _FieldLabel(
          label: l10n.createMemoryPlaceNameLabel,
          optionalText: l10n.createMemoryOptionalLabel,
        ),
        SizedBox(height: spacing.fieldLabelGap),
        TextFormField(
          key: const ValueKey('create-memory.place-name-field'),
          controller: placeNameController,
          focusNode: placeNameFocusNode,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          validator: (value) {
            if (value != null && value.length > Memory.maxPlaceNameLength) {
              return l10n.createMemoryPlaceNameMax;
            }

            return null;
          },
          decoration: _inputDecoration(
            hintText: l10n.createMemoryPlaceNameHint,
          ),
        ),
        SizedBox(height: spacing.sectionTransitionGap),
        _SectionHeading(text: l10n.createMemoryWhenWhereSection),
        SizedBox(height: spacing.whenWhereFirstFieldGap),
        _PickerField(
          key: const ValueKey('create-memory.date-field'),
          icon: Icons.calendar_today_rounded,
          label: l10n.createMemoryEventDateLabel,
          required: true,
          value: selectedDate == null
              ? l10n.createMemoryEventDateEmpty
              : formatMemoryDate(l10n, selectedDate!),
          actionLabel: selectedDate == null
              ? l10n.createMemoryChooseDate
              : l10n.createMemoryChangeDate,
          errorText: showDateError ? l10n.createMemoryDateRequired : null,
          enabled: enabled,
          onPressed: onPickDate,
        ),
        SizedBox(height: spacing.dateLocationGap),
        _PickerField(
          key: const ValueKey('create-memory.location-field'),
          icon: Icons.location_on_rounded,
          label: l10n.createMemoryLocationLabel,
          required: true,
          value: selectedLocation == null
              ? l10n.createMemoryLocationEmpty
              : l10n.createMemoryLocationSelected,
          actionLabel: selectedLocation == null
              ? l10n.createMemoryChooseLocation
              : l10n.createMemoryChangeLocation,
          errorText:
              showLocationError ? l10n.createMemoryLocationRequired : null,
          enabled: enabled && canPickLocation,
          onPressed: onPickLocation,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFA0A7B1),
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: _createMemoryInputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFEFE5E1), width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xB8D16A74), width: 1.1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _createMemoryAccent, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _createMemoryAccent, width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFF2EBE8), width: 0.8),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.icon,
    required this.label,
    required this.required,
    required this.value,
    required this.actionLabel,
    required this.errorText,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool required;
  final String value;
  final String actionLabel;
  final String? errorText;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final actionKey = ValueKey<String>(
      icon == Icons.calendar_today_rounded
          ? 'create-memory.date-action'
          : 'create-memory.location-action',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          key: actionKey,
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: _createMemoryAccent,
            disabledForegroundColor: _createMemoryMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: enabled
                  ? _createMemoryInputFill
                  : _createMemoryInputFill.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: errorText == null
                    ? const Color(0xFFEFE5E1)
                    : _createMemoryAccent,
                width: errorText == null ? 0.8 : 1.4,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _createMemoryAccentSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: _createMemoryAccent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel(label: label, required: required),
                      const SizedBox(height: 5),
                      Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _createMemoryMuted,
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  actionLabel,
                  style: const TextStyle(
                    color: _createMemoryAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _createMemoryAccent,
                ),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(
              color: _createMemoryAccent,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
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
            color: _createMemoryInk,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        if (required)
          const Text(
            '*',
            style: TextStyle(
              color: _createMemoryAccent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        if (optionalText != null)
          Text(
            optionalText!,
            style: const TextStyle(
              color: _createMemoryMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
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

class _CreateMemoryButton extends StatelessWidget {
  const _CreateMemoryButton({
    required this.isSubmitting,
    required this.onPressed,
  });

  final bool isSubmitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FilledButton(
      key: const ValueKey('create-memory.submit-action'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _createMemoryAccent,
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
      child: isSubmitting
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
                Text(l10n.createMemorySubmittingButton),
              ],
            )
          : Text(l10n.createMemorySubmitButton),
    );
  }
}

class _CreateMemoryFailureBanner extends StatelessWidget {
  const _CreateMemoryFailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('create-memory.failure-banner'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _createMemoryAccentSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x2ED16A74)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: _createMemoryAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _createMemoryMuted,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<MemoryDate?> _defaultDatePicker(
  BuildContext context,
  MemoryDate? initialDate,
) async {
  final initialDateTime = initialDate == null
      ? DateTime.now()
      : DateTime(initialDate.year, initialDate.month, initialDate.day);
  final selected = await showDatePicker(
    context: context,
    initialDate: initialDateTime,
    firstDate: DateTime(1),
    lastDate: DateTime(9999, 12, 31),
  );
  if (selected == null) {
    return null;
  }

  return MemoryDate(
    year: selected.year,
    month: selected.month,
    day: selected.day,
  );
}
