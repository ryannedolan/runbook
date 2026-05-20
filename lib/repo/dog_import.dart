import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../models/q.dart';

/// One Q parsed from a dataset, paired with the metadata we need to
/// dedupe / attribute it.
class ImportedQ {
  ImportedQ({required this.q, required this.dedupeKey});
  final Q q;
  final String dedupeKey;
}

/// Hardcoded gh-pages location of the prebuilt JSON datasets. Used by
/// the mobile builds (web uses a relative URL — see [_datasetUri]).
const String _datasetMobileBaseUrl = 'https://ryannedolan.github.io/runbook';

/// Resolves the URL for a given AKC ID's prebuilt dataset.
/// - On web, uses a relative URL so localhost + production both work
///   without further config.
/// - On mobile, hits the deployed gh-pages location.
Uri _datasetUri(String akcId) {
  if (kIsWeb) return Uri.base.resolve('dogs/$akcId.json');
  return Uri.parse('$_datasetMobileBaseUrl/dogs/$akcId.json');
}

/// Fetch and parse the prebuilt dataset for [akcId]. Returns an empty
/// list when the dataset doesn't exist (e.g. typo'd AKC ID) or the
/// network request fails — backfill is best-effort and never throws
/// to its caller.
Future<List<ImportedQ>> loadQsForAkcId(String akcId, String dogId) async {
  try {
    final res = await http.get(_datasetUri(akcId));
    if (res.statusCode != 200) return const [];
    return parseDogJson(res.body, dogId: dogId);
  } catch (_) {
    // Offline, DNS failure, malformed JSON, etc. Silent — backfill is
    // best-effort and the user can retry by re-saving the dog.
    return const [];
  }
}

List<ImportedQ> parseDogJson(String raw, {required String dogId}) {
  final obj = jsonDecode(raw) as Map<String, dynamic>;
  final qs = (obj['qs'] as List<dynamic>?) ?? const <dynamic>[];
  final out = <ImportedQ>[];
  for (final rec in qs) {
    final m = rec as Map<String, dynamic>;
    final q = _qFromMap(m, dogId: dogId);
    if (q == null) continue;
    out.add(ImportedQ(q: q, dedupeKey: dedupeKeyFor(q)));
  }
  return out;
}

/// A stable, value-based key. Two Qs collide iff they're plausibly the
/// same event for the same dog (same date, sport, class/level/element,
/// trial). Time/score/placement can vary between manual entry and the
/// imported record without breaking dedupe.
///
/// Trial number matters because FastCAT dogs routinely run two trials
/// on the same day — every other field is identical.
String dedupeKeyFor(Q q) {
  final d = q.date;
  final day =
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return [
    q.dogId,
    day,
    q.sport.name,
    q.agilityClass?.name ?? '-',
    q.level?.name ?? '-',
    q.preferred ? 'pref' : 'reg',
    q.scentElement?.name ?? '-',
    q.scentLevel?.name ?? '-',
    q.trial ?? '-',
  ].join('|');
}

// ---------------------------------------------------------------------------
// Field-mapping. The dataset's vocabulary is a touch looser than the
// app's enums; normalize here.
// ---------------------------------------------------------------------------

const _agilityClassByLabel = <String, AgilityClass>{
  'STD': AgilityClass.standard,
  'STANDARD': AgilityClass.standard,
  'JWW': AgilityClass.jww,
  'FAST': AgilityClass.fast,
  'T2B': AgilityClass.t2b,
  'PSTD': AgilityClass.premierStandard,
  'PJWW': AgilityClass.premierJww,
  'PREMIER STANDARD': AgilityClass.premierStandard,
  'PREMIER JWW': AgilityClass.premierJww,
};

const _agilityLevelByLabel = <String, AgilityLevel>{
  'NOV': AgilityLevel.novice,
  'NOV A': AgilityLevel.novice,
  'NOV B': AgilityLevel.novice,
  'NOVICE': AgilityLevel.novice,
  'NOVICE A': AgilityLevel.novice,
  'NOVICE B': AgilityLevel.novice,
  'OPEN': AgilityLevel.open,
  'OPEN A': AgilityLevel.open,
  'OPEN B': AgilityLevel.open,
  'EX': AgilityLevel.excellent,
  'EXC': AgilityLevel.excellent,
  'EXCELLENT': AgilityLevel.excellent,
  'EXCELLENT A': AgilityLevel.excellent,
  'EXCELLENT B': AgilityLevel.excellent,
  'MAS': AgilityLevel.master,
  'MASTER': AgilityLevel.master,
};

const _scentElementByLabel = <String, ScentElement>{
  'CONTAINER': ScentElement.container,
  'INTERIOR': ScentElement.interior,
  'EXTERIOR': ScentElement.exterior,
  'BURIED': ScentElement.buried,
};

const _scentLevelByLabel = <String, ScentLevel>{
  'NOVICE': ScentLevel.novice,
  'ADVANCED': ScentLevel.advanced,
  'EXCELLENT': ScentLevel.excellent,
  'MASTER': ScentLevel.master,
  'DETECTIVE': ScentLevel.detective,
};

Q? _qFromMap(Map<String, dynamic> m, {required String dogId}) {
  // Skip non-AKC venues. The data has a few ASCA agility & Barn Hunt
  // entries that don't fit any of our trees.
  final venue = (m['venue'] as String?)?.trim().toUpperCase();
  if (venue != null && venue != 'AKC') return null;

  final sportRaw = (m['sport'] as String?)?.trim().toLowerCase();
  final dateStr = m['date'] as String?;
  if (sportRaw == null || dateStr == null) return null;

  final date = _parseDate(dateStr);
  if (date == null) return null;

  final placement = _parseInt(m['place']);
  final trial = m['trial'] as String?;

  switch (sportRaw) {
    case 'agility':
      return _agilityQ(m,
          dogId: dogId, date: date, placement: placement, trial: trial);
    case 'fastcat':
      return _fastCATQ(m,
          dogId: dogId, date: date, placement: placement, trial: trial);
    case 'scent work':
    case 'scentwork':
      return _scentworkQ(m,
          dogId: dogId, date: date, placement: placement, trial: trial);
  }
  return null;
}

Q? _agilityQ(
  Map<String, dynamic> m, {
  required String dogId,
  required DateTime date,
  required int? placement,
  required String? trial,
}) {
  final clsRaw = (m['class'] as String?)?.trim().toUpperCase();
  final lvlRaw = (m['level'] as String?)?.trim().toUpperCase();
  if (clsRaw == null) return null;

  final cls = _agilityClassByLabel[clsRaw];
  if (cls == null) return null;

  // T2B uses REG/PREF in place of a level name; everything else uses
  // the standard novice/open/excellent/master vocabulary.
  AgilityLevel level;
  bool preferred;
  if (lvlRaw == 'REG' || (cls == AgilityClass.t2b && lvlRaw == null)) {
    level = AgilityLevel.master;
    preferred = false;
  } else if (lvlRaw == 'PREF') {
    level = AgilityLevel.master;
    preferred = true;
  } else {
    final mapped = lvlRaw != null ? _agilityLevelByLabel[lvlRaw] : null;
    if (mapped == null) return null;
    level = mapped;
    preferred = false;
  }
  if (cls.isPremier) {
    // Premier classes are always Master-level but can be Regular or
    // Preferred — preserve whatever the level-row already decided.
    level = AgilityLevel.master;
  }

  final sct = _parseDouble(m['sct']);
  final time = _parseDouble(m['time']);
  // MACH/PACH points only count at Master STD/JWW (non-Premier). Use
  // the explicit value when present, else compute from sct+time;
  // clamp to ≥0 because some sources report negative numbers (time
  // *over* SCT) rather than the AKC-awarded points value, and a true
  // over-SCT Master Q earns 0 MACH points.
  final eligibleForMachPoints = level == AgilityLevel.master &&
      !cls.isPremier &&
      (cls == AgilityClass.standard || cls == AgilityClass.jww);
  int machPoints;
  if (eligibleForMachPoints) {
    final explicit = _parseInt(m['mach_points']);
    machPoints = (explicit ?? Q.computeMachPoints(sct: sct, timeSeconds: time))
        .clamp(0, 1 << 30)
        .toInt();
  } else {
    machPoints = 0;
  }

  return Q(
    id: const Uuid().v4(),
    dogId: dogId,
    date: date,
    sport: Sport.akcAgility,
    agilityClass: cls,
    level: level,
    preferred: preferred,
    placement: placement,
    yards: _parseDouble(m['yards']),
    score: _parseInt(m['score']),
    timeSeconds: time,
    machPoints: machPoints,
    sct: sct,
    ypsOverride: _parseDouble(m['yps']),
    trial: trial,
  );
}

Q? _fastCATQ(
  Map<String, dynamic> m, {
  required String dogId,
  required DateTime date,
  required int? placement,
  required String? trial,
}) {
  // FastCAT has no placements. Even if the YAML source includes a
  // `place` field, we drop it here to avoid showing a nonexistent
  // placement ribbon.
  return Q(
    id: const Uuid().v4(),
    dogId: dogId,
    date: date,
    sport: Sport.fastCAT,
    score: _parseInt(m['points']) ?? _parseDouble(m['points'])?.round(),
    timeSeconds: _parseDouble(m['time']),
    trial: trial,
  );
}

Q? _scentworkQ(
  Map<String, dynamic> m, {
  required String dogId,
  required DateTime date,
  required int? placement,
  required String? trial,
}) {
  final elementRaw = (m['element'] as String?)?.trim().toUpperCase();
  final classRaw = (m['class'] as String?)?.trim().toUpperCase();
  if (elementRaw == null || classRaw == null) return null;
  final element = _scentElementByLabel[elementRaw];
  final level = _scentLevelByLabel[classRaw];
  if (element == null || level == null) return null;

  return Q(
    id: const Uuid().v4(),
    dogId: dogId,
    date: date,
    sport: Sport.scentwork,
    scentElement: element,
    scentLevel: level,
    placement: placement,
    timeSeconds: _parseSearchTime(m['search_time'] as String?),
    trial: trial,
  );
}

DateTime? _parseDate(String s) {
  final parts = s.split('-');
  if (parts.length != 3) return DateTime.tryParse(s);
  final y = int.tryParse(parts[0]);
  final mo = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || mo == null || d == null) return null;
  return DateTime(y, mo, d);
}

int? _parseInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round();
  return null;
}

double? _parseDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

/// search_time arrives in two flavors: `MM:SS:HH` and `MM:SS.HH`
/// (occasional `HH:MM:SS.HH` for >1h runs). Return seconds, or null if
/// unparseable.
double? _parseSearchTime(String? s) {
  if (s == null) return null;
  final t = s.trim();
  if (t.isEmpty) return null;
  final fields = t.split(RegExp(r'[:\.]'));
  if (fields.length < 2) return double.tryParse(t);
  final ints = fields.map(int.tryParse).toList();
  if (ints.any((v) => v == null)) return null;
  final hundredths = ints.last!;
  final seconds = ints[ints.length - 2]!;
  var minutes = 0;
  var hours = 0;
  if (ints.length >= 3) minutes = ints[ints.length - 3]!;
  if (ints.length >= 4) hours = ints[ints.length - 4]!;
  return hours * 3600 + minutes * 60 + seconds + hundredths / 100.0;
}
