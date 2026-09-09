import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memory_map/features/memory/application/edit_memory_notifier.dart';
import 'package:memory_map/features/memory/application/edit_memory_state.dart';
import 'package:memory_map/features/memory/domain/memory.dart';
import 'package:memory_map/features/memory/domain/memory_date.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/domain/memory_update_field.dart';
import 'package:memory_map/features/memory/domain/update_memory_input.dart';
import 'package:memory_map/features/memory/presentation/memory_date_format.dart';
import 'package:memory_map/features/memory/presentation/memory_failure_message.dart';
import 'package:memory_map/l10n/app_localizations.dart';

const _editMemoryBackground = Color(0xFFFBF6F1);
const _editMemoryInk = Color(0xFF182331);
const _editMemoryMuted = Color(0xFF747B86);
const _editMemoryAccent = Color(0xFFD16A74);
const _editMemoryAccentSoft = Color(0xFFFFEEF0);
const _editMemoryInputFill = Color(0xFFFFFDFB);
const _editMemoryDisplayFontFamily = 'NotoSerif';

class _EditMemorySpacing {
  const _EditMemorySpacing({
    required this.formTopPadding,
    required this.formBottomPadding,
    required this.headerTopPadding,
    required this.headerBackTitleGap,
    required this.headerBottomPadding,
    required this.sectionFirstFieldGap,
    required this.fieldLabelGap,
    required this.fieldBlockGap,
    required this.sectionTransitionGap,
    required this.whenWhereFirstFieldGap,
    required this.dateLocationGap,
    required this.locationCtaGap,
  });

  const _EditMemorySpacing.normal()
      : this(
          formTopPadding: 8,
          formBottomPadding: 16,
          headerTopPadding: 8,
          headerBackTitleGap: 20,
          headerBottomPadding: 16,
          sectionFirstFieldGap: 14,
          fieldLabelGap: 8,
          fieldBlockGap: 18,
          sectionTransitionGap: 24,
          whenWhereFirstFieldGap: 14,
          dateLocationGap: 12,
          locationCtaGap: 24,
        );

  const _EditMemorySpacing.compact()
      : this(
          formTopPadding: 4,
          formBottomPadding: 8,
          headerTopPadding: 12,
          headerBackTitleGap: 14,
          headerBottomPadding: 8,
          sectionFirstFieldGap: 8,
          fieldLabelGap: 8,
          fieldBlockGap: 12,
          sectionTransitionGap: 14,
          whenWhereFirstFieldGap: 8,
          dateLocationGap: 6,
          locationCtaGap: 12,
        );

  factory _EditMemorySpacing.forAvailableHeight(double availableHeight) {
    if (availableHeight < 860) {
      return const _EditMemorySpacing.compact();
    }

    return const _EditMemorySpacing.normal();
  }

  final double formTopPadding;
  final double formBottomPadding;
  final double headerTopPadding;
  final double headerBackTitleGap;
  final double headerBottomPadding;
  final double sectionFirstFieldGap;
  final double fieldLabelGap;
  final double fieldBlockGap;
  final double sectionTransitionGap;
  final double whenWhereFirstFieldGap;
  final double dateLocationGap;
  final double locationCtaGap;
}

typedef EditMemoryLocationPicker = Future<MemoryLocation?> Function(
  MemoryLocation? initialLocation,
);

typedef EditMemoryDatePicker = Future<MemoryDate?> Function(
  BuildContext context,
  MemoryDate? initialDate,
);

class EditMemoryScreen extends ConsumerStatefulWidget {
  const EditMemoryScreen({
    required this.memory,
    this.onBack,
    this.onPickLocation,
    this.onMemoryUpdated,
    this.datePicker = _defaultDatePicker,
    super.key,
  });

  final Memory memory;
  final VoidCallback? onBack;
  final EditMemoryLocationPicker? onPickLocation;
  final ValueChanged<Memory>? onMemoryUpdated;
  final EditMemoryDatePicker datePicker;

  @override
  ConsumerState<EditMemoryScreen> createState() => _EditMemoryScreenState();
}

class _EditMemoryScreenState extends ConsumerState<EditMemoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _placeNameController;
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _placeNameFocusNode = FocusNode();

  late Memory _baselineMemory;
  late MemoryDate _selectedDate;
  late MemoryLocation _selectedLocation;
  bool _descriptionTouched = false;
  bool _placeNameTouched = false;
  bool _inputConstructionFailed = false;
  bool _submitInFlight = false;
  bool _applyingMemory = false;

  @override
  void initState() {
    super.initState();
    _baselineMemory = widget.memory;
    _selectedDate = widget.memory.eventDate;
    _selectedLocation = widget.memory.location;
    _titleController = TextEditingController(text: widget.memory.title);
    _descriptionController = TextEditingController(
      text: widget.memory.description ?? '',
    );
    _placeNameController = TextEditingController(
      text: widget.memory.placeName ?? '',
    );
    _titleController.addListener(_onDraftChanged);
    _descriptionController.addListener(_onDescriptionChanged);
    _placeNameController.addListener(_onPlaceNameChanged);
  }

  @override
  void didUpdateWidget(EditMemoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memory.id == widget.memory.id) {
      return;
    }

    _applyMemory(widget.memory);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onDraftChanged);
    _descriptionController.removeListener(_onDescriptionChanged);
    _placeNameController.removeListener(_onPlaceNameChanged);
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
    final editValue = ref.watch(editMemoryProvider(_baselineMemory.id));
    final editState = editValue.asData?.value ?? const EditMemoryState();
    final isSaving = _submitInFlight || editState.isSaving;
    final failureMessage = _failureMessage(l10n, editValue, editState);
    final hasChanges = _hasChanges;
    final canSave = hasChanges && !isSaving;
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height - mediaQuery.padding.vertical;
    final spacing = _EditMemorySpacing.forAvailableHeight(availableHeight);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || isSaving) {
          return;
        }

        widget.onBack?.call();
      },
      child: Scaffold(
        backgroundColor: _editMemoryBackground,
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
                SliverToBoxAdapter(
                  child: _EditMemoryHeader(
                    isSaving: isSaving,
                    onBack: widget.onBack,
                    spacing: spacing,
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    spacing.formTopPadding,
                    24,
                    spacing.formBottomPadding + mediaQuery.viewInsets.bottom,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _EditMemoryForm(
                            titleController: _titleController,
                            descriptionController: _descriptionController,
                            placeNameController: _placeNameController,
                            titleFocusNode: _titleFocusNode,
                            descriptionFocusNode: _descriptionFocusNode,
                            placeNameFocusNode: _placeNameFocusNode,
                            selectedDate: _selectedDate,
                            selectedLocation: _selectedLocation,
                            canPickLocation: widget.onPickLocation != null,
                            enabled: !isSaving,
                            onPickDate: _pickDate,
                            onPickLocation: _pickLocation,
                            spacing: spacing,
                          ),
                          if (failureMessage != null) ...[
                            const SizedBox(height: 16),
                            _EditMemoryFailureBanner(message: failureMessage),
                          ],
                          SizedBox(height: spacing.locationCtaGap),
                          _EditMemorySaveButton(
                            isSaving: isSaving,
                            onPressed: canSave ? _submit : null,
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            key: const ValueKey('edit-memory.cancel-action'),
                            onPressed: isSaving ? null : widget.onBack,
                            style: TextButton.styleFrom(
                              foregroundColor: _editMemoryAccent,
                              disabledForegroundColor: _editMemoryMuted,
                              minimumSize: const Size.fromHeight(44),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            ),
                            child: Text(l10n.cancel),
                          ),
                          const SizedBox(height: 16),
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
    AsyncValue<EditMemoryState> editValue,
    EditMemoryState editState,
  ) {
    if (_inputConstructionFailed) {
      return l10n.memoryFailureValidation;
    }

    if (editValue.hasError) {
      return l10n.memoryFailureUnknown;
    }

    final failure = editState.saveFailure;
    if (failure == null) {
      return null;
    }

    return memoryFailureMessage(l10n, failure);
  }

  Future<void> _pickDate() async {
    if (_isSaving()) {
      return;
    }

    final selectedDate = await widget.datePicker(context, _selectedDate);
    if (!mounted || selectedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = selectedDate;
      _inputConstructionFailed = false;
    });
  }

  Future<void> _pickLocation() async {
    if (_isSaving()) {
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
      _inputConstructionFailed = false;
    });
  }

  Future<void> _submit() async {
    if (_isSaving()) {
      return;
    }

    setState(() {
      _inputConstructionFailed = false;
    });

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final input = _buildInput();
    if (input == null) {
      setState(() {
        _inputConstructionFailed = true;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitInFlight = true;
    });

    final provider = editMemoryProvider(_baselineMemory.id);
    final notifier = ref.read(provider.notifier);
    if (ref.read(provider).hasError) {
      notifier.reset();
    }

    final updatedMemory = await notifier.save(input);
    if (!mounted) {
      return;
    }

    setState(() {
      _submitInFlight = false;
    });

    if (updatedMemory == null) {
      return;
    }

    setState(() {
      _applyMemory(updatedMemory);
    });
    widget.onMemoryUpdated?.call(updatedMemory);
  }

  UpdateMemoryInput? _buildInput() {
    final title = _titleController.text;
    final titleField = title == _baselineMemory.title
        ? const MemoryUpdateField<String>.notProvided()
        : MemoryUpdateField<String>.provided(title);
    final descriptionField = _nullableTextField(
      current: _descriptionController.text,
      original: _baselineMemory.description,
      touched: _descriptionTouched,
    );
    final placeNameField = _nullableTextField(
      current: _placeNameController.text,
      original: _baselineMemory.placeName,
      touched: _placeNameTouched,
    );
    final locationField = _selectedLocation == _baselineMemory.location
        ? const MemoryUpdateField<MemoryLocation>.notProvided()
        : MemoryUpdateField<MemoryLocation>.provided(_selectedLocation);
    final eventDateField = _selectedDate == _baselineMemory.eventDate
        ? const MemoryUpdateField<MemoryDate>.notProvided()
        : MemoryUpdateField<MemoryDate>.provided(_selectedDate);

    if (!titleField.isProvided &&
        !descriptionField.isProvided &&
        !placeNameField.isProvided &&
        !locationField.isProvided &&
        !eventDateField.isProvided) {
      return null;
    }

    try {
      return UpdateMemoryInput(
        memoryId: _baselineMemory.id,
        title: titleField,
        description: descriptionField,
        placeName: placeNameField,
        location: locationField,
        eventDate: eventDateField,
      );
    } on ArgumentError {
      return null;
    }
  }

  MemoryUpdateField<String?> _nullableTextField({
    required String current,
    required String? original,
    required bool touched,
  }) {
    if (!touched) {
      return const MemoryUpdateField<String?>.notProvided();
    }

    final desiredValue = current.trim().isEmpty ? null : current;
    if (desiredValue == original) {
      return const MemoryUpdateField<String?>.notProvided();
    }

    return MemoryUpdateField<String?>.provided(desiredValue);
  }

  bool get _hasChanges {
    return _titleController.text != _baselineMemory.title ||
        _nullableTextField(
          current: _descriptionController.text,
          original: _baselineMemory.description,
          touched: _descriptionTouched,
        ).isProvided ||
        _nullableTextField(
          current: _placeNameController.text,
          original: _baselineMemory.placeName,
          touched: _placeNameTouched,
        ).isProvided ||
        _selectedLocation != _baselineMemory.location ||
        _selectedDate != _baselineMemory.eventDate;
  }

  bool _isSaving() {
    final state = ref.read(editMemoryProvider(_baselineMemory.id)).asData?.value;
    return _submitInFlight || (state?.isSaving ?? false);
  }

  void _applyMemory(Memory memory) {
    _applyingMemory = true;
    _baselineMemory = memory;
    _selectedDate = memory.eventDate;
    _selectedLocation = memory.location;
    _descriptionTouched = false;
    _placeNameTouched = false;
    _inputConstructionFailed = false;
    _titleController.text = memory.title;
    _descriptionController.text = memory.description ?? '';
    _placeNameController.text = memory.placeName ?? '';
    _applyingMemory = false;
  }

  void _onDraftChanged() {
    if (_applyingMemory) {
      return;
    }

    setState(() {
      _inputConstructionFailed = false;
    });
  }

  void _onDescriptionChanged() {
    if (_applyingMemory) {
      return;
    }

    setState(() {
      _descriptionTouched = true;
      _inputConstructionFailed = false;
    });
  }

  void _onPlaceNameChanged() {
    if (_applyingMemory) {
      return;
    }

    setState(() {
      _placeNameTouched = true;
      _inputConstructionFailed = false;
    });
  }
}

class _EditMemoryHeader extends StatelessWidget {
  const _EditMemoryHeader({
    required this.isSaving,
    required this.onBack,
    required this.spacing,
  });

  final bool isSaving;
  final VoidCallback? onBack;
  final _EditMemorySpacing spacing;

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
              color: _editMemoryInputFill.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.68),
                width: 0.8,
              ),
            ),
            child: IconButton(
              key: const ValueKey('edit-memory.back-action'),
              onPressed: isSaving ? null : onBack,
              tooltip: l10n.editMemoryBackLabel,
              color: _editMemoryInk,
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
          ),
          SizedBox(height: spacing.headerBackTitleGap),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              l10n.editMemoryPageTitle,
              style: const TextStyle(
                color: _editMemoryInk,
                fontFamily: _editMemoryDisplayFontFamily,
                fontFamilyFallback: <String>['NotoSerifGeorgian'],
                fontSize: 33,
                fontWeight: FontWeight.w500,
                height: 1.08,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditMemoryForm extends StatelessWidget {
  const _EditMemoryForm({
    required this.titleController,
    required this.descriptionController,
    required this.placeNameController,
    required this.titleFocusNode,
    required this.descriptionFocusNode,
    required this.placeNameFocusNode,
    required this.selectedDate,
    required this.selectedLocation,
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
  final MemoryDate selectedDate;
  final MemoryLocation selectedLocation;
  final bool canPickLocation;
  final bool enabled;
  final VoidCallback onPickDate;
  final VoidCallback onPickLocation;
  final _EditMemorySpacing spacing;

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
          key: const ValueKey('edit-memory.title-field'),
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
          key: const ValueKey('edit-memory.description-field'),
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
          key: const ValueKey('edit-memory.place-name-field'),
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
          key: const ValueKey('edit-memory.date-field'),
          actionKey: const ValueKey('edit-memory.date-action'),
          icon: Icons.calendar_today_rounded,
          label: l10n.createMemoryEventDateLabel,
          required: true,
          value: formatMemoryDate(l10n, selectedDate),
          actionLabel: l10n.createMemoryChangeDate,
          enabled: enabled,
          onPressed: onPickDate,
        ),
        SizedBox(height: spacing.dateLocationGap),
        _PickerField(
          key: const ValueKey('edit-memory.location-field'),
          actionKey: const ValueKey('edit-memory.location-action'),
          icon: Icons.location_on_rounded,
          label: l10n.createMemoryLocationLabel,
          required: true,
          value: l10n.createMemoryLocationSelected,
          actionLabel: l10n.createMemoryChangeLocation,
          enabled: enabled && canPickLocation,
          onPressed: onPickLocation,
        ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.required,
    required this.value,
    required this.actionLabel,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final bool required;
  final String value;
  final String actionLabel;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          key: actionKey,
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: _editMemoryAccent,
            disabledForegroundColor: _editMemoryMuted,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: enabled
                  ? _editMemoryInputFill
                  : _editMemoryInputFill.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFEFE5E1),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _editMemoryAccentSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: _editMemoryAccent),
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
                          color: _editMemoryMuted,
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
                    color: _editMemoryAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _editMemoryAccent,
                ),
              ],
            ),
          ),
        ),
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
            color: _editMemoryInk,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        if (required)
          const Text(
            '*',
            style: TextStyle(
              color: _editMemoryAccent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        if (optionalText != null)
          Text(
            optionalText!,
            style: const TextStyle(
              color: _editMemoryMuted,
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

class _EditMemorySaveButton extends StatelessWidget {
  const _EditMemorySaveButton({
    required this.isSaving,
    required this.onPressed,
  });

  final bool isSaving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FilledButton(
      key: const ValueKey('edit-memory.save-action'),
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _editMemoryAccent,
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
                Text(l10n.editMemorySavingButton),
              ],
            )
          : Text(l10n.editMemorySaveButton),
    );
  }
}

class _EditMemoryFailureBanner extends StatelessWidget {
  const _EditMemoryFailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('edit-memory.failure-banner'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _editMemoryAccentSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x2ED16A74)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: _editMemoryAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _editMemoryMuted,
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

InputDecoration _inputDecoration({required String hintText}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFFA0A7B1),
      fontWeight: FontWeight.w500,
    ),
    filled: true,
    fillColor: _editMemoryInputFill,
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
      borderSide: const BorderSide(color: _editMemoryAccent, width: 1.4),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _editMemoryAccent, width: 1.4),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFFF2EBE8), width: 0.8),
    ),
  );
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
