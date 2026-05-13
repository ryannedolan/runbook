import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dog.dart';
import '../models/q.dart';

class Repo extends ChangeNotifier {
  Repo._(this._prefs);

  static const _kDogs = 'runbook.dogs';
  static const _kQs = 'runbook.qs';
  static const _kPinned = 'runbook.pinnedCards';

  final SharedPreferences _prefs;
  final List<Dog> _dogs = [];
  final List<Q> _qs = [];
  final Set<String> _pinned = {};

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
  }

  Future<void> _saveDogs() async =>
      _prefs.setString(_kDogs, jsonEncode(_dogs.map((d) => d.toJson()).toList()));

  Future<void> _saveQs() async =>
      _prefs.setString(_kQs, jsonEncode(_qs.map((q) => q.toJson()).toList()));

  Future<void> _savePinned() async =>
      _prefs.setString(_kPinned, jsonEncode(_pinned.toList()));

  List<Dog> get dogs => List.unmodifiable(_dogs);
  List<Q> get qs => List.unmodifiable(_qs);
  Set<String> get pinnedCards => Set.unmodifiable(_pinned);

  Dog? dogById(String id) {
    for (final d in _dogs) {
      if (d.id == id) return d;
    }
    return null;
  }

  List<Q> qsForDog(String dogId) =>
      _qs.where((q) => q.dogId == dogId).toList(growable: false);

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
