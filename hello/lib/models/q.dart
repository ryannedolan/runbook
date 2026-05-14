import 'package:uuid/uuid.dart';

/// AKC agility classes we currently model. Easy to extend.
enum AgilityClass {
  standard,
  jww,
  fast,
  t2b,
  premierStandard,
  premierJww,
}

extension AgilityClassX on AgilityClass {
  String get label => switch (this) {
    AgilityClass.standard => 'Standard',
    AgilityClass.jww => 'JWW',
    AgilityClass.fast => 'FAST',
    AgilityClass.t2b => 'T2B',
    AgilityClass.premierStandard => 'Premier Standard',
    AgilityClass.premierJww => 'Premier JWW',
  };

  String get short => switch (this) {
    AgilityClass.standard => 'STD',
    AgilityClass.jww => 'JWW',
    AgilityClass.fast => 'FAST',
    AgilityClass.t2b => 'T2B',
    AgilityClass.premierStandard => 'PSTD',
    AgilityClass.premierJww => 'PJWW',
  };

  /// Premier classes are only run at Master level.
  bool get isPremier =>
      this == AgilityClass.premierStandard ||
      this == AgilityClass.premierJww;
}

enum AgilityLevel { novice, open, excellent, master }

extension AgilityLevelX on AgilityLevel {
  String get label => switch (this) {
    AgilityLevel.novice => 'Novice',
    AgilityLevel.open => 'Open',
    AgilityLevel.excellent => 'Excellent',
    AgilityLevel.master => 'Master',
  };

  int get rank => switch (this) {
    AgilityLevel.novice => 0,
    AgilityLevel.open => 1,
    AgilityLevel.excellent => 2,
    AgilityLevel.master => 3,
  };
}

/// A qualifying run. Currently AKC agility only — sport field reserved
/// for future expansion.
class Q {
  Q({
    required this.id,
    required this.dogId,
    required this.date,
    required this.agilityClass,
    required this.level,
    this.preferred = false,
    this.placement,
    this.yards,
    this.score,
    this.timeSeconds,
    this.machPoints = 0,
    this.notes,
  });

  final String id;
  final String dogId;
  final DateTime date;
  final AgilityClass agilityClass;
  final AgilityLevel level;

  /// True if this Q was earned in the Preferred division. Preferred
  /// titles use parallel name schemes (NAP, MXP, PAX, ...). Premier
  /// classes do not have a Preferred division — preferred is always
  /// false when [agilityClass.isPremier] is true.
  final bool preferred;

  /// 1st/2nd/3rd/4th place, if awarded. Null if the Q wasn't placed.
  /// In the UI a placed Q renders with a second flat ribbon next to
  /// its green Q ribbon (blue/red/yellow/white for 1st-4th).
  final int? placement;

  final double? yards;
  final int? score;
  final double? timeSeconds;

  /// MACH/PACH championship points. Counts toward MACH (regular Master)
  /// or PAX (Preferred Master) depending on [preferred].
  final int machPoints;
  final String? notes;

  factory Q.create({
    required String dogId,
    required DateTime date,
    required AgilityClass agilityClass,
    required AgilityLevel level,
    bool preferred = false,
    int? placement,
    double? yards,
    int? score,
    double? timeSeconds,
    int machPoints = 0,
    String? notes,
  }) {
    return Q(
      id: const Uuid().v4(),
      dogId: dogId,
      date: date,
      agilityClass: agilityClass,
      level: level,
      preferred: preferred,
      placement: placement,
      yards: yards,
      score: score,
      timeSeconds: timeSeconds,
      machPoints: machPoints,
      notes: notes,
    );
  }

  String get sport => 'AKC Agility';

  /// "YPS" — yards per second. Null when either yards or time is unknown.
  double? get yps {
    final y = yards;
    final t = timeSeconds;
    if (y == null || t == null || t <= 0) return null;
    return y / t;
  }

  Q copyWith({
    String? dogId,
    DateTime? date,
    AgilityClass? agilityClass,
    AgilityLevel? level,
    bool? preferred,
    int? placement,
    bool clearPlacement = false,
    double? yards,
    int? score,
    double? timeSeconds,
    int? machPoints,
    String? notes,
  }) => Q(
    id: id,
    dogId: dogId ?? this.dogId,
    date: date ?? this.date,
    agilityClass: agilityClass ?? this.agilityClass,
    level: level ?? this.level,
    preferred: preferred ?? this.preferred,
    placement: clearPlacement ? null : (placement ?? this.placement),
    yards: yards ?? this.yards,
    score: score ?? this.score,
    timeSeconds: timeSeconds ?? this.timeSeconds,
    machPoints: machPoints ?? this.machPoints,
    notes: notes ?? this.notes,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'dogId': dogId,
    'date': date.toIso8601String(),
    'agilityClass': agilityClass.name,
    'level': level.name,
    if (preferred) 'preferred': true,
    if (placement != null) 'placement': placement,
    if (yards != null) 'yards': yards,
    if (score != null) 'score': score,
    if (timeSeconds != null) 'timeSeconds': timeSeconds,
    if (machPoints != 0) 'machPoints': machPoints,
    if (notes != null) 'notes': notes,
  };

  factory Q.fromJson(Map<String, dynamic> json) => Q(
    id: json['id'] as String,
    dogId: json['dogId'] as String,
    date: DateTime.parse(json['date'] as String),
    agilityClass: AgilityClass.values.byName(json['agilityClass'] as String),
    level: AgilityLevel.values.byName(json['level'] as String),
    preferred: json['preferred'] as bool? ?? false,
    placement: (json['placement'] as num?)?.toInt(),
    yards: (json['yards'] as num?)?.toDouble(),
    score: (json['score'] as num?)?.toInt(),
    timeSeconds: (json['timeSeconds'] as num?)?.toDouble(),
    machPoints: (json['machPoints'] as num?)?.toInt() ?? 0,
    notes: json['notes'] as String?,
  );
}
