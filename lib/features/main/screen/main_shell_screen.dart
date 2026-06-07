import 'package:flutter/material.dart';
import '../../auth/service/auth_service.dart';
import '../../my/screen/my_placeholder_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final authService = widget.authService;
    final tripService =
        widget.tripService ?? TripService(authService: authService);
    final screens = <Widget>[
      TripListScreen(tripService: tripService),
      MyPlaceholderScreen(authService: authService),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
        ),
        child: Row(
          children: [
            _TabItem(
              label: '여행',
              isActive: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _TabItem(
              label: '마이',
              isActive: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

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
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFF9E9E9E),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
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
