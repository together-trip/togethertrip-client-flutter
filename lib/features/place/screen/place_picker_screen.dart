import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/widget/app_design.dart';
import '../model/place_models.dart';
import '../service/place_location_provider.dart';
import '../service/place_service.dart';

typedef PlaceMapBuilder =
    Widget Function(
      PlaceSelection? selection,
      ValueChanged<LatLng> onCoordinateSelected,
    );

class PlacePickerScreen extends StatefulWidget {
  final int tripId;
  final PlaceSelection? initialSelection;
  final PlaceService? placeService;
  final PlaceLocationProvider? locationProvider;
  final PlaceMapBuilder? mapBuilder;

  const PlacePickerScreen({
    super.key,
    required this.tripId,
    this.initialSelection,
    this.placeService,
    this.locationProvider,
    this.mapBuilder,
  });

  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  final _searchController = TextEditingController();
  final _manualController = TextEditingController();
  final _sessionToken = const Uuid().v4();

  late final PlaceService _placeService;
  late final PlaceLocationProvider _locationProvider;
  GoogleMapController? _mapController;
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  PlaceSelection? _selection;
  bool _isSearching = false;
  bool _isResolving = false;
  bool _manualMode = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _placeService = widget.placeService ?? PlaceService();
    _locationProvider =
        widget.locationProvider ?? DevicePlaceLocationProvider();
    _selection = widget.initialSelection;
    _manualController.text = widget.initialSelection?.name ?? '';
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _manualController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _suggestions = const [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });
    try {
      final suggestions = await _placeService.autocomplete(
        widget.tripId,
        query: query,
        sessionToken: _sessionToken,
      );
      if (!mounted || query != _searchController.text.trim()) return;
      setState(() => _suggestions = suggestions);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = '장소를 검색하지 못했습니다. 직접 입력할 수 있어요.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });
    try {
      final selection = await _placeService.getPlace(
        widget.tripId,
        placeId: suggestion.placeId,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      _applySelection(selection);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = '선택한 장소 정보를 불러오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _selectCoordinate(LatLng coordinate) async {
    final isManualSelection = _manualMode;
    final manualName = _manualController.text.trim();
    final provisionalSelection = PlaceSelection(
      placeId: null,
      name: isManualSelection && manualName.isNotEmpty ? manualName : '선택한 위치',
      address:
          '${coordinate.latitude.toStringAsFixed(6)}, '
          '${coordinate.longitude.toStringAsFixed(6)}',
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
    );
    setState(() {
      _selection = provisionalSelection;
      if (!isManualSelection) {
        _manualController.text = provisionalSelection.name;
      }
      _isResolving = true;
      _errorMessage = null;
    });
    try {
      final selection = await _placeService.reverseGeocode(
        widget.tripId,
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
      );
      if (!mounted) return;
      if (isManualSelection) {
        _applyManualCoordinate(selection, coordinate);
      } else {
        _applySelection(selection);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = '장소명은 확인하지 못했지만 선택한 위치는 표시했어요.');
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });
    try {
      final location = await _locationProvider.getCurrentLocation();
      final coordinate = LatLng(location.latitude, location.longitude);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(coordinate, 16),
      );
      await _selectCoordinate(coordinate);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  void _applySelection(PlaceSelection selection) {
    setState(() {
      _selection = selection;
      _manualController.text = selection.name;
      _searchController.clear();
      _suggestions = const [];
      _manualMode = false;
    });
    if (selection.hasCoordinates) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(selection.latitude!, selection.longitude!),
          16,
        ),
      );
    }
  }

  void _applyManualCoordinate(
    PlaceSelection resolvedSelection,
    LatLng coordinate,
  ) {
    final manualName = _manualController.text.trim();
    setState(() {
      _selection = PlaceSelection(
        placeId: null,
        name: manualName.isEmpty ? '선택한 위치' : manualName,
        address: resolvedSelection.address,
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
      );
    });
  }

  void _toggleManualMode() {
    setState(() {
      _manualMode = !_manualMode;
      _errorMessage = null;
      if (_manualMode) {
        _selection = null;
      }
    });
  }

  void _confirm() {
    if (_manualMode) {
      final name = _manualController.text.trim();
      if (name.isEmpty) {
        setState(() => _errorMessage = '장소명을 입력해주세요.');
        return;
      }
      final selectedCoordinate = _selection;
      Navigator.of(context).pop(
        selectedCoordinate?.hasCoordinates == true
            ? PlaceSelection(
                placeId: null,
                name: name,
                address: selectedCoordinate!.address,
                latitude: selectedCoordinate.latitude,
                longitude: selectedCoordinate.longitude,
              )
            : PlaceSelection.manual(name),
      );
      return;
    }
    final selection = _selection;
    if (selection == null) {
      setState(() => _errorMessage = '장소를 선택하거나 직접 입력해주세요.');
      return;
    }
    Navigator.of(context).pop(selection);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('장소 선택', style: AppTextStyles.screenTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                key: const ValueKey('placeSearchField'),
                controller: _searchController,
                enabled: !_manualMode && !_isResolving,
                decoration: AppInputDecorations.filled(
                  hintText: '어디로 가시나요?',
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            if (_isSearching) const LinearProgressIndicator(minHeight: 2),
            if (_suggestions.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return ListTile(
                      key: ValueKey('placeSuggestion_${suggestion.placeId}'),
                      tileColor: Colors.white,
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.brandSoft,
                        child: Icon(
                          Icons.place_outlined,
                          color: AppColors.brandStrong,
                        ),
                      ),
                      title: Text(suggestion.name),
                      subtitle: suggestion.address == null
                          ? null
                          : Text(suggestion.address!),
                      onTap: _isResolving
                          ? null
                          : () => _selectSuggestion(suggestion),
                    );
                  },
                ),
              ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: _buildMap(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selection != null && !_manualMode)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.location_on,
                        color: AppColors.brandStrong,
                      ),
                      title: Text(_selection!.name),
                      subtitle: Text(_selection!.address),
                    ),
                  if (_manualMode)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: const ValueKey('manualPlaceField'),
                          controller: _manualController,
                          maxLength: 100,
                          decoration: AppInputDecorations.filled(
                            labelText: '장소명 직접 입력',
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text('지도에서 위치를 누르면 핀도 함께 저장돼요.'),
                        ),
                      ],
                    ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('currentLocationButton'),
                          onPressed: _isResolving ? null : _useCurrentLocation,
                          icon: const Icon(Icons.my_location),
                          label: const Text('현재 위치'),
                          style: AppButtonStyles.outlined(
                            sideColor: AppColors.lineSoft,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('manualPlaceButton'),
                          onPressed: _isResolving ? null : _toggleManualMode,
                          style: AppButtonStyles.outlined(
                            sideColor: AppColors.lineSoft,
                          ),
                          child: Text(_manualMode ? '장소 검색' : '직접 입력'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    key: const ValueKey('confirmPlaceButton'),
                    onPressed: _isResolving ? null : _confirm,
                    style: AppButtonStyles.elevatedPrimary(),
                    child: Text(_isResolving ? '위치 확인 중...' : '이 장소 선택'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    if (widget.mapBuilder != null) {
      return widget.mapBuilder!(_selection, _selectCoordinate);
    }

    final initialCoordinate = _selection?.hasCoordinates == true
        ? LatLng(_selection!.latitude!, _selection!.longitude!)
        : const LatLng(37.5665, 126.9780);
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialCoordinate,
        zoom: 12,
      ),
      onMapCreated: (controller) => _mapController = controller,
      onTap: _isResolving ? null : _selectCoordinate,
      markers: _selection?.hasCoordinates == true
          ? {
              Marker(
                markerId: const MarkerId('selectedPlace'),
                position: LatLng(_selection!.latitude!, _selection!.longitude!),
              ),
            }
          : const {},
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
    );
  }
}
