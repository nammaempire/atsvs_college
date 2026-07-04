import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atsvs_outpass_app/models/models.dart';
import 'package:atsvs_outpass_app/services/auth_service.dart';
import 'package:atsvs_outpass_app/services/firestore_repository.dart';

/// Riverpod providers for the Firebase layer. Screens will switch from the
/// offline `appStateProvider` to these once Firebase is initialized.

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final repositoryProvider =
    Provider<FirestoreRepository>((ref) => const FirestoreRepository());

/// Current Firebase auth state.
final authStateProvider = StreamProvider<User?>(
    (ref) => ref.watch(authServiceProvider).authStateChanges());

/// Role mapping ({role, rollNo, phone}) for the signed-in user.
final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref.watch(repositoryProvider).userDoc(user.uid);
});

// ----- Example data streams (use these when migrating screens) -----

final eventsStreamProvider = StreamProvider<List<CollegeEvent>>(
    (ref) => ref.watch(repositoryProvider).watchEvents());

/// All students (staff views: warden hostel list, canteen, name lookups).
final studentsStreamProvider = StreamProvider<List<Student>>(
    (ref) => ref.watch(repositoryProvider).watchStudents());

final messMenuStreamProvider = StreamProvider<List<MessMenuItem>>(
    (ref) => ref.watch(repositoryProvider).watchMessMenu());

/// All mess bookings (canteen: side-dish requests + meal planning).
final messBookingsStreamProvider = StreamProvider<List<MealBooking>>(
    (ref) => ref.watch(repositoryProvider).watchMessBookings());

/// Admin-managed side-dish list.
final sideDishesStreamProvider = StreamProvider<List<SideDish>>(
    (ref) => ref.watch(repositoryProvider).watchSideDishes());

/// Requests for a specific student (the family view).
final requestsForRollProvider =
    StreamProvider.family<List<AppRequest>, String>(
        (ref, roll) => ref.watch(repositoryProvider).watchRequestsForRoll(roll));

/// A single request, live (used by the tracking/detail screen).
final requestStreamProvider = StreamProvider.family<AppRequest?, String>(
    (ref, id) => ref.watch(repositoryProvider).watchRequest(id));

/// Warden approval queue.
final pendingWardenProvider = StreamProvider<List<AppRequest>>(
    (ref) => ref.watch(repositoryProvider).watchPendingWarden());

/// Higher-authority queue (leave, warden-approved).
final pendingAuthorityProvider = StreamProvider<List<AppRequest>>(
    (ref) => ref.watch(repositoryProvider).watchPendingAuthority());

/// Security gate list (approved, not yet returned).
final gateApprovedProvider = StreamProvider<List<AppRequest>>(
    (ref) => ref.watch(repositoryProvider).watchGateApproved());

/// Canteen: students currently away.
final awayProvider = StreamProvider<List<AppRequest>>(
    (ref) => ref.watch(repositoryProvider).watchAway());
