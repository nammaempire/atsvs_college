import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:atsvs_outpass_app/models/models.dart';
import 'package:atsvs_outpass_app/services/firestore_repository.dart';

/// Riverpod provider exposing the app's state store. Widgets use
/// `ref.watch(appStateProvider)` to rebuild on change and
/// `ref.read(appStateProvider)` to call actions.
final appStateProvider =
    ChangeNotifierProvider<AppState>((ref) => AppState.instance);

/// Single in-memory store for the whole app, persisted locally with
/// SharedPreferences so the demo survives restarts. No internet required.
///
/// In this offline/simulated build the parent app, student app and the
/// (separate) web admin portal are not truly connected — instead both roles
/// share this one on-device store, so a warden approval shows up for both
/// the parent and student views.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  static const _kRecords = 'adminRecords';
  static const _kEvents = 'events';
  static const _kRequests = 'requests';
  static const _kRole = 'role';
  static const _kActiveRoll = 'activeRoll';
  static const _kBlocks = 'outpassBlocks';
  static const _kMeals = 'mealBookings';
  static const _kMenu = 'messMenu';
  static const _kSeeded = 'seeded_v4';

  /// Number of weeks an outpass is disabled after a late return.
  static const blockWeeks = 3;

  SharedPreferences? _prefs;

  // Session
  UserRole? role;
  String? activeRoll; // roll no of the logged-in student

  // Data
  final List<Student> records = []; // admin-managed student records (gate)
  final List<CollegeEvent> events = [];
  final List<AppRequest> requests = [];

  /// rollNo -> date until which outpass is blocked (late-return penalty).
  final Map<String, DateTime> outpassBlockedUntil = {};

  /// Mess meal bookings (availability + customization).
  final List<MealBooking> mealBookings = [];

  /// Admin-managed mess menu (food choices shown to students).
  final List<MessMenuItem> messMenu = [];

  bool get isLoggedIn {
    if (role == null) return false;
    if (role!.isFamily) return activeRoll != null;
    return true; // staff roles don't need a linked student
  }

  Student? get activeStudent {
    if (activeRoll == null) return null;
    for (final s in records) {
      if (s.rollNo == activeRoll) return s;
    }
    return null;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();

    if (!(_prefs!.getBool(_kSeeded) ?? false)) {
      _seed();
      await _persist();
      await _prefs!.setBool(_kSeeded, true);
    }

    _readList(_kRecords, records, (j) => Student.fromJson(j));
    _readList(_kEvents, events, (j) => CollegeEvent.fromJson(j));
    _readList(_kRequests, requests, (j) => AppRequest.fromJson(j));

    final blocksRaw = _prefs!.getString(_kBlocks);
    outpassBlockedUntil.clear();
    if (blocksRaw != null) {
      (jsonDecode(blocksRaw) as Map<String, dynamic>).forEach((k, v) {
        outpassBlockedUntil[k] = DateTime.parse(v);
      });
    }

    _readList(_kMeals, mealBookings, (j) => MealBooking.fromJson(j));
    _readList(_kMenu, messMenu, (j) => MessMenuItem.fromJson(j));

    final roleStr = _prefs!.getString(_kRole);
    role = roleStr == null
        ? null
        : UserRole.values.firstWhere((e) => e.name == roleStr,
            orElse: () => UserRole.parent);
    activeRoll = _prefs!.getString(_kActiveRoll);

    notifyListeners();
  }

  void _readList<T>(
    String key,
    List<T> target,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = _prefs!.getString(key);
    if (raw == null) return;
    final list =
        (jsonDecode(raw) as List).map((e) => fromJson(e)).toList();
    target
      ..clear()
      ..addAll(list);
  }

  void _seed() {
    records.addAll(const [
      Student(
        name: 'Arun Kumar',
        rollNo: '21CS001',
        course: 'B.E. Computer Science',
        year: '2nd Year',
        hostelRoom: 'H1 - 204',
        studentPhone: '9000000001',
        parentName: 'Ramesh Kumar',
        parentPhone: '9876543210',
      ),
      Student(
        name: 'Priya S',
        rollNo: '21EC015',
        course: 'B.E. Electronics',
        year: '1st Year',
        hostelRoom: 'G2 - 110',
        studentPhone: '9000000002',
        parentName: 'Lakshmi S',
        parentPhone: '9876500011',
      ),
    ]);
    final now = DateTime.now();
    events.addAll([
      CollegeEvent(
        id: 'e1',
        title: 'College Annual Day',
        description:
            'Cultural programmes and prize distribution in the main auditorium. Parents are welcome.',
        date: DateTime(now.year, now.month, now.day + 5),
      ),
      CollegeEvent(
        id: 'e2',
        title: 'Semester Exams Begin',
        description:
            'End-semester examinations start. Hall tickets to be collected from the office.',
        date: DateTime(now.year, now.month, now.day + 12),
      ),
      CollegeEvent(
        id: 'e3',
        title: 'Hostel Maintenance Day',
        description:
            'Water supply will be interrupted from 10 AM to 2 PM for tank cleaning.',
        date: DateTime(now.year, now.month, now.day + 2),
      ),
    ]);
    messMenu.addAll(const [
      MessMenuItem(id: 'm1', meal: MealType.breakfast, name: 'Idli & Sambar'),
      MessMenuItem(id: 'm2', meal: MealType.breakfast, name: 'Pongal'),
      MessMenuItem(id: 'm3', meal: MealType.breakfast, name: 'Dosa & Chutney'),
      MessMenuItem(id: 'm4', meal: MealType.lunch, name: 'Veg Meals'),
      MessMenuItem(id: 'm5', meal: MealType.lunch, name: 'Curd Rice'),
      MessMenuItem(id: 'm6', meal: MealType.lunch, name: 'Chapati & Channa'),
      MessMenuItem(id: 'm7', meal: MealType.dinner, name: 'Chapati & Kurma'),
      MessMenuItem(id: 'm8', meal: MealType.dinner, name: 'Veg Fried Rice'),
      MessMenuItem(id: 'm9', meal: MealType.dinner, name: 'Veg Meals'),
    ]);
  }

  Future<void> _persist() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(
        _kRecords, jsonEncode(records.map((e) => e.toJson()).toList()));
    await p.setString(
        _kEvents, jsonEncode(events.map((e) => e.toJson()).toList()));
    await p.setString(
        _kRequests, jsonEncode(requests.map((e) => e.toJson()).toList()));
    await p.setString(
        _kBlocks,
        jsonEncode(outpassBlockedUntil
            .map((k, v) => MapEntry(k, v.toIso8601String()))));
    await p.setString(
        _kMeals, jsonEncode(mealBookings.map((e) => e.toJson()).toList()));
    await p.setString(
        _kMenu, jsonEncode(messMenu.map((e) => e.toJson()).toList()));
    if (role != null) {
      await p.setString(_kRole, role!.name);
    } else {
      await p.remove(_kRole);
    }
    if (activeRoll != null) {
      await p.setString(_kActiveRoll, activeRoll!);
    } else {
      await p.remove(_kActiveRoll);
    }
  }

  // --- Auth ---

  /// Parent login: looks up a record by parent phone. Returns the student
  /// name on success, or null if no record exists for that number.
  Future<String?> loginParent(String parentPhone) async {
    final match = records.where((s) => s.parentPhone == parentPhone.trim());
    if (match.isEmpty) return null;
    role = UserRole.parent;
    activeRoll = match.first.rollNo;
    await _persist();
    notifyListeners();
    return match.first.name;
  }

  /// Student login: allowed only if a record matches BOTH the student's own
  /// mobile number and the parent's mobile number.
  Future<bool> loginStudent(String studentPhone, String parentPhone) async {
    final match = records.where((s) =>
        s.studentPhone == studentPhone.trim() &&
        s.parentPhone == parentPhone.trim());
    if (match.isEmpty) return false;
    role = UserRole.student;
    activeRoll = match.first.rollNo;
    await _persist();
    notifyListeners();
    return true;
  }

  /// Loads a family user's real data from Firestore after they sign in with
  /// Firebase, and sets the session. The existing screens read this store, so
  /// they keep working — now backed by live data.
  Future<bool> hydrateFromFirebase({
    required UserRole familyRole,
    required String rollNo,
  }) async {
    const repo = FirestoreRepository();
    final student = await repo.studentByRoll(rollNo);
    if (student == null) return false;

    final fetchedRequests = await repo.fetchRequestsForRoll(rollNo);
    final fetchedMenu = await repo.fetchMessMenu();
    final fetchedBookings = await repo.fetchMealBookings(rollNo);
    final block = await repo.blockedUntil(rollNo);

    records
      ..clear()
      ..add(student);
    requests
      ..clear()
      ..addAll(fetchedRequests);
    messMenu
      ..clear()
      ..addAll(fetchedMenu);
    mealBookings
      ..clear()
      ..addAll(fetchedBookings);
    outpassBlockedUntil.clear();
    if (block != null) outpassBlockedUntil[rollNo] = block;

    role = familyRole;
    activeRoll = rollNo;
    notifyListeners();
    return true;
  }

  /// Staff session after a Firebase email/password login (role comes from the
  /// user's users/{uid} doc). Staff read/write Firestore directly via providers.
  void setStaffSession(UserRole staffRole) {
    role = staffRole;
    activeRoll = null;
    notifyListeners();
  }

  /// Staff login (hostel warden / security / canteen). Demo: no gating.
  Future<void> loginStaff(UserRole staffRole) async {
    role = staffRole;
    activeRoll = null;
    await _persist();
    notifyListeners();
  }

  Future<void> logout() async {
    role = null;
    activeRoll = null;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    await _persist();
    notifyListeners();
  }

  Student? studentByRoll(String roll) {
    for (final s in records) {
      if (s.rollNo == roll) return s;
    }
    return null;
  }

  // --- Requests ---

  List<AppRequest> get activeStudentRequests {
    final list =
        requests.where((r) => r.studentRoll == activeRoll).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> addRequest(AppRequest r) async {
    requests.add(r);
    await _persist();
    notifyListeners();
  }

  Future<void> setWardenDecision(
      String id, RequestStatus status, String? remark) async {
    final r = requests.firstWhere((e) => e.id == id);
    r.wardenStatus = status;
    r.wardenRemark = remark;
    r.wardenDecidedAt = DateTime.now();
    await _persist();
    notifyListeners();
  }

  Future<void> setAuthorityDecision(
      String id, RequestStatus status, String? remark) async {
    final r = requests.firstWhere((e) => e.id == id);
    r.authorityStatus = status;
    r.authorityRemark = remark;
    r.authorityDecidedAt = DateTime.now();
    await _persist();
    notifyListeners();
  }

  // Requests pending the hostel warden (all types, warden not yet decided).
  List<AppRequest> get pendingWarden => requests
      .where((r) => r.wardenStatus == RequestStatus.pending)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // Leave requests warden-approved but awaiting higher authority.
  List<AppRequest> get pendingAuthority => requests
      .where((r) =>
          r.type == RequestType.leave &&
          r.wardenStatus == RequestStatus.approved &&
          r.authorityStatus == RequestStatus.pending)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // --- Security (gate) ---

  /// Returns true if marking this status triggered a late-return penalty.
  Future<bool> setGateStatus(String id, GateStatus status) async {
    final r = requests.firstWhere((e) => e.id == id);
    r.gateStatus = status;
    if (status == GateStatus.out) r.wentOutAt = DateTime.now();
    bool penalised = false;
    if (status == GateStatus.returned) {
      r.returnedAt = DateTime.now();
      // Late return on an outpass disables outpass for `blockWeeks` weeks.
      if (r.isLateReturn) {
        outpassBlockedUntil[r.studentRoll] =
            r.returnedAt!.add(const Duration(days: blockWeeks * 7));
        penalised = true;
      }
    }
    await _persist();
    notifyListeners();
    return penalised;
  }

  // --- Outpass penalty helpers ---

  bool isOutpassBlocked(String roll) {
    final until = outpassBlockedUntil[roll];
    return until != null && until.isAfter(DateTime.now());
  }

  DateTime? blockedUntil(String roll) {
    final until = outpassBlockedUntil[roll];
    return (until != null && until.isAfter(DateTime.now())) ? until : null;
  }

  /// Approved requests the gate cares about (not yet returned), newest first.
  List<AppRequest> get gateApprovedRequests => requests
      .where((r) =>
          r.overallStatus == RequestStatus.approved &&
          r.gateStatus != GateStatus.returned)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // --- Canteen ---

  /// Students currently away (approved + went out, not returned).
  List<AppRequest> get awayRequests =>
      requests.where((r) => r.isAway).toList()
        ..sort((a, b) => a.toDate.compareTo(b.toDate));

  // --- Mess (meal bookings) ---

  MealBooking? mealBookingFor(String roll, String dateKey, MealType meal) {
    for (final b in mealBookings) {
      if (b.studentRoll == roll && b.dateKey == dateKey && b.meal == meal) {
        return b;
      }
    }
    return null;
  }

  Future<void> saveMealBooking(MealBooking booking) async {
    mealBookings.removeWhere((b) =>
        b.studentRoll == booking.studentRoll &&
        b.dateKey == booking.dateKey &&
        b.meal == booking.meal);
    mealBookings.add(booking);
    await _persist();
    notifyListeners();
  }

  /// Admin-defined food choices for a meal.
  List<MessMenuItem> menuFor(MealType meal) =>
      messMenu.where((m) => m.meal == meal).toList();

  Future<void> addMenuItem(MealType meal, String name) async {
    messMenu.add(MessMenuItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      meal: meal,
      name: name,
    ));
    await _persist();
    notifyListeners();
  }

  Future<void> removeMenuItem(String id) async {
    messMenu.removeWhere((m) => m.id == id);
    await _persist();
    notifyListeners();
  }

  // --- Events (used by admin demo / portal parity) ---

  Future<void> addEvent(CollegeEvent e) async {
    events.add(e);
    await _persist();
    notifyListeners();
  }

  List<CollegeEvent> get eventsByDate {
    final list = [...events]..sort((a, b) {
        final ad = a.date, bd = b.date;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1; // undated last
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    return list;
  }
}
