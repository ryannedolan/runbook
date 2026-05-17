import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:uuid/uuid.dart';

import '../models/q.dart';

/// One Q parsed from a YAML asset, paired with the metadata we need to
/// dedupe / attribute it.
class ImportedQ {
  ImportedQ({required this.q, required this.dedupeKey});
  final Q q;
  final String dedupeKey;
}

/// Header for an asset (parsed from the leading `# ...` comments).
class DogDataset {
  DogDataset({
    required this.akcId,
    this.callName,
    this.registeredName,
  });
  final String akcId;
  final String? callName;
  final String? registeredName;
}

/// What we found inside `assets/dogs/*.yaml`, indexed by AKC ID.
class DatasetIndex {
  DatasetIndex(this.byAkcId);
  final Map<String, DogDataset> byAkcId;

  DogDataset? bestMatchByName(String callName) {
    final norm = callName.trim().toLowerCase();
    for (final d in byAkcId.values) {
      if (d.callName?.trim().toLowerCase() == norm) return d;
    }
    return null;
  }
}

/// List every `assets/dogs/*.yaml` and read the header comments. We
/// only parse the full file when we actually need to import a dog.
Future<DatasetIndex> loadDatasetIndex() async {
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final paths = manifest
      .listAssets()
      .where((p) => p.startsWith('assets/dogs/') && p.endsWith('.yaml'))
      .toList();
  final out = <String, DogDataset>{};
  for (final path in paths) {
    final raw = await rootBundle.loadString(path);
    final header = _parseHeader(raw);
    final akcId = header['akc number'] ??
        // Filename fallback: `assets/dogs/<akcId>.yaml`.
        path.split('/').last.replaceAll('.yaml', '');
    out[akcId] = DogDataset(
      akcId: akcId,
      callName: header['call name'],
      registeredName: header['registered name'],
    );
  }
  return DatasetIndex(out);
}

/// Parse the leading `# Key: Value` lines. Stops at the first non-`#`
/// line. Keys are lowercased.
Map<String, String> _parseHeader(String raw) {
  final out = <String, String>{};
  for (final line in raw.split('\n')) {
    if (line.isEmpty) continue;
    if (!line.startsWith('#')) break;
    final stripped = line.substring(1).trim();
    final i = stripped.indexOf(':');
    if (i < 0) continue;
    out[stripped.substring(0, i).trim().toLowerCase()] =
        stripped.substring(i + 1).trim();
  }
  return out;
}

/// Read & parse `assets/dogs/$akcId.yaml`. Returns the Qs we know how
/// to model (AKC agility/scentwork/FastCAT). Non-AKC records (e.g. ASCA
/// agility, Barn Hunt) and elements we don't model (e.g. Handler
/// Discrimination) are skipped.
Future<List<ImportedQ>> loadQsForAkcId(String akcId, String dogId) async {
  final raw = await rootBundle.loadString('assets/dogs/$akcId.yaml');
  return parseDogYaml(raw, dogId: dogId);
}

List<ImportedQ> parseDogYaml(String raw, {required String dogId}) {
  final out = <ImportedQ>[];
  for (final block in _splitDocs(raw)) {
    final m = _parseBlock(block);
    if (m.isEmpty) continue;
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
/// on the same day — every other field is identical. Manual entries
/// today don't carry a trial; for them the trial slot is "-".
String dedupeKeyFor(Q q) {
  final d = q.date;
  final day =
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return [
    q.dogId,
    day,
    q.sport.name,
    q.agilityClass.name,
    q.level.name,
    q.preferred ? 'pref' : 'reg',
    q.scentElement?.name ?? '-',
    q.scentLevel?.name ?? '-',
    q.trial ?? '-',
  ].join('|');
}

// ---------------------------------------------------------------------------
// Tiny YAML reader. The agent emits a very narrow subset: multi-doc
// (`---` separators) with flat `key: value` pairs plus a single nested
// `faults:` block we ignore. No need to pull in the full yaml package.
// ---------------------------------------------------------------------------

Iterable<String> _splitDocs(String raw) sync* {
  final lines = raw.split('\n');
  final buf = <String>[];
  for (final line in lines) {
    if (line.startsWith('#')) continue;
    if (line.trim() == '---') {
      if (buf.isNotEmpty) yield buf.join('\n');
      buf.clear();
      continue;
    }
    buf.add(line);
  }
  if (buf.isNotEmpty) yield buf.join('\n');
}

Map<String, dynamic> _parseBlock(String block) {
  final out = <String, dynamic>{};
  for (final raw in block.split('\n')) {
    if (raw.trim().isEmpty) continue;
    // Skip nested children (anything indented). Top-level keys only.
    if (raw.startsWith(' ') || raw.startsWith('\t')) continue;
    final i = raw.indexOf(':');
    if (i < 0) continue;
    final key = raw.substring(0, i).trim();
    final rawVal = raw.substring(i + 1).trim();
    if (rawVal.isEmpty) continue; // nested block header (e.g. `faults:`)
    out[key] = _unquote(rawVal);
  }
  return out;
}

String _unquote(String s) {
  if (s.length >= 2) {
    final first = s[0];
    final last = s[s.length - 1];
    if ((first == "'" && last == "'") || (first == '"' && last == '"')) {
      return s.substring(1, s.length - 1);
    }
  }
  return s;
}

// ---------------------------------------------------------------------------
// Field-mapping. The agent's vocabulary is a touch looser than the
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
    level = AgilityLevel.master;
    preferred = false;
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
    timeSeconds: _parseDouble(m['time']),
    machPoints: _parseInt(m['mach_points']) ?? 0,
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
  return Q(
    id: const Uuid().v4(),
    dogId: dogId,
    date: date,
    sport: Sport.fastCAT,
    agilityClass: AgilityClass.fast, // placeholder; matches convo.
    level: AgilityLevel.novice,
    placement: placement,
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
    agilityClass: AgilityClass.fast, // placeholder; matches convo.
    level: AgilityLevel.novice,
    scentElement: element,
    scentLevel: level,
    placement: placement,
    timeSeconds: _parseSearchTime(m['search_time'] as String?),
    trial: trial,
  );
}

DateTime? _parseDate(String s) {
  // YAML dates land here as ISO strings (`2024-05-11`).
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
  // Replace stray `:` between seconds and hundredths with `.`, then
  // split. Examples we need to handle: "01:06.65", "01:06:65", "00:33:04".
  final fields = t.split(RegExp(r'[:\.]'));
  if (fields.length < 2) return double.tryParse(t);
  final ints = fields.map(int.tryParse).toList();
  if (ints.any((v) => v == null)) return null;
  // last field is hundredths, second-to-last is seconds. Earlier
  // fields are minutes (and optionally hours).
  final hundredths = ints.last!;
  final seconds = ints[ints.length - 2]!;
  var minutes = 0;
  var hours = 0;
  if (ints.length >= 3) minutes = ints[ints.length - 3]!;
  if (ints.length >= 4) hours = ints[ints.length - 4]!;
  return hours * 3600 + minutes * 60 + seconds + hundredths / 100.0;
}
