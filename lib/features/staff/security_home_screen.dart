import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atsvs_outpass_app/state/app_state.dart';
import 'package:atsvs_outpass_app/models/models.dart';
import 'package:atsvs_outpass_app/theme/theme.dart';
import 'package:atsvs_outpass_app/services/firebase_providers.dart';
import 'package:atsvs_outpass_app/services/firestore_repository.dart';

/// Security (gate) home: shows only APPROVED passes (live) and lets the guard
/// mark a student "Went out" / "Returned". Writes to Firestore, so the parent
/// and student apps update.
class SecurityHomeScreen extends ConsumerStatefulWidget {
  const SecurityHomeScreen({super.key});

  @override
  ConsumerState<SecurityHomeScreen> createState() => _SecurityHomeScreenState();
}

class _SecurityHomeScreenState extends ConsumerState<SecurityHomeScreen> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.read(appStateProvider);
    final repo = ref.read(repositoryProvider);
    final gate = ref.watch(gateApprovedProvider);
    final students = ref.watch(studentsStreamProvider).valueOrNull ?? const [];

    Student? byRoll(String roll) {
      for (final s in students) {
        if (s.rollNo == roll) return s;
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security — Gate'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => confirmLogout(context, app.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _ctrl,
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by student name or roll no',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _ctrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() => _q = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: gate.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  const Center(child: Text('Could not load passes.')),
              data: (all) {
                final items = _q.isEmpty
                    ? all
                    : all.where((r) {
                        final name = (byRoll(r.studentRoll)?.name ?? '')
                            .toLowerCase();
                        return name.contains(_q) ||
                            r.studentRoll.toLowerCase().contains(_q);
                      }).toList();
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_outlined,
                              size: 60, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                              all.isEmpty
                                  ? 'No approved passes at the gate.'
                                  : 'No matching passes.',
                              style: TextStyle(
                                  fontSize: 15, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: items
                      .map((r) => _GateCard(
                            request: r,
                            student: byRoll(r.studentRoll),
                            repo: repo,
                          ))
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GateCard extends StatelessWidget {
  final AppRequest request;
  final Student? student;
  final FirestoreRepository repo;
  const _GateCard(
      {required this.request, required this.student, required this.repo});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final s = student;
    final isOut = r.gateStatus == GateStatus.out;
    final isOutpass = r.type == RequestType.outpass;
    return GradientCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(s?.name ?? r.studentRoll,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                _GateChip(status: r.gateStatus),
              ],
            ),
            if (s != null)
              Text('Roll ${s.rollNo} • Room ${s.hostelRoom}',
                  style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(r.type.label,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOutpass
                        ? '${_fmtDate(r.fromDate)}  ${_fmtTime(r.fromDate)}–${_fmtTime(r.toDate)}'
                        : '${_fmtDate(r.fromDate)} → ${_fmtDate(r.toDate)}',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Return by ${_fmtDate(r.toDate)} ${_fmtTime(r.toDate)}',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            if (!isOut)
              FilledButton.icon(
                onPressed: () => repo.setGateStatus(r, GateStatus.out),
                icon: const Icon(Icons.logout),
                label: const Text('Mark Went Out'),
              )
            else
              FilledButton.icon(
                style:
                    FilledButton.styleFrom(backgroundColor: AppTheme.accent),
                onPressed: () => _markReturned(context),
                icon: const Icon(Icons.login),
                label: const Text('Mark Returned'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _markReturned(BuildContext context) async {
    final penalised = await repo.setGateStatus(request, GateStatus.returned);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: penalised ? AppTheme.statusColor('Rejected') : null,
        content: Text(penalised
            ? 'Late return — outpass disabled for 3 weeks.'
            : 'Marked returned.'),
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _GateChip extends StatelessWidget {
  final GateStatus status;
  const _GateChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == GateStatus.out
        ? AppTheme.statusColor('Pending')
        : AppTheme.statusColor('Approved');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status.label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
