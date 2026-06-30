import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Auth wrapper for the hybrid login flow:
/// - Staff: email + password.
/// - Families: phone OTP to verify the number (first login / reset), then a
///   password for everyday login via a synthesized email so no inbox is needed.
///
/// NOTE: this is the integration scaffolding. Test the phone-OTP flow on a real
/// device / test number before relying on it.
class AuthService {
  AuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Everyday login uses this synthesized email for families, so a parent/
  /// student logs in with their phone number + password (no email inbox).
  static String familyEmail(String phone) =>
      '${phone.trim()}@family.atsvs.local';

  // ---- Staff ----
  Future<UserCredential> loginStaff(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> sendStaffPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  // ---- Families: everyday password login ----
  Future<UserCredential> loginFamily(String phone, String password) =>
      _auth.signInWithEmailAndPassword(
          email: familyEmail(phone), password: password);

  /// During first-login (after OTP sign-in), link an email/password credential
  /// to the SAME account, so everyday login works AND the password can later be
  /// reset by re-verifying the phone.
  Future<void> linkFamilyPassword(String phone, String password) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    final cred = EmailAuthProvider.credential(
        email: familyEmail(phone), password: password);
    await user.linkWithCredential(cred);
  }

  /// Forgot-password: after the user re-verifies their phone by OTP (so they're
  /// signed into the same account), set a new password.
  Future<void> updateCurrentPassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    await user.updatePassword(newPassword);
  }

  // ---- Phone OTP (first login / verification) ----

  /// Sends an OTP to [phone] (E.164, e.g. +91XXXXXXXXXX).
  /// [onCodeSent] gives you a verificationId to pass to [verifyOtp].
  Future<void> sendOtp({
    required String phone,
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException e) onError,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: onAutoVerified ?? (_) {},
      verificationFailed: onError,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Confirms the OTP. Signing in proves the user owns the phone number.
  Future<UserCredential> verifyOtp(String verificationId, String smsCode) {
    final credential = PhoneAuthProvider.credential(
        verificationId: verificationId, smsCode: smsCode);
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() => _auth.signOut();
}
