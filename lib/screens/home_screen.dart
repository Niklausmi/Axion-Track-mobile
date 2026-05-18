// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../utils/theme.dart';
import 'dashboard_screen.dart';
import 'vehicles_screen.dart';
import 'map_screen.dart';
import 'alerts_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  final _pages = const [
    DashboardScreen(),
    VehiclesScreen(),
    MapScreen(),
    AlertsScreen(),
    SettingsScreen(),
  ];

  final _titles = ['Dashboard', 'Vehicles', 'Map', 'Alerts', 'Settings'];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AC.surface,
        systemNavigationBarIconBrightness: Brightness.light),
      child: Scaffold(
        backgroundColor: AC.bg,
        appBar: AppBar(
          backgroundColor: AC.surface,
          elevation: 0,
          title: _tab == 0
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1565C0), AC.blue]),
                    borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 17)),
                const SizedBox(width: 8),
                RichText(text: const TextSpan(children: [
                  TextSpan(text: 'Axion',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                      color: AC.text1, fontFamily: 'Inter')),
                  TextSpan(text: ' Track',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                      color: AC.blue, fontFamily: 'Inter')),
                ])),
              ])
            : Text(_titles[_tab]),
          actions: [
            // WS live indicator
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: state.wsConnected ? AC.green : AC.text4,
                  shape: BoxShape.circle,
                  boxShadow: state.wsConnected
                    ? [BoxShadow(color: AC.green.withOpacity(0.6), blurRadius: 8)]
                    : null)))),
            // Refresh
            IconButton(
              icon: state.isLoading
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: AC.blue, strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, size: 22, color: AC.text2),
              onPressed: state.isLoading ? null : state.refresh),
          ],
        ),
        body: IndexedStack(index: _tab, children: _pages),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: AC.surface,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0,-2))]),
          child: SafeArea(
            child: SizedBox(
              height: 58,
              child: Row(children: [
                _NItem(0, Icons.home_rounded,          Icons.home_outlined,            'Dashboard', _tab, () => setState(() => _tab = 0)),
                _NItem(1, Icons.directions_car_rounded, Icons.directions_car_outlined,  'Vehicles',  _tab, () => setState(() => _tab = 1)),
                // Centre map button
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _tab = 2),
                  child: Center(child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      gradient: _tab == 2
                        ? const LinearGradient(colors: [Color(0xFF1565C0), AC.blue])
                        : const LinearGradient(colors: [AC.surface2, AC.surface3]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _tab == 2
                        ? [BoxShadow(color: AC.blue.withOpacity(0.4), blurRadius: 12, offset: const Offset(0,3))]
                        : null),
                    child: Icon(Icons.map_rounded, color: _tab == 2 ? Colors.white : AC.text3, size: 22))))),
                _NItemBadge(3, Icons.notifications_rounded, Icons.notifications_outlined, 'Alerts',
                  state.unreadEvents, _tab, () => setState(() => _tab = 3)),
                _NItem(4, Icons.settings_rounded, Icons.settings_outlined, 'Settings', _tab, () => setState(() => _tab = 4)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _NItem extends StatelessWidget {
  final int idx;
  final IconData activeIcon, inactiveIcon;
  final String label;
  final int current;
  final VoidCallback onTap;
  const _NItem(this.idx, this.activeIcon, this.inactiveIcon, this.label, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final sel = idx == current;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 36, height: 26,
          decoration: BoxDecoration(
            color: sel ? AC.blue.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8)),
          child: Icon(sel ? activeIcon : inactiveIcon,
            size: 20, color: sel ? AC.blue : AC.text3)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: sel ? AC.blue : AC.text3)),
      ])));
  }
}

class _NItemBadge extends StatelessWidget {
  final int idx;
  final IconData activeIcon, inactiveIcon;
  final String label;
  final int badge;
  final int current;
  final VoidCallback onTap;
  const _NItemBadge(this.idx, this.activeIcon, this.inactiveIcon, this.label,
    this.badge, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final sel = idx == current;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Stack(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36, height: 26,
            decoration: BoxDecoration(
              color: sel ? AC.blue.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8)),
            child: Icon(sel ? activeIcon : inactiveIcon,
              size: 20, color: sel ? AC.blue : AC.text3)),
          if (badge > 0) Positioned(top: -1, right: -1,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AC.red, shape: BoxShape.circle,
                border: Border.all(color: AC.surface, width: 1.5)),
              child: Text('${badge > 99 ? "99+" : badge}',
                style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)))),
        ]),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: sel ? AC.blue : AC.text3)),
      ])));
  }
}
