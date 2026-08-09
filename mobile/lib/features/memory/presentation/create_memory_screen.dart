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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || isSubmitting) {
          return;
        }

        widget.onBack?.call();
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
                    child: _CreateMemoryAppBar(
                      isSubmitting: isSubmitting,
                      onBack: widget.onBack,
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
                          ),
                          if (failureMessage != null) ...[
                            const SizedBox(height: 16),
                            _CreateMemoryFailureBanner(
                              message: failureMessage,
                            ),
                          ],
                          const SizedBox(height: 24),
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

class _CreateMemoryAppBar extends StatelessWidget {
  const _CreateMemoryAppBar({
    required this.isSubmitting,
    required this.onBack,
  });

  final bool isSubmitting;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        IconButton(
          key: const ValueKey('create-memory.back-action'),
          onPressed: isSubmitting ? null : onBack,
          tooltip: l10n.createMemoryBackLabel,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        Expanded(
          child: Text(
            l10n.createMemoryPageTitle,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _CreateMemoryCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: l10n.createMemoryTitleLabel, required: true),
          const SizedBox(height: 12),
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
          const SizedBox(height: 22),
          _FieldLabel(
            label: l10n.createMemoryDescriptionLabel,
            optionalText: l10n.createMemoryOptionalLabel,
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 22),
          _FieldLabel(
            label: l10n.createMemoryPlaceNameLabel,
            optionalText: l10n.createMemoryOptionalLabel,
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 24),
          const Divider(color: Color(0xFFE8EBEF)),
          const SizedBox(height: 22),
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
          const SizedBox(height: 16),
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
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText}) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, required: required),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: errorText == null
                  ? const Color(0xFFD8DDE5)
                  : const Color(0xFFFF5D72),
              width: errorText == null ? 1 : 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFFF5D72)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                key: ValueKey(
                  icon == Icons.calendar_today_rounded
                      ? 'create-memory.date-action'
                      : 'create-memory.location-action',
                ),
                onPressed: enabled ? onPressed : null,
                child: Text(actionLabel),
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(
              color: Color(0xFFFF5D72),
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

    return FilledButton.icon(
      key: const ValueKey('create-memory.submit-action'),
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
      icon: isSubmitting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.bookmark_add_rounded),
      label: Text(
        isSubmitting
            ? l10n.createMemorySubmittingButton
            : l10n.createMemorySubmitButton,
      ),
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
          color: const Color(0xFFFFF7F8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFD6DC)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  color: Color(0xFF6B7280),
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

class _CreateMemoryCardShell extends StatelessWidget {
  const _CreateMemoryCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
