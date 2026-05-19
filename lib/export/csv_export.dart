import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/dog.dart';
import '../models/q.dart';
import '../repo/repo.dart';

/// Wide-format columns for the Q export. Spreadsheet apps render them
/// in this order. New columns should be appended (don't reorder) so
/// users who keep their exports as backups can diff over time.
const List<String> kCsvColumns = [
  'dog',
  'akc_id',
  'date',
  'sport',
  'class',
  'level',
  'preferred',
  'placement',
  'time_seconds',
  'yards',
  'yps',
  'sct',
  'score',
  'mach_points',
  'scent_element',
  'scent_level',
  'trial',
  'notes',
];

/// Build the wide CSV (one row per Q, columns shared across sports).
/// Newest Qs first. Pure-Dart — no plugins — so it's easy to unit-test.
String buildQsCsv(Repo repo) {
  final dogsById = <String, Dog>{for (final d in repo.dogs) d.id: d};
  final qs = [...repo.qs]..sort((a, b) => b.date.compareTo(a.date));
  final buf = StringBuffer();
  buf.writeln(kCsvColumns.map(_csvCell).join(','));
  for (final q in qs) {
    final dog = dogsById[q.dogId];
    buf.writeln(_rowFor(dog, q));
  }
  return buf.toString();
}

String _rowFor(Dog? dog, Q q) {
  final cells = <Object?>[
    dog?.callName ?? '',
    dog?.akcId ?? '',
    DateFormat('yyyy-MM-dd').format(q.date),
    q.sport.label,
    q.agilityClass?.label ?? '',
    // Premier and T2B are single-level; leave level blank for those
    // and for non-agility sports (matches what the user-facing UI shows).
    (q.agilityClass != null && !q.agilityClass!.isSingleLevel)
        ? (q.level?.label ?? '')
        : '',
    q.sport == Sport.akcAgility ? (q.preferred ? 'preferred' : 'regular') : '',
    q.placement,
    q.timeSeconds,
    q.yards,
    q.yps,
    q.sct,
    q.score,
    q.machPoints == 0 ? '' : q.machPoints,
    q.scentElement?.label ?? '',
    q.scentLevel?.label ?? '',
    q.trial ?? '',
    q.notes ?? '',
  ];
  return cells.map(_csvCell).join(',');
}

/// RFC-4180-ish escape: wrap in quotes when the cell contains a comma,
/// quote, or newline; double up internal quotes.
String _csvCell(Object? v) {
  if (v == null) return '';
  if (v is num) {
    if (v is int) return v.toString();
    // Trim 4.130000000001 → "4.13", but keep small/integer-ish nums tidy.
    if (v == v.roundToDouble()) return v.toInt().toString();
    final s = v.toStringAsFixed(3);
    var t = s;
    while (t.endsWith('0')) {
      t = t.substring(0, t.length - 1);
    }
    if (t.endsWith('.')) t = t.substring(0, t.length - 1);
    return t;
  }
  final s = v.toString();
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Build the CSV, write it to the app's temp directory under a
/// time-stamped name, and hand off via the system share sheet.
/// Returns the count of rows written, or null if the user has no Qs.
Future<int?> shareQsCsv(Repo repo) async {
  if (repo.qs.isEmpty) return null;
  final csv = buildQsCsv(repo);
  final dir = await getTemporaryDirectory();
  final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final file = File('${dir.path}/runbook-qs-$stamp.csv');
  await file.writeAsString(csv);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    subject: 'Runbook Qs ($stamp)',
    text: '${repo.qs.length} Qs exported from Runbook.',
  );
  return repo.qs.length;
}

/// Web variant — share_plus / path_provider don't work in the browser
/// the same way. Defer until we actually need export on web.
bool get csvExportSupportedOnThisPlatform => !kIsWeb;
