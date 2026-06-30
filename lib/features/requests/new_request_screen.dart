import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atsvs_outpass_app/state/app_state.dart';
import 'package:atsvs_outpass_app/models/models.dart';
import 'package:atsvs_outpass_app/theme/theme.dart';
import 'package:atsvs_outpass_app/services/firebase_providers.dart';

/// Raise a new request.
/// - Students: Outpass (Spiritual / Sunday) or Leave.
/// - Parents: Leave only.
///
/// Outpass rules:
/// - Spiritual: valid for up to 2 hours 30 minutes from the start time.
/// - Sunday: a Sunday only, fixed window 1:30 PM – 6:00 PM.
/// Late return (after the deadline) disables outpass for 3 weeks.
class NewRequestScreen extends ConsumerStatefulWidget {
  const NewRequestScreen({super.key});

  @override
  ConsumerState<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();

  late RequestType _type;
  OutpassKind _kind = OutpassKind.spiritual;
  bool get _isStudent => ref.read(appStateProvider).role == UserRole.student;

  // Leave dates
  DateTime? _from;
  DateTime? _to;
  // Outpass (spiritual)
  DateTime? _spDate;
  TimeOfDay? _spStart;
  // Outpass (sunday)
  DateTime? _sunDate;

  @override
  void initState() {
    super.initState();
    _type = _isStudent ? RequestType.outpass : RequestType.leave;
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  bool get _blocked =>
      _isStudent && ref.read(appStateProvider).isOutpassBlocked(ref.read(appStateProvider).activeRoll!);

  Future<void> _pickLeaveDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to != null && _to!.isBefore(picked)) _to = picked;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _pickSpiritualDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _spDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _spDate = picked);
  }

  Future<void> _pickSpiritualTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _spStart ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _spStart = picked);
  }

  Future<void> _pickSundayDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextSunday(now),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
      selectableDayPredicate: (d) => d.weekday == DateTime.sunday,
    );
    if (picked != null) setState(() => _sunDate = picked);
  }

  DateTime _nextSunday(DateTime from) {
    var d = DateTime(from.year, from.month, from.day);
    while (d.weekday != DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final app = ref.read(appStateProvider);

    if (_type == RequestType.outpass && _blocked) {
      _toast('Outpass is currently disabled for this student.');
      return;
    }

    DateTime from;
    DateTime to;
    OutpassKind? kind;

    if (_type == RequestType.outpass) {
      kind = _kind;
      if (_kind == OutpassKind.spiritual) {
        if (_spDate == null || _spStart == null) {
          _toast('Please pick the date and start time');
          return;
        }
        from = DateTime(_spDate!.year, _spDate!.month, _spDate!.day,
            _spStart!.hour, _spStart!.minute);
        to = from.add(const Duration(
            minutes: OutpassKindInfo.spiritualMaxMinutes)); // up to 2h30
      } else {
        if (_sunDate == null) {
          _toast('Please pick a Sunday');
          return;
        }
        if (_sunDate!.weekday != DateTime.sunday) {
          _toast('Sunday outpass must be on a Sunday');
          return;
        }
        from = DateTime(_sunDate!.year, _sunDate!.month, _sunDate!.day,
            OutpassKindInfo.sundayStartHour, OutpassKindInfo.sundayStartMinute);
        to = DateTime(_sunDate!.year, _sunDate!.month, _sunDate!.day,
            OutpassKindInfo.sundayEndHour, OutpassKindInfo.sundayEndMinute);
      }
    } else {
      if (_from == null || _to == null) {
        _toast('Please pick both dates');
        return;
      }
      from = _from!;
      to = _to!;
    }

    final req = AppRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      studentRoll: app.activeRoll!,
      type: _type,
      outpassKind: kind,
      reason: _reasonCtrl.text.trim(),
      fromDate: from,
      toDate: to,
      createdAt: DateTime.now(),
      raisedBy: app.role == UserRole.parent ? 'Parent' : 'Student',
    );
    try {
      await ref.read(repositoryProvider).addRequest(req); // -> Firestore (live)
    } catch (e) {
      _toast('Could not send request. Please try again.');
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    _toast(_type == RequestType.outpass
        ? 'Outpass request sent to hostel warden'
        : 'Leave request sent for approval');
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final isOutpass = _type == RequestType.outpass;
    final blocked = isOutpass && _blocked;
    return Scaffold(
      appBar: AppBar(title: const Text('New Request')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isStudent) ...[
                  const Text('Request type',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SegmentedButton<RequestType>(
                    segments: const [
                      ButtonSegment(
                        value: RequestType.outpass,
                        label: Text('Outpass'),
                        icon: Icon(Icons.timer_outlined),
                      ),
                      ButtonSegment(
                        value: RequestType.leave,
                        label: Text('Leave'),
                        icon: Icon(Icons.home_outlined),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() => _type = s.first),
                  ),
                  const SizedBox(height: 20),
                ],
                if (isOutpass) ...[
                  if (blocked) _BlockBanner(
                      until: ref.read(appStateProvider)
                          .blockedUntil(ref.read(appStateProvider).activeRoll!)!),
                  const Text('Outpass type',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SegmentedButton<OutpassKind>(
                    segments: const [
                      ButtonSegment(
                        value: OutpassKind.spiritual,
                        label: Text('Spiritual'),
                        icon: Icon(Icons.self_improvement),
                      ),
                      ButtonSegment(
                        value: OutpassKind.sunday,
                        label: Text('Sunday'),
                        icon: Icon(Icons.wb_sunny_outlined),
                      ),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (s) => setState(() => _kind = s.first),
                  ),
                  const SizedBox(height: 14),
                ],
                _RuleNote(type: _type, kind: _kind),
                const SizedBox(height: 18),
                const Text('Reason',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Temple visit, medical, family function…',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a reason'
                      : null,
                ),
                const SizedBox(height: 18),
                if (isOutpass)
                  ..._outpassInputs()
                else
                  _leaveInputs(),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: blocked ? null : _submit,
                  icon: const Icon(Icons.send),
                  label: Text(blocked ? 'Outpass disabled' : 'Send Request'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _outpassInputs() {
    if (_kind == OutpassKind.spiritual) {
      return [
        Row(
          children: [
            Expanded(
              child: _PickerBox(
                label: 'Date',
                icon: Icons.calendar_month_outlined,
                value: _spDate == null ? 'Select' : _fmtDate(_spDate!),
                onTap: _pickSpiritualDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PickerBox(
                label: 'Start time',
                icon: Icons.access_time,
                value: _spStart == null ? 'Select' : _spStart!.format(context),
                onTap: _pickSpiritualTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Must return within 2 hours 30 minutes of the start time.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
      ];
    }
    // Sunday
    return [
      _PickerBox(
        label: 'Sunday',
        icon: Icons.calendar_month_outlined,
        value: _sunDate == null ? 'Select a Sunday' : _fmtDate(_sunDate!),
        onTap: _pickSundayDate,
      ),
      const SizedBox(height: 8),
      Text('Fixed timing: 1:30 PM – 6:00 PM. Must be back by 6:00 PM.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
    ];
  }

  Widget _leaveInputs() {
    return Row(
      children: [
        Expanded(
          child: _PickerBox(
            label: 'From',
            icon: Icons.calendar_month_outlined,
            value: _from == null ? 'Select' : _fmtDate(_from!),
            onTap: () => _pickLeaveDate(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PickerBox(
            label: 'To',
            icon: Icons.calendar_month_outlined,
            value: _to == null ? 'Select' : _fmtDate(_to!),
            onTap: () => _pickLeaveDate(false),
          ),
        ),
      ],
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _BlockBanner extends StatelessWidget {
  final DateTime until;
  const _BlockBanner({required this.until});

  @override
  Widget build(BuildContext context) {
    String f(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.block, color: Color(0xFFC62828)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Outpass is disabled until ${f(until)} due to a late return. '
              'You can still apply for Leave.',
              style: const TextStyle(color: Color(0xFFC62828), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleNote extends StatelessWidget {
  final RequestType type;
  final OutpassKind kind;
  const _RuleNote({required this.type, required this.kind});

  @override
  Widget build(BuildContext context) {
    String text;
    if (type == RequestType.leave) {
      text = 'Leave needs approval from the Hostel Warden and a Higher Authority.';
    } else if (kind == OutpassKind.spiritual) {
      text =
          'Spiritual outpass — max 2h 30m. Approved by the Hostel Warden. Late return disables outpass for 3 weeks.';
    } else {
      text =
          'Sunday outpass — 1:30 PM to 6:00 PM. Approved by the Hostel Warden. Returning after 6:00 PM disables outpass for 3 weeks.';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }
}

class _PickerBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  const _PickerBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Text(value),
      ),
    );
  }
}
