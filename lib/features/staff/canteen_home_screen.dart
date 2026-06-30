import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atsvs_outpass_app/state/app_state.dart';
import 'package:atsvs_outpass_app/models/models.dart';
import 'package:atsvs_outpass_app/theme/theme.dart';
import 'package:atsvs_outpass_app/services/firebase_providers.dart';
import 'package:atsvs_outpass_app/services/firestore_repository.dart';

/// Canteen home: meal count + side-dish requests, and a tab to manage the daily
/// mess menu (the canteen can add/remove dishes, same as the admin).
class CanteenHomeScreen extends ConsumerWidget {
  const CanteenHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.read(appStateProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Canteen'),
          actions: [
            IconButton(
              tooltip: 'Logout',
              icon: const Icon(Icons.logout),
              onPressed: () => confirmLogout(context, app.logout),
            ),
          ],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            tabs: const [
              Tab(text: 'Meal Count'),
              Tab(text: 'Mess Menu'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MealCountTab(),
            _MenuTab(),
          ],
        ),
      ),
    );
  }
}

// ---------------- Meal count + side-dish requests ----------------

class _MealCountTab extends ConsumerWidget {
  const _MealCountTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final awayAsync = ref.watch(awayProvider);
    final students = ref.watch(studentsStreamProvider).valueOrNull ?? const [];
    final bookings =
        ref.watch(messBookingsStreamProvider).valueOrNull ?? const [];

    Student? byRoll(String roll) {
      for (final s in students) {
        if (s.rollNo == roll) return s;
      }
      return null;
    }

    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final sideRequests = bookings
        .where((b) =>
            b.extra.trim().isNotEmpty && b.dateKey.compareTo(todayKey) >= 0)
        .toList()
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));

    return awayAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('Error: $e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFC62828))),
        ),
      ),
      data: (away) {
        final total = students.length;
        final present = total - away.length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _Stat(
                    label: 'On campus',
                    value: '$present',
                    color: AppTheme.accent,
                    icon: Icons.restaurant),
                const SizedBox(width: 12),
                _Stat(
                    label: 'Away',
                    value: '${away.length}',
                    color: AppTheme.statusColor('Pending'),
                    icon: Icons.directions_walk),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Prepare meals for about $present students today.',
                style: TextStyle(
                    color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Students currently away',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (away.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('Everyone is on campus.',
                      style: TextStyle(color: Colors.grey.shade600)),
                ),
              )
            else
              ...away.map((r) {
                final s = byRoll(r.studentRoll);
                return GradientCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.statusColor('Pending')
                          .withValues(alpha: 0.14),
                      child: Icon(
                          r.type == RequestType.outpass
                              ? Icons.timer_outlined
                              : Icons.home_outlined,
                          color: AppTheme.statusColor('Pending')),
                    ),
                    title: Text(s?.name ?? r.studentRoll,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(s == null
                        ? r.type.label
                        : '${r.type.label} • Room ${s.hostelRoom}'),
                    trailing: Text(_back(r),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ),
                );
              }),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.add_circle_outline,
                    size: 18, color: AppTheme.primary),
                const SizedBox(width: 6),
                const Text('Extra side-dish requests',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            if (sideRequests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('No extra requests.',
                      style: TextStyle(color: Colors.grey.shade600)),
                ),
              )
            else
              ...sideRequests.map((b) {
                final s = byRoll(b.studentRoll);
                return GradientCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                      child: const Icon(Icons.restaurant_menu,
                          color: AppTheme.primary),
                    ),
                    title: Text('${b.extra}  (${b.meal.label})',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${s?.name ?? b.studentRoll} • ${_fmtKey(b.dateKey)}'),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  static String _back(AppRequest r) {
    final d = r.toDate;
    return 'back ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  static String _fmtKey(String key) {
    final p = key.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : key;
  }
}

// ---------------- Manage mess menu ----------------

class _MenuTab extends ConsumerStatefulWidget {
  const _MenuTab();
  @override
  ConsumerState<_MenuTab> createState() => _MenuTabState();
}

class _MenuTabState extends ConsumerState<_MenuTab> {
  final _ctrl = TextEditingController();
  MealType _meal = MealType.breakfast;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    final item = MessMenuItem(
      id: 'mi${DateTime.now().microsecondsSinceEpoch}',
      meal: _meal,
      name: name,
    );
    try {
      await ref.read(repositoryProvider).addMenuItem(item);
      _ctrl.clear();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(messMenuStreamProvider).valueOrNull ?? const [];
    final repo = ref.read(repositoryProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Add today's dish",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SegmentedButton<MealType>(
          segments: const [
            ButtonSegment(value: MealType.breakfast, label: Text('Breakfast')),
            ButtonSegment(value: MealType.lunch, label: Text('Lunch')),
            ButtonSegment(value: MealType.dinner, label: Text('Dinner')),
          ],
          selected: {_meal},
          onSelectionChanged: (s) => setState(() => _meal = s.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          decoration: const InputDecoration(
            labelText: 'Dish name',
            hintText: 'e.g. Idli & Sambar',
            prefixIcon: Icon(Icons.restaurant_menu),
          ),
          onSubmitted: (_) => _add(),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: Text('Add to ${_meal.label}'),
        ),
        const SizedBox(height: 22),
        for (final m in MealType.values) ...[
          Text(m.label,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._dishesFor(menu, m, repo),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  List<Widget> _dishesFor(
      List<MessMenuItem> menu, MealType m, FirestoreRepository repo) {
    final items = menu.where((i) => i.meal == m).toList();
    if (items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('No dishes yet.',
              style: TextStyle(color: Colors.grey.shade500)),
        )
      ];
    }
    return items
        .map((i) => GradientCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(i.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFC62828)),
                  onPressed: () => repo.removeMenuItem(i.id),
                ),
              ),
            ))
        .toList();
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _Stat(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GradientCard(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  Text(label, style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
