import 'package:flutter/material.dart';

import '../model/place_models.dart';
import '../screen/place_picker_screen.dart';
import '../service/place_location_provider.dart';
import '../service/place_service.dart';

class PlaceInputField extends StatelessWidget {
  final int tripId;
  final PlaceSelection? selection;
  final bool enabled;
  final ValueChanged<PlaceSelection?> onChanged;
  final PlaceService? placeService;
  final PlaceLocationProvider? locationProvider;
  final PlaceMapBuilder? mapBuilder;

  const PlaceInputField({
    super.key,
    required this.tripId,
    required this.selection,
    required this.enabled,
    required this.onChanged,
    this.placeService,
    this.locationProvider,
    this.mapBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('placeInputField'),
      onTap: enabled ? () => _openPicker(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '장소',
          prefixIcon: const Icon(Icons.place_outlined),
          suffixIcon: selection == null
              ? const Icon(Icons.chevron_right_rounded)
              : IconButton(
                  key: const ValueKey('clearPlaceButton'),
                  tooltip: '장소 지우기',
                  onPressed: enabled ? () => onChanged(null) : null,
                  icon: const Icon(Icons.close),
                ),
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        isEmpty: selection == null,
        child: Text(
          selection?.name ?? '검색하거나 지도에서 선택',
          style: TextStyle(
            color: selection == null
                ? Theme.of(context).hintColor
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final result = await Navigator.of(context).push<PlaceSelection>(
      MaterialPageRoute(
        builder: (_) => PlacePickerScreen(
          tripId: tripId,
          initialSelection: selection,
          placeService: placeService,
          locationProvider: locationProvider,
          mapBuilder: mapBuilder,
        ),
      ),
    );
    if (result != null) onChanged(result);
  }
}
