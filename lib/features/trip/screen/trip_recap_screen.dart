import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/widget/app_design.dart';
import '../service/trip_service.dart';

class TripRecapScreen extends StatefulWidget {
  final int tripId;
  final int? tripRecapId;
  final TripService? tripService;

  const TripRecapScreen({
    super.key,
    required this.tripId,
    this.tripRecapId,
    this.tripService,
  });

  @override
  State<TripRecapScreen> createState() => _TripRecapScreenState();
}

class _TripRecapScreenState extends State<TripRecapScreen> {
  late final TripService _tripService;
  final PageController _pageController = PageController();

  TripRecap? _recap;
  bool _isLoading = true;
  int _pageIndex = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tripService = widget.tripService ?? TripService();
    _loadRecap();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadRecap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final recap = await _tripService.getRecap(widget.tripId);
      if (!mounted) return;
      setState(() => _recap = recap);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Recap을 불러오지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recap = _recap;
    return Scaffold(
      backgroundColor: AppColors.ink,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '여행 기록',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.brand,
              ),
            )
          : SafeArea(
              child: _isLoading
                  ? const SizedBox.shrink()
                  : _errorMessage != null
                  ? _RecapErrorState(
                      message: _errorMessage!,
                      onRetry: _loadRecap,
                    )
                  : recap == null || recap.scenes.isEmpty
                  ? _RecapErrorState(
                      message: '표시할 Recap 장면이 없습니다.',
                      onRetry: _loadRecap,
                    )
                  : _RecapScenePager(
                      recap: recap,
                      pageController: _pageController,
                      pageIndex: _pageIndex,
                      tripService: _tripService,
                      onPageChanged: (value) =>
                          setState(() => _pageIndex = value),
                    ),
            ),
    );
  }
}

class _RecapScenePager extends StatelessWidget {
  final TripRecap recap;
  final PageController pageController;
  final int pageIndex;
  final TripService tripService;
  final ValueChanged<int> onPageChanged;

  const _RecapScenePager({
    required this.recap,
    required this.pageController,
    required this.pageIndex,
    required this.tripService,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scenes = [...recap.scenes]
      ..sort((a, b) => a.order.compareTo(b.order));
    return Stack(
      children: [
        Positioned.fill(
          child: PageView.builder(
            controller: pageController,
            itemCount: scenes.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              return _RecapSceneImage(
                scene: scenes[index],
                tripService: tripService,
              );
            },
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: 12,
          child: Row(
            children: List.generate(scenes.length, (index) {
              final selected = index == pageIndex;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 3,
                  margin: EdgeInsets.only(
                    right: index == scenes.length - 1 ? 0 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected || index < pageIndex
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _RecapSceneImage extends StatelessWidget {
  final TripRecapScene scene;
  final TripService tripService;

  const _RecapSceneImage({required this.scene, required this.tripService});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.ink,
      child: Center(
        child: AspectRatio(
          aspectRatio: scene.numericAspectRatio,
          child: FutureBuilder<List<int>>(
            future: tripService.getRecapSceneImageBytes(scene.imageUrl),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const ColoredBox(
                  color: AppColors.ink,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.brand,
                    ),
                  ),
                );
              }
              if (snapshot.hasError || snapshot.data == null) {
                return const ColoredBox(
                  color: AppColors.ink,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 36,
                      color: Colors.white70,
                    ),
                  ),
                );
              }

              return Image.memory(
                Uint8List.fromList(snapshot.data!),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RecapErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RecapErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 120, 20, 20),
      children: [
        const Icon(Icons.error_outline, size: 36, color: AppColors.danger),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: onRetry,
            style: AppButtonStyles.inkText().copyWith(
              foregroundColor: const WidgetStatePropertyAll(AppColors.brand),
            ),
            child: const Text('다시 시도'),
          ),
        ),
      ],
    );
  }
}
