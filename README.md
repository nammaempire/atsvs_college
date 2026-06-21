# ATSVS College — Outpass & Leave System

A Flutter app (for parents and students) plus a web admin portal for the college.

> This version is **offline / simulated** for demo purposes. The phone app and the
> web portal each store data locally and are **not yet connected** to each other.
> Making them sync live (so the admin and apps share one database in real time)
> requires a shared backend such as **Firebase** — see "Next steps".

## Roles & login

The login screen has a **role picker** with five roles:

Family roles (checked against the college's student records):

- **Parent** — logs in with the registered parent phone number.
- **Student** — logs in with **their own mobile number + the parent's mobile
  number**. Login is **only allowed when both match the college record** (the
  admin stores both numbers); otherwise the student cannot log in. After login the
  student sees their parent's name and number.

Staff roles (demo login — any username & password):

- **Hostel Warden** — approval queue (approves outpass finally, and the first
  stage of leave) plus a read-only list of hostel students. A small app-bar
  button opens a **Higher Authority (demo)** step so leave requests can be fully
  approved during a demo.
- **Security** — sees only **approved** passes and marks each student
  **Went out** / **Returned** at the gate. This status shows in the parent &
  student apps.
- **Canteen** — list of students currently away (approved + went out) with an
  on-campus vs away count for meal planning.

Seeded demo family accounts (any password):

- Arun Kumar — student mobile `9000000001`, parent `9876543210`
- Priya S — student mobile `9000000002`, parent `9876500011`

(Parent logs in with the parent number; student logs in with student mobile +
parent mobile.)

To see the whole flow, log in as a student/parent and raise a request, then log
out and log in as the Hostel Warden to approve, then Security to mark the gate
movement — the result shows back in the family app.

## What the app does

- **Home page** shows college **events** (posted by admin) and the student's requests.
- **Outpass** — students request one of two kinds, both needing **Hostel Warden**
  approval only:
  - **Spiritual** — valid for up to **2 hours 30 minutes** from the start time.
  - **Sunday** — a Sunday only, fixed window **1:30 PM – 6:00 PM**.
  If a student is marked **returned after the deadline** (e.g. after 6:00 PM on a
  Sunday), their **outpass is disabled for 3 weeks** (leave is still allowed).
- **Leave (go home)** — parents (or students) request leave. Needs **Hostel Warden**
  approval **and** a **Higher Authority** approval.
- **Status & timeline** — every request shows its approval progress. Because the
  parent and student share the same on-device data here, an approval shows up for
  both of them.
- **Gate status** — once approved, Security marks the student Went out / Returned,
  which appears in the parent and student views.
- **Timed tracking timeline** — each request shows the exact date & time of every
  step (requested, warden approved, authority approved, went out, returned), so a
  parent can track their child's outpass/leave precisely.
- **Mess booking** — the mess icon in the home app bar opens meal booking. For an
  upcoming day the student can mark each meal (breakfast / lunch / dinner) as
  **not available** (no food), or pick a dish from the **admin-managed mess menu**.
  If they don't pick anything, they get the **regular mess** by default. Bookings
  must be made **at least 1 day in advance**, so only tomorrow onward can be edited.
  The admin maintains the food list in the **Mess Menu** section of the web portal.

## Web admin portal

`admin_portal/index.html` — open it in any browser (login `admin` / `admin`). It
lets the college:

- add / remove **student records** (these control who can log in),
- post **events** (shown on the apps' home page),
- view **outpass & leave requests** with their approval status.

It is a standalone simulation using the browser's local storage, seeded with the
same sample data as the app.

## Run the app

```bash
flutter pub get
flutter run
```

## Project layout

Organized by layer + feature; all internal imports use `package:atsvs_outpass_app/...`.

```
lib/
  main.dart                       app entry (ProviderScope) + role routing
  models/
    models.dart                   Student, CollegeEvent, AppRequest, enums, mess
  state/
    app_state.dart                local store + appStateProvider (Riverpod)
  theme/
    theme.dart                    colors & styling
  features/
    auth/      login_screen.dart
    home/      home_screen.dart         (parent/student dashboard + events)
    requests/  new_request_screen.dart, request_detail_screen.dart
    staff/     warden_home_screen.dart, security_home_screen.dart,
               canteen_home_screen.dart, approvals.dart
    mess/      mess_screen.dart
admin_portal/
  index.html                      standalone web admin portal
```

## Next steps (to make it real)

- Move data to **Firebase** (Firestore + Auth) so the apps and web portal share
  one live database and approvals sync instantly across devices.
- Give the Hostel Warden and Higher Authority their own logins (app or portal).
- Add real **push notifications** on approval (Firebase Cloud Messaging).
# atsvs_college
