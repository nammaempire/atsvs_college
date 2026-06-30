# Deploy the Admin Portal (Firebase Hosting)

The portal (`admin_portal/index.html`) now logs the admin in with Firebase Auth and
reads/writes the live Firestore database. Do these steps once.

## 1. Get the Web app config

The portal needs a **Web** Firebase config (separate from the Android one).

1. Firebase console → ⚙️ **Project settings** → scroll to **Your apps**.
2. Click the **Web** icon (`</>`) → register an app, e.g. `admin-portal`.
   (You don't need Firebase Hosting checkbox here; we deploy via CLI.)
3. Copy the `firebaseConfig` object it shows (apiKey, authDomain, projectId, etc.).

## 2. Paste it into the portal

Open `admin_portal/index.html`, find the block near the bottom marked
`PASTE YOUR FIREBASE WEB CONFIG HERE`, and replace the placeholder values with the
config from step 1.

## 3. Make sure an admin account exists

The portal only lets in users whose `users/{uid}.role == "admin"`.

1. Console → **Authentication** → make sure **Email/Password** is enabled.
2. Authentication → Users → **Add user** → use the default the portal is pre-filled with:
   - Email: `admin@atsvs.com`
   - Password: `admin123`
3. Copy that user's **UID**.
4. Console → **Firestore Database** → start a collection `users`, document id = that UID,
   with a field `role` = `admin`. (Add it manually this once to bootstrap.)

> The login form is pre-filled with `admin@atsvs.com` / `admin123`, so once this user
> exists you can just click **Login**. Change the password later for production.

## 4. Deploy

From the project root:

```bash
firebase deploy --only hosting
```

(You can also deploy the rules at the same time:
`firebase deploy --only hosting,firestore:rules`.)

When it finishes it prints a **Hosting URL** like
`https://atsvs-college.web.app` — that's your live admin portal.

## 5. Log in

Open the Hosting URL, sign in with the admin email/password from step 3. You'll see
the dashboard, and any student/event/menu you add appears live in the apps (and vice
versa).

---

### Notes
- The Hosting domain (`*.web.app` / `*.firebaseapp.com`) is automatically an authorized
  domain for Firebase Auth, so email/password login works out of the box.
- To test locally before deploying: `firebase serve --only hosting` (or just open the
  file) — email/password login still talks to the real Firebase project.
- Field names in the portal match the app's models exactly (`rollNo`, `studentPhone`,
  `parentPhone`, `description`, `meal`, etc.), so data written here is read correctly by
  the Flutter app once its screens are wired to Firestore.
