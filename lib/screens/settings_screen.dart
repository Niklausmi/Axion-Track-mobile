// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.text1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: state.eventPrefs.entries.map((entry) {
          final meta = eventMeta(entry.key);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  Icon(meta['icon'] as IconData, color: Color(meta['color'] as int), size: 20),
                  const SizedBox(width: 8),
                  Text(meta['label'] as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text1)),
                ],
              ),
              const SizedBox(height: 12),
              _NotifRow(
                label: 'Show in Feed',
                value: entry.value.showInApp,
                onChanged: (v) => state.setEventPref(entry.key, showInApp: v)),
              const SizedBox(height: 10),
              _NotifRow(
                label: 'Push Notifications',
                value: entry.value.pushEnabled,
                onChanged: (v) => state.setEventPref(entry.key, pushEnabled: v)),
            ]),
          );
        }).toList(),
      ),
    );
  }
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
    Switch(
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    ),
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