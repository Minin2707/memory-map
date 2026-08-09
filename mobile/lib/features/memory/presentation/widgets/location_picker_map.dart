import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:memory_map/features/memory/domain/memory_location.dart';
import 'package:memory_map/features/memory/presentation/location_picker_map_configuration.dart';
import 'package:memory_map/l10n/app_localizations.dart';

class LocationPickerMap extends StatefulWidget {
  const LocationPickerMap({
    required this.configuration,
    required this.selectedLocation,
    required this.onPointSelected,
    super.key,
  });

  final LocationPickerMapConfiguration configuration;
  final MemoryLocation? selectedLocation;
  final ValueChanged<MemoryLocation> onPointSelected;

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  final LocationPickerMapReadiness _readiness = LocationPickerMapReadiness();
  MapLibreMapController? _controller;
  Object? _selectedCircle;

  @override
  void didUpdateWidget(LocationPickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLocation != widget.selectedLocation) {
      _syncSelectedMarker();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraTarget = widget.selectedLocation ??
        widget.configuration.defaultCameraLocation;
    final cameraZoom = widget.selectedLocation == null
        ? widget.configuration.defaultZoom
        : widget.configuration.selectedZoom;

    return Stack(
      fit: StackFit.expand,
      children: [
        MapLibreMap(
          styleString: widget.configuration.styleString,
          initialCameraPosition: CameraPosition(
            target: _toLatLng(cameraTarget),
            zoom: cameraZoom,
          ),
          compassEnabled: false,
          myLocationEnabled: false,
          onMapCreated: (controller) {
            _controller = controller;
          },
          onStyleLoadedCallback: () {
            _handleStyleLoaded();
            _syncSelectedMarker();
          },
          onMapClick: (point, coordinate) {
            widget.onPointSelected(memoryLocationFromMapLibreLatLng(coordinate));
          },
        ),
        if (_readiness.isLoading)
          DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFFEFF3F7)),
            child: Center(
              child: _MapLoadingFallback(
                message: AppLocalizations.of(context).locationPickerMapLoading,
              ),
            ),
          ),
      ],
    );
  }

  void _handleStyleLoaded() {
    if (_readiness.styleLoaded || !mounted) {
      return;
    }

    setState(() {
      _readiness.markStyleLoaded();
    });
  }

  Future<void> _syncSelectedMarker() async {
    final controller = _controller;
    if (!mounted || controller == null || !_readiness.styleLoaded) {
      return;
    }

    final selectedLocation = widget.selectedLocation;
    if (selectedLocation == null) {
      final existingCircle = _selectedCircle;
      if (existingCircle != null) {
        await controller.removeCircle(existingCircle as dynamic);
        _selectedCircle = null;
      }
      return;
    }

    final options = CircleOptions(
      geometry: _toLatLng(selectedLocation),
      circleColor: '#FF5D72',
      circleRadius: 9.0,
      circleStrokeColor: '#FFFFFF',
      circleStrokeWidth: 3.0,
    );

    final existingCircle = _selectedCircle;
    if (existingCircle == null) {
      _selectedCircle = await controller.addCircle(options);
    } else {
      await controller.updateCircle(existingCircle as dynamic, options);
    }
  }
}

class LocationPickerMapReadiness {
  bool _styleLoaded = false;

  bool get styleLoaded => _styleLoaded;

  bool get isLoading => !_styleLoaded;

  bool markStyleLoaded() {
    if (_styleLoaded) {
      return false;
    }

    _styleLoaded = true;
    return true;
  }
}

MemoryLocation memoryLocationFromMapLibreLatLng(LatLng value) {
  return MemoryLocation(
    latitude: value.latitude,
    longitude: value.longitude,
  );
}

LatLng _toLatLng(MemoryLocation location) {
  return LatLng(location.latitude, location.longitude);
}

class _MapLoadingFallback extends StatelessWidget {
  const _MapLoadingFallback({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFFFF5D72),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
