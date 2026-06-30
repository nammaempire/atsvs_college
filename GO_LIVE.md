# ATSVS College — Go-Live Checklist (Blockers)

Do these in order. Steps 1–3 unblock **real SMS login** (the #1 blocker), 4 is the
plan, 5–7 produce a **publishable build**, 8 loads real data, 9 is the final test.

The app display name is already set to **ATSVS College**.

---

## 1. Install a JDK (needed to read the SHA key)

Your machine has no Java. Install one (needs Homebrew):

```bash
brew install --cask temurin
java -version    # should now print a version
```

No Homebrew? Download a JDK from https://adoptium.net and install it.

---

## 2. Add your SHA keys to Firebase (enables real phone OTP)

Phone OTP on real Android devices needs your app's signing fingerprint registered.

**Get the debug SHA (for testing on your phone):**
```bash
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android
```
Copy the **SHA1** and **SHA-256** lines.

**Add them in Firebase:**
1. Console → ⚙️ **Project settings** → scroll to **Your apps** → your Android app.
2. **Add fingerprint** → paste **SHA-1** → save. Repeat for **SHA-256**.
3. Click **google-services.json** → download → replace `android/app/google-services.json`.

> You'll repeat this with the **release** keystore's SHA in step 6.

---

## 3. Turn on Play Integrity + the India SMS region

**Play Integrity** (Android app attestation that powers phone auth):
1. Google Cloud Console → APIs & Services → **Enable APIs** → search **Play Integrity API** → Enable (for the `atsvs-college` project).
2. Firebase phone auth uses it automatically once SHA-256 is added (step 2).

**SMS region** (so OTP can be sent to +91 numbers):
1. Firebase console → **Authentication → Settings** → **SMS region policy**.
2. Set to **Allow** and add **India (IN)** (or allow all). Save.

Now a real `+91` number should receive an SMS OTP. (Keep a test number configured for QA.)

---

## 4. Upgrade to Blaze + enable Storage (only if you want image uploads)

- Image **URLs** already work on the free plan — if that's enough, skip this.
- For **file uploads**: Console → **Build → Storage → Get started** (this prompts the
  **Blaze** upgrade; add a billing card). Then deploy the storage rules:
  ```bash
  firebase deploy --only storage
  ```
- Blaze also removes the Firestore free daily cap — good insurance for 300 users.
  Set a **budget alert** (Billing → Budgets) of e.g. ₹500/month for peace of mind.

---

## 5. Change the package id (Play Store rejects `com.example.*`)

Current id is `com.example.atsvs_outpass_app`. Pick a real one, e.g. `com.atsvs.college`.

Easiest way (Flutter tool):
```bash
dart pub global activate rename
rename setBundleId --targetPlatform android --value "com.atsvs.college"
```
Then **re-register** the app in Firebase with the new id and regenerate config:
```bash
flutterfire configure
```
- Select `atsvs-college`, platform Android, accept overwriting `firebase_options.dart`.
- This creates a new Android app entry — **re-add the SHA keys (step 2) to it** and
  re-download `google-services.json`.

---

## 6. Release signing

1. Create a release keystore (keep it safe — you need it for every future update):
   ```bash
   keytool -genkey -v -keystore ~/atsvs-release.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias atsvs
   ```
2. Create `android/key.properties` (do **not** commit it):
   ```
   storePassword=YOUR_STORE_PASSWORD
   keyPassword=YOUR_KEY_PASSWORD
   keyAlias=atsvs
   storeFile=/Users/jerbo/atsvs-release.jks
   ```
3. Wire it into `android/app/build.gradle.kts` (load the properties and add a
   `release` signingConfig that uses them; replace `signingConfig = signingConfigs.debug`
   in the release buildType). See Flutter's "Sign the app" guide for the exact snippet.
4. Get the **release SHA-1/256** and add them to Firebase (step 2), re-download
   `google-services.json`:
   ```bash
   keytool -list -v -keystore ~/atsvs-release.jks -alias atsvs
   ```
5. Build:
   ```bash
   flutter build appbundle        # .aab for Play Store
   # or: flutter build apk --release   # for direct install / testing
   ```

> An app icon: replace the launcher icons (use the `flutter_launcher_icons` package,
> or swap the `android/app/src/main/res/mipmap-*` images).

---

## 7. Final rules / portal deploy

Make sure everything live is current:
```bash
firebase deploy --only firestore:rules,hosting,storage
```

---

## 8. Real data + cleanup

1. **Delete all test accounts**: Console → Authentication → Users → remove the test
   family/staff entries; in Firestore delete their `users/{uid}` docs.
2. In the **admin portal**: add the real **staff logins** (warden/security/canteen) and
   the **300 students** (each add writes the phone-index needed for login).
3. Post real **events** and the **mess menu**.

> Bulk students: adding 300 by hand is slow. If you have them in a spreadsheet, I can
> write a small one-time import script (CSV → Firestore) for you.

---

## 9. Go-live test checklist (on a real device)

- [ ] Parent first-time setup: real number → real **SMS OTP** → set password → home.
- [ ] Log out / log back in with password. Forgot-password (OTP) works.
- [ ] Student login (own number + parent number) works.
- [ ] Apply leave/outpass → appears in **warden** app live.
- [ ] Warden approves → (leave) admin approves authority in portal → status updates in the
      parent/student app live.
- [ ] Security marks **Went out / Returned** → shows in family app; late return blocks outpass.
- [ ] Canteen shows correct away count.
- [ ] Events with images show correctly.

---

### Still on the "important" list (not strictly blocking, decide before launch)
- Student **mess bookings** still save on-device only (not Firestore) — say the word and
  I'll finish this in code.
- Reads are currently open to any signed-in user (needed because Firestore can't run
  owner-scoped *queries* through `get()` rules). Hardening = **custom claims via a Cloud
  Function** (Blaze). Fine for a controlled launch; plan to add it.
- App doesn't remember the session across restarts (re-login each open) — easy to add.
