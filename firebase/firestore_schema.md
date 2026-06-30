# Firestore Schema — ATSVS College App

Collections mirror the app's existing models (`lib/models/models.dart`), so the JSON
each model already produces (`toJson`) maps straight onto a Firestore document.

## Collections

### `students/{rollNo}`
Document id = roll number. Created/edited by **admin**.
```
name, rollNo, course, year, hostelRoom,
studentPhone, parentName, parentPhone
```
Used as the login gate: a student logs in only if their studentPhone + parentPhone
match a record; a parent logs in if parentPhone matches.

### `users/{uid}`
One per Firebase Auth user. Maps an auth account to a role.
```
role       // "parent" | "student" | "hostelWarden" | "security" | "canteen" | "admin"
rollNo     // for parent/student: which student they belong to (null for staff)
phone      // optional, for families
```

### `events/{eventId}`
Posted by **admin**, readable by everyone signed in.
```
id, title, description, date   // date stored as ISO string
```

### `requests/{requestId}`
Outpass / leave requests.
```
id, studentRoll, type (0=outpass,1=leave), outpassKind (0=spiritual,1=sunday|null),
reason, fromDate, toDate, createdAt,         // ISO strings
raisedBy,                                    // "Parent" | "Student"
wardenStatus, wardenRemark, wardenDecidedAt,
authorityStatus, authorityRemark, authorityDecidedAt,
gateStatus (0=notOut,1=out,2=returned), wentOutAt, returnedAt
```
Queries: by `studentRoll` (family view), by `wardenStatus == 0` (warden queue),
leave + `wardenStatus == 1` + `authorityStatus == 0` (authority queue),
approved + `gateStatus != 2` (security gate).

### `messMenu/{itemId}`
Admin-managed food choices.
```
id, meal (0=breakfast,1=lunch,2=dinner), name
```

### `messBookings/{rollNo}_{date}_{meal}`
One per student / day / meal. Deterministic id keeps it idempotent.
```
studentRoll, dateKey (yyyy-MM-dd), meal, available (bool), preference (string)
```

### `outpassBlocks/{rollNo}`
Late-return penalty.
```
blockedUntil   // ISO string
```

## Notes
- Dates are stored as ISO-8601 strings to reuse the models' existing `toJson`/`fromJson`.
  If you later want range queries on dates, switch these to Firestore `Timestamp`.
- Composite indexes: Firestore will prompt you with a link to auto-create any index a
  query needs (e.g. leave + wardenStatus + authorityStatus). Click it once.
