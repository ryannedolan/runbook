import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dog.dart';
import '../models/q.dart';
import 'dog_import.dart';

class Repo extends ChangeNotifier {
  Repo._(this._prefs);

  static const _kDogs = 'runbook.dogs';
  static const _kQs = 'runbook.qs';
  static const _kPinned = 'runbook.pinnedCards';
  static const _kCollectedRibbons = 'runbook.collectedRibbons';
  static const _kOverrides = 'runbook.overrideCounts';

  final SharedPreferences _prefs;
  final List<Dog> _dogs = [];
  final List<Q> _qs = [];
  final Set<String> _pinned = {};
  final Set<String> _collectedRibbons = {};

  /// Pool-count overrides keyed by `${dogId}::${poolKey}`. Captures
  /// the user's "AKC says I have N Qs in this pool" adjustment from
  /// the points-progression report — the rules engine treats the
  /// effective count as `max(realCount, override)` so a scanned ribbon
  /// for an AKC-reported Q never double-counts.
  final Map<String, int> _overrideCounts = {};

  static Future<Repo> open() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = Repo._(prefs);
    repo._load();
    return repo;
  }

  void _load() {
    final dogsJson = _prefs.getString(_kDogs);
    if (dogsJson != null) {
      final list = jsonDecode(dogsJson) as List<dynamic>;
      _dogs
        ..clear()
        ..addAll(list.map((j) => Dog.fromJson(j as Map<String, dynamic>)));
    }
    final qsJson = _prefs.getString(_kQs);
    if (qsJson != null) {
      final list = jsonDecode(qsJson) as List<dynamic>;
      _qs
        ..clear()
        ..addAll(list.map((j) => Q.fromJson(j as Map<String, dynamic>)));
    }
    final pinnedJson = _prefs.getString(_kPinned);
    if (pinnedJson != null) {
      final list = jsonDecode(pinnedJson) as List<dynamic>;
      _pinned
        ..clear()
        ..addAll(list.cast<String>());
    }
    final collectedJson = _prefs.getString(_kCollectedRibbons);
    if (collectedJson != null) {
      final list = jsonDecode(collectedJson) as List<dynamic>;
      _collectedRibbons
        ..clear()
        ..addAll(list.cast<String>());
    }
    final overridesJson = _prefs.getString(_kOverrides);
    if (overridesJson != null) {
      final m = jsonDecode(overridesJson) as Map<String, dynamic>;
      _overrideCounts
        ..clear()
        ..addAll(m.map((k, v) => MapEntry(k, (v as num).toInt())));
    }
    _dedupeDogs();
  }

  /// One-shot: collapse dogs with the same call name (case-insensitive)
  /// into the first occurrence, reassigning any Qs to the kept dog's
  /// id. Runs on load to clean up legacy data.
  void _dedupeDogs() {
    final keepers = <String, Dog>{}; // normalized name -> keeper
    final remap = <String, String>{}; // old dogId -> keeper dogId
    final survivors = <Dog>[];
    for (final d in _dogs) {
      final key = d.callName.trim().toLowerCase();
      final existing = keepers[key];
      if (existing == null) {
        keepers[key] = d;
        survivors.add(d);
      } else {
        // Merge: prefer existing non-nulls, fill blanks from this dup.
        final merged = existing.copyWith(
          breed: existing.breed ?? d.breed,
          heightInches: existing.heightInches ?? d.heightInches,
          dateOfBirth: existing.dateOfBirth ?? d.dateOfBirth,
          notes: existing.notes ?? d.notes,
        );
        keepers[key] = merged;
        final i = survivors.indexWhere((s) => s.id == existing.id);
        if (i >= 0) survivors[i] = merged;
        remap[d.id] = existing.id;
      }
    }
    if (remap.isEmpty) return;
    _dogs
      ..clear()
      ..addAll(survivors);
    for (var i = 0; i < _qs.length; i++) {
      final newOwner = remap[_qs[i].dogId];
      if (newOwner != null) {
        _qs[i] = _qs[i].copyWith(dogId: newOwner);
      }
    }
    // Persist the cleanup immediately so we never re-dedupe on load.
    unawaited(_saveDogs());
    unawaited(_saveQs());
  }

  Future<void> _saveDogs() async =>
      _prefs.setString(_kDogs, jsonEncode(_dogs.map((d) => d.toJson()).toList()));

  Future<void> _saveQs() async =>
      _prefs.setString(_kQs, jsonEncode(_qs.map((q) => q.toJson()).toList()));

  Future<void> _savePinned() async =>
      _prefs.setString(_kPinned, jsonEncode(_pinned.toList()));

  Future<void> _saveCollected() async => _prefs.setString(
      _kCollectedRibbons, jsonEncode(_collectedRibbons.toList()));

  Future<void> _saveOverrides() async =>
      _prefs.setString(_kOverrides, jsonEncode(_overrideCounts));

  /// AKC-reported pool count overrides. Used by the rules engine to
  /// bump `have` for Q-count titles when the user knows (from the AKC
  /// points report) they have more Qs than they've recorded.
  Map<String, int> overridesForDog(String dogId) {
    final out = <String, int>{};
    final prefix = '$dogId::';
    for (final entry in _overrideCounts.entries) {
      if (entry.key.startsWith(prefix)) {
        out[entry.key.substring(prefix.length)] = entry.value;
      }
    }
    return out;
  }

  int overrideForPool(String dogId, String poolKey) =>
      _overrideCounts['$dogId::$poolKey'] ?? 0;

  /// Set the override for a (dog, pool). Pass 0 to clear. Notifies
  /// listeners so the feed and detail pages refresh.
  Future<void> setOverride(String dogId, String poolKey, int count) async {
    final k = '$dogId::$poolKey';
    if (count <= 0) {
      _overrideCounts.remove(k);
    } else {
      _overrideCounts[k] = count;
    }
    await _saveOverrides();
    notifyListeners();
  }

  List<Dog> get dogs => List.unmodifiable(_dogs);
  List<Q> get qs => List.unmodifiable(_qs);
  Set<String> get pinnedCards => Set.unmodifiable(_pinned);

  Dog? dogById(String id) {
    for (final d in _dogs) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Case-insensitive lookup by call name. Used to merge duplicate
  /// entries.
  Dog? dogByName(String callName) {
    final norm = callName.trim().toLowerCase();
    for (final d in _dogs) {
      if (d.callName.toLowerCase() == norm) return d;
    }
    return null;
  }

  List<Q> qsForDog(String dogId) =>
      _qs.where((q) => q.dogId == dogId).toList(growable: false);

  /// Add a dog, or merge into an existing one if the call name matches
  /// (case-insensitive). Returns the resulting Dog and whether it was
  /// merged into an existing record.
  Future<({Dog dog, bool merged})> upsertDog(Dog dog) async {
    final existing = dogByName(dog.callName);
    if (existing != null && existing.id != dog.id) {
      final merged = existing.copyWith(
        callName: dog.callName,
        breed: dog.breed ?? existing.breed,
        heightInches: dog.heightInches ?? existing.heightInches,
        dateOfBirth: dog.dateOfBirth ?? existing.dateOfBirth,
        notes: dog.notes ?? existing.notes,
      );
      final i = _dogs.indexWhere((d) => d.id == existing.id);
      _dogs[i] = merged;
      await _saveDogs();
      notifyListeners();
      return (dog: merged, merged: true);
    }
    final i = _dogs.indexWhere((d) => d.id == dog.id);
    if (i >= 0) {
      _dogs[i] = dog;
    } else {
      _dogs.add(dog);
    }
    await _saveDogs();
    notifyListeners();
    return (dog: dog, merged: false);
  }

  Future<void> addDog(Dog dog) async {
    _dogs.add(dog);
    await _saveDogs();
    notifyListeners();
  }

  Future<void> updateDog(Dog dog) async {
    final i = _dogs.indexWhere((d) => d.id == dog.id);
    if (i < 0) return;
    _dogs[i] = dog;
    await _saveDogs();
    notifyListeners();
  }

  Future<void> deleteDog(String id) async {
    _dogs.removeWhere((d) => d.id == id);
    _qs.removeWhere((q) => q.dogId == id);
    await _saveDogs();
    await _saveQs();
    notifyListeners();
  }

  Future<void> addQ(Q q) async {
    _qs.add(q);
    await _saveQs();
    notifyListeners();
  }

  Future<void> updateQ(Q q) async {
    final i = _qs.indexWhere((x) => x.id == q.id);
    if (i < 0) return;
    _qs[i] = q;
    await _saveQs();
    notifyListeners();
  }

  Future<void> deleteQ(String id) async {
    _qs.removeWhere((q) => q.id == id);
    await _saveQs();
    notifyListeners();
  }

  bool isPinned(String cardId) => _pinned.contains(cardId);

  Future<void> togglePin(String cardId) async {
    if (!_pinned.add(cardId)) _pinned.remove(cardId);
    await _savePinned();
    notifyListeners();
  }

  /// Has the user marked the physical ribbon for this (dog, achievement)
  /// as collected? Used to suppress the "Don't forget your X ribbon!" tip.
  bool isRibbonCollected(String dogId, String achievementId) =>
      _collectedRibbons.contains('$dogId::$achievementId');

  Future<void> markRibbonCollected(String dogId, String achievementId) async {
    _collectedRibbons.add('$dogId::$achievementId');
    await _saveCollected();
    notifyListeners();
  }

  Future<void> unmarkRibbonCollected(String dogId, String achievementId) async {
    _collectedRibbons.remove('$dogId::$achievementId');
    await _saveCollected();
    notifyListeners();
  }

  /// Pull Qs for a single dog from the deployed JSON dataset. Called
  /// when the user saves a dog with an AKC ID — that's both the
  /// initial backfill and the "refresh now" lever (re-saving an
  /// already-imported dog picks up new YAML entries on the server).
  ///
  /// Idempotent: dedupe is by event identity (date + dog + sport +
  /// class/level/element/preferred + trial). Best-effort: any network
  /// or parse failure silently yields 0 new Qs (the user can retry by
  /// re-saving the dog).
  ///
  /// `loadQs` lets tests inject a fake fetcher.
  Future<int> backfillForDog(
    Dog dog, {
    Future<List<ImportedQ>> Function(String akcId, String dogId)? loadQs,
  }) async {
    final akcId = dog.akcId;
    if (akcId == null || akcId.isEmpty) return 0;
    final fetch = loadQs ?? loadQsForAkcId;
    List<ImportedQ> records;
    try {
      records = await fetch(akcId, dog.id);
    } catch (_) {
      return 0;
    }
    if (records.isEmpty) return 0;
    final existingKeys = <String>{for (final q in _qs) dedupeKeyFor(q)};
    final fresh = <Q>[];
    for (final r in records) {
      if (existingKeys.add(r.dedupeKey)) fresh.add(r.q);
    }
    if (fresh.isEmpty) return 0;
    _qs.addAll(fresh);
    await _saveQs();
    notifyListeners();
    return fresh.length;
  }

  /// Seed-data helper for first launch / testing.
  Future<void> seedSampleData() async {
    if (_dogs.isNotEmpty) return;
    final bandit = Dog.create(callName: 'Bandit', breed: 'Border Collie', heightInches: 21);
    _dogs.add(bandit);
    // A few Qs to make the feed lively on first launch.
    final base = DateTime(2026, 1, 11);
    final samples = <Q>[
      Q.create(dogId: bandit.id, date: base, agilityClass: AgilityClass.standard, level: AgilityLevel.novice, score: 100, timeSeconds: 41.2),
      Q.create(dogId: bandit.id, date: base.add(const Duration(days: 1)), agilityClass: AgilityClass.jww, level: AgilityLevel.novice, score: 100, timeSeconds: 39.5),
      Q.create(dogId: bandit.id, date: base.add(const Duration(days: 14)), agilityClass: AgilityClass.standard, level: AgilityLevel.novice, score: 100, timeSeconds: 43.8),
      Q.create(dogId: bandit.id, date: base.add(const Duration(days: 28)), agilityClass: AgilityClass.standard, level: AgilityLevel.novice, score: 100, timeSeconds: 42.4),
      Q.create(dogId: bandit.id, date: base.add(const Duration(days: 29)), agilityClass: AgilityClass.jww, level: AgilityLevel.novice, score: 100, timeSeconds: 36.0),
      Q.create(dogId: bandit.id, date: base.add(const Duration(days: 30)), agilityClass: AgilityClass.jww, level: AgilityLevel.novice, score: 100, timeSeconds: 38.2),
    ];
    _qs.addAll(samples);
    await _saveDogs();
    await _saveQs();
    notifyListeners();
  }
}
