import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atsvs_outpass_app/firebase_options.dart';
import 'package:atsvs_outpass_app/state/app_state.dart';
import 'package:atsvs_outpass_app/models/models.dart';
import 'package:atsvs_outpass_app/theme/theme.dart';
import 'package:atsvs_outpass_app/features/auth/login_screen.dart';
import 'package:atsvs_outpass_app/features/home/home_screen.dart';
import 'package:atsvs_outpass_app/features/staff/warden_home_screen.dart';
import 'package:atsvs_outpass_app/features/staff/security_home_screen.dart';
import 'package:atsvs_outpass_app/features/staff/canteen_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Offline store still loads during migration; remove once fully on Firestore.
  await AppState.instance.load();
  runApp(const ProviderScope(child: ATSVSApp()));
}

class ATSVSApp extends StatelessWidget {
  const ATSVSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ATSVS College',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const RootGate(),
    );
  }
}

/// Shows login until someone is authenticated, then routes to the right home
/// screen for their role.
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appStateProvider);
    if (!app.isLoggedIn) return const LoginScreen();
    switch (app.role!) {
      case UserRole.parent:
      case UserRole.student:
        return const HomeScreen();
      case UserRole.hostelWarden:
        return const WardenHomeScreen();
      case UserRole.security:
        return const SecurityHomeScreen();
      case UserRole.canteen:
        return const CanteenHomeScreen();
    }
  }
}
