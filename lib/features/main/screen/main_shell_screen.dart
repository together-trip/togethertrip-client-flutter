import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';
import '../../auth/service/auth_service.dart';
import '../../auth/service/terms_agreement_service.dart';
import '../../exchange/screen/exchange_rate_screen.dart';
import '../../exchange/service/exchange_rate_service.dart';
import '../../my/screen/my_placeholder_screen.dart';
import '../../trip/screen/trip_detail_screen.dart';
import '../../trip/screen/trip_list_screen.dart';
import '../../trip/service/trip_service.dart';

class MainShellScreen extends StatefulWidget {
  final AuthService? authService;
  final TripService? tripService;
  final TermsAgreementService? termsAgreementService;

  const MainShellScreen({
    super.key,
    this.authService,
    this.tripService,
    this.termsAgreementService,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;
  TripSummary? _selectedTrip;
  int _tripListVersion = 0;

  void _openTripDetail(TripSummary trip) {
    setState(() {
      _currentIndex = 0;
      _selectedTrip = trip;
    });
  }

  void _closeTripDetail(bool changed) {
    setState(() {
      _selectedTrip = null;
      if (changed) {
        _tripListVersion++;
      }
    });
  }

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final authService = widget.authService;
    final tripService =
        widget.tripService ?? TripService(authService: authService);
    final exchangeRateService = ExchangeRateService(authService: authService);
    final selectedTrip = _selectedTrip;
    final tripScreen = selectedTrip == null
        ? TripListScreen(
            key: ValueKey('tripList_$_tripListVersion'),
            tripService: tripService,
            onOpenTripDetail: _openTripDetail,
          )
        : TripDetailScreen(
            key: ValueKey('tripDetail_${selectedTrip.id}'),
            tripId: selectedTrip.id,
            tripService: tripService,
            onClose: _closeTripDetail,
          );
    final screens = <Widget>[
      AppMotionSwitcher(child: tripScreen),
      ExchangeRateScreen(exchangeRateService: exchangeRateService),
      MyPlaceholderScreen(
        authService: authService,
        termsAgreementService: widget.termsAgreementService,
        onBack: () => _selectTab(0),
      ),
    ];
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          for (var index = 0; index < screens.length; index++)
            _AnimatedTabSurface(
              key: ValueKey('mainTabSurface_$index'),
              active: _currentIndex == index,
              horizontalOffset: index < _currentIndex ? -0.018 : 0.018,
              reduceMotion: reduceMotion,
              child: screens[index],
            ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(44, 0, 44, 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SizedBox(
              height: 58,
              child: Row(
                children: [
                  _TabItem(
                    icon: Icons.map_outlined,
                    activeIcon: Icons.map,
                    label: '여행',
                    isActive: _currentIndex == 0,
                    onTap: () => _selectTab(0),
                  ),
                  _TabItem(
                    icon: Icons.currency_exchange,
                    activeIcon: Icons.currency_exchange,
                    label: '환율',
                    isActive: _currentIndex == 1,
                    onTap: () => _selectTab(1),
                  ),
                  _TabItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: '마이',
                    isActive: _currentIndex == 2,
                    onTap: () => _selectTab(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppColors.brandSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.fast,
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  size: 21,
                  color: isActive ? AppColors.brand : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  color: isActive ? AppColors.brandStrong : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedTabSurface extends StatelessWidget {
  final bool active;
  final double horizontalOffset;
  final bool reduceMotion;
  final Widget child;

  const _AnimatedTabSurface({
    super.key,
    required this.active,
    required this.horizontalOffset,
    required this.reduceMotion,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final duration = reduceMotion ? Duration.zero : AppMotion.standard;
    return ExcludeSemantics(
      excluding: !active,
      child: IgnorePointer(
        ignoring: !active,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          duration: duration,
          curve: AppMotion.curve,
          child: AnimatedSlide(
            offset: active ? Offset.zero : Offset(horizontalOffset, 0),
            duration: duration,
            curve: AppMotion.curve,
            child: TickerMode(enabled: active, child: child),
          ),
        ),
      ),
    );
  }
}
