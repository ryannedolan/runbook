import '../models/dog.dart';
import '../models/q.dart';

/// Result of parsing one ribbon's worth of OCR text. Q is always
/// returned even when many fields couldn't be extracted — the user is
/// expected to review/edit before saving.
class ParsedRibbon {
  ParsedRibbon({
    required this.rawText,
    required this.q,
    required this.dogId,
    required this.matchedFields,
    this.confidenceNote,
  });

  /// Raw text (newline-joined) returned by ML Kit. Useful for the
  /// review UI to fall back on when parsing missed everything.
  final String rawText;

  /// Best-effort Q. Required fields (date / class / level) are filled
  /// with sentinel values when missing — the matchedFields set tells
  /// you which fields are real.
  final Q q;

  /// Dog ID if we matched a known call name; null otherwise.
  final String? dogId;

  /// Names of the fields we successfully extracted. Drives "needs
  /// review" highlighting in the UI.
  final Set<String> matchedFields;

  /// Short hint for the UI when nothing useful came out.
  final String? confidenceNote;

  /// True if the parser pulled out enough to be worth auto-capturing.
  /// We accept any of:
  ///   - dog + (any one field)
  ///   - sport + date
  ///   - 3+ matched fields (signal beats noise even with no dog/sport)
  /// Below this bar the ribbon goes into the "unparsed" pile and the
  /// user can still capture it manually via the Snap button.
  bool get isUseful {
    if (matchedFields.length >= 3) return true;
    if (matchedFields.contains('dog') && matchedFields.length >= 2) return true;
    if (matchedFields.contains('sport') &&
        matchedFields.contains('date')) {
      return true;
    }
    return false;
  }

  /// Stable text fingerprint used to skip duplicate captures within a
  /// single scan session. Lower-case alphanumerics only.
  String get textFingerprint {
    final norm = rawText.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return norm.length > 96 ? norm.substring(0, 96) : norm;
  }
}

/// Sport-aware parser. Construct with the user's dogs so we can
/// recognize call names; call [parse] with each frame's recognized
/// text.
class RibbonParser {
  RibbonParser({required this.dogs});

  final List<Dog> dogs;

  ParsedRibbon parse(String rawText) {
    final lines = _normalizeLines(rawText);
    final joined = lines.join(' ');
    final upper = joined.toUpperCase();
    final matched = <String>{};

    final dogId = _matchDog(lines);
    if (dogId != null) matched.add('dog');

    final date = _matchDate(joined);
    if (date != null) matched.add('date');

    final sport = _matchSport(upper);
    if (sport != null) matched.add('sport');

    final placement = _matchPlacement(upper);
    if (placement != null) matched.add('placement');

    // Sport branches: each returns a partial-but-typed Q.
    Q q;
    switch (sport) {
      case Sport.fastCAT:
        q = _fastCATQ(
            dogId: dogId,
            date: date,
            placement: placement,
            upper: upper,
            joined: joined,
            matched: matched);
        break;
      case Sport.scentwork:
        q = _scentworkQ(
            dogId: dogId,
            date: date,
            placement: placement,
            upper: upper,
            joined: joined,
            matched: matched);
        break;
      case Sport.akcAgility:
        q = _agilityQ(
            dogId: dogId,
            date: date,
            placement: placement,
            upper: upper,
            joined: joined,
            matched: matched);
        break;
      case null:
        // No sport keyword — default to agility (the common case for
        // unlabeled ribbons) and let the user pick during review.
        q = _agilityQ(
            dogId: dogId,
            date: date,
            placement: placement,
            upper: upper,
            joined: joined,
            matched: matched);
        break;
    }

    return ParsedRibbon(
      rawText: rawText,
      q: q,
      dogId: dogId,
      matchedFields: matched,
      confidenceNote: matched.isEmpty
          ? "Couldn't recognize any fields — try again or fill in manually."
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Dog matching: tokenize the OCR text and look for the call name as
  // a whole-token (case-insensitive). Falls back to substring match.
  // ---------------------------------------------------------------------------
  String? _matchDog(List<String> lines) {
    final hay = lines.join(' ').toLowerCase();
    final tokens = hay.split(RegExp(r'[^a-z0-9]+')).where((s) => s.isNotEmpty);
    final tokenSet = tokens.toSet();
    String? best;
    var bestLen = 0;
    for (final d in dogs) {
      final name = d.callName.trim().toLowerCase();
      if (name.isEmpty) continue;
      // Exact whole-word match wins. Multi-word names: all parts present.
      final parts = name.split(RegExp(r'\s+'));
      final allHit = parts.every(tokenSet.contains);
      final subHit = hay.contains(name);
      if (allHit || subHit) {
        if (name.length > bestLen) {
          best = d.id;
          bestLen = name.length;
        }
      }
    }
    return best;
  }

  // ---------------------------------------------------------------------------
  // Date matching.
  // ---------------------------------------------------------------------------
  static final _dateMonth = RegExp(
    r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|sept|oct|nov|dec)[a-z]*\.?\s+(\d{1,2})(?:,)?\s+(\d{4})\b',
    caseSensitive: false,
  );
  static final _dateSlash = RegExp(r'\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\b');
  static final _dateISO = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b');

  DateTime? _matchDate(String s) {
    final iso = _dateISO.firstMatch(s);
    if (iso != null) {
      final y = int.parse(iso.group(1)!);
      final mo = int.parse(iso.group(2)!);
      final d = int.parse(iso.group(3)!);
      return _safeDate(y, mo, d);
    }
    final mon = _dateMonth.firstMatch(s);
    if (mon != null) {
      final m = _monthFromName(mon.group(1)!);
      final d = int.parse(mon.group(2)!);
      final y = int.parse(mon.group(3)!);
      if (m != null) return _safeDate(y, m, d);
    }
    final sl = _dateSlash.firstMatch(s);
    if (sl != null) {
      final a = int.parse(sl.group(1)!);
      final b = int.parse(sl.group(2)!);
      var c = int.parse(sl.group(3)!);
      if (c < 100) c += 2000;
      // US ribbons: MM/DD/YYYY. Heuristic: if a > 12, swap.
      if (a > 12 && b <= 12) return _safeDate(c, b, a);
      return _safeDate(c, a, b);
    }
    return null;
  }

  int? _monthFromName(String s) {
    const m = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };
    return m[s.toLowerCase().substring(0, 3)];
  }

  DateTime? _safeDate(int y, int m, int d) {
    if (y < 1990 || y > 2100) return null;
    if (m < 1 || m > 12) return null;
    if (d < 1 || d > 31) return null;
    return DateTime(y, m, d);
  }

  // ---------------------------------------------------------------------------
  // Sport detection. FastCAT and Scentwork have very strong keyword
  // cues; agility is the catch-all when class/level words appear.
  // ---------------------------------------------------------------------------
  Sport? _matchSport(String upper) {
    if (RegExp(r'\bFASTCAT\b|\bFAST\s*CAT\b|\bBCAT\b|\bDCAT\b|\bFCAT\b|\bMPH\b')
        .hasMatch(upper)) {
      return Sport.fastCAT;
    }
    if (RegExp(r'\bSCENT\s*WORK\b|\bCONTAINER\b|\bINTERIOR\b|\bEXTERIOR\b|\bBURIED\b|\bHANDLER\s+DISCRIMINATION\b')
        .hasMatch(upper)) {
      // Don't false-positive on agility class hints
      if (!RegExp(r'\bSTANDARD\b|\bJWW\b|\bJUMPERS\b|\bT2B\b|\bTIME\s*2\s*BEAT\b')
          .hasMatch(upper)) {
        return Sport.scentwork;
      }
    }
    // Agility: strong cues (class/championship words) OR weaker cues
    // (level words, "AGILITY", "AKC", "QUALIFYING", "Q!"). The weaker
    // cues are still good enough to default to — agility is the most
    // common ribbon by far, and the user can swap sport in review.
    final strong = RegExp(
        r'\bSTANDARD\b|\bSTD\b|\bJWW\b|\bJUMPERS\b|\bT2B\b|\bTIME\s*2\s*BEAT\b|\bPREMIER\b|\bMACH\b|\bPACH\b');
    final weak = RegExp(
        r'\bAGILITY\b|\bAKC\b|\bQUALIFYING\b|\bNOVICE\b|\bOPEN\b|\bEXCELLENT\b|\bMASTER\b|\bPREFERRED\b|\bQ\b|\bNAJ\b|\bNAP\b');
    if (strong.hasMatch(upper) || weak.hasMatch(upper)) {
      return Sport.akcAgility;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Placement: "1st"/"First Place"/"PLACE: 1"/"PL 1"/"1 of 12".
  // ---------------------------------------------------------------------------
  int? _matchPlacement(String upper) {
    final ord = RegExp(r'\b(1ST|2ND|3RD|4TH|FIRST|SECOND|THIRD|FOURTH)\b');
    final m = ord.firstMatch(upper);
    if (m != null) {
      final t = m.group(1)!;
      if (t.startsWith('1') || t == 'FIRST') return 1;
      if (t.startsWith('2') || t == 'SECOND') return 2;
      if (t.startsWith('3') || t == 'THIRD') return 3;
      if (t.startsWith('4') || t == 'FOURTH') return 4;
    }
    // "Placement: 1", "PLACE: 1", "PL 1" — non-word chars between the
    // keyword and the number are fine. PLACEMENT has to come first
    // because PLACE is a substring of it (the regex alternation tries
    // alternatives left-to-right).
    final placeN =
        RegExp(r'\b(?:PLACEMENT|PLACE|PL)\b\W{0,4}([1-4])\b').firstMatch(upper);
    if (placeN != null) return int.tryParse(placeN.group(1)!);
    return null;
  }

  // ---------------------------------------------------------------------------
  // Agility-specific extraction.
  // ---------------------------------------------------------------------------
  Q _agilityQ({
    required String? dogId,
    required DateTime? date,
    required int? placement,
    required String upper,
    required String joined,
    required Set<String> matched,
  }) {
    AgilityClass cls = AgilityClass.standard;
    var clsMatched = false;
    AgilityLevel level = AgilityLevel.novice;
    var levelMatched = false;

    // Premier shows up as "PREMIER" or the abbrev "PRM" on ribbon
    // stickers. Don't confuse with the trailing "P" suffix that marks
    // the Preferred division (handled below).
    final isPremier = upper.contains('PREMIER') ||
        RegExp(r'\bPRM\b').hasMatch(upper);

    // Try the AKC class+level shorthand first — it disambiguates both
    // fields at once and works even when OCR concatenates the two (no
    // whitespace) or drops the trailing letter boundary. Higher
    // priority than the individual class/level keyword sweeps.
    final shorthand = RegExp(
      r'\b(STD|STANDARD|JW|JWW|JUMPERS|FAST|T2B|PRM|PREMIER)\s*'
      r'(MASTER|MAST|MAS|MSTR|EXCELLENT|EXCEL|EXC|EX|OPEN|OPN|NOVICE|NOV)\b',
    ).firstMatch(upper);
    if (shorthand != null) {
      final clsRaw = shorthand.group(1)!;
      final lvlRaw = shorthand.group(2)!;
      // Resolve class. PRM/PREMIER + JW⇒premierJww; PRM alone ⇒
      // premierStandard. JUMPERS or JW(W) ⇒ jww; FAST ⇒ fast etc.
      if (isPremier) {
        cls = (clsRaw.startsWith('JW') || clsRaw == 'JUMPERS')
            ? AgilityClass.premierJww
            : AgilityClass.premierStandard;
      } else if (clsRaw == 'JW' || clsRaw == 'JWW' || clsRaw == 'JUMPERS') {
        cls = AgilityClass.jww;
      } else if (clsRaw == 'FAST') {
        cls = AgilityClass.fast;
      } else if (clsRaw == 'T2B') {
        cls = AgilityClass.t2b;
      } else {
        cls = AgilityClass.standard;
      }
      clsMatched = true;
      if (lvlRaw.startsWith('MAS') || lvlRaw == 'MSTR') {
        level = AgilityLevel.master;
      } else if (lvlRaw.startsWith('EX')) {
        level = AgilityLevel.excellent;
      } else if (lvlRaw.startsWith('OP')) {
        level = AgilityLevel.open;
      } else {
        level = AgilityLevel.novice;
      }
      levelMatched = true;
    }

    // If shorthand didn't fire, fall back to scanning class and level
    // independently — handles cases where the two appear in separate
    // lines / fields.
    if (!clsMatched) {
      if (isPremier) {
        cls = RegExp(r'JWW|\bJW\b|JUMPERS').hasMatch(upper)
            ? AgilityClass.premierJww
            : AgilityClass.premierStandard;
        clsMatched = true;
      } else if (RegExp(r'\bT2B\b|\bT2BP\b|TIME\s*2\s*BEAT|TIME\s*TO\s*BEAT')
          .hasMatch(upper)) {
        cls = AgilityClass.t2b;
        clsMatched = true;
      } else if (RegExp(r'\bJWW\b|\bJW\b|JUMPERS\s+WITH\s+WEAVES|\bJUMPERS\b')
          .hasMatch(upper)) {
        cls = AgilityClass.jww;
        clsMatched = true;
      } else if (RegExp(r'\bFAST\b').hasMatch(upper) &&
          !RegExp(r'FAST\s*CAT').hasMatch(upper)) {
        cls = AgilityClass.fast;
        clsMatched = true;
      } else if (RegExp(r'\bSTANDARD\b|\bSTD\b').hasMatch(upper)) {
        cls = AgilityClass.standard;
        clsMatched = true;
      }
    }
    if (!levelMatched) {
      // Standalone level keyword anywhere — highest first.
      if (RegExp(r'\bMASTER\b|\bMAST\b|\bMAS\b|\bMSTR\b').hasMatch(upper)) {
        level = AgilityLevel.master;
        levelMatched = true;
      } else if (RegExp(r'\bEXCELLENT\b|\bEXCEL\b|\bEXC\b|\bEX\b')
          .hasMatch(upper)) {
        level = AgilityLevel.excellent;
        levelMatched = true;
      } else if (RegExp(r'\bOPEN\b|\bOPN\b').hasMatch(upper)) {
        level = AgilityLevel.open;
        levelMatched = true;
      } else if (RegExp(r'\bNOVICE\b|\bNOV\b').hasMatch(upper)) {
        level = AgilityLevel.novice;
        levelMatched = true;
      }
    }
    if (clsMatched) matched.add('agilityClass');
    if (cls.isPremier || cls == AgilityClass.t2b) {
      // Premier and T2B are Master-only — no level field on the ribbon.
      level = AgilityLevel.master;
      levelMatched = true;
    }
    if (levelMatched) matched.add('level');

    // Preferred shorthand: "MAS P", "JW MAS P", "STD P", or a Preferred
    // title acronym (NAP/OAP/AXP/MXP/NJP/OJP/AJP/MJP/T2BP/PAX). Be
    // careful not to flag the leading P in "PRM" — `\bP\b` won't
    // match there because R is a word char.
    final preferred = RegExp(r'\bPREFERRED\b|\bPREF\b').hasMatch(upper) ||
        RegExp(r'\b(STD|JW|JWW|FAST|T2B|NOV|OPN|OPEN|EXC|EXCELLENT|MAS|MASTER|PRM|PREMIER)\s+P\b')
            .hasMatch(upper) ||
        RegExp(r'\b(NAP|OAP|AXP|MXP|NJP|OJP|AJP|MJP|T2BP|PAX|PAD|PAJ|PAJP|PNAC|PNAP|PNJC|PNJP)\b')
            .hasMatch(upper);
    if (preferred) matched.add('preferred');

    final time = _extractTime(joined);
    if (time != null) matched.add('timeSeconds');

    final yards = _extractYards(joined);
    if (yards != null) matched.add('yards');

    final ypsOverride = _extractYps(joined);
    if (ypsOverride != null) matched.add('yps');

    final sct = _extractSct(joined);
    if (sct != null) matched.add('sct');

    final scannedMach = _extractMachPoints(joined);
    final eligibleForMach = level == AgilityLevel.master &&
        !cls.isPremier &&
        (cls == AgilityClass.standard || cls == AgilityClass.jww);
    int? computedMach;
    if (eligibleForMach && sct != null && time != null) {
      computedMach = Q.computeMachPoints(sct: sct, timeSeconds: time);
    }
    // Prefer computed over scanned (we trust math over OCR), but if
    // they disagree by more than 2 flag it for review in the notes.
    int? mach;
    String? mismatchNote;
    if (computedMach != null) {
      mach = computedMach;
      if (scannedMach != null && (scannedMach - computedMach).abs() > 2) {
        mismatchNote =
            'Points: scanned $scannedMach but $sct s SCT − ${time!.toStringAsFixed(2)} s '
            '= $computedMach. Review.';
      }
    } else if (scannedMach != null) {
      mach = scannedMach;
    }
    if (mach != null) matched.add('machPoints');

    final score = _extractScore(joined, cls);
    if (score != null) matched.add('score');

    return Q.create(
      dogId: dogId ?? '',
      date: date ?? DateTime.now(),
      sport: Sport.akcAgility,
      agilityClass: cls,
      level: level,
      preferred: preferred,
      placement: placement,
      timeSeconds: time,
      yards: yards,
      score: score,
      machPoints: mach ?? 0,
      sct: sct,
      ypsOverride: ypsOverride,
      notes: mismatchNote,
    );
  }

  Q _fastCATQ({
    required String? dogId,
    required DateTime? date,
    required int? placement,
    required String upper,
    required String joined,
    required Set<String> matched,
  }) {
    final mph = RegExp(r'(\d{1,2}\.\d{1,3})\s*MPH', caseSensitive: false)
        .firstMatch(joined);
    double? speed = mph != null ? double.tryParse(mph.group(1)!) : null;
    // Time: usually 7.xx to 12.xx seconds; appears as "8.45 sec" or
    // bare "8.45". If we already have speed, prefer the *other* decimal.
    final time = _extractFastCATTime(joined, speed);
    if (time != null) matched.add('timeSeconds');
    final points = _extractFastCATPoints(joined);
    if (points != null) matched.add('score');
    final trial = _extractTrial(joined);
    if (trial != null) matched.add('trial');

    return Q.create(
      dogId: dogId ?? '',
      date: date ?? DateTime.now(),
      sport: Sport.fastCAT,
      agilityClass: AgilityClass.fast,
      level: AgilityLevel.novice,
      placement: placement,
      timeSeconds: time,
      score: points,
      trial: trial,
    );
  }

  Q _scentworkQ({
    required String? dogId,
    required DateTime? date,
    required int? placement,
    required String upper,
    required String joined,
    required Set<String> matched,
  }) {
    ScentElement? element;
    if (upper.contains('CONTAINER')) {
      element = ScentElement.container;
    } else if (upper.contains('INTERIOR')) {
      element = ScentElement.interior;
    } else if (upper.contains('EXTERIOR')) {
      element = ScentElement.exterior;
    } else if (upper.contains('BURIED')) {
      element = ScentElement.buried;
    }
    if (element != null) matched.add('scentElement');

    ScentLevel? level;
    if (upper.contains('DETECTIVE')) {
      level = ScentLevel.detective;
    } else if (RegExp(r'\bMASTER\b').hasMatch(upper)) {
      level = ScentLevel.master;
    } else if (RegExp(r'\bEXCELLENT\b').hasMatch(upper)) {
      level = ScentLevel.excellent;
    } else if (RegExp(r'\bADVANCED\b').hasMatch(upper)) {
      level = ScentLevel.advanced;
    } else if (RegExp(r'\bNOVICE\b').hasMatch(upper)) {
      level = ScentLevel.novice;
    }
    if (level != null) matched.add('scentLevel');

    final time = _extractSearchTime(joined);
    if (time != null) matched.add('timeSeconds');

    return Q.create(
      dogId: dogId ?? '',
      date: date ?? DateTime.now(),
      sport: Sport.scentwork,
      agilityClass: AgilityClass.fast,
      level: AgilityLevel.novice,
      placement: placement,
      timeSeconds: time,
      scentElement: element,
      scentLevel: level,
    );
  }

  // ---------------------------------------------------------------------------
  // Field extractors.
  // ---------------------------------------------------------------------------
  double? _extractTime(String s) {
    final labeled = RegExp(
            r'(?:TIME|RUN\s*TIME|COURSE\s*TIME)\D{0,6}(\d{1,3}\.\d{1,3})',
            caseSensitive: false)
        .firstMatch(s);
    if (labeled != null) return double.tryParse(labeled.group(1)!);
    // Bare decimal with "sec" or "s" suffix.
    final secSuffix =
        RegExp(r'(\d{1,3}\.\d{1,3})\s*(?:SEC|S\b)', caseSensitive: false)
            .firstMatch(s);
    if (secSuffix != null) return double.tryParse(secSuffix.group(1)!);
    return null;
  }

  double? _extractYards(String s) {
    final m = RegExp(r'(?:YARDS|YDS|YARDAGE)\D{0,6}(\d{2,4})',
            caseSensitive: false)
        .firstMatch(s);
    if (m != null) return double.tryParse(m.group(1)!);
    final n = RegExp(r'(\d{2,4})\s*(?:YDS|YARDS)\b', caseSensitive: false)
        .firstMatch(s);
    if (n != null) return double.tryParse(n.group(1)!);
    return null;
  }

  /// Yards-per-second — "4.13 YPS", "YPS: 4.13", "Y.P.S. 4.13".
  double? _extractYps(String s) {
    final m = RegExp(r'(\d{1,2}\.\d{1,3})\s*YPS', caseSensitive: false)
        .firstMatch(s);
    if (m != null) return double.tryParse(m.group(1)!);
    final n = RegExp(r'\bY\.?\s*P\.?\s*S\.?\b\W{0,4}(\d{1,2}\.\d{1,3})',
            caseSensitive: false)
        .firstMatch(s);
    if (n != null) return double.tryParse(n.group(1)!);
    return null;
  }

  /// Standard Course Time. Tolerates "SCT 58", "SCT: 58.45", "S.C.T.
  /// 58.123", "Standard Course Time 58", "Course Time: 58", and up to
  /// 3 decimal places.
  double? _extractSct(String s) {
    // SCT acronym, optionally dotted (S.C.T.).
    final m = RegExp(
            r'\bS\.?\s*C\.?\s*T\.?\b\W{0,6}(\d{1,3}(?:\.\d{1,3})?)',
            caseSensitive: false)
        .firstMatch(s);
    if (m != null) return double.tryParse(m.group(1)!);
    // Full phrase, "Standard Course Time" or just "Course Time".
    final n = RegExp(
            r'(?:STANDARD\s*COURSE\s*TIME|COURSE\s*TIME)\W{0,6}(\d{1,3}(?:\.\d{1,3})?)',
            caseSensitive: false)
        .firstMatch(s);
    if (n != null) return double.tryParse(n.group(1)!);
    return null;
  }

  int? _extractMachPoints(String s) {
    final m = RegExp(r'(?:MACH|PACH)\s*(?:PTS|POINTS)?\D{0,4}(\d{1,3})',
            caseSensitive: false)
        .firstMatch(s);
    if (m != null) return int.tryParse(m.group(1)!);
    return null;
  }

  int? _extractScore(String s, AgilityClass cls) {
    final m = RegExp(r'\bSCORE\D{0,4}(\d{1,3})\b', caseSensitive: false)
        .firstMatch(s);
    if (m != null) return int.tryParse(m.group(1)!);
    if (cls == AgilityClass.fast) {
      final f =
          RegExp(r'(?:FAST\s*PTS|FAST\s*POINTS|POINTS)\D{0,4}(\d{1,3})',
                  caseSensitive: false)
              .firstMatch(s);
      if (f != null) return int.tryParse(f.group(1)!);
    }
    return null;
  }

  double? _extractFastCATTime(String s, double? speed) {
    final labeled = RegExp(r'(?:TIME)\D{0,6}(\d{1,2}\.\d{1,3})',
            caseSensitive: false)
        .firstMatch(s);
    if (labeled != null) return double.tryParse(labeled.group(1)!);
    final sec = RegExp(r'(\d{1,2}\.\d{1,3})\s*(?:SEC|S\b)', caseSensitive: false)
        .firstMatch(s);
    if (sec != null) {
      final t = double.tryParse(sec.group(1)!);
      if (t != null && (speed == null || (t - speed).abs() > 1)) return t;
    }
    return null;
  }

  int? _extractFastCATPoints(String s) {
    final m = RegExp(r'(\d{1,3})\s*(?:PTS|POINTS)\b', caseSensitive: false)
        .firstMatch(s);
    if (m != null) return int.tryParse(m.group(1)!);
    return null;
  }

  String? _extractTrial(String s) {
    final m =
        RegExp(r'TRIAL\s*(?:#|NO\.?)?\s*(\d+)', caseSensitive: false).firstMatch(s);
    if (m != null) return 'Trial ${m.group(1)}';
    return null;
  }

  double? _extractSearchTime(String s) {
    final mmss =
        RegExp(r'\b(\d{1,2}):(\d{2})(?:[.:](\d{1,2}))?\b').firstMatch(s);
    if (mmss != null) {
      final mm = int.parse(mmss.group(1)!);
      final ss = int.parse(mmss.group(2)!);
      final hh = mmss.group(3) != null ? int.parse(mmss.group(3)!) : 0;
      return mm * 60 + ss + hh / 100.0;
    }
    final bare = RegExp(r'(?:SEARCH\s*TIME|TIME)\D{0,6}(\d{1,3}\.\d{1,3})',
            caseSensitive: false)
        .firstMatch(s);
    if (bare != null) return double.tryParse(bare.group(1)!);
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers.
  // ---------------------------------------------------------------------------
  List<String> _normalizeLines(String raw) {
    return raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }
}
