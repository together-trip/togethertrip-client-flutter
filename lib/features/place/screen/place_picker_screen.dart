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
  PlaceSelection? _selectionBeforeManual;
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
    FocusScope.of(context).unfocus();
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
    FocusScope.of(context).unfocus();
    final enteringManualMode = !_manualMode;
    setState(() {
      _manualMode = enteringManualMode;
      _errorMessage = null;
      _searchController.clear();
      _suggestions = const [];
      if (enteringManualMode) {
        _selectionBeforeManual = _selection;
        _selection = null;
      } else {
        _selection = _selectionBeforeManual;
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
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final mapTop = _manualMode ? 108.0 : 76.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          tooltip: '뒤로',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        title: const Text('장소 선택'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final suggestionMaxHeight =
                (constraints.maxHeight - 72 - (keyboardVisible ? 12 : 174))
                    .clamp(56.0, 280.0)
                    .toDouble();
            return Stack(
              children: [
                Positioned(
                  key: const ValueKey('placeMapArea'),
                  top: mapTop,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Semantics(
                    label: '장소 위치 지도',
                    container: true,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: _buildMap(),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: _buildTopInput(),
                ),
                if (_isSearching)
                  const Positioned(
                    top: 72,
                    left: 16,
                    right: 16,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                if (!_manualMode && _suggestions.isNotEmpty)
                  Positioned(
                    top: 72,
                    left: 16,
                    right: 16,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: suggestionMaxHeight,
                      ),
                      child: _buildSuggestions(),
                    ),
                  ),
                if (keyboardVisible &&
                    _errorMessage != null &&
                    _suggestions.isEmpty)
                  Positioned(
                    top: mapTop + 10,
                    left: 16,
                    right: 72,
                    child: _buildErrorMessage(),
                  ),
                Positioned(
                  right: 16,
                  bottom: keyboardVisible ? 16 : 178,
                  child: Semantics(
                    button: true,
                    label: '현재 위치 사용',
                    child: IconButton(
                      key: const ValueKey('currentLocationButton'),
                      tooltip: '현재 위치',
                      onPressed: _isResolving ? null : _useCurrentLocation,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.ink,
                        fixedSize: const Size(48, 48),
                        elevation: 1,
                        shadowColor: Colors.black26,
                      ),
                      icon: const Icon(Icons.my_location_rounded, size: 20),
                    ),
                  ),
                ),
                if (!keyboardVisible)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildBottomPanel(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopInput() {
    if (_manualMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('manualPlaceField'),
            controller: _manualController,
            enabled: !_isResolving,
            maxLength: 100,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: AppInputDecorations.filled(
              hintText: '장소명을 입력해주세요',
              prefixIcon: const Icon(Icons.edit_location_alt_outlined),
              counterText: '',
            ),
          ),
          const SizedBox(height: 6),
          const Text('지도에서 위치를 누르면 핀도 함께 저장돼요.', style: AppTextStyles.caption),
        ],
      );
    }

    return TextField(
      key: const ValueKey('placeSearchField'),
      controller: _searchController,
      enabled: !_isResolving,
      textInputAction: TextInputAction.search,
      decoration: AppInputDecorations.filled(
        hintText: '장소명 또는 주소 검색',
        prefixIcon: const Icon(Icons.search_rounded),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.controlRadius,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.lineSoft),
          borderRadius: AppRadii.controlRadius,
        ),
        child: ListView.separated(
          shrinkWrap: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: _suggestions.length,
          separatorBuilder: (_, _) => const Divider(indent: 50),
          itemBuilder: (context, index) {
            final suggestion = _suggestions[index];
            return ListTile(
              key: ValueKey('placeSuggestion_${suggestion.placeId}'),
              minTileHeight: 56,
              leading: const Icon(
                Icons.location_on_outlined,
                color: AppColors.textSubtle,
              ),
              title: Text(
                suggestion.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: suggestion.address == null
                  ? null
                  : Text(
                      suggestion.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: _isResolving ? null : () => _selectSuggestion(suggestion),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.controlRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: _buildAccessibleError(),
      ),
    );
  }

  Widget _buildAccessibleError() {
    return Semantics(
      liveRegion: true,
      child: Text(_errorMessage!, style: AppTextStyles.error),
    );
  }

  Widget _buildBottomPanel() {
    final selection = _selection;
    return DecoratedBox(
      key: const ValueKey('placeBottomPanel'),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selection == null)
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '지도에서 위치를 선택하세요',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '지도를 누르거나 현재 위치를 사용할 수 있어요.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.brandStrong,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selection.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selection.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_rounded, color: AppColors.success),
                  ],
                ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 6),
                _buildAccessibleError(),
              ],
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  key: const ValueKey('confirmPlaceButton'),
                  onPressed: _isResolving ? null : _confirm,
                  style: AppButtonStyles.elevatedPrimary(radius: 12),
                  child: Text(_isResolving ? '위치 확인 중...' : '이 장소 선택'),
                ),
              ),
              SizedBox(
                height: 44,
                child: TextButton(
                  key: const ValueKey('manualPlaceButton'),
                  onPressed: _isResolving ? null : _toggleManualMode,
                  style: AppButtonStyles.inkText(),
                  child: _manualMode
                      ? const Text('장소 검색으로 돌아가기')
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '찾는 장소가 없나요?',
                              style: TextStyle(color: AppColors.textSubtle),
                            ),
                            SizedBox(width: 5),
                            Text(
                              '직접 입력',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
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
