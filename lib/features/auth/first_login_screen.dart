import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:atsvs_outpass_app/state/app_state.dart';
import 'package:atsvs_outpass_app/models/models.dart';
import 'package:atsvs_outpass_app/theme/theme.dart';
import 'package:atsvs_outpass_app/services/firebase_providers.dart';

/// First-time family onboarding: verify the phone number by OTP (proving the
/// parent/student owns it and matches a college record), then set a password
/// for everyday login.
class FirstLoginScreen extends ConsumerStatefulWidget {
  final UserRole role; // parent or student
  final String parentPhone;
  final String studentPhone;
  final bool isReset; // true = forgot-password flow
  const FirstLoginScreen({
    super.key,
    required this.role,
    required this.parentPhone,
    required this.studentPhone,
    this.isReset = false,
  });

  @override
  ConsumerState<FirstLoginScreen> createState() => _FirstLoginScreenState();
}

enum _Step { phone, code, password }

class _FirstLoginScreenState extends ConsumerState<FirstLoginScreen> {
  final _parentCtrl = TextEditingController();
  final _studentCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  _Step _step = _Step.phone;
  bool _busy = false;
  String? _error;
  String? _verificationId;
  String? _rollNo;

  bool get _isStudent => widget.role == UserRole.student;

  @override
  void initState() {
    super.initState();
    _parentCtrl.text = widget.parentPhone;
    _studentCtrl.text = widget.studentPhone;
  }

  @override
  void dispose() {
    for (final c in [_parentCtrl, _studentCtrl, _codeCtrl, _passCtrl, _pass2Ctrl]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Phone we verify & use for the everyday login email.
  String get _targetPhone =>
      _isStudent ? _studentCtrl.text.trim() : _parentCtrl.text.trim();

  String _e164(String number) {
    final n = number.replaceAll(RegExp(r'\s|-'), '');
    if (n.startsWith('+')) return n;
    return '+91$n'; // India default
  }

  Future<void> _sendOtp() async {
    if (_targetPhone.isEmpty || (_isStudent && _parentCtrl.text.trim().isEmpty)) {
      setState(() => _error = 'Please enter the mobile number(s).');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final auth = ref.read(authServiceProvider);
    final repo = ref.read(repositoryProvider);
    try {
      // Record gate FIRST (public phone index): both numbers must be registered
      // by the admin before we send an OTP / allow login.
      final parentIdx = await repo.lookupPhone(_parentCtrl.text.trim());
      if (parentIdx == null || parentIdx['kind'] != 'parent') {
        setState(() {
          _busy = false;
          _error =
              'Parent mobile number is not registered by the college. Ask the admin to add it.';
        });
        return;
      }
      if (_isStudent) {
        final studentIdx = await repo.lookupPhone(_studentCtrl.text.trim());
        if (studentIdx == null || studentIdx['kind'] != 'student') {
          setState(() {
            _busy = false;
            _error =
                'Student mobile number is not registered by the college.';
          });
          return;
        }
        if (studentIdx['rollNo'] != parentIdx['rollNo']) {
          setState(() {
            _busy = false;
            _error =
                'Student and parent numbers do not belong to the same student record.';
          });
          return;
        }
        _rollNo = studentIdx['rollNo'];
      } else {
        _rollNo = parentIdx['rollNo'];
      }

      // Numbers verified against records — send the OTP.
      await auth.sendOtp(
        phone: _e164(_targetPhone),
        onCodeSent: (verificationId) {
          setState(() {
            _verificationId = verificationId;
            _step = _Step.code;
            _busy = false;
          });
        },
        onError: (e) {
          setState(() {
            _busy = false;
            _error = e.message ?? 'Could not send OTP.';
          });
        },
      );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_verificationId == null) return;
    setState(() {
      _error = null;
      _busy = true;
    });
    final auth = ref.read(authServiceProvider);
    try {
      await auth.verifyOtp(_verificationId!, _codeCtrl.text.trim());
      // Record already verified before OTP; proceed to set password.
      setState(() {
        _step = _Step.password;
        _busy = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _busy = false;
        _error = e.code == 'invalid-verification-code'
            ? 'Incorrect OTP. Please try again.'
            : (e.message ?? 'Verification failed.');
      });
    }
  }

  Future<void> _finish() async {
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (_passCtrl.text != _pass2Ctrl.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final auth = ref.read(authServiceProvider);
    final repo = ref.read(repositoryProvider);
    final app = ref.read(appStateProvider);
    try {
      if (widget.isReset) {
        // Forgot-password: user is signed in via OTP — just update the password.
        await auth.updateCurrentPassword(_passCtrl.text);
      } else {
        // First-time: link the password to the OTP-verified account.
        await auth.linkFamilyPassword(_targetPhone, _passCtrl.text);
        await repo.setUserMapping(
          auth.currentUser!.uid,
          role: widget.role.name,
          rollNo: _rollNo,
          phone: _targetPhone,
        );
      }
      // Load the family's data and go home (user is signed in either way).
      final doc = await repo.userDoc(auth.currentUser!.uid);
      final role = doc?['role'] == 'student'
          ? UserRole.student
          : (doc?['role'] == 'parent' ? UserRole.parent : widget.role);
      final rollNo = (doc?['rollNo'] as String?) ?? _rollNo;
      if (rollNo != null) {
        await app.hydrateFromFirebase(familyRole: role, rollNo: rollNo);
      }
      if (!mounted) return;
      Navigator.of(context).pop(); // RootGate now shows Home
    } on FirebaseAuthException catch (e) {
      setState(() {
        _busy = false;
        _error = e.code == 'email-already-in-use' ||
                e.code == 'credential-already-in-use' ||
                e.code == 'provider-already-linked'
            ? 'Password already set for this number. Go back and log in (or use Forgot password).'
            : (e.message ?? 'Could not set password.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.isReset ? 'Reset Password' : 'First-time Setup')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _stepHeader(),
              const SizedBox(height: 20),
              if (_step == _Step.phone) ..._phoneStep(),
              if (_step == _Step.code) ..._codeStep(),
              if (_step == _Step.password) ..._passwordStep(),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: Color(0xFFC62828), fontSize: 13)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepHeader() {
    final n = _step == _Step.phone ? 1 : (_step == _Step.code ? 2 : 3);
    return Text('Step $n of 3',
        style: TextStyle(color: Colors.grey.shade600));
  }

  List<Widget> _phoneStep() => [
        Text(
          _isStudent
              ? 'Confirm your mobile number and your parent\'s number. We\'ll send an OTP to your number.'
              : 'Confirm your mobile number. We\'ll send you an OTP to verify it.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        if (_isStudent) ...[
          TextField(
            controller: _studentCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Your Mobile Number',
                prefixIcon: Icon(Icons.smartphone)),
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _parentCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
              labelText: _isStudent ? "Parent's Mobile Number" : 'Mobile Number',
              prefixIcon: const Icon(Icons.phone_outlined)),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _busy ? null : _sendOtp,
          child: _busy
              ? const _Spinner()
              : const Text('Send OTP'),
        ),
      ];

  List<Widget> _codeStep() => [
        Text('Enter the 6-digit code sent to ${_e164(_targetPhone)}.',
            style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 16),
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'OTP Code', prefixIcon: Icon(Icons.sms_outlined)),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _busy ? null : _verifyCode,
          child: _busy ? const _Spinner() : const Text('Verify'),
        ),
        TextButton(
          onPressed: _busy ? null : () => setState(() => _step = _Step.phone),
          child: const Text('Change number'),
        ),
      ];

  List<Widget> _passwordStep() => [
        Text(
            widget.isReset
                ? 'Number verified. Set your new password.'
                : 'Number verified. Set a password for everyday login.',
            style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 16),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          decoration: const InputDecoration(
              labelText: 'New Password (min 6)',
              prefixIcon: Icon(Icons.lock_outline)),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _pass2Ctrl,
          obscureText: true,
          decoration: const InputDecoration(
              labelText: 'Confirm Password',
              prefixIcon: Icon(Icons.lock_outline)),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _busy ? null : _finish,
          child: _busy ? const _Spinner() : const Text('Finish & Login'),
        ),
      ];
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: Colors.white),
      );
}
