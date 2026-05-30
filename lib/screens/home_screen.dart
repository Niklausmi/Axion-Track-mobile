// lib/screens/home_screen.dart — v3
// Bottom nav: Dashboard | Vehicles | Map | Alerts | Settings
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../utils/theme.dart';
import 'dashboard_screen.dart';
import 'vehicles_screen.dart';
import 'secondary_screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  Timer? _autoRefresh;

  void _switchTab(int index) => setState(() => _tab = index);

  @override
  void initState() {
    super.initState();
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) context.read<AppState>().refresh();
    });
  }

  @override
  void dispose() { _autoRefresh?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final unread = state.events.length;

    final pages = [
      DashboardScreen(onSeeAllAlerts: () => _switchTab(3), onSeeMap: () => _switchTab(2)),
      const VehiclesScreen(),
      const MapScreen(),
      const AlertsScreen(),
      const SettingsScreen(),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _tab, children: pages),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            boxShadow: [BoxShadow(color: Color(0x0C000000), blurRadius: 12, offset: Offset(0, -2))],
          ),
          child: SafeArea(
            child: SizedBox(height: 62, child: Row(children: [
              _NavItem(icon: Icons.home_rounded,           label: 'Dashboard', selected: _tab == 0, onTap: () => _switchTab(0)),
              _NavItem(icon: Icons.directions_car_rounded, label: 'Vehicles',  selected: _tab == 1, onTap: () => _switchTab(1)),
              _NavItem(icon: Icons.map_rounded,            label: 'Map',       selected: _tab == 2, onTap: () => _switchTab(2)),
              _NavItem(icon: Icons.notifications_rounded,  label: 'Alerts',    selected: _tab == 3,
                badge: unread > 0 ? (unread > 99 ? '99+' : '$unread') : null,
                onTap: () => _switchTab(3)),
              _NavItem(icon: Icons.settings_rounded,       label: 'Settings',  selected: _tab == 4, onTap: () => _switchTab(4)),
            ])),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.selected, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Stack(clipBehavior: Clip.none, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40, height: 28,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: selected ? AppColors.primary : AppColors.text4),
          ),
          if (badge != null) Positioned(
            top: -4, right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: Text(badge!, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ]),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: selected ? AppColors.primary : AppColors.text4)),
      ]),
    ),
  );
}
