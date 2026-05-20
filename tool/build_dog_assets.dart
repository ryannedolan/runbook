// Converts data/dogs/*.yaml into web/dogs/*.json.
//
// Source files in data/ are human/agent-friendly YAML (multi-doc,
// comments at the top for AKC number + call name). The generated JSON
// is served as static files from the deployed site (and from
// `flutter run -d web-server`); the client never reads YAML directly.
// The output lives under web/ rather than assets/ so it's published
// by GitHub Pages but NOT bundled into the mobile APK — mobile fetches
// the same URL over HTTPS at backfill time.
//
// Run from the package root (the directory containing pubspec.yaml):
//   dart run tool/build_dog_assets.dart

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

void main(List<String> args) {
  final root = Directory.current;
  final inDir = Directory('${root.path}/data/dogs');
  final outDir = Directory('${root.path}/web/dogs');
  if (!inDir.existsSync()) {
    stderr.writeln('No data/dogs directory at ${inDir.path}');
    exit(1);
  }
  outDir.createSync(recursive: true);

  // Wipe any stale JSON whose YAML source no longer exists.
  final yamlBases = <String>{};
  final files = inDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.yaml'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    yamlBases.add(f.uri.pathSegments.last.replaceAll('.yaml', ''));
  }
  for (final f in outDir.listSync().whereType<File>()) {
    if (!f.path.endsWith('.json')) continue;
    final base = f.uri.pathSegments.last.replaceAll('.json', '');
    if (!yamlBases.contains(base)) {
      stdout.writeln('  rm ${f.path} (no matching YAML)');
      f.deleteSync();
    }
  }

  var totalRecords = 0;
  for (final f in files) {
    final raw = f.readAsStringSync();
    final header = _parseHeader(raw);
    final docs = loadYamlStream(raw)
        .where((d) => d != null)
        .map(_yamlToJson)
        .toList();
    final akcId = header['akc number'] ??
        f.uri.pathSegments.last.replaceAll('.yaml', '');
    final out = <String, dynamic>{
      'akcId': akcId,
      if (header['call name'] != null) 'callName': header['call name'],
      if (header['registered name'] != null)
        'registeredName': header['registered name'],
      'qs': docs,
    };
    final outFile = File('${outDir.path}/$akcId.json');
    outFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(out)}\n',
    );
    totalRecords += docs.length;
    stdout.writeln(
      '  ${f.path} -> ${outFile.path} (${docs.length} records)',
    );
  }
  stdout.writeln('Built ${files.length} datasets, $totalRecords records.');
}

/// Reads the `# Key: Value` block at the head of a YAML file. The yaml
/// package strips comments, so we do this ourselves before handing the
/// body off. Keys are lowercased.
Map<String, String> _parseHeader(String raw) {
  final out = <String, String>{};
  for (final line in raw.split('\n')) {
    if (line.isEmpty) continue;
    if (!line.startsWith('#')) break;
    final s = line.substring(1).trim();
    final i = s.indexOf(':');
    if (i < 0) continue;
    out[s.substring(0, i).trim().toLowerCase()] = s.substring(i + 1).trim();
  }
  return out;
}

/// Recursively converts YamlMap/YamlList/Yaml scalars into plain
/// jsonEncode-able structures. Dates are emitted as `YYYY-MM-DD`
/// strings so the client can keep its existing date-parsing logic.
dynamic _yamlToJson(dynamic v) {
  if (v is YamlMap) {
    return {for (final e in v.entries) e.key.toString(): _yamlToJson(e.value)};
  }
  if (v is YamlList) {
    return [for (final x in v) _yamlToJson(x)];
  }
  if (v is DateTime) {
    return v.toIso8601String().substring(0, 10);
  }
  return v;
}
