import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atsvs_outpass_app/models/models.dart';
import 'package:atsvs_outpass_app/theme/theme.dart';
import 'package:atsvs_outpass_app/services/firebase_providers.dart';

/// Full status + approval timeline for one request (live from Firestore).
class RequestDetailScreen extends ConsumerWidget {
  final String requestId;
  const RequestDetailScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rAsync = ref.watch(requestStreamProvider(requestId));
    return Scaffold(
      appBar: AppBar(title: const Text('Request Status')),
      body: rAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            const Center(child: Text('Could not load request.')),
        data: (r) {
          if (r == null) {
            return const Center(child: Text('Request not found.'));
          }
          final status = r.overallStatus;
          final color = AppTheme.statusColor(status.label);
          final isOutpass = r.type == RequestType.outpass;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_statusIcon(status), color: color, size: 46),
                    ),
                    const SizedBox(height: 12),
                    Text('${r.fullLabel} • ${status.label}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: color)),
                    const SizedBox(height: 4),
                    Text(_message(r),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (r.isLateReturn) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.block, color: Color(0xFFC62828)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Returned late. Outpass is disabled for 3 weeks.',
                          style:
                              TextStyle(color: Color(0xFFC62828), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              GradientCard(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('Reason', r.reason),
                      const Divider(height: 24),
                      if (isOutpass) ...[
                        _row('Date', _fmtDate(r.fromDate)),
                        const Divider(height: 24),
                        _row('Time',
                            '${_fmtTime(r.fromDate)} – ${_fmtTime(r.toDate)}'),
                        const Divider(height: 24),
                        _row('Return by', _fmtTime(r.toDate)),
                      ] else ...[
                        _row('From', _fmtDate(r.fromDate)),
                        const Divider(height: 24),
                        _row('To', _fmtDate(r.toDate)),
                      ],
                      const Divider(height: 24),
                      _row('Raised by', r.raisedBy),
                      const Divider(height: 24),
                      _row('Requested on', _fmtDateTime(r.createdAt)),
                      if (r.overallStatus == RequestStatus.approved) ...[
                        const Divider(height: 24),
                        _row('Gate status', r.gateStatus.label),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _Timeline(request: r),
            ],
          );
        },
      ),
    );
  }

  static IconData _statusIcon(RequestStatus s) {
    switch (s) {
      case RequestStatus.approved:
        return Icons.check_circle;
      case RequestStatus.rejected:
        return Icons.cancel;
      case RequestStatus.pending:
        return Icons.hourglass_top;
    }
  }

  static String _message(AppRequest r) {
    switch (r.overallStatus) {
      case RequestStatus.approved:
        if (r.type == RequestType.leave) {
          return 'Leave fully approved. Student may go home.';
        }
        return r.outpassKind == OutpassKind.sunday
            ? 'Approved. Out 1:30–6:00 PM, must be back by 6:00 PM.'
            : 'Approved. Must return within 2h 30m.';
      case RequestStatus.rejected:
        return 'This request was rejected.';
      case RequestStatus.pending:
        return 'Awaiting approval.';
    }
  }

  static Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  static String _fmtDateTime(DateTime d) =>
      '${_fmtDate(d)}, ${_fmtTime(d)}';
}

class _Timeline extends StatelessWidget {
  final AppRequest request;
  const _Timeline({required this.request});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final steps = <_Step>[
      _Step('Request submitted', RequestStatus.approved, null, r.createdAt),
      _Step('Hostel Warden', r.wardenStatus, r.wardenRemark, r.wardenDecidedAt),
    ];
    if (r.needsAuthority) {
      steps.add(_Step('Higher Authority', r.authorityStatus, r.authorityRemark,
          r.authorityDecidedAt));
    }
    // Gate steps appear once the request is fully approved.
    if (r.overallStatus == RequestStatus.approved) {
      steps.add(_Step(
        'Went out (gate)',
        r.wentOutAt != null ? RequestStatus.approved : RequestStatus.pending,
        null,
        r.wentOutAt,
      ));
      steps.add(_Step(
        'Returned (gate)',
        r.returnedAt != null ? RequestStatus.approved : RequestStatus.pending,
        null,
        r.returnedAt,
      ));
    }
    return GradientCard(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tracking timeline',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            for (int i = 0; i < steps.length; i++)
              _stepRow(steps[i], i < steps.length - 1),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(_Step step, bool hasNext) {
    final color = AppTheme.statusColor(step.status.label);
    final icon = step.status == RequestStatus.approved
        ? Icons.check_circle
        : step.status == RequestStatus.rejected
            ? Icons.cancel
            : Icons.radio_button_unchecked;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, color: color, size: 22),
              if (hasNext) Expanded(child: Container(width: 2, color: color)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(step.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Text(step.status.label,
                          style: TextStyle(
                              color: color,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  // The exact time this step happened.
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      step.time != null ? _stamp(step.time!) : 'Waiting…',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: step.time != null
                              ? Colors.grey.shade700
                              : Colors.grey.shade500),
                    ),
                  ),
                  if (step.remark != null && step.remark!.isNotEmpty)
                    Text('“${step.remark}”',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /// e.g. "07 Jun 2026, 04:35 PM"
  static String _stamp(DateTime d) {
    final h24 = d.hour;
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    var h = h24 % 12;
    if (h == 0) h = 12;
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}, '
        '${h.toString().padLeft(2, '0')}:$mm $ampm';
  }
}

class _Step {
  final String title;
  final RequestStatus status;
  final String? remark;
  final DateTime? time;
  _Step(this.title, this.status, this.remark, this.time);
}
