import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atsvs_outpass_app/state/app_state.dart';
import 'package:atsvs_outpass_app/models/models.dart';
import 'package:atsvs_outpass_app/theme/theme.dart';
import 'package:atsvs_outpass_app/services/firebase_providers.dart';
import 'package:atsvs_outpass_app/features/staff/approvals.dart';

/// Hostel Warden home: live approval queue + hostel student list (Firestore),
/// each with a search bar (by student name or roll number).
class WardenHomeScreen extends ConsumerWidget {
  const WardenHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.read(appStateProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hostel Warden'),
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
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Approvals'),
              Tab(text: 'Hostel Students'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ApprovalsTab(),
            _HostelStudentsTab(),
          ],
        ),
      ),
    );
  }
}

/// Shared search box.
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search by student name or roll no',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

bool _matches(String query, String? name, String roll) {
  if (query.isEmpty) return true;
  return (name ?? '').toLowerCase().contains(query) ||
      roll.toLowerCase().contains(query);
}

// ---------------- Approvals tab ----------------

class _ApprovalsTab extends ConsumerStatefulWidget {
  const _ApprovalsTab();
  @override
  ConsumerState<_ApprovalsTab> createState() => _ApprovalsTabState();
}

class _ApprovalsTabState extends ConsumerState<_ApprovalsTab> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingWardenProvider);
    final students = ref.watch(studentsStreamProvider).valueOrNull ?? const [];
    String? nameOf(String roll) {
      for (final s in students) {
        if (s.rollNo == roll) return s.name;
      }
      return null;
    }

    return Column(
      children: [
        _SearchBar(
          controller: _ctrl,
          onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
        ),
        Expanded(
          child: pending.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                const Center(child: Text('Could not load requests.')),
            data: (items) {
              final filtered = items
                  .where((r) =>
                      _matches(_q, nameOf(r.studentRoll), r.studentRoll))
                  .toList();
              return ApprovalList(
                emptyText: items.isEmpty
                    ? 'No requests awaiting the warden.'
                    : 'No matching requests.',
                items: filtered,
                onDecide: (r, status, remark) => ref
                    .read(repositoryProvider)
                    .setWardenDecision(r.id, status, remark),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------- Hostel students tab ----------------

class _HostelStudentsTab extends ConsumerStatefulWidget {
  const _HostelStudentsTab();
  @override
  ConsumerState<_HostelStudentsTab> createState() => _HostelStudentsTabState();
}

class _HostelStudentsTabState extends ConsumerState<_HostelStudentsTab> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsStreamProvider);
    return Column(
      children: [
        _SearchBar(
          controller: _ctrl,
          onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
        ),
        Expanded(
          child: studentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                const Center(child: Text('Could not load students.')),
            data: (list) {
              final filtered = list
                  .where((s) => _matches(_q, s.name, s.rollNo))
                  .toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Text(list.isEmpty
                      ? 'No students on record.'
                      : 'No matching students.'),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final s = filtered[i];
                  return GradientCard(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.12),
                        child: Text(
                            s.hostelRoom.isNotEmpty ? s.hostelRoom[0] : '?',
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold)),
                      ),
                      title: Text(s.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          'Roll ${s.rollNo} • ${s.course}\nRoom ${s.hostelRoom} • Parent ${s.parentPhone}'),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
