import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atsvs_outpass_app/state/app_state.dart';
import 'package:atsvs_outpass_app/models/models.dart';
import 'package:atsvs_outpass_app/theme/theme.dart';
import 'package:atsvs_outpass_app/services/firebase_providers.dart';

/// Mess (dining) bookings. The student picks an upcoming day, marks whether
/// they want each meal (Breakfast / Lunch / Dinner) and customizes the food.
/// Bookings must be made at least 1 day in advance, so only tomorrow onwards
/// can be edited.
class MessScreen extends ConsumerStatefulWidget {
  const MessScreen({super.key});

  @override
  ConsumerState<MessScreen> createState() => _MessScreenState();
}

class _MessScreenState extends ConsumerState<MessScreen> {
  late List<DateTime> _days;
  late DateTime _selected;

  // Editable state for the selected day's three meals.
  final Map<MealType, bool> _available = {};
  final Map<MealType, TextEditingController> _pref = {
    MealType.breakfast: TextEditingController(),
    MealType.lunch: TextEditingController(),
    MealType.dinner: TextEditingController(),
  };
  final Map<MealType, TextEditingController> _extra = {
    MealType.breakfast: TextEditingController(),
    MealType.lunch: TextEditingController(),
    MealType.dinner: TextEditingController(),
  };

  String get _roll => ref.read(appStateProvider).activeRoll!;
  List<MessMenuItem> _menuItems = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _days = List.generate(7, (i) => tomorrow.add(Duration(days: i)));
    _selected = _days.first;
    _loadForDate();
  }

  @override
  void dispose() {
    for (final c in [..._pref.values, ..._extra.values]) {
      c.dispose();
    }
    super.dispose();
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadForDate() async {
    final repo = ref.read(repositoryProvider);
    final dateKey = _key(_selected);
    for (final m in MealType.values) {
      final b = await repo.mealBookingFor(_roll, dateKey, m);
      _available[m] = b?.available ?? true;
      _pref[m]!.text = b?.preference ?? '';
      _extra[m]!.text = b?.extra ?? '';
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final repo = ref.read(repositoryProvider);
    try {
      for (final m in MealType.values) {
        await repo.saveMealBooking(MealBooking(
          studentRoll: _roll,
          dateKey: _key(_selected),
          meal: m,
          available: _available[m] ?? true,
          preference: _pref[m]!.text.trim(),
          extra: _extra[m]!.text.trim(),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mess booking saved for ${_fmtLong(_selected)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Live admin-managed menu from Firestore.
    _menuItems = ref.watch(messMenuStreamProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Mess Booking')),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppTheme.primary.withValues(alpha: 0.06),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Book at least 1 day ahead. Turn a meal off if you don’t need food.',
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                itemCount: _days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final d = _days[i];
                  final sel = _key(d) == _key(_selected);
                  return InkWell(
                    onTap: () => setState(() {
                      _selected = d;
                      _loadForDate();
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 60,
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: sel
                                ? AppTheme.primary
                                : const Color(0xFFD7DDD7)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_weekday(d),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: sel
                                      ? Colors.white70
                                      : Colors.grey.shade600)),
                          const SizedBox(height: 2),
                          Text('${d.day}',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: sel ? Colors.white : Colors.black87)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Text('Meals for ${_fmtLong(_selected)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ...MealType.values.map(_mealCard),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: const Text('Save Bookings'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mealCard(MealType m) {
    final available = _available[m] ?? true;
    return GradientCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Icon(_mealIcon(m), size: 20, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text(m.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              subtitle: Text(available ? 'I want food' : 'Not available — no food'),
              value: available,
              onChanged: (v) => setState(() => _available[m] = v),
            ),
            if (available) ...[
              const SizedBox(height: 4),
              const Text('Main dish',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _menuChips(m),
              const SizedBox(height: 12),
              TextField(
                controller: _extra[m],
                decoration: const InputDecoration(
                  labelText: 'Additional side dish (optional)',
                  hintText: 'e.g. extra curd, papad, sweet…',
                  prefixIcon: Icon(Icons.add_circle_outline),
                  isDense: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _menuChips(MealType m) {
    final items = _menuItems.where((it) => it.meal == m).toList();
    final current = _pref[m]!.text;
    if (items.isEmpty) {
      return Text('No dishes posted for this meal yet.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ...items.map((it) {
          final sel = current == it.name;
          return ChoiceChip(
            label: Text(it.name),
            selected: sel,
            onSelected: (_) =>
                setState(() => _pref[m]!.text = sel ? '' : it.name),
          );
        }),
      ],
    );
  }

  IconData _mealIcon(MealType m) {
    switch (m) {
      case MealType.breakfast:
        return Icons.free_breakfast;
      case MealType.lunch:
        return Icons.lunch_dining;
      case MealType.dinner:
        return Icons.dinner_dining;
    }
  }

  static const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _mo = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  String _weekday(DateTime d) => _wd[d.weekday - 1];
  String _fmtLong(DateTime d) =>
      '${_weekday(d)}, ${d.day} ${_mo[d.month - 1]}';
}
