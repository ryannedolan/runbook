import 'package:flutter/material.dart';

import '../../models/q.dart';
import '../../rules/achievement.dart';

// ---------------------------------------------------------------------------
// Pixel-art ribbons and rosettes. Each sprite is defined as a list of
// equal-length rows of single-character codes; an attached palette
// maps each code to a Color (or null for transparent). Sprites scale
// up with nearest-neighbour rendering for that crisp 8-bit feel.
// ---------------------------------------------------------------------------

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

  /// Each sprite pixel becomes a [scale]x[scale] block of device pixels.
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: sprite.width * scale,
      height: sprite.height * scale,
      child: CustomPaint(painter: _PixelPainter(sprite, scale)),
    );
  }
}

class _PixelPainter extends CustomPainter {
  _PixelPainter(this.sprite, this.scale);
  final PixelSprite sprite;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    for (var y = 0; y < sprite.height; y++) {
      final row = sprite.rows[y];
      for (var x = 0; x < sprite.width; x++) {
        final ch = row[x];
        final color = sprite.palette[ch];
        if (color == null) continue;
        p.color = color;
        // +0.5 width/height to avoid hair-line seams between blocks at
        // fractional scales.
        canvas.drawRect(
          Rect.fromLTWH(x * scale, y * scale, scale + 0.5, scale + 0.5),
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) =>
      old.sprite != sprite || old.scale != scale;
}

// ---------------------------------------------------------------------------
// Flat ribbons (Qs and placements)
// ---------------------------------------------------------------------------

/// 8 wide × 12 tall flat ribbon: rectangular body with a satin sheen
/// stripe down the left-center and a fringe at the bottom.
const _flatRibbonRows = <String>[
  '.MMMMMM.', // 0  top edge
  'LMMMMMMD', // 1  shoulders
  'LHMMMMMD', // 2  sheen pixel
  'LHMMMMMD', // 3
  'LHMMMMMD', // 4
  'LHMMMMMD', // 5
  'LHMMMMMD', // 6
  'LHMMMMMD', // 7
  'LMMMMMMD', // 8
  'LMMMMMMD', // 9
  'MMMMMMMM', // 10 zigzag base
  'D.M.M.MD', // 11 alternating teeth
];

class RibbonPalette {
  const RibbonPalette({
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

const _qGreen = RibbonPalette(
  light: Color(0xFF7BD18A),
  mid: Color(0xFF2E8B57),
  dark: Color(0xFF153D26),
);
const _placeBlue = RibbonPalette(
  light: Color(0xFF6FA8E6),
  mid: Color(0xFF1F4FA8),
  dark: Color(0xFF0E2C60),
);
const _placeRed = RibbonPalette(
  light: Color(0xFFE07B92),
  mid: Color(0xFFB30E2A),
  dark: Color(0xFF5C0814),
);
const _placeYellow = RibbonPalette(
  light: Color(0xFFFFE891),
  mid: Color(0xFFE5BA00),
  dark: Color(0xFF7A5F00),
);
const _placeWhite = RibbonPalette(
  light: Color(0xFFFFFFFF),
  mid: Color(0xFFE0E0E0),
  dark: Color(0xFF9C9C9C),
  sheen: Color(0xFFFAFAFA),
);

PixelSprite _ribbonSprite(RibbonPalette p) => PixelSprite(
      rows: _flatRibbonRows,
      palette: {
        '.': null,
        'L': p.light,
        'M': p.mid,
        'D': p.dark,
        'H': p.sheen,
      },
    );

/// A flat ribbon — Q (green for agility) or placement (blue/red/yellow/white).
class PixelFlatRibbon extends StatelessWidget {
  const PixelFlatRibbon._({required this.palette, this.scale = 2});
  final RibbonPalette palette;
  final double scale;

  /// Q ribbon for a given Q (today: always green agility; FastCAT etc.
  /// will dispatch by sport later).
  factory PixelFlatRibbon.forQ(Q q, {double scale = 2}) =>
      PixelFlatRibbon._(palette: _qGreen, scale: scale);

  /// Placement ribbon for 1st/2nd/3rd/4th.
  static PixelFlatRibbon? forPlacement(int? placement, {double scale = 2}) {
    final p = switch (placement) {
      1 => _placeBlue,
      2 => _placeRed,
      3 => _placeYellow,
      4 => _placeWhite,
      _ => null,
    };
    if (p == null) return null;
    return PixelFlatRibbon._(palette: p, scale: scale);
  }

  @override
  Widget build(BuildContext context) {
    return PixelIcon(sprite: _ribbonSprite(palette), scale: scale);
  }
}

/// A pair of ribbons — Q + optional placement, drawn side by side.
class PixelQRibbonPair extends StatelessWidget {
  const PixelQRibbonPair({super.key, required this.q, this.scale = 2});
  final Q q;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final placement = PixelFlatRibbon.forPlacement(q.placement, scale: scale);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PixelFlatRibbon.forQ(q, scale: scale),
        if (placement != null) ...[
          SizedBox(width: scale * 1.0),
          placement,
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Rosettes (titles)
// ---------------------------------------------------------------------------

/// Plain rosette — 12 wide × 16 tall. A pleated disc with one short
/// flat ribbon tail.
///
/// Palette codes:
///   . — transparent
///   O — outer pleat color (dark)
///   P — pleat color (mid)
///   p — pleat highlight (light)
///   C — center disc edge (dark)
///   c — center disc fill (light)
///   W — center white
///   T — tail mid
///   t — tail dark
///   L — tail light/sheen
const _rosetteRows = <String>[
  '...OOOOOO...',  // 0
  '..OPPPPPPO..',  // 1
  '.OPpppppPPO.',  // 2
  'OPpCCCCccPO.',  // 3
  'OPpCWWWWcCPO',  // 4   center area
  'OPpCWWWWcCPO',  // 5
  'OPpCccccCCPO',  // 6
  'OPpccCCccPOO',  // 7
  'OPPpppppPPO.',  // 8
  '.OPPPPPPPO..',  // 9
  '..OOPPPOO...',  // 10
  '...OTTTO....',  // 11   tail begins
  '...TTtTT....',  // 12
  '...TLtTT....',  // 13
  '...TLtTT....',  // 14
  '...TT.TT....',  // 15   pinked bottom
];

/// Elaborate rosette — 16 wide × 20 tall. Two pleat rings + longer
/// two-tail flourish. Used for MACH, PAX, Century, etc.
const _rosetteElaborateRows = <String>[
  '....OOOOOOOO....',  // 0
  '...OxxxxxxxxO...',  // 1   outer ring (lighter)
  '..OxxPPPPPPxxO..',  // 2
  '.OxxPPpppppPPxO.',  // 3
  'OxPPpCCCCccPPxO.',  // 4
  'OxPpCWWWWWWcCpPO',  // 5
  'OxPpCWWWWWWcCpPO',  // 6
  'OxPpCccccccCPxO.',  // 7
  'OxPPpccCCCccPxO.',  // 8
  '.OxxPPpppppPxO..',  // 9
  '..OxxPPPPPxxO...',  // 10
  '...OxxxxxxO.....',  // 11
  '....OOOOOO......',  // 12
  '...TTTOOTTT.....',  // 13   double tails
  '...TLtTTLT......',  // 14
  '...TLtTTLT......',  // 15
  '...TLtTTLT......',  // 16
  '...TLtTTLT......',  // 17
  '....TT.TT.......',  // 18
  '.....t..t.......',  // 19
];

class _RosettePalette {
  const _RosettePalette({
    required this.outer,
    required this.pleat,
    required this.pleatLight,
    required this.center,
    required this.centerEdge,
    required this.white,
    Color? tail,
    Color? tailDark,
  })  : tail = tail ?? pleat,
        tailDark = tailDark ?? centerEdge;
  final Color outer;
  final Color pleat;
  final Color pleatLight;
  final Color center;
  final Color centerEdge;
  final Color white;
  final Color tail;
  final Color tailDark;
}

PixelSprite _rosetteSprite(_RosettePalette p, {bool elaborate = false}) {
  return PixelSprite(
    rows: elaborate ? _rosetteElaborateRows : _rosetteRows,
    palette: {
      '.': null,
      'O': p.outer,
      'x': p.pleatLight,
      'P': p.pleat,
      'p': p.pleatLight,
      'C': p.centerEdge,
      'c': p.center,
      'W': p.white,
      'T': p.tail,
      't': p.tailDark,
      'L': Colors.white.withValues(alpha: 0.6),
    },
  );
}

/// Pick a palette for a given achievement. Plain vs elaborate is
/// chosen automatically based on title type.
({_RosettePalette palette, bool elaborate}) _paletteFor(Achievement a) {
  if (a is ChampionTitle) {
    final base = a.preferred
        ? const Color(0xFF6E1E7A)
        : const Color(0xFFB30E2A);
    final baseLight = a.preferred
        ? const Color(0xFFA452B0)
        : const Color(0xFFE07A8E);
    return (
      palette: _RosettePalette(
        outer: const Color(0xFFE6C547),
        pleat: base,
        pleatLight: baseLight,
        center: const Color(0xFFFFE066),
        centerEdge: const Color(0xFFB07A00),
        white: const Color(0xFFFFE066),
        tail: base,
        tailDark: const Color(0xFF3A0612),
      ),
      elaborate: true,
    );
  }
  if (a is PremierCountTitle) {
    return (
      palette: const _RosettePalette(
        outer: Color(0xFF7B3F00),
        pleat: Color(0xFFE07B00),
        pleatLight: Color(0xFFFFB55E),
        center: Color(0xFFFFFFFF),
        centerEdge: Color(0xFF7B3F00),
        white: Color(0xFFFFFFFF),
      ),
      elaborate: false,
    );
  }
  if (a is LevelQCountTitle) {
    final l = a.level;
    final preferred = a.preferred;
    if (l == AgilityLevel.master) {
      final n = a.qCountNeeded;
      if (n >= 100) {
        // Gold / Century — elaborate
        return (
          palette: const _RosettePalette(
            outer: Color(0xFF7B5A00),
            pleat: Color(0xFFCFA300),
            pleatLight: Color(0xFFFFE066),
            center: Color(0xFFFFF6D0),
            centerEdge: Color(0xFF7B5A00),
            white: Color(0xFFFFFFFF),
            tail: Color(0xFFCFA300),
          ),
          elaborate: true,
        );
      }
      if (n >= 50) {
        // Silver
        return (
          palette: const _RosettePalette(
            outer: Color(0xFF505863),
            pleat: Color(0xFF99A1AC),
            pleatLight: Color(0xFFD0D5DC),
            center: Color(0xFFF1F1F4),
            centerEdge: Color(0xFF505863),
            white: Color(0xFFFFFFFF),
          ),
          elaborate: false,
        );
      }
      if (n >= 25) {
        // Bronze
        return (
          palette: const _RosettePalette(
            outer: Color(0xFF6E3B0F),
            pleat: Color(0xFFB87333),
            pleatLight: Color(0xFFE0A26B),
            center: Color(0xFFFFE7C7),
            centerEdge: Color(0xFF6E3B0F),
            white: Color(0xFFFFFFFF),
          ),
          elaborate: false,
        );
      }
      // MX/MXJ/MXP/MJP entry — navy w/ gold edge (or purple if preferred)
      final base = preferred
          ? const Color(0xFF6A38B6)
          : const Color(0xFF1B2E80);
      final baseLight = preferred
          ? const Color(0xFF9871D6)
          : const Color(0xFF5366C0);
      return (
        palette: _RosettePalette(
          outer: const Color(0xFFB07A00),
          pleat: base,
          pleatLight: baseLight,
          center: Colors.white,
          centerEdge: const Color(0xFFB07A00),
          white: Colors.white,
          tail: base,
        ),
        elaborate: false,
      );
    }
    if (l == AgilityLevel.excellent) {
      return (
        palette: const _RosettePalette(
          outer: Color(0xFF7A0F1F),
          pleat: Color(0xFFB30E2A),
          pleatLight: Color(0xFFE07B92),
          center: Colors.white,
          centerEdge: Color(0xFF7A0F1F),
          white: Colors.white,
        ),
        elaborate: false,
      );
    }
    if (l == AgilityLevel.open) {
      return (
        palette: const _RosettePalette(
          outer: Color(0xFF12326C),
          pleat: Color(0xFF1F4FA8),
          pleatLight: Color(0xFF6FA8E6),
          center: Colors.white,
          centerEdge: Color(0xFF12326C),
          white: Colors.white,
        ),
        elaborate: false,
      );
    }
    // Novice
    return (
      palette: const _RosettePalette(
        outer: Color(0xFF18573A),
        pleat: Color(0xFF2E8B57),
        pleatLight: Color(0xFF7BD18A),
        center: Colors.white,
        centerEdge: Color(0xFF18573A),
        white: Colors.white,
      ),
      elaborate: false,
    );
  }
  // Fallback
  return (
    palette: const _RosettePalette(
      outer: Color(0xFF555555),
      pleat: Color(0xFF888888),
      pleatLight: Color(0xFFBBBBBB),
      center: Colors.white,
      centerEdge: Color(0xFF555555),
      white: Colors.white,
    ),
    elaborate: false,
  );
}

class PixelRosette extends StatelessWidget {
  const PixelRosette({
    super.key,
    required this.achievement,
    this.scale = 3,
    this.dimmed = false,
    this.showLabel = true,
  });

  final Achievement achievement;
  final double scale;
  final bool dimmed;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final spec = _paletteFor(achievement);
    final sprite = _rosetteSprite(spec.palette, elaborate: spec.elaborate);
    final pixelIcon = PixelIcon(sprite: sprite, scale: scale);
    final label = achievement.title.length <= 4 ? achievement.title : null;
    return Opacity(
      opacity: dimmed ? 0.4 : 1.0,
      child: showLabel && label != null
          ? Stack(
              alignment: Alignment.topCenter,
              children: [
                pixelIcon,
                Positioned(
                  // Place text over the center disc — sprite center is
                  // roughly y=4..7 (plain) or y=5..7 (elaborate).
                  top: scale * (spec.elaborate ? 5 : 4) - 1,
                  child: SizedBox(
                    width: sprite.width * scale,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: scale *
                            (spec.elaborate ? 2.8 : 3.0) *
                            _labelScaleFor(label),
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1B1B1B),
                        height: 1.0,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : pixelIcon,
    );
  }

  double _labelScaleFor(String s) {
    if (s.length >= 4) return 0.7;
    if (s.length == 3) return 0.85;
    return 1.0;
  }
}
