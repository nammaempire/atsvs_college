import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atsvs_outpass_app/state/app_state.dart';
import 'package:atsvs_outpass_app/models/models.dart';
import 'package:atsvs_outpass_app/theme/theme.dart';
import 'package:atsvs_outpass_app/services/firebase_providers.dart';
import 'package:atsvs_outpass_app/features/auth/first_login_screen.dart';

/// Login with role selection: Parent / Student (family) and the staff roles
/// Hostel Warden / Security / Canteen.
/// - Parent: parent phone must match a college record.
/// - Student: roll no + parent phone must match a record.
/// - Staff: demo login (any password).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController(); // parent phone
  final _studentPhoneCtrl = TextEditingController(); // student's own phone
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  UserRole _role = UserRole.parent;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _studentPhoneCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool get _isFamily => _role.isFamily;

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final app = ref.read(appStateProvider);

    if (!_isFamily) {
      // Staff: Firebase email/password; role comes from their users/{uid} doc.
      final auth = ref.read(authServiceProvider);
      final repo = ref.read(repositoryProvider);
      try {
        final cred = await auth.loginStaff(_userCtrl.text.trim(), _passCtrl.text);
        final doc = await repo.userDoc(cred.user!.uid);
        final staffRole = _staffRoleFromString(doc?['role']);
        if (staffRole == null) {
          await auth.signOut();
          setState(() => _error = 'This account is not a staff account.');
          return;
        }
        app.setStaffSession(staffRole);
      } on FirebaseAuthException catch (e) {
        setState(() => _error = _friendlyError(e));
      } catch (_) {
        setState(() => _error = 'Login failed. Please try again.');
      }
      return;
    }

    // Family: everyday login with phone + password (Firebase).
    final auth = ref.read(authServiceProvider);
    final repo = ref.read(repositoryProvider);
    final phone = _role == UserRole.parent
        ? _phoneCtrl.text.trim()
        : _studentPhoneCtrl.text.trim();
    try {
      final cred = await auth.loginFamily(phone, _passCtrl.text);
      final doc = await repo.userDoc(cred.user!.uid);
      if (doc == null || doc['rollNo'] == null) {
        await auth.signOut();
        setState(() => _error =
            'Account not set up yet. Use “First time? Verify & set password”.');
        return;
      }
      final r =
          doc['role'] == 'student' ? UserRole.student : UserRole.parent;
      final ok = await app.hydrateFromFirebase(
          familyRole: r, rollNo: doc['rollNo']);
      if (!ok) {
        setState(() => _error = 'Your student record was not found.');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyError(e));
    } catch (e) {
      setState(() => _error = 'Login failed. Please try again.');
    }
  }

  UserRole? _staffRoleFromString(dynamic role) {
    switch (role) {
      case 'hostelWarden':
        return UserRole.hostelWarden;
      case 'security':
        return UserRole.security;
      case 'canteen':
        return UserRole.canteen;
      default:
        return null; // family/admin/unknown not allowed on the staff path
    }
  }

  String _friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Wrong number or password. First time? Verify & set your password below.';
      case 'invalid-email':
        return 'Please enter a valid mobile number.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return e.message ?? 'Login failed.';
    }
  }

  void _openFirstLogin({bool isReset = false}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FirstLoginScreen(
        role: _role,
        parentPhone: _phoneCtrl.text.trim(),
        studentPhone: _studentPhoneCtrl.text.trim(),
        isReset: isReset,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.school, color: Colors.white, size: 42),
                  ),
                  const SizedBox(height: 14),
                  const Text('ATSVS College',
                      style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary)),
                  Text('Outpass & Leave Portal',
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  const SizedBox(height: 20),
                  _RolePicker(
                    selected: _role,
                    onChanged: (r) => setState(() {
                      _role = r;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 22),
                  ..._fieldsForRole(),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    _ErrorBox(_error!),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _submit,
                    child: Text('Login as ${_role.label}'),
                  ),
                  if (_isFamily) ...[
                    TextButton(
                      onPressed: _openFirstLogin,
                      child: const Text('First time? Verify & set password'),
                    ),
                    TextButton(
                      onPressed: () => _openFirstLogin(isReset: true),
                      child: const Text('Forgot password?'),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _DemoHint(role: _role),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _fieldsForRole() {
    switch (_role) {
      case UserRole.parent:
        return [
          _phoneField('Phone Number'),
          const SizedBox(height: 14),
          _passwordField(),
        ];
      case UserRole.student:
        return [
          TextFormField(
            controller: _studentPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Your Mobile Number',
              prefixIcon: Icon(Icons.smartphone),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Enter your mobile number'
                : null,
          ),
          const SizedBox(height: 14),
          _phoneField("Parent's Mobile Number"),
          const SizedBox(height: 14),
          _passwordField(),
        ];
      default: // staff
        return [
          TextFormField(
            controller: _userCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Staff Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
          ),
          const SizedBox(height: 14),
          _passwordField(),
        ];
    }
  }

  Widget _phoneField(String label) => TextFormField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.phone_outlined),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Enter the phone number' : null,
      );

  Widget _passwordField() => TextFormField(
        controller: _passCtrl,
        obscureText: _obscure,
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Enter a password' : null,
      );
}

class _RolePicker extends StatelessWidget {
  final UserRole selected;
  final ValueChanged<UserRole> onChanged;
  const _RolePicker({required this.selected, required this.onChanged});

  static const _roles = [
    (UserRole.parent, Icons.escalator_warning),
    (UserRole.student, Icons.person),
    (UserRole.hostelWarden, Icons.apartment),
    (UserRole.security, Icons.security),
    (UserRole.canteen, Icons.restaurant),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _roles.map((r) {
        final isSel = selected == r.$1;
        return InkWell(
          onTap: () => onChanged(r.$1),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isSel ? AppTheme.primary : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isSel ? AppTheme.primary : const Color(0xFFD7DDD7)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(r.$2,
                    size: 17,
                    color: isSel ? Colors.white : Colors.grey.shade700),
                const SizedBox(width: 6),
                Text(r.$1.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSel ? Colors.white : Colors.grey.shade800)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;
  const _ErrorBox(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFC62828), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFFC62828), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _DemoHint extends StatelessWidget {
  final UserRole role;
  const _DemoHint({required this.role});

  @override
  Widget build(BuildContext context) {
    final isFamily = role.isFamily;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4EF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isFamily
            ? 'Use your registered mobile number. First time here? Tap “Verify & set password” to receive an OTP and set your password.'
            : 'Staff login (warden / security / canteen) moves to Firebase accounts soon.',
        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
      ),
    );
  }
}
