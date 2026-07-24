import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';
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
    final valueColor = enabled
        ? selection == null
              ? AppColors.textSubtle
              : AppColors.ink
        : AppColors.disabledText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '장소',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSubtle,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          enabled: enabled,
          label: selection == null
              ? '장소 선택, 검색하거나 지도에서 선택'
              : '선택한 장소 ${selection!.name}',
          child: InkWell(
            key: const ValueKey('placeInputField'),
            onTap: enabled ? () => _openPicker(context) : null,
            borderRadius: AppRadii.controlRadius,
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.only(left: 14),
              decoration: BoxDecoration(
                color: enabled ? AppColors.surface : AppColors.neutralSoft,
                borderRadius: AppRadii.controlRadius,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 20,
                    color: enabled
                        ? AppColors.textSubtle
                        : AppColors.disabledText,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selection?.name ?? '검색하거나 지도에서 선택',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: valueColor),
                    ),
                  ),
                  if (selection == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    )
                  else
                    IconButton(
                      key: const ValueKey('clearPlaceButton'),
                      tooltip: '장소 지우기',
                      onPressed: enabled ? () => onChanged(null) : null,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: AppColors.textSubtle,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
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
