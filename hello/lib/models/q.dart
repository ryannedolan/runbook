import 'package:uuid/uuid.dart';

/// AKC agility classes we currently model. Easy to extend.
enum AgilityClass { standard, jww, fast, t2b }

extension AgilityClassX on AgilityClass {
  String get label => switch (this) {
    AgilityClass.standard => 'Standard',
    AgilityClass.jww => 'JWW',
    AgilityClass.fast => 'FAST',
    AgilityClass.t2b => 'T2B',
  };

  String get short => switch (this) {
    AgilityClass.standard => 'STD',
    AgilityClass.jww => 'JWW',
    AgilityClass.fast => 'FAST',
    AgilityClass.t2b => 'T2B',
  };
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
  final int? score;
  final double? timeSeconds;
  final int machPoints;
  final String? notes;

  factory Q.create({
    required String dogId,
    required DateTime date,
    required AgilityClass agilityClass,
    required AgilityLevel level,
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
      score: score,
      timeSeconds: timeSeconds,
      machPoints: machPoints,
      notes: notes,
    );
  }

  String get sport => 'AKC Agility';

  Q copyWith({
    DateTime? date,
    AgilityClass? agilityClass,
    AgilityLevel? level,
    int? score,
    double? timeSeconds,
    int? machPoints,
    String? notes,
  }) => Q(
    id: id,
    dogId: dogId,
    date: date ?? this.date,
    agilityClass: agilityClass ?? this.agilityClass,
    level: level ?? this.level,
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
    score: (json['score'] as num?)?.toInt(),
    timeSeconds: (json['timeSeconds'] as num?)?.toDouble(),
    machPoints: (json['machPoints'] as num?)?.toInt() ?? 0,
    notes: json['notes'] as String?,
  );
}
