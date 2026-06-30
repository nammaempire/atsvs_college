# Firebase Setup — ATSVS College App

This guide takes you from nothing to a working Firebase backend (Cloud Firestore +
Firebase Auth) for the app. The app code already includes a Firebase data/auth layer
under `lib/services/` — this guide gets the project created and connected.

> You run these steps on your own machine with your Google account. They can't be
> done for you remotely.

---

## 0. What you'll end up with

- **Cloud Firestore** — the shared database for students, requests, events, mess.
- **Firebase Auth** — phone OTP (families) + email/password (staff).
- A generated `lib/firebase_options.dart` connecting the app to your project.

Auth model (chosen): **admin creates accounts → first login verified by phone OTP →
parent/student then set a password for everyday login**; staff use email + password.
See "Auth flow" at the bottom.

---

## 1. Install the tools (one time)

You need Flutter (already installed), Node.js, and two CLIs.

```bash
# 1. Firebase CLI (needs Node.js installed first: https://nodejs.org)
npm install -g firebase-tools

# 2. Sign in to Firebase with your Google account
firebase login

# 3. FlutterFire CLI
dart pub global activate flutterfire_cli
```

If `flutterfire` isn't found afterwards, add Dart's pub-cache bin to your PATH:
`export PATH="$PATH":"$HOME/.pub-cache/bin"` (add to your shell profile).

---

## 2. Create the Firebase project

1. Go to <https://console.firebase.google.com> → **Add project**.
2. Name it e.g. `atsvs-college` → continue (Google Analytics optional, can skip).
3. Once created, you're in the project dashboard.

---

## 3. Enable the services

In the Firebase console for your project:

**Authentication**
1. Build → **Authentication** → Get started.
2. Sign-in method tab → enable **Phone**.
3. Also enable **Email/Password**.
4. (Phone testing) Under Phone → "Phone numbers for testing", add a test number +
   code so you can log in during development without real SMS.

**Firestore**
1. Build → **Firestore Database** → Create database.
2. Start in **production mode** (we'll add rules in step 6).
3. Choose a region close to you (e.g. `asia-south1` for India). This is permanent.

---

## 4. Connect the app (FlutterFire)

From the project root (`atsvs_outpass_app/`):

```bash
flutterfire configure
```

- Select your `atsvs-college` project.
- Select platforms: Android, iOS (and others if needed).
- This generates **`lib/firebase_options.dart`** and adds the platform config
  (`google-services.json` for Android, `GoogleService-Info.plist` for iOS).

Then fetch packages:

```bash
flutter pub get
```

---

## 5. Initialize Firebase in the app

Once `lib/firebase_options.dart` exists, update `lib/main.dart` so `main()` initializes
Firebase before the app runs:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // (Existing offline store load can stay during migration.)
  await AppState.instance.load();
  runApp(const ProviderScope(child: ATSVSApp()));
}
```

> Until you've run `flutterfire configure`, do **not** add the two imports above —
> the app won't compile without the generated file. That's why the current `main.dart`
> is left untouched.

---

## 6. Deploy the security rules

The repo includes `firebase/firestore.rules`. To use them:

```bash
# from project root, one-time:
firebase init firestore     # pick your project; accept firestore.rules path

# then deploy whenever rules change:
firebase deploy --only firestore:rules
```

Or paste the contents of `firebase/firestore.rules` into the console:
Firestore Database → **Rules** tab → publish.

See `firebase/firestore_schema.md` for the collection design these rules protect.

---

## 7. Seed the first admin + students

Auth accounts are created by an admin, so you need a first admin to bootstrap:

1. In the console → Authentication → Users → **Add user** with an email + password.
   This is your **admin** login.
2. In Firestore, create `users/{thatUid}` with `{ role: "admin" }`
   (copy the UID from the Authentication users list).
3. Now that admin can create student/staff records and accounts (from the web portal
   once it's wired to Firebase, or manually in the console for testing).

---

## Auth flow (hybrid)

**Staff (warden / security / canteen / admin)**
- Admin creates an Auth user (email + password) and a `users/{uid}` doc with their role.
- They log in with email + password.

**Families (parent / student)** — created by admin, verified by OTP, then password:
1. Admin adds the student record in `students/{rollNo}` (incl. studentPhone + parentPhone).
2. **First login:** the parent/student enters their phone → app sends an **OTP** →
   on success their phone is verified and we create their `users/{uid}` doc with the
   role + rollNo (looked up from the matching `students` record).
3. They then **set a password**. Everyday login uses a synthesized email
   (`<phone>@family.atsvs.local`) + that password, so they don't need an email inbox.
   (Helper `AuthService.familyEmail(phone)` builds this.)
4. **Forgot password:** re-verify by OTP, then set a new password.

This keeps SMS cost to first login / resets only, while still requiring the parent
number to match an admin record (the rule you already use).

---

## Migration order (suggested)

The app currently runs fully offline. Migrate one slice at a time so it always works:

1. Do steps 1–6 above; confirm `flutter run` still launches (offline store intact).
2. Switch **reads** to Firestore (students, events, requests) via
   `lib/services/firestore_repository.dart` providers.
3. Switch **writes** (new request, approvals, gate status, mess) to the repository.
4. Replace the demo login with `AuthService` (OTP + password).
5. Move the **web admin portal** to the Firebase JS SDK so admin changes hit the same
   database.
6. Remove the `shared_preferences` store once everything reads/writes Firestore.

When you're ready for any of these, tell me which slice and I'll wire it up.
