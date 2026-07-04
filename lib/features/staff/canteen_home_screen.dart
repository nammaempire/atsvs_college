import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atsvs_outpass_app/state/app_state.dart';
import 'package:atsvs_outpass_app/models/models.dart';
import 'package:atsvs_outpass_app/theme/theme.dart';
import 'package:atsvs_outpass_app/services/firebase_providers.dart';

/// Canteen home: meal count (on-campus vs away) + extra side-dish requests.
class CanteenHomeScreen extends ConsumerWidget {
  const CanteenHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.read(appStateProvider);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canteen — Meal Count'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => confirmLogout(context, app.logout),
          ),
        ],
      ),
      body: awayAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load. $e',
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
                      isThreeLine: true,
                      leading: CircleAvatar(
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.12),
                        child: const Icon(Icons.restaurant_menu,
                            color: AppTheme.primary),
                      ),
                      // The requested dish.
                      title: Text(b.extra,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person_outline,
                                    size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(s?.name ?? b.studentRoll,
                                      style: TextStyle(
                                          color: Colors.grey.shade800,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('${b.meal.label}  •  ${_fmtKey(b.dateKey)}',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
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
