import 'package:flutter/material.dart';

/// Shows a "Are you sure you want to logout?" dialog and, if confirmed, runs
/// [onConfirm] (e.g. the logout action). Used by every role's logout button.
Future<void> confirmLogout(
    BuildContext context, Future<void> Function() onConfirm) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Logout'),
        ),
      ],
    ),
  );
  if (ok == true) await onConfirm();
}

/// A card with a green gradient border. Use in place of [Card] for the app's
/// consistent look. Pass [onTap] to make it tappable.
class GradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  const GradientCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF66BB6A), Color(0xFF1B5E20)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.8),
      // Material (not a plain Container) so ListTile/SwitchListTile ripples
      // and tile colors render correctly.
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.5),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? child
            : InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

/// Central place for the app's look & feel.
class AppTheme {
  static const Color primary = Color(0xFF1B5E20); // deep green
  static const Color accent = Color(0xFF2E7D32);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF5F7F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD7DDD7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD7DDD7)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'Approved':
        return const Color(0xFF2E7D32);
      case 'Rejected':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFFEF6C00);
    }
  }
}
