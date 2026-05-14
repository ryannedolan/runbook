import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/q.dart';
import '../../rules/achievement.dart';

// ============================================================================
// Pixel sprite infrastructure
// ----------------------------------------------------------------------------
// Sprites are defined as a list of equal-length row strings; an attached
// palette maps each character to a Color (or null for transparent). At
// paint time each cell becomes a scale-by-scale block with anti-aliasing
// off — that gives the crisp 8-bit feel.
// ============================================================================

class PixelSprite {
  PixelSprite({required this.rows, required this.palette})
      : assert(rows.isNotEmpty),
        width = rows.first.length,
        height = rows.length {
    for (final r in rows) {
      assert(r.length == width, 'sprite rows must all be the same width');
    }
  }

  final List<String> rows;
  final Map<String, Color?> palette;
  final int width;
  final int height;
}

class PixelIcon extends StatelessWidget {
  const PixelIcon({super.key, required this.sprite, this.scale = 2});
  final PixelSprite sprite;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: sprite.width * scale,
      height: sprite.height * scale,
      child: CustomPaint(painter: _SpritePainter(sprite, scale)),
    );
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.sprite, this.scale);
  final PixelSprite sprite;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    for (var y = 0; y < sprite.height; y++) {
      final row = sprite.rows[y];
      for (var x = 0; x < sprite.width; x++) {
        final c = sprite.palette[row[x]];
        if (c == null) continue;
        p.color = c;
        canvas.drawRect(
          Rect.fromLTWH(x * scale, y * scale, scale + 0.5, scale + 0.5),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.sprite != sprite || old.scale != scale;
}

// ============================================================================
// Flat ribbons (Qs)
// ----------------------------------------------------------------------------
// Real-world Qs are flat ribbons with pinked bottoms — agility/scentwork
// are green, FastCAT is light blue.
// ============================================================================

const _flatRibbonRows = <String>[
  '..MMMMMM..', //  0  top tip
  '.LMMMMMMD.', //  1
  'LMHMMMMMMD', //  2  shoulders + sheen
  'LMHMMMMMMD', //  3
  'LMHMMMMMMD', //  4
  'LMHMMMMMMD', //  5
  'LMHMMMMMMD', //  6
  'LMHMMMMMMD', //  7
  'LMHMMMMMMD', //  8
  'LMHMMMMMMD', //  9
  'LMMMMMMMMD', // 10
  'MMMMMMMMMM', // 11  pinking base
  '.D.M.M.M.D', // 12  alternating teeth
];

class FlatRibbonPalette {
  const FlatRibbonPalette({
    required this.light,
    required this.mid,
    required this.dark,
    this.sheen = Colors.white,
  });
  final Color light;
  final Color mid;
  final Color dark;
  final Color sheen;
}

const _qGreen = FlatRibbonPalette(
  light: Color(0xFF7BD18A),
  mid: Color(0xFF2E8B57),
  dark: Color(0xFF143B23),
);
const _qFastCATBlue = FlatRibbonPalette(
  light: Color(0xFF9DCEF5),
  mid: Color(0xFF4090D8),
  dark: Color(0xFF1B4870),
);

PixelSprite _flatRibbonSprite(FlatRibbonPalette p) => PixelSprite(
      rows: _flatRibbonRows,
      palette: {
        '.': null,
        'L': p.light,
        'M': p.mid,
        'D': p.dark,
        'H': p.sheen,
      },
    );

class PixelFlatRibbon extends StatelessWidget {
  const PixelFlatRibbon._({required this.palette, this.scale = 2});
  final FlatRibbonPalette palette;
  final double scale;

  factory PixelFlatRibbon.forQ(Q q, {double scale = 2}) =>
      PixelFlatRibbon._(palette: _qGreen, scale: scale);

  factory PixelFlatRibbon.agility({double scale = 2}) =>
      PixelFlatRibbon._(palette: _qGreen, scale: scale);

  factory PixelFlatRibbon.fastCAT({double scale = 2}) =>
      PixelFlatRibbon._(palette: _qFastCATBlue, scale: scale);

  @override
  Widget build(BuildContext context) =>
      PixelIcon(sprite: _flatRibbonSprite(palette), scale: scale);
}

/// A Q ribbon optionally paired with a placement rosette to its right.
class PixelQRibbonPair extends StatelessWidget {
  const PixelQRibbonPair({super.key, required this.q, this.scale = 2});
  final Q q;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final placement = PixelRosette.forPlacement(q.placement, scale: scale);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PixelFlatRibbon.forQ(q, scale: scale),
        if (placement != null) ...[
          SizedBox(width: scale * 1.5),
          placement,
        ],
      ],
    );
  }
}

// ============================================================================
// Rosettes (titles, placements, achievements)
// ----------------------------------------------------------------------------
// Drawn procedurally so a single definition scales to any size: pleated
// wheel (alternating light/dark sectors), thin gold ring with diagonal
// shading, medallion in the center, then two forked tails below with
// pinked ends. The medallion can carry a symbol overlay (paw/heart/star)
// or a system-font text label (1st, NA, MACH, ...).
// ============================================================================

enum RosetteSymbol { none, paw, heart, star }

class RosetteStyle {
  const RosetteStyle({
    required this.pleatDark,
    required this.pleatLight,
    required this.pleatRim,
    required this.goldOuter,
    required this.goldInner,
    required this.medallion,
    required this.medallionEdge,
    required this.tailBase,
    required this.tailHighlight,
    required this.tailDark,
    this.symbol = RosetteSymbol.none,
    this.symbolMain,
    this.symbolHighlight,
    this.label,
  });

  final Color pleatDark;
  final Color pleatLight;
  final Color pleatRim;
  final Color goldOuter;
  final Color goldInner;
  final Color medallion;
  final Color medallionEdge;
  final Color tailBase;
  final Color tailHighlight;
  final Color tailDark;
  final RosetteSymbol symbol;
  final Color? symbolMain;
  final Color? symbolHighlight;

  /// Optional text shown over the medallion (e.g. "1st", "MACH", "QQ").
  final String? label;
}

class PixelRosette extends StatelessWidget {
  const PixelRosette({
    super.key,
    required this.style,
    this.wheelSize = 24,
    this.scale = 2,
    this.dimmed = false,
  }) : assert(wheelSize >= 10);

  /// Picks a style automatically based on the achievement type.
  factory PixelRosette.forAchievement(
    Achievement a, {
    double scale = 3,
    int wheelSize = 24,
    bool dimmed = false,
    Key? key,
  }) {
    return PixelRosette(
      key: key,
      style: _styleForAchievement(a),
      wheelSize: wheelSize,
      scale: scale,
      dimmed: dimmed,
    );
  }

  /// Mini placement rosette for inline use next to a Q ribbon. Returns
  /// null when there is no placement (1..4).
  static PixelRosette? forPlacement(int? placement, {double scale = 2}) {
    final style = _placementStyle(placement);
    if (style == null) return null;
    return PixelRosette(style: style, wheelSize: 12, scale: scale);
  }

  final RosetteStyle style;
  final int wheelSize;
  final double scale;
  final bool dimmed;

  int get _tailHeight => (wheelSize * 0.46).round();
  int get _totalHeight => wheelSize + _tailHeight;

  @override
  Widget build(BuildContext context) {
    final size = Size(wheelSize * scale, _totalHeight * scale);
    final label = style.label;
    return Opacity(
      opacity: dimmed ? 0.45 : 1.0,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            CustomPaint(
              size: size,
              painter: _RosettePainter(
                style: style,
                wheelSize: wheelSize,
                tailHeight: _tailHeight,
                scale: scale,
              ),
            ),
            if (label != null)
              Positioned(
                top: scale * wheelSize * 0.34,
                child: SizedBox(
                  width: wheelSize * scale,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: scale * _labelSizeFor(label, wheelSize),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1B1B1B),
                      height: 1.0,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static double _labelSizeFor(String s, int wheelSize) {
    final base = wheelSize * 0.32;
    if (s.length >= 5) return base * 0.45;
    if (s.length == 4) return base * 0.55;
    if (s.length == 3) return base * 0.7;
    return base * 0.9;
  }
}

class _RosettePainter extends CustomPainter {
  _RosettePainter({
    required this.style,
    required this.wheelSize,
    required this.tailHeight,
    required this.scale,
  });

  final RosetteStyle style;
  final int wheelSize;
  final int tailHeight;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    final cx = wheelSize / 2.0;
    final cy = wheelSize / 2.0;
    final outerR = wheelSize / 2.0;
    final pleatWidth = (wheelSize / 6.5).clamp(2.0, 5.5);
    final goldWidth = (wheelSize / 11).clamp(1.0, 2.5);
    final pleatInnerR = outerR - pleatWidth;
    final goldInnerR = pleatInnerR - goldWidth;
    final medallionR = goldInnerR;
    final pleatCount = wheelSize >= 20 ? 14 : 8;

    _paintTails(canvas, p);
    _paintWheel(
      canvas, p,
      cx: cx, cy: cy,
      outerR: outerR,
      pleatInnerR: pleatInnerR,
      goldInnerR: goldInnerR,
      medallionR: medallionR,
      pleatCount: pleatCount,
    );
    if (style.symbol != RosetteSymbol.none) {
      _paintSymbol(canvas, p, cx: cx, cy: cy);
    }
  }

  void _paintWheel(
    Canvas canvas,
    Paint p, {
    required double cx,
    required double cy,
    required double outerR,
    required double pleatInnerR,
    required double goldInnerR,
    required double medallionR,
    required int pleatCount,
  }) {
    for (var y = 0; y < wheelSize; y++) {
      for (var x = 0; x < wheelSize; x++) {
        final dx = x + 0.5 - cx;
        final dy = y + 0.5 - cy;
        final d = math.sqrt(dx * dx + dy * dy);
        Color? c;
        if (d > outerR) {
          c = null;
        } else if (d > outerR - 0.65) {
          c = style.pleatRim;
        } else if (d > pleatInnerR) {
          final angle = math.atan2(dy, dx);
          final t = (angle / (2 * math.pi) + 0.5) * pleatCount * 2;
          c = (t.floor() % 2 == 0) ? style.pleatDark : style.pleatLight;
        } else if (d > pleatInnerR - 0.8) {
          c = style.pleatRim;
        } else if (d > goldInnerR) {
          // diagonal lighting on gold ring (upper-left lit)
          final lit = (dx + dy) < 0;
          c = lit ? style.goldOuter : style.goldInner;
        } else if (d > medallionR - 0.6) {
          c = style.medallionEdge;
        } else {
          c = style.medallion;
        }
        if (c == null) continue;
        p.color = c;
        canvas.drawRect(
          Rect.fromLTWH(x * scale, y * scale, scale + 0.5, scale + 0.5),
          p,
        );
      }
    }
  }

  void _paintTails(Canvas canvas, Paint p) {
    final isSmall = wheelSize < 18;
    final tailTopY = wheelSize - 1;
    final joinedHeight =
        (tailHeight * 0.35).round().clamp(2, 6);

    void drawPixel(int x, int y, int relX, int width, bool isLastRow) {
      if (isLastRow && relX.isOdd) return; // pinking
      Color c;
      if (relX == 0) {
        c = style.tailHighlight;
      } else if (relX == width - 1) {
        c = style.tailDark;
      } else {
        c = style.tailBase;
      }
      p.color = c;
      canvas.drawRect(
        Rect.fromLTWH(x * scale, y * scale, scale + 0.5, scale + 0.5),
        p,
      );
    }

    if (isSmall) {
      // single centered tail
      final width = (wheelSize / 3).round().clamp(3, 6);
      final left = ((wheelSize - width) / 2).floor();
      for (var ry = 0; ry < tailHeight; ry++) {
        final y = tailTopY + ry;
        final isLastRow = ry == tailHeight - 1;
        for (var i = 0; i < width; i++) {
          drawPixel(left + i, y, i, width, isLastRow);
        }
      }
      return;
    }

    final tailWidth = (wheelSize / 5.5).round().clamp(3, 5);
    final gap = (wheelSize / 16).round().clamp(0, 2);
    final centerX = wheelSize / 2.0;
    final leftStart = (centerX - tailWidth - gap / 2).floor();
    final rightStart = (centerX + gap / 2).ceil();

    for (var ry = 0; ry < tailHeight; ry++) {
      final y = tailTopY + ry;
      final isLastRow = ry == tailHeight - 1;
      final joined = ry < joinedHeight;
      if (joined) {
        final totalW = (rightStart + tailWidth) - leftStart;
        for (var i = 0; i < totalW; i++) {
          drawPixel(leftStart + i, y, i, totalW, isLastRow);
        }
      } else {
        for (var i = 0; i < tailWidth; i++) {
          drawPixel(leftStart + i, y, i, tailWidth, isLastRow);
        }
        for (var i = 0; i < tailWidth; i++) {
          drawPixel(rightStart + i, y, i, tailWidth, isLastRow);
        }
      }
    }
  }

  void _paintSymbol(
    Canvas canvas,
    Paint p, {
    required double cx,
    required double cy,
  }) {
    final sprite = _symbolSpriteRows(style.symbol);
    if (sprite == null) return;
    final w = sprite[0].length;
    final h = sprite.length;
    final originX = (cx - w / 2.0).round();
    final originY = (cy - h / 2.0).round();
    final main = style.symbolMain ?? style.pleatDark;
    final hi = style.symbolHighlight ?? style.medallionEdge;
    for (var ry = 0; ry < h; ry++) {
      for (var rx = 0; rx < w; rx++) {
        final ch = sprite[ry][rx];
        if (ch == '.') continue;
        p.color = ch == 'X' ? main : hi;
        canvas.drawRect(
          Rect.fromLTWH(
            (originX + rx) * scale,
            (originY + ry) * scale,
            scale + 0.5,
            scale + 0.5,
          ),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RosettePainter old) =>
      old.style != style ||
      old.wheelSize != wheelSize ||
      old.tailHeight != tailHeight ||
      old.scale != scale;
}

// 5×5 symbol sprites stamped onto the medallion.
const _pawSymbol = <String>[
  '.X.X.',
  'X...X',
  '.....',
  '.XXX.',
  '.XXX.',
];
const _heartSymbol = <String>[
  '.....',
  'XX.XX',
  'XXXXX',
  '.XXX.',
  '..X..',
];
const _starSymbol = <String>[
  '..X..',
  '.XXX.',
  'XXXXX',
  '.XXX.',
  '.X.X.',
];

List<String>? _symbolSpriteRows(RosetteSymbol s) => switch (s) {
      RosetteSymbol.none => null,
      RosetteSymbol.paw => _pawSymbol,
      RosetteSymbol.heart => _heartSymbol,
      RosetteSymbol.star => _starSymbol,
    };

// ----------------------------------------------------------------------------
// Palette presets
// ----------------------------------------------------------------------------

const _goldDeep = Color(0xFFA67A00);
const _goldLight = Color(0xFFFFE891);
const _ivory = Color(0xFFFFF6D0);

RosetteStyle _wheel({
  required Color dark,
  required Color mid,
  required Color light,
  Color? medallion,
  Color? medallionEdge,
  Color? goldOuter,
  Color? goldInner,
  RosetteSymbol symbol = RosetteSymbol.none,
  Color? symbolMain,
  Color? symbolHighlight,
  String? label,
}) {
  return RosetteStyle(
    pleatDark: mid,
    pleatLight: light,
    pleatRim: dark,
    goldOuter: goldOuter ?? _goldLight,
    goldInner: goldInner ?? _goldDeep,
    medallion: medallion ?? Colors.white,
    medallionEdge: medallionEdge ?? dark,
    tailBase: mid,
    tailHighlight: light,
    tailDark: dark,
    symbol: symbol,
    symbolMain: symbolMain ?? mid,
    symbolHighlight: symbolHighlight ?? dark,
    label: label,
  );
}

// Placement palettes (1st blue, 2nd red, 3rd gold, 4th white). The label
// is optional — supplied for large standalone variants but omitted when
// the rosette is shown inline next to a Q ribbon.
RosetteStyle placement1stStyle({String? label}) => _wheel(
      dark: const Color(0xFF0E2C60),
      mid: const Color(0xFF1F4FA8),
      light: const Color(0xFF6FA8E6),
      label: label,
    );
RosetteStyle placement2ndStyle({String? label}) => _wheel(
      dark: const Color(0xFF5C0814),
      mid: const Color(0xFFB30E2A),
      light: const Color(0xFFE07B92),
      label: label,
    );
RosetteStyle placement3rdStyle({String? label}) => _wheel(
      dark: const Color(0xFF7A5F00),
      mid: const Color(0xFFE5BA00),
      light: const Color(0xFFFFE891),
      goldOuter: const Color(0xFFFFE891),
      goldInner: const Color(0xFFB07A00),
      label: label,
    );
RosetteStyle placement4thStyle({String? label}) => _wheel(
      dark: const Color(0xFF7F7F7F),
      mid: const Color(0xFFD0D0D0),
      light: Colors.white,
      medallionEdge: const Color(0xFF9C9C9C),
      goldOuter: const Color(0xFFE0E0E0),
      goldInner: const Color(0xFF7F7F7F),
      label: label,
    );

RosetteStyle? _placementStyle(int? p) => switch (p) {
      1 => placement1stStyle(),
      2 => placement2ndStyle(),
      3 => placement3rdStyle(),
      4 => placement4thStyle(),
      _ => null,
    };

/// Double-Q rosette — purple body with gold trim, "QQ"/"QQQ" label.
RosetteStyle doubleQStyle({required String label}) => _wheel(
      dark: const Color(0xFF3A1654),
      mid: const Color(0xFF6E1E7A),
      light: const Color(0xFFA452B0),
      medallion: _goldLight,
      medallionEdge: _goldDeep,
      goldOuter: _goldLight,
      goldInner: _goldDeep,
      label: label,
    );

/// Generic "new title" rosette — purple with a paw stamp on white.
RosetteStyle newTitleStyle({String? label}) => _wheel(
      dark: const Color(0xFF3A1654),
      mid: const Color(0xFF7B2DB0),
      light: const Color(0xFFC68DEA),
      symbol: label == null ? RosetteSymbol.paw : RosetteSymbol.none,
      symbolMain: const Color(0xFF3A1654),
      label: label,
    );

/// Generic decorative rosettes (no specific achievement attached).
RosetteStyle pawRosetteStyle() => _wheel(
      dark: const Color(0xFF14492A),
      mid: const Color(0xFF2E8B57),
      light: const Color(0xFF7BD18A),
      symbol: RosetteSymbol.paw,
      symbolMain: const Color(0xFF14492A),
    );
RosetteStyle heartRosetteStyle() => _wheel(
      dark: const Color(0xFF7A1041),
      mid: const Color(0xFFD24587),
      light: const Color(0xFFF8B0CF),
      symbol: RosetteSymbol.heart,
      symbolMain: const Color(0xFF7A1041),
    );
RosetteStyle starRosetteStyle() => _wheel(
      dark: const Color(0xFF7A5F00),
      mid: const Color(0xFFE5BA00),
      light: const Color(0xFFFFE891),
      goldOuter: const Color(0xFFFFE891),
      goldInner: const Color(0xFFB07A00),
      symbol: RosetteSymbol.star,
      symbolMain: const Color(0xFF7A5F00),
    );

RosetteStyle _styleForAchievement(Achievement a) {
  String? labelOf(String t) => t.length <= 5 ? t : null;

  if (a is ChampionTitle) {
    // MACH/PAX: red (or purple) body + gold ring + ivory medallion
    return _wheel(
      dark: a.preferred
          ? const Color(0xFF3A0612)
          : const Color(0xFF3A0612),
      mid: a.preferred
          ? const Color(0xFF6E1E7A)
          : const Color(0xFFB30E2A),
      light: a.preferred
          ? const Color(0xFFA452B0)
          : const Color(0xFFE07B92),
      goldOuter: _goldLight,
      goldInner: _goldDeep,
      medallion: _goldLight,
      medallionEdge: _goldDeep,
      label: labelOf(a.title),
    );
  }
  if (a is PremierCountTitle) {
    return _wheel(
      dark: const Color(0xFF7B3F00),
      mid: const Color(0xFFE07B00),
      light: const Color(0xFFFFB55E),
      label: labelOf(a.title),
    );
  }
  if (a is LevelQCountTitle) {
    final preferred = a.preferred;
    final l = a.level;
    if (l == AgilityLevel.master) {
      final n = a.qCountNeeded;
      if (n >= 100) {
        return _wheel(
          dark: const Color(0xFF7A5F00),
          mid: const Color(0xFFCFA300),
          light: _goldLight,
          medallion: _ivory,
          medallionEdge: const Color(0xFF7A5F00),
          label: labelOf(a.title),
        );
      }
      if (n >= 50) {
        return _wheel(
          dark: const Color(0xFF505863),
          mid: const Color(0xFF99A1AC),
          light: const Color(0xFFD0D5DC),
          label: labelOf(a.title),
        );
      }
      if (n >= 25) {
        return _wheel(
          dark: const Color(0xFF6E3B0F),
          mid: const Color(0xFFB87333),
          light: const Color(0xFFE0A26B),
          label: labelOf(a.title),
        );
      }
      // entry Master (MX/MXJ or MXP/MJP) — navy or purple with gold trim
      final base = preferred
          ? const Color(0xFF6A38B6)
          : const Color(0xFF1B2E80);
      final baseLight = preferred
          ? const Color(0xFF9871D6)
          : const Color(0xFF5366C0);
      final baseDark = preferred
          ? const Color(0xFF2E144D)
          : const Color(0xFF0A1442);
      return _wheel(
        dark: baseDark,
        mid: base,
        light: baseLight,
        goldOuter: _goldLight,
        goldInner: _goldDeep,
        label: labelOf(a.title),
      );
    }
    if (l == AgilityLevel.excellent) {
      return _wheel(
        dark: const Color(0xFF7A0F1F),
        mid: const Color(0xFFB30E2A),
        light: const Color(0xFFE07B92),
        label: labelOf(a.title),
      );
    }
    if (l == AgilityLevel.open) {
      return _wheel(
        dark: const Color(0xFF12326C),
        mid: const Color(0xFF1F4FA8),
        light: const Color(0xFF6FA8E6),
        label: labelOf(a.title),
      );
    }
    // Novice
    return _wheel(
      dark: const Color(0xFF14492A),
      mid: const Color(0xFF2E8B57),
      light: const Color(0xFF7BD18A),
      label: labelOf(a.title),
    );
  }
  // Fallback gray
  return _wheel(
    dark: const Color(0xFF333333),
    mid: const Color(0xFF888888),
    light: const Color(0xFFBBBBBB),
    label: labelOf(a.title),
  );
}

// ============================================================================
// Standalone utility icons — small pixel sprites for tips, section
// markers, sport indicators, etc.
// ============================================================================

class PixelPawIcon extends StatelessWidget {
  const PixelPawIcon({
    super.key,
    this.color = const Color(0xFF6E3B0F),
    this.scale = 2,
  });
  final Color color;
  final double scale;
  @override
  Widget build(BuildContext context) => PixelIcon(
        scale: scale,
        sprite: PixelSprite(
          rows: const <String>[
            '.X..X.',
            'XX..XX',
            '......',
            '.XXXX.',
            'XXXXXX',
            '.XXXX.',
          ],
          palette: {'.': null, 'X': color},
        ),
      );
}

class PixelHeartIcon extends StatelessWidget {
  const PixelHeartIcon({
    super.key,
    this.color = const Color(0xFFD24587),
    this.scale = 2,
  });
  final Color color;
  final double scale;
  @override
  Widget build(BuildContext context) => PixelIcon(
        scale: scale,
        sprite: PixelSprite(
          rows: const <String>[
            '.X.X.',
            'XXXXX',
            'XXXXX',
            '.XXX.',
            '..X..',
          ],
          palette: {'.': null, 'X': color},
        ),
      );
}

class PixelStarIcon extends StatelessWidget {
  const PixelStarIcon({
    super.key,
    this.color = const Color(0xFFE5BA00),
    this.outline = const Color(0xFF7A5F00),
    this.scale = 2,
  });
  final Color color;
  final Color outline;
  final double scale;
  @override
  Widget build(BuildContext context) => PixelIcon(
        scale: scale,
        sprite: PixelSprite(
          rows: const <String>[
            '..X..',
            '.XHX.',
            'XHHHX',
            '.XHX.',
            '.X.X.',
          ],
          palette: {
            '.': null,
            'X': outline,
            'H': color,
          },
        ),
      );
}

/// Mini agility-jump silhouette: two white uprights and a red bar.
class PixelAgilityIcon extends StatelessWidget {
  const PixelAgilityIcon({super.key, this.scale = 2});
  final double scale;
  @override
  Widget build(BuildContext context) => PixelIcon(
        scale: scale,
        sprite: PixelSprite(
          rows: const <String>[
            '.W..W.',
            '.W..W.',
            'RRRRRR',
            'RRRRRR',
            '.W..W.',
            '.W..W.',
            'GGGGGG',
          ],
          palette: const {
            '.': null,
            'W': Color(0xFFEFEFEF),
            'R': Color(0xFFB30E2A),
            'G': Color(0xFF4A6E36),
          },
        ),
      );
}

/// FastCAT running-dog silhouette.
class PixelFastCATIcon extends StatelessWidget {
  const PixelFastCATIcon({super.key, this.scale = 2});
  final double scale;
  @override
  Widget build(BuildContext context) => PixelIcon(
        scale: scale,
        sprite: PixelSprite(
          rows: const <String>[
            '.......XX',
            '......XXX',
            '..XXXXXXX',
            '.XXXXXXXX',
            'XXXXXXXXX',
            'X.X..X..X',
            '.X....X..',
          ],
          palette: const {
            '.': null,
            'X': Color(0xFF6E3B0F),
          },
        ),
      );
}

/// Scentwork — a vial / odor jar.
class PixelScentworkIcon extends StatelessWidget {
  const PixelScentworkIcon({super.key, this.scale = 2});
  final double scale;
  @override
  Widget build(BuildContext context) => PixelIcon(
        scale: scale,
        sprite: PixelSprite(
          rows: const <String>[
            '..XX..',
            '..XX..',
            '.LLLL.',
            'LLLLLL',
            'LBBBBL',
            'LBBBBL',
            'LBBBBL',
            'LLLLLL',
          ],
          palette: const {
            '.': null,
            'X': Color(0xFF6E3B0F),
            'L': Color(0xFF9DCEF5),
            'B': Color(0xFF4090D8),
          },
        ),
      );
}

/// New-title certificate — folded paper with a gold seal + red ribbons.
class PixelCertificateIcon extends StatelessWidget {
  const PixelCertificateIcon({super.key, this.scale = 2});
  final double scale;
  @override
  Widget build(BuildContext context) => PixelIcon(
        scale: scale,
        sprite: PixelSprite(
          rows: const <String>[
            'KWWWWWWWWK',
            'W--------W',
            'W-LLLLLL-W',
            'W--------W',
            'W-LLLLLL-W',
            'W--------W',
            'W---SSSS-W',
            'KWWWSSSSWK',
            '...RSSSSR.',
            '...RR..RR.',
            '...R....R.',
          ],
          palette: const {
            '.': null,
            'K': Color(0xFF333333),
            'W': Color(0xFFFFFFFF),
            '-': Color(0xFFE8E8E8),
            'L': Color(0xFFCCCCCC),
            'S': Color(0xFFE5BA00),
            'R': Color(0xFFB30E2A),
          },
        ),
      );
}
