import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atsvs_outpass_app/models/models.dart';
import 'package:atsvs_outpass_app/theme/theme.dart';
import 'package:atsvs_outpass_app/services/firebase_providers.dart';

typedef DecideCallback = Future<void> Function(
    AppRequest r, RequestStatus status, String? remark);

/// Reusable approval queue used by the Hostel Warden and the Higher Authority.
class ApprovalList extends ConsumerWidget {
  final String emptyText;
  final List<AppRequest> items;
  final DecideCallback onDecide;
  const ApprovalList({
    super.key,
    required this.emptyText,
    required this.items,
    required this.onDecide,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return _Empty(emptyText);
    }
    final students = ref.watch(studentsStreamProvider).valueOrNull ?? const [];
    Student? byRoll(String roll) {
      for (final s in students) {
        if (s.rollNo == roll) return s;
      }
      return null;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.map((r) {
        final s = byRoll(r.studentRoll);
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
                    _Tag(r.type.label),
                    const Spacer(),
                    Text('by ${r.raisedBy}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(s?.name ?? r.studentRoll,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                if (s != null)
                  Text('Roll ${s.rollNo} • Room ${s.hostelRoom}',
                      style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text(r.reason),
                const SizedBox(height: 6),
                Text(
                  isOutpass
                      ? '${_fmtDate(r.fromDate)}  ${_fmtTime(r.fromDate)}–${_fmtTime(r.toDate)}'
                      : '${_fmtDate(r.fromDate)} → ${_fmtDate(r.toDate)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.statusColor('Rejected')),
                        onPressed: () =>
                            _decide(context, r, RequestStatus.rejected),
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            _decide(context, r, RequestStatus.approved),
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _decide(
      BuildContext context, AppRequest r, RequestStatus status) async {
    final remark = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: Text('${status.label} ${r.type.label.toLowerCase()}'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Remark (optional)'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Skip')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Confirm')),
          ],
        );
      },
    );
    await onDecide(r, status, remark);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Marked ${status.label.toLowerCase()}')),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary)),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
