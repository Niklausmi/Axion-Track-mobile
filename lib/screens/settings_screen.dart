// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sess  = state.session;

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      // ── Profile card ──
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1565C0), AppColors.primary]),
              shape: BoxShape.circle),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 28)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sess?.name ?? 'Admin account',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text1)),
            const SizedBox(height: 3),
            Text(sess?.administrator == true ? 'Fleet Manager' : 'User',
              style: const TextStyle(fontSize: 13, color: AppColors.text3)),
            const SizedBox(height: 6),
            Text(sess?.email ?? '', style: const TextStyle(fontSize: 12, color: AppColors.text3)),
          ])),
        ]),
      ),
      const SizedBox(height: 20),

      // ── Notification Preferences ──
      const Text('Notification Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
      const SizedBox(height: 10),
      ...state.notifPrefs.entries.map((entry) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.key, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text1)),
          const SizedBox(height: 12),
          _NotifRow(
            label: 'Push Notifications',
            value: entry.value.push,
            onChanged: (v) => state.setNotifPref(entry.key, push: v)),
          const SizedBox(height: 10),
          _NotifRow(
            label: 'Email Alerts',
            value: entry.value.email,
            onChanged: (v) => state.setNotifPref(entry.key, email: v)),
        ]),
      )),
      const SizedBox(height: 10),

      // ── Connection Info ──
      const Text('Connection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          _InfoRow2(Icons.dns_rounded,    const Color(0xFF1A3A6A), 'Server',    state.serverUrl ?? '—'),
          _divider(),
          _InfoRow2(
            state.wsConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            state.wsConnected ? const Color(0xFF1A3A2A) : const Color(0xFF3A1A1A),
            'WebSocket',
            state.wsConnected ? 'Connected ✓' : 'Disconnected',
            valueColor: state.wsConnected ? AppColors.running : AppColors.stopped),
          _divider(),
          _InfoRow2(Icons.person_outline_rounded, const Color(0xFF2A1A4A), 'User ID', '#${sess?.id ?? "—"}'),
          _divider(),
          _InfoRow2(Icons.speed_rounded, const Color(0xFF3A2A1A), 'Speed Unit', sess?.speedUnit ?? 'kmh'),
          _divider(),
          _InfoRow2(Icons.straighten_rounded, const Color(0xFF1A2A3A), 'Distance Unit', sess?.distanceUnit ?? 'km'),
        ]),
      ),
      const SizedBox(height: 20),

      // ── About ──
      const Text('About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text1)),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          const _InfoRow2(Icons.info_outline_rounded, Color(0xFF1A3A6A), 'App Version', 'v2.0.0'),
          _divider(),
          const _InfoRow2(Icons.satellite_alt_rounded, Color(0xFF1A3A6A), 'Traccar Engine', 'v6.0'),
          _divider(),
          const _InfoRow2(Icons.business_rounded, Color(0xFF1A3A6A), 'Provider', 'FAMS Pakistan Pvt Ltd'),
        ]),
      ),
      const SizedBox(height: 20),

      // ── Logout ──
      GestureDetector(
        onTap: () => _confirmLogout(context),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.stopped.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.logout_rounded, color: AppColors.stopped, size: 20),
            const SizedBox(width: 10),
            Text('Sign Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.stopped)),
          ])),
      ),
    ]);
  }

  void _confirmLogout(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Sign Out', style: TextStyle(color: AppColors.text1, fontWeight: FontWeight.w800)),
      content: const Text('Are you sure you want to sign out?', style: TextStyle(color: AppColors.text3)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: AppColors.text3))),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await context.read<AppState>().logout();
            if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.stopped),
          child: const Text('Sign Out')),
      ],
    ));
  }

  Widget _divider() => const Divider(height: 1, indent: 56, color: Color(0xFF1E2A40));
}

class _NotifRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _NotifRow({required this.label, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: const TextStyle(fontSize: 14, color: AppColors.text2, fontWeight: FontWeight.w500)),
    const Spacer(),
    AToggle(value: value, onChanged: onChanged),
  ]);
}

class _InfoRow2 extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String label, value;
  final Color? valueColor;
  const _InfoRow2(this.icon, this.iconBg, this.label, this.value, {this.valueColor});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.primary, size: 18)),
      const SizedBox(width: 14),
      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text1)),
      const Spacer(),
      Flexible(child: Text(value,
        style: TextStyle(fontSize: 12, color: valueColor ?? AppColors.text3, fontWeight: FontWeight.w600),
        textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
    ]));
}