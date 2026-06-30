// Data models for the ATSVS College app (parent + student + staff demo).

/// A student record. In the real system these are created by the college admin
/// in the web portal; here they are seeded locally. A student can only log in
/// if a matching record (roll no + parent phone) exists.
class Student {
  final String name;
  final String rollNo;
  final String course;
  final String year;
  final String hostelRoom;
  final String studentPhone; // student's own mobile (used for student login)
  final String parentName;
  final String parentPhone;

  const Student({
    required this.name,
    required this.rollNo,
    required this.course,
    required this.year,
    required this.hostelRoom,
    required this.studentPhone,
    required this.parentName,
    required this.parentPhone,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'rollNo': rollNo,
        'course': course,
        'year': year,
        'hostelRoom': hostelRoom,
        'studentPhone': studentPhone,
        'parentName': parentName,
        'parentPhone': parentPhone,
      };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        name: json['name'] ?? '',
        rollNo: json['rollNo'] ?? '',
        course: json['course'] ?? '',
        year: json['year'] ?? '',
        hostelRoom: json['hostelRoom'] ?? '',
        studentPhone: json['studentPhone'] ?? '',
        parentName: json['parentName'] ?? '',
        parentPhone: json['parentPhone'] ?? '',
      );
}

/// Who is logged in. parent/student are "family" roles tied to a student
/// record; the rest are college staff roles.
enum UserRole { parent, student, hostelWarden, security, canteen }

extension UserRoleInfo on UserRole {
  bool get isFamily => this == UserRole.parent || this == UserRole.student;

  String get label {
    switch (this) {
      case UserRole.parent:
        return 'Parent';
      case UserRole.student:
        return 'Student';
      case UserRole.hostelWarden:
        return 'Hostel Warden';
      case UserRole.security:
        return 'Security';
      case UserRole.canteen:
        return 'Canteen';
    }
  }
}

/// Mess meals.
enum MealType { breakfast, lunch, dinner }

extension MealTypeInfo on MealType {
  String get label {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
    }
  }
}

/// A food item on the mess menu, added by the college admin. Shown as a
/// customization choice for the matching meal.
class MessMenuItem {
  final String id;
  final MealType meal;
  final String name;

  const MessMenuItem({
    required this.id,
    required this.meal,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'meal': meal.index,
        'name': name,
      };

  factory MessMenuItem.fromJson(Map<String, dynamic> json) => MessMenuItem(
        id: json['id'],
        meal: MealType.values[json['meal'] ?? 0],
        name: json['name'] ?? '',
      );
}

/// A student's mess booking for one meal on one day.
/// [available] false means "no food needed" for that meal.
/// [preference] holds the food customization (e.g. "Less spicy", "No onion").
class MealBooking {
  final String studentRoll;
  final String dateKey; // yyyy-MM-dd
  final MealType meal;
  bool available;
  String preference;
  String extra; // free-text extra side dish the student requests

  MealBooking({
    required this.studentRoll,
    required this.dateKey,
    required this.meal,
    this.available = true,
    this.preference = '',
    this.extra = '',
  });

  Map<String, dynamic> toJson() => {
        'studentRoll': studentRoll,
        'dateKey': dateKey,
        'meal': meal.index,
        'available': available,
        'preference': preference,
        'extra': extra,
      };

  factory MealBooking.fromJson(Map<String, dynamic> json) => MealBooking(
        studentRoll: json['studentRoll'] ?? '',
        dateKey: json['dateKey'] ?? '',
        meal: MealType.values[json['meal'] ?? 0],
        available: json['available'] ?? true,
        preference: json['preference'] ?? '',
        extra: json['extra'] ?? '',
      );
}

/// Gate movement of a student for an approved request (set by Security).
enum GateStatus { notOut, out, returned }

extension GateStatusLabel on GateStatus {
  String get label {
    switch (this) {
      case GateStatus.notOut:
        return 'Not gone out';
      case GateStatus.out:
        return 'Went out';
      case GateStatus.returned:
        return 'Returned';
    }
  }
}

/// An event posted by the college admin, visible to everyone on the home page.
class CollegeEvent {
  final String id;
  final String title;
  final String description;
  final DateTime? date; // optional
  final List<String> imageUrls; // optional, up to 5

  const CollegeEvent({
    required this.id,
    this.title = '',
    this.description = '',
    this.date,
    this.imageUrls = const [],
  });

  String get firstImage => imageUrls.isNotEmpty ? imageUrls.first : '';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'date': date?.toIso8601String() ?? '',
        'imageUrls': imageUrls,
      };

  factory CollegeEvent.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    // Accept new list field, or fall back to the old single imageUrl.
    List<String> imgs;
    if (json['imageUrls'] is List) {
      imgs = List<String>.from(json['imageUrls']).where((u) => u.isNotEmpty).toList();
    } else if ((json['imageUrl'] ?? '') != '') {
      imgs = [json['imageUrl']];
    } else {
      imgs = const [];
    }
    return CollegeEvent(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      date: (rawDate == null || rawDate == '')
          ? null
          : DateTime.tryParse(rawDate),
      imageUrls: imgs,
    );
  }
}

/// Two kinds of requests with different approval chains:
/// - outpass (spiritual or Sunday): hostel warden approves only.
/// - leave (go home): hostel warden AND a higher authority must approve.
enum RequestType { outpass, leave }

extension RequestTypeLabel on RequestType {
  String get label => this == RequestType.outpass ? 'Outpass' : 'Leave';
}

/// Two kinds of outpass with different time rules:
/// - spiritual: maximum 2 hours 30 minutes.
/// - sunday: fixed Sunday window, 1:30 PM to 6:00 PM.
enum OutpassKind { spiritual, sunday }

extension OutpassKindInfo on OutpassKind {
  String get label =>
      this == OutpassKind.spiritual ? 'Spiritual' : 'Sunday';

  /// Maximum duration allowed for a spiritual outpass.
  static const spiritualMaxMinutes = 150; // 2h 30m

  /// Sunday window start/end (24h).
  static const sundayStartHour = 13, sundayStartMinute = 30; // 1:30 PM
  static const sundayEndHour = 18, sundayEndMinute = 0; // 6:00 PM
}

/// Status of a single approval stage (or overall).
enum RequestStatus { pending, approved, rejected }

extension RequestStatusLabel on RequestStatus {
  String get label {
    switch (this) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.approved:
        return 'Approved';
      case RequestStatus.rejected:
        return 'Rejected';
    }
  }
}

/// A request raised by a parent or student.
class AppRequest {
  final String id;
  final String studentRoll; // which student this is for
  final RequestType type;
  final String reason;
  final DateTime fromDate; // includes start time for outpass
  final DateTime toDate; // includes end time for outpass
  final DateTime createdAt;
  final String raisedBy; // 'Parent' or 'Student'
  final OutpassKind? outpassKind; // only for outpass requests

  // Approval stages.
  RequestStatus wardenStatus;
  String? wardenRemark;
  RequestStatus authorityStatus; // only used for leave
  String? authorityRemark;

  // Gate movement, set by Security once a request is approved.
  GateStatus gateStatus;

  // Exact time each step happened (null until it happens).
  DateTime? wardenDecidedAt;
  DateTime? authorityDecidedAt;
  DateTime? wentOutAt;
  DateTime? returnedAt;

  AppRequest({
    required this.id,
    required this.studentRoll,
    required this.type,
    required this.reason,
    required this.fromDate,
    required this.toDate,
    required this.createdAt,
    required this.raisedBy,
    this.outpassKind,
    this.wardenStatus = RequestStatus.pending,
    this.wardenRemark,
    this.authorityStatus = RequestStatus.pending,
    this.authorityRemark,
    this.gateStatus = GateStatus.notOut,
    this.wardenDecidedAt,
    this.authorityDecidedAt,
    this.wentOutAt,
    this.returnedAt,
  });

  /// Overall computed status shown to parent/student.
  RequestStatus get overallStatus {
    if (wardenStatus == RequestStatus.rejected) return RequestStatus.rejected;
    if (type == RequestType.outpass) {
      return wardenStatus; // warden only
    }
    // leave: needs both
    if (authorityStatus == RequestStatus.rejected) {
      return RequestStatus.rejected;
    }
    if (wardenStatus == RequestStatus.approved &&
        authorityStatus == RequestStatus.approved) {
      return RequestStatus.approved;
    }
    return RequestStatus.pending;
  }

  bool get needsAuthority => type == RequestType.leave;

  /// Student is currently away: approved and gone out, not yet returned.
  bool get isAway =>
      overallStatus == RequestStatus.approved &&
      gateStatus == GateStatus.out;

  /// True if this outpass was returned after its deadline (toDate).
  bool get isLateReturn =>
      type == RequestType.outpass &&
      returnedAt != null &&
      returnedAt!.isAfter(toDate);

  /// Display label e.g. "Outpass (Sunday)" or "Leave".
  String get fullLabel => type == RequestType.outpass && outpassKind != null
      ? '${type.label} (${outpassKind!.label})'
      : type.label;

  Map<String, dynamic> toJson() => {
        'id': id,
        'studentRoll': studentRoll,
        'type': type.index,
        'reason': reason,
        'fromDate': fromDate.toIso8601String(),
        'toDate': toDate.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'raisedBy': raisedBy,
        'outpassKind': outpassKind?.index,
        'wardenStatus': wardenStatus.index,
        'wardenRemark': wardenRemark,
        'authorityStatus': authorityStatus.index,
        'authorityRemark': authorityRemark,
        'gateStatus': gateStatus.index,
        'wardenDecidedAt': wardenDecidedAt?.toIso8601String(),
        'authorityDecidedAt': authorityDecidedAt?.toIso8601String(),
        'wentOutAt': wentOutAt?.toIso8601String(),
        'returnedAt': returnedAt?.toIso8601String(),
      };

  static DateTime? _parseOpt(dynamic v) =>
      (v == null || v == '') ? null : DateTime.parse(v);

  factory AppRequest.fromJson(Map<String, dynamic> json) => AppRequest(
        id: json['id'],
        studentRoll: json['studentRoll'] ?? '',
        type: RequestType.values[json['type'] ?? 0],
        reason: json['reason'] ?? '',
        fromDate: DateTime.parse(json['fromDate']),
        toDate: DateTime.parse(json['toDate']),
        createdAt: DateTime.parse(json['createdAt']),
        raisedBy: json['raisedBy'] ?? '',
        outpassKind: json['outpassKind'] == null
            ? null
            : OutpassKind.values[json['outpassKind']],
        wardenStatus: RequestStatus.values[json['wardenStatus'] ?? 0],
        wardenRemark: json['wardenRemark'],
        authorityStatus: RequestStatus.values[json['authorityStatus'] ?? 0],
        authorityRemark: json['authorityRemark'],
        gateStatus: GateStatus.values[json['gateStatus'] ?? 0],
        wardenDecidedAt: _parseOpt(json['wardenDecidedAt']),
        authorityDecidedAt: _parseOpt(json['authorityDecidedAt']),
        wentOutAt: _parseOpt(json['wentOutAt']),
        returnedAt: _parseOpt(json['returnedAt']),
      );
}
