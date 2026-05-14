import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dog.dart';
import '../models/event.dart';
import '../models/q.dart';

class Repo extends ChangeNotifier {
  Repo._(this._prefs);

  static const _kDogs = 'runbook.dogs';
  static const _kQs = 'runbook.qs';
  static const _kEvents = 'runbook.events';
  static const _kPinned = 'runbook.pinnedCards';
  static const _kCollectedRibbons = 'runbook.collectedRibbons';

  final SharedPreferences _prefs;
  final List<Dog> _dogs = [];
  final List<Q> _qs = [];
  final List<Event> _events = [];
  final Set<String> _pinned = {};
  final Set<String> _collectedRibbons = {};

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
    final eventsJson = _prefs.getString(_kEvents);
    if (eventsJson != null) {
      final list = jsonDecode(eventsJson) as List<dynamic>;
      _events
        ..clear()
        ..addAll(list.map((j) => Event.fromJson(j as Map<String, dynamic>)));
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

  Future<void> _saveEvents() async => _prefs.setString(
      _kEvents, jsonEncode(_events.map((e) => e.toJson()).toList()));

  Future<void> _savePinned() async =>
      _prefs.setString(_kPinned, jsonEncode(_pinned.toList()));

  Future<void> _saveCollected() async => _prefs.setString(
      _kCollectedRibbons, jsonEncode(_collectedRibbons.toList()));

  List<Dog> get dogs => List.unmodifiable(_dogs);
  List<Q> get qs => List.unmodifiable(_qs);
  List<Event> get events => List.unmodifiable(_events);
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
    _events.removeWhere((e) => e.dogId == id);
    await _saveDogs();
    await _saveQs();
    await _saveEvents();
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

  List<Event> eventsForDog(String dogId) =>
      _events.where((e) => e.dogId == dogId).toList(growable: false);

  Future<void> addEvent(Event e) async {
    _events.add(e);
    await _saveEvents();
    notifyListeners();
  }

  Future<void> updateEvent(Event e) async {
    final i = _events.indexWhere((x) => x.id == e.id);
    if (i < 0) return;
    _events[i] = e;
    await _saveEvents();
    notifyListeners();
  }

  Future<void> deleteEvent(String id) async {
    _events.removeWhere((e) => e.id == id);
    await _saveEvents();
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
