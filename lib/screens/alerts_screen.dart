// lib/screens/alerts_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/traccar_models.dart';
import '../utils/theme.dart';
import '../widgets/shared_widgets.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  int? _devFilter;
  String? _typeFilter;

  @override void initState() { super.initState(); _tab = TabController(length: 3, vsync: this)..addListener(() => setState(() {})); }
  @override void dispose()   { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state  = context.watch<AppState>();
    final devMap = {for (final d in state.devices) d.id: d};

    final allEvents  = state.events;
    final unread     = allEvents.where((e) => !e.read).toList();
    final read       = allEvents.where((e) =>  e.read).toList();
    final current    = _tab.index == 0 ? allEvents : _tab.index == 1 ? unread : read;

    final filtered = current.where((e) {
      if (_devFilter  != null && e.deviceId != _devFilter)  return false;
      if (_typeFilter != null && e.type     != _typeFilter)  return false;
      return true;
    }).toList();

    return Column(children: [
      // ── Filter bar ──
      Container(
        color: AC.surface,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(children: [
          Expanded(child: _DropBtn(
            label: _devFilter == null ? 'Select Vehicle' : devMap[_devFilter]?.name ?? 'Unknown',
            onTap: () => _showDevPicker(context, state.devices, devMap))),
          const SizedBox(width: 10),
          Expanded(child: _DropBtn(
            label: _typeFilter == null ? 'All' : (eventMeta(_typeFilter!)['label'] as String),
            badge: '(${filtered.length})',
            badgeColor: AC.green,
            onTap: () => _showTypePicker(context, state.events))),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () { setState(() { _devFilter = null; _typeFilter = null; }); },
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: AC.blue, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.search_rounded, color: Colors.white, size: 20))),
        ]),
      ),

      // ── Tabs ──
      Container(
        color: AC.surface,
        child: TabBar(
          controller: _tab,
          indicatorColor: AC.blue,
          indicatorWeight: 2,
          labelColor: AC.blue,
          unselectedLabelColor: AC.text3,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: [
            const Tab(text: 'All'),
            Tab(text: unread.isEmpty ? 'Unread' : 'Unread  ${unread.length}'),
            const Tab(text: 'Read'),
          ],
        ),
      ),

      // ── Summary bar ──
      if (filtered.isNotEmpty) Container(
        color: AC.surface2,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Text('${filtered.length} events', style: const TextStyle(fontSize: 12, color: AC.text3)),
          const SizedBox(width: 12),
          if (state.overspeedToday > 0) _SumChip('⚡ ${state.overspeedToday} Overspeed', AC.red),
          const Spacer(),
          if (_tab.index == 0 && unread.isNotEmpty) GestureDetector(
            onTap: () { state.markAllRead(); },
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.done_all_rounded, size: 14, color: AC.blue),
              SizedBox(width: 4),
              Text('Mark all', style: TextStyle(fontSize: 12, color: AC.blue, fontWeight: FontWeight.w600)),
            ])),
        ]),
      ),

      // ── List ──
      Expanded(child: filtered.isEmpty
        ? const EmptyState(icon: Icons.notifications_none_rounded, message: 'No data received')
        : RefreshIndicator(
            onRefresh: state.refresh,
            color: AC.blue, backgroundColor: AC.surface,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final e  = filtered[i];
                final dn = devMap[e.deviceId]?.name ?? 'Device #${e.deviceId}';
                return _EventCard(event: e, deviceName: dn,
                  onTap: () { state.markRead(e.id); });
              }))),
    ]);
  }

  void _showDevPicker(BuildContext ctx, List<TraccarDevice> devs, Map<int,TraccarDevice> devMap) {
    showModalBottomSheet(context: ctx, backgroundColor: AC.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PickerSheet(
        title: 'Select Vehicle',
        items: [const {'id': null, 'label': 'All Vehicles'},
          ...devs.map((d) => {'id': d.id, 'label': d.name})],
        selected: _devFilter,
        onSelect: (v) => setState(() => _devFilter = v as int?)));
  }

  void _showTypePicker(BuildContext ctx, List<TraccarEvent> events) {
    final types = ['all', ...{...events.map((e) => e.type)}];
    showModalBottomSheet(context: ctx, backgroundColor: AC.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PickerSheet(
        title: 'Filter by Type',
        items: types.map((t) => {'id': t == 'all' ? null : t,
          'label': t == 'all' ? 'All Events' : eventMeta(t)['label'] as String}).toList(),
        selected: _typeFilter,
        onSelect: (v) => setState(() => _typeFilter = v as String?)));
  }
}

class _EventCard extends StatelessWidget {
  final TraccarEvent event;
  final String deviceName;
  final VoidCallback onTap;
  const _EventCard({required this.event, required this.deviceName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final m   = eventMeta(event.type);
    final col = Color(m['color'] as int);
    final bg  = Color(m['bg']    as int);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AC.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0,2))]),
        child: Row(children: [
          // Left colour bar
          Container(width: 4, height: 74, decoration: BoxDecoration(
            color: col, borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)))),
          const SizedBox(width: 12),
          Container(width: 38, height: 38,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(m['icon'] as IconData, color: col, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(m['label'] as String,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AC.text1))),
                Text(event.serverTime != null ? _timeStr(event.serverTime!) : '—',
                  style: const TextStyle(fontSize: 11, color: AC.text3)),
                if (!event.read) Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 6),
                  decoration: const BoxDecoration(color: AC.blue, shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 3),
              Text(deviceName, style: const TextStyle(fontSize: 12, color: AC.text3, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 11, color: AC.text4),
                const SizedBox(width: 3),
                Text(event.attributes['address'] as String? ?? '—',
                  style: const TextStyle(fontSize: 11, color: AC.text4), overflow: TextOverflow.ellipsis),
                const SizedBox(width: 10),
                const Icon(Icons.speed_rounded, size: 11, color: AC.text4),
                const SizedBox(width: 3),
                Text('${((event.attributes['speed'] as num?)?.toDouble() ?? 0) * 3.6 ~/ 1} km/h',
                  style: const TextStyle(fontSize: 11, color: AC.text4)),
              ]),
            ])),
          ),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }

  String _timeStr(DateTime dt) {
    final l = dt.toLocal();
    final h = l.hour, ap = h >= 12 ? 'PM' : 'AM', h12 = h % 12 == 0 ? 12 : h % 12;
    return '${h12.toString().padLeft(2,'0')}:${l.minute.toString().padLeft(2,'0')} $ap';
  }
}

class _DropBtn extends StatelessWidget {
  final String label;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback onTap;
  const _DropBtn({required this.label, this.badge, this.badgeColor, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: AC.surface2, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AC.text1),
            overflow: TextOverflow.ellipsis)),
          if (badge != null) ...[
            const SizedBox(width: 4),
            Text(badge!, style: TextStyle(fontSize: 11, color: badgeColor ?? AC.text3, fontWeight: FontWeight.w700)),
          ],
        ])),
        const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AC.text3),
      ])));
}

class _SumChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SumChip(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)));
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final dynamic selected;
  final Function(dynamic) onSelect;
  const _PickerSheet({required this.title, required this.items, this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: AC.surface3, borderRadius: BorderRadius.circular(2))),
    Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AC.text1))),
    ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
      child: ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: items.map((item) => GestureDetector(
          onTap: () { onSelect(item['id']); Navigator.pop(context); },
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected == item['id'] ? AC.blue.withOpacity(0.15) : AC.surface2,
              borderRadius: BorderRadius.circular(12),
              border: selected == item['id'] ? Border.all(color: AC.blue.withOpacity(0.4)) : null),
            child: Text(item['label'] as String, style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: selected == item['id'] ? AC.blue : AC.text1))))).toList())),
  ]);
}
