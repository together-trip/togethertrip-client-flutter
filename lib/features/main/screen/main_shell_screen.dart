import 'package:flutter/material.dart';
import '../../auth/service/auth_service.dart';
import '../../exchange/screen/exchange_rate_screen.dart';
import '../../exchange/service/exchange_rate_service.dart';
import '../../my/screen/my_placeholder_screen.dart';
import '../../trip/screen/trip_detail_screen.dart';
import '../../trip/screen/trip_list_screen.dart';
import '../../trip/service/trip_service.dart';

class MainShellScreen extends StatefulWidget {
  final AuthService? authService;
  final TripService? tripService;

  const MainShellScreen({super.key, this.authService, this.tripService});

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
    final screens = <Widget>[
      selectedTrip == null
          ? TripListScreen(
              key: ValueKey(_tripListVersion),
              tripService: tripService,
              onOpenTripDetail: _openTripDetail,
            )
          : TripDetailScreen(
              tripId: selectedTrip.id,
              tripService: tripService,
              onClose: _closeTripDetail,
            ),
      ExchangeRateScreen(
        tripService: tripService,
        exchangeRateService: exchangeRateService,
      ),
      MyPlaceholderScreen(
        authService: authService,
        onBack: () => _selectTab(0),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(58, 0, 58, 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E2E2)),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 22,
              color: isActive
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFF8A8A8A),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFF6B6B6B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
