import 'package:flutter/material.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/presentation/location_picker_map_configuration.dart';
import 'package:memory_map/features/memory/presentation/widgets/location_picker_map.dart';
import 'package:memory_map/l10n/app_localizations.dart';

typedef LocationPickerMapBuilder = Widget Function(
  BuildContext context,
  LocationPickerMapConfiguration configuration,
  MemoryLocation? selectedLocation,
  ValueChanged<MemoryLocation> onPointSelected,
);

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    this.initialLocation,
    this.onBack,
    this.onLocationSelected,
    this.mapConfiguration = openFreeMapLocationPickerMapConfiguration,
    this.mapBuilder = _defaultLocationPickerMapBuilder,
    super.key,
  });

  final MemoryLocation? initialLocation;
  final VoidCallback? onBack;
  final ValueChanged<MemoryLocation>? onLocationSelected;
  final LocationPickerMapConfiguration mapConfiguration;
  final LocationPickerMapBuilder mapBuilder;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late MemoryLocation? _selectedLocation = widget.initialLocation;

  @override
  void didUpdateWidget(LocationPickerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLocation != widget.initialLocation) {
      _selectedLocation = widget.initialLocation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          widget.onBack?.call();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _LocationPickerAppBar(onBack: widget.onBack),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
                child: Text(
                  l10n.locationPickerInstruction,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF3F7),
                      ),
                      child: widget.mapBuilder(
                        context,
                        widget.mapConfiguration,
                        _selectedLocation,
                        _selectLocation,
                      ),
                    ),
                  ),
                ),
              ),
              _LocationPickerBottomBar(
                selectedLocation: _selectedLocation,
                confirmEnabled: _selectedLocation != null &&
                    widget.onLocationSelected != null,
                onConfirm: _confirmSelection,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectLocation(MemoryLocation location) {
    setState(() {
      _selectedLocation = location;
    });
  }

  void _confirmSelection() {
    final selectedLocation = _selectedLocation;
    final onLocationSelected = widget.onLocationSelected;
    if (selectedLocation == null || onLocationSelected == null) {
      return;
    }

    onLocationSelected(selectedLocation);
  }
}

class _LocationPickerAppBar extends StatelessWidget {
  const _LocationPickerAppBar({
    required this.onBack,
  });

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        IconButton(
          key: const ValueKey('location-picker.back-action'),
          onPressed: onBack,
          tooltip: l10n.locationPickerBackLabel,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        Expanded(
          child: Text(
            l10n.locationPickerTitle,
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

class _LocationPickerBottomBar extends StatelessWidget {
  const _LocationPickerBottomBar({
    required this.selectedLocation,
    required this.confirmEnabled,
    required this.onConfirm,
  });

  final MemoryLocation? selectedLocation;
  final bool confirmEnabled;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasSelection = selectedLocation != null;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Color(0x180F172A),
              offset: Offset(0, -8),
              blurRadius: 26,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE6EA),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    hasSelection
                        ? Icons.location_on_rounded
                        : Icons.touch_app_rounded,
                    color: const Color(0xFFFF5D72),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasSelection
                            ? l10n.locationPickerSelectedTitle
                            : l10n.locationPickerNoSelectionTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasSelection
                            ? l10n.locationPickerSelectedDescription
                            : l10n.locationPickerNoSelectionDescription,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('location-picker.confirm-action'),
              onPressed: confirmEnabled ? onConfirm : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF5D72),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFFFD6DC),
                disabledForegroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              icon: const Icon(Icons.check_rounded),
              label: Text(l10n.locationPickerConfirmAction),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _defaultLocationPickerMapBuilder(
  BuildContext context,
  LocationPickerMapConfiguration configuration,
  MemoryLocation? selectedLocation,
  ValueChanged<MemoryLocation> onPointSelected,
) {
  return LocationPickerMap(
    configuration: configuration,
    selectedLocation: selectedLocation,
    onPointSelected: onPointSelected,
  );
}
