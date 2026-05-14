import 'package:uuid/uuid.dart';

/// A named competition the dog attended (NAC, Invitational, Westminster
/// Masters, etc). Separate from a Q because the event itself is the
/// thing we're tracking, not the qualifying score.
enum EventType {
  nationalAgilityChampionship,
  agilityInvitational,
  juniorNAC,
  westminsterMasters,
  regionals,
  worldChampionships,
  usdaaNationals,
  other,
}

extension EventTypeX on EventType {
  /// Full name shown on cards.
  String get name => switch (this) {
        EventType.nationalAgilityChampionship => 'AKC National Agility Championship',
        EventType.agilityInvitational => 'AKC Agility Invitational',
        EventType.juniorNAC => 'AKC Junior National Agility Championship',
        EventType.westminsterMasters => 'Westminster Masters Agility',
        EventType.regionals => 'Regional Agility Championship',
        EventType.worldChampionships => 'IFCS World Agility Championships',
        EventType.usdaaNationals => 'USDAA Cynosport World Games',
        EventType.other => 'Event',
      };

  /// Short label used in chips / compact rows.
  String get short => switch (this) {
        EventType.nationalAgilityChampionship => 'NAC',
        EventType.agilityInvitational => 'Invitational',
        EventType.juniorNAC => 'Jr. NAC',
        EventType.westminsterMasters => 'Westminster',
        EventType.regionals => 'Regional',
        EventType.worldChampionships => 'IFCS Worlds',
        EventType.usdaaNationals => 'USDAA Nat\'ls',
        EventType.other => 'Other',
      };
}

/// How the dog did at the event. Ordered roughly best→worst-known; null
/// means the user didn't record a result yet.
enum EventResult {
  champion,
  reservePlace,
  place1st,
  place2nd,
  place3rd,
  top3,
  top10,
  finalist,
  semifinalist,
  madeCut,
  participated,
}

extension EventResultX on EventResult {
  String get label => switch (this) {
        EventResult.champion => 'Champion',
        EventResult.reservePlace => 'Reserve',
        EventResult.place1st => '1st place',
        EventResult.place2nd => '2nd place',
        EventResult.place3rd => '3rd place',
        EventResult.top3 => 'Top 3',
        EventResult.top10 => 'Top 10',
        EventResult.finalist => 'Finalist',
        EventResult.semifinalist => 'Semifinalist',
        EventResult.madeCut => 'Made the cut',
        EventResult.participated => 'Participated',
      };

  /// Sort weight: lower is better. Used to order multiple events on the
  /// same date when surfacing the "best" result for a dog.
  int get rank => switch (this) {
        EventResult.champion => 0,
        EventResult.reservePlace => 1,
        EventResult.place1st => 2,
        EventResult.place2nd => 3,
        EventResult.place3rd => 4,
        EventResult.top3 => 5,
        EventResult.top10 => 6,
        EventResult.finalist => 7,
        EventResult.semifinalist => 8,
        EventResult.madeCut => 9,
        EventResult.participated => 10,
      };
}

class Event {
  Event({
    required this.id,
    required this.dogId,
    required this.date,
    required this.type,
    this.customName,
    this.result,
    this.notes,
  });

  final String id;
  final String dogId;
  final DateTime date;
  final EventType type;

  /// Only meaningful when [type] is [EventType.other] — lets the user
  /// enter a custom event name (e.g. a specific trial nickname).
  final String? customName;
  final EventResult? result;
  final String? notes;

  /// Display name. For "other" events with a custom name, prefer that;
  /// otherwise the type's canonical name.
  String get displayName {
    if (type == EventType.other && (customName?.isNotEmpty ?? false)) {
      return customName!;
    }
    return type.name;
  }

  String get shortLabel {
    if (type == EventType.other && (customName?.isNotEmpty ?? false)) {
      return customName!;
    }
    return type.short;
  }

  factory Event.create({
    required String dogId,
    required DateTime date,
    required EventType type,
    String? customName,
    EventResult? result,
    String? notes,
  }) =>
      Event(
        id: const Uuid().v4(),
        dogId: dogId,
        date: date,
        type: type,
        customName: customName,
        result: result,
        notes: notes,
      );

  Event copyWith({
    String? dogId,
    DateTime? date,
    EventType? type,
    String? customName,
    bool clearCustomName = false,
    EventResult? result,
    bool clearResult = false,
    String? notes,
    bool clearNotes = false,
  }) =>
      Event(
        id: id,
        dogId: dogId ?? this.dogId,
        date: date ?? this.date,
        type: type ?? this.type,
        customName: clearCustomName ? null : (customName ?? this.customName),
        result: clearResult ? null : (result ?? this.result),
        notes: clearNotes ? null : (notes ?? this.notes),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'dogId': dogId,
        'date': date.toIso8601String(),
        'type': type.name,
        if (customName != null) 'customName': customName,
        if (result != null) 'result': result!.name,
        if (notes != null) 'notes': notes,
      };

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] as String,
        dogId: j['dogId'] as String,
        date: DateTime.parse(j['date'] as String),
        type: EventType.values.byName(j['type'] as String),
        customName: j['customName'] as String?,
        result: j['result'] is String
            ? EventResult.values.byName(j['result'] as String)
            : null,
        notes: j['notes'] as String?,
      );
}
