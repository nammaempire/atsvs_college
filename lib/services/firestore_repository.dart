import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:atsvs_outpass_app/models/models.dart';
import 'package:atsvs_outpass_app/services/firestore_refs.dart';

/// Firestore-backed data layer. Method names mirror the current `AppState`
/// so the screens can be migrated with minimal change: reads become streams,
/// writes become Futures. Documents reuse the models' `toJson`/`fromJson`.
class FirestoreRepository {
  const FirestoreRepository();

  // ---------- Students ----------

  Stream<List<Student>> watchStudents() => Collections.students
      .snapshots()
      .map((s) => s.docs.map((d) => Student.fromJson(d.data())).toList());

  Future<Student?> studentByRoll(String roll) async {
    final doc = await Collections.students.doc(roll).get();
    return doc.exists ? Student.fromJson(doc.data()!) : null;
  }

  Future<void> upsertStudent(Student s) =>
      Collections.students.doc(s.rollNo).set(s.toJson());

  Future<void> deleteStudent(String roll) =>
      Collections.students.doc(roll).delete();

  /// Public lookup: returns {rollNo, kind: 'parent'|'student'} for a number,
  /// or null if it isn't registered. Used to gate login before sign-in.
  Future<Map<String, dynamic>?> lookupPhone(String phone) async {
    final d = await Collections.phoneIndex.doc(phone.trim()).get();
    return d.exists ? d.data() : null;
  }

  /// Login gate: a record matching student's own phone + parent phone.
  Future<Student?> findForStudentLogin(
      String studentPhone, String parentPhone) async {
    final q = await Collections.students
        .where('studentPhone', isEqualTo: studentPhone.trim())
        .where('parentPhone', isEqualTo: parentPhone.trim())
        .limit(1)
        .get();
    return q.docs.isEmpty ? null : Student.fromJson(q.docs.first.data());
  }

  Future<Student?> findForParentLogin(String parentPhone) async {
    final q = await Collections.students
        .where('parentPhone', isEqualTo: parentPhone.trim())
        .limit(1)
        .get();
    return q.docs.isEmpty ? null : Student.fromJson(q.docs.first.data());
  }

  // ---------- Users / roles ----------

  /// The signed-in user's role mapping ({role, rollNo, phone}), or null.
  Future<Map<String, dynamic>?> userDoc(String uid) async {
    final doc = await Collections.users.doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  /// Created on first login (or by admin) to map an auth uid to a role.
  Future<void> setUserMapping(
    String uid, {
    required String role,
    String? rollNo,
    String? phone,
  }) =>
      Collections.users.doc(uid).set({
        'role': role,
        if (rollNo != null) 'rollNo': rollNo,
        if (phone != null) 'phone': phone,
      });

  // ---------- Events ----------

  Stream<List<CollegeEvent>> watchEvents() => Collections.events
      .orderBy('date')
      .snapshots()
      .map((s) => s.docs.map((d) => CollegeEvent.fromJson(d.data())).toList());

  Future<void> addEvent(CollegeEvent e) =>
      Collections.events.doc(e.id).set(e.toJson());

  Future<void> deleteEvent(String id) => Collections.events.doc(id).delete();

  // ---------- Requests ----------

  Stream<List<AppRequest>> watchRequestsForRoll(String roll) =>
      Collections.requests
          .where('studentRoll', isEqualTo: roll)
          .snapshots()
          .map(_mapRequests);

  Stream<List<AppRequest>> watchPendingWarden() => Collections.requests
      .where('wardenStatus', isEqualTo: RequestStatus.pending.index)
      .snapshots()
      .map(_mapRequests);

  Stream<List<AppRequest>> watchPendingAuthority() => Collections.requests
      .where('type', isEqualTo: RequestType.leave.index)
      .where('wardenStatus', isEqualTo: RequestStatus.approved.index)
      .where('authorityStatus', isEqualTo: RequestStatus.pending.index)
      .snapshots()
      .map(_mapRequests);

  /// Approved passes the gate cares about (not yet returned). Overall-approval
  /// is computed in Dart since it depends on multiple fields.
  Stream<List<AppRequest>> watchGateApproved() => Collections.requests
      .where('gateStatus', isNotEqualTo: GateStatus.returned.index)
      .snapshots()
      .map((s) => _mapRequests(s)
          .where((r) => r.overallStatus == RequestStatus.approved)
          .toList());

  /// Students currently away (approved + went out).
  Stream<List<AppRequest>> watchAway() => Collections.requests
      .where('gateStatus', isEqualTo: GateStatus.out.index)
      .snapshots()
      .map((s) => _mapRequests(s).where((r) => r.isAway).toList());

  Future<void> addRequest(AppRequest r) =>
      Collections.requests.doc(r.id).set(r.toJson());

  /// Live single request (for the detail/tracking screen).
  Stream<AppRequest?> watchRequest(String id) =>
      Collections.requests.doc(id).snapshots().map(
          (d) => d.exists ? AppRequest.fromJson(d.data()!) : null);

  Future<void> setWardenDecision(
          String id, RequestStatus status, String? remark) =>
      Collections.requests.doc(id).update({
        'wardenStatus': status.index,
        'wardenRemark': remark,
        'wardenDecidedAt': DateTime.now().toIso8601String(),
      });

  Future<void> setAuthorityDecision(
          String id, RequestStatus status, String? remark) =>
      Collections.requests.doc(id).update({
        'authorityStatus': status.index,
        'authorityRemark': remark,
        'authorityDecidedAt': DateTime.now().toIso8601String(),
      });

  /// Set gate status. Returns true if a late-return penalty was applied.
  Future<bool> setGateStatus(AppRequest r, GateStatus status) async {
    final now = DateTime.now();
    final updates = <String, dynamic>{'gateStatus': status.index};
    if (status == GateStatus.out) {
      updates['wentOutAt'] = now.toIso8601String();
    }
    var penalised = false;
    if (status == GateStatus.returned) {
      updates['returnedAt'] = now.toIso8601String();
      if (r.type == RequestType.outpass && now.isAfter(r.toDate)) {
        await setOutpassBlock(
            r.studentRoll, now.add(const Duration(days: 21)));
        penalised = true;
      }
    }
    await Collections.requests.doc(r.id).update(updates);
    return penalised;
  }

  // ---------- Mess ----------

  Stream<List<MessMenuItem>> watchMessMenu() => Collections.messMenu
      .snapshots()
      .map((s) => s.docs.map((d) => MessMenuItem.fromJson(d.data())).toList());

  Future<void> addMenuItem(MessMenuItem item) =>
      Collections.messMenu.doc(item.id).set(item.toJson());

  Future<void> removeMenuItem(String id) =>
      Collections.messMenu.doc(id).delete();

  // ---------- Side dishes (admin list) ----------

  Stream<List<SideDish>> watchSideDishes() => Collections.sideDishes
      .snapshots()
      .map((s) => s.docs.map((d) => SideDish.fromJson(d.data())).toList());

  Future<void> addSideDish(SideDish d) =>
      Collections.sideDishes.doc(d.id).set(d.toJson());

  Future<void> removeSideDish(String id) =>
      Collections.sideDishes.doc(id).delete();

  String mealDocId(String roll, String dateKey, MealType meal) =>
      '${roll}_${dateKey}_${meal.index}';

  Future<MealBooking?> mealBookingFor(
      String roll, String dateKey, MealType meal) async {
    final doc =
        await Collections.messBookings.doc(mealDocId(roll, dateKey, meal)).get();
    return doc.exists ? MealBooking.fromJson(doc.data()!) : null;
  }

  Future<void> saveMealBooking(MealBooking b) => Collections.messBookings
      .doc(mealDocId(b.studentRoll, b.dateKey, b.meal))
      .set(b.toJson());

  /// All mess bookings (canteen view of side-dish requests etc.).
  Stream<List<MealBooking>> watchMessBookings() => Collections.messBookings
      .snapshots()
      .map((s) => s.docs.map((d) => MealBooking.fromJson(d.data())).toList());

  // ---------- Outpass blocks ----------

  Future<DateTime?> blockedUntil(String roll) async {
    final doc = await Collections.outpassBlocks.doc(roll).get();
    if (!doc.exists) return null;
    final until = DateTime.tryParse(doc.data()!['blockedUntil'] ?? '');
    return (until != null && until.isAfter(DateTime.now())) ? until : null;
  }

  Future<void> setOutpassBlock(String roll, DateTime until) => Collections
      .outpassBlocks
      .doc(roll)
      .set({'blockedUntil': until.toIso8601String()});

  // ---------- helpers ----------

  // ---------- One-shot fetchers (used to hydrate the app on login) ----------

  Future<List<AppRequest>> fetchRequestsForRoll(String roll) async {
    final q = await Collections.requests
        .where('studentRoll', isEqualTo: roll)
        .get();
    return _mapRequests(q);
  }

  Future<List<CollegeEvent>> fetchEvents() async {
    final q = await Collections.events.get();
    return q.docs.map((d) => CollegeEvent.fromJson(d.data())).toList();
  }

  Future<List<MessMenuItem>> fetchMessMenu() async {
    final q = await Collections.messMenu.get();
    return q.docs.map((d) => MessMenuItem.fromJson(d.data())).toList();
  }

  Future<List<MealBooking>> fetchMealBookings(String roll) async {
    final q = await Collections.messBookings
        .where('studentRoll', isEqualTo: roll)
        .get();
    return q.docs.map((d) => MealBooking.fromJson(d.data())).toList();
  }

  List<AppRequest> _mapRequests(QuerySnapshot<Map<String, dynamic>> s) {
    final list = s.docs.map((d) => AppRequest.fromJson(d.data())).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}
