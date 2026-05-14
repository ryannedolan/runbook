import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/q.dart';
import '../../rules/achievement.dart';

/// A flat ribbon — straight length of ribbon with a zig-zag pinking-shear
/// cut along the bottom. Used for Q ribbons.
///
/// Agility / Scentwork Qs are green; FastCAT Qs are light blue. The
/// color is selected by [forQ] based on sport.
class FlatRibbon extends StatelessWidget {
  const FlatRibbon({super.key, this.color = const Color(0xFF2E8B57), this.height = 22});
  final Color color;
  final double height;

  /// Pick the right Q-ribbon color for a given Q. AKC agility = green;
  /// (FastCAT and Scentwork wired for when those sports land).
  factory FlatRibbon.forQ(Q q, {double height = 22}) {
    // Today we only model AKC agility, but keep the dispatch explicit
    // so adding sports later is a one-line change.
    return FlatRibbon(color: const Color(0xFF2E8B57), height: height);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: height * 0.46,
      height: height,
      child: CustomPaint(painter: _FlatRibbonPainter(color)),
    );
  }
}

class _FlatRibbonPainter extends CustomPainter {
  _FlatRibbonPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final hsl = HSLColor.fromColor(color);
    final highlight = hsl.withLightness((hsl.lightness + 0.14).clamp(0.0, 1.0)).toColor();
    final shadow = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();

    final width = size.width;
    final height = size.height;
    final zigzagDepth = width * 0.32;
    final zigzagTop = height - zigzagDepth;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(width, 0)
      ..lineTo(width, zigzagTop);
    const teeth = 4;
    final toothW = width / teeth;
    for (var i = teeth - 1; i >= 0; i--) {
      final xRight = (i + 1) * toothW;
      final xLeft = i * toothW;
      // Down to point of tooth, then up to top-of-tooth
      path.lineTo(xLeft + toothW * 0.5, height);
      path.lineTo(xLeft, zigzagTop);
      // tiny hack so the path reads correctly:
      // we already moved from xRight->zigzagTop->mid->xLeft
      // but for the next iteration we need to start at xLeft, which we are.
      // (just ignore xRight after first iteration's move-to)
      // ignore: unused_local_variable
      final _ = xRight;
    }
    path.close();

    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [highlight, color, shadow],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, width, height));
    canvas.drawPath(path, Paint()..shader = shader);

    // Subtle white-ish center stripe to suggest a satin sheen.
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = width * 0.06
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(width * 0.5, 1),
      Offset(width * 0.5, zigzagTop - 1),
      stripe,
    );
  }

  @override
  bool shouldRepaint(_FlatRibbonPainter old) => old.color != color;
}

/// Visual recipe for a title rosette.
class RosetteStyle {
  const RosetteStyle({
    required this.center,
    required this.pleats,
    required this.outline,
    this.tails = const [Color(0xFF2A6E48)],
    this.size = 44,
    this.elaborate = false,
  });

  /// Color of the small disc at the center of the rosette.
  final Color center;

  /// Color of the surrounding pleated petal ring.
  final Color pleats;

  /// Optional contrasting outline (used to give Master-level rosettes
  /// a gold or silver edge).
  final Color outline;

  /// Tail colors — one or two ribbon tails hang below the disc.
  final List<Color> tails;

  /// Diameter of the disc portion.
  final double size;

  /// True for very elaborate rosettes (MACH, PAX, top-tier titles).
  /// These are larger and have two layered pleat rings.
  final bool elaborate;
}

/// Pick a RosetteStyle for an achievement. AKC clubs don't have a
/// strict color standard, but the hierarchy below at least matches the
/// general "the higher the title, the fancier the ribbon" vibe.
RosetteStyle styleForAchievement(Achievement a, {double size = 44}) {
  if (a is ChampionTitle) {
    // MACH / MACH2 / MACH3 / PAX / PAX2 / PAX3
    final base = a.preferred
        ? const Color(0xFF6E1E7A) // purple for PACH
        : const Color(0xFFB30E2A); // crimson for MACH
    return RosetteStyle(
      center: const Color(0xFFFFE08A),
      pleats: base,
      outline: const Color(0xFFE6C547),
      tails: [base, const Color(0xFFE6C547)],
      size: size + 6,
      elaborate: true,
    );
  }
  if (a is PremierCountTitle) {
    return RosetteStyle(
      center: Colors.white,
      pleats: const Color(0xFFE07B00), // orange for Premier
      outline: const Color(0xFF7B3F00),
      tails: const [Color(0xFFE07B00)],
      size: size,
    );
  }
  if (a is LevelQCountTitle) {
    final l = a.level;
    final preferred = a.preferred;
    // Master-tier titles vary by Q count (Bronze/Silver/Gold/Century).
    if (l == AgilityLevel.master) {
      final n = a.qCountNeeded;
      if (n >= 100) {
        // Gold / Century
        return RosetteStyle(
          center: const Color(0xFFFFF6D0),
          pleats: const Color(0xFFCFA300),
          outline: const Color(0xFF7B5A00),
          tails: const [Color(0xFFCFA300), Color(0xFFFFE066)],
          size: size + 4,
          elaborate: true,
        );
      }
      if (n >= 50) {
        // Silver
        return RosetteStyle(
          center: const Color(0xFFF1F1F4),
          pleats: const Color(0xFF99A1AC),
          outline: const Color(0xFF505863),
          tails: const [Color(0xFF99A1AC)],
          size: size + 2,
        );
      }
      if (n >= 25) {
        // Bronze
        return RosetteStyle(
          center: const Color(0xFFFFE7C7),
          pleats: const Color(0xFFB87333),
          outline: const Color(0xFF6E3B0F),
          tails: const [Color(0xFFB87333)],
          size: size + 2,
        );
      }
      // MX / MXJ / MXP / MJP — Master entry.
      return RosetteStyle(
        center: Colors.white,
        pleats: preferred ? const Color(0xFF6A38B6) : const Color(0xFF1B2E80),
        outline: const Color(0xFFE6C547),
        tails: [
          preferred ? const Color(0xFF6A38B6) : const Color(0xFF1B2E80),
          const Color(0xFFE6C547),
        ],
        size: size,
      );
    }
    if (l == AgilityLevel.excellent) {
      return RosetteStyle(
        center: Colors.white,
        pleats: const Color(0xFFB30E2A),
        outline: const Color(0xFF7A0F1F),
        tails: const [Color(0xFFB30E2A)],
        size: size,
      );
    }
    if (l == AgilityLevel.open) {
      return RosetteStyle(
        center: Colors.white,
        pleats: const Color(0xFF1F4FA8),
        outline: const Color(0xFF12326C),
        tails: const [Color(0xFF1F4FA8)],
        size: size,
      );
    }
    // Novice
    return RosetteStyle(
      center: Colors.white,
      pleats: const Color(0xFF2E8B57),
      outline: const Color(0xFF18573A),
      tails: const [Color(0xFF2E8B57)],
      size: size,
    );
  }
  // Fallback.
  return RosetteStyle(
    center: Colors.white,
    pleats: Theme.of(_FallbackContext.context).colorScheme.primary,
    outline: Theme.of(_FallbackContext.context).colorScheme.primary,
    size: size,
  );
}

/// Hack — needed only for the unreachable theme fallback above.
class _FallbackContext {
  static late BuildContext context;
}

/// A title rosette — pleated petal ring around a center disc, with
/// short flat-ribbon tails hanging below. The whole thing is drawn
/// with CustomPaint so it can scale and recolor freely.
class Rosette extends StatelessWidget {
  const Rosette({super.key, required this.style, this.label, this.dimmed = false});

  final RosetteStyle style;

  /// Optional 2-3 character label rendered in the center disc.
  final String? label;

  /// If true, the rosette is rendered desaturated/translucent to
  /// indicate "in progress, not yet earned".
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    _FallbackContext.context = context;
    final disc = style.size;
    final tailLen = disc * 0.7;
    final width = disc + tailLen * 0.4; // pleats overhang a bit horizontally
    final height = disc + tailLen;
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _RosettePainter(style: style, label: label),
        ),
      ),
    );
  }
}

class _RosettePainter extends CustomPainter {
  _RosettePainter({required this.style, required this.label});
  final RosetteStyle style;
  final String? label;

  @override
  void paint(Canvas canvas, Size size) {
    final disc = style.size;
    final center = Offset(size.width / 2, disc / 2 + 2);
    final outerR = disc / 2;

    // Tails first (drawn behind the disc).
    _drawTails(canvas, center, outerR);

    // Outer pleated ring — many overlapping small petals around the
    // disc. Elaborate rosettes get two rings.
    if (style.elaborate) {
      _drawPleatRing(canvas, center, outerR * 1.05, outerR * 0.30, 22,
          style.outline);
      _drawPleatRing(canvas, center, outerR * 0.92, outerR * 0.25, 20,
          style.pleats);
    } else {
      _drawPleatRing(canvas, center, outerR * 0.92, outerR * 0.28, 18,
          style.pleats);
    }

    // Inner disc.
    final innerR = outerR * 0.6;
    canvas.drawCircle(
      center,
      innerR + 1,
      Paint()..color = style.outline,
    );
    canvas.drawCircle(
      center,
      innerR,
      Paint()..color = style.center,
    );

    // Optional center label.
    if (label != null) {
      final lblColor = _readableOn(style.center);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: lblColor,
            fontSize: innerR * 0.85,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: innerR * 2);
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _drawPleatRing(
    Canvas canvas,
    Offset center,
    double ringR,
    double petalR,
    int petals,
    Color color,
  ) {
    final hsl = HSLColor.fromColor(color);
    final lighter = hsl.withLightness((hsl.lightness + 0.10).clamp(0.0, 1.0)).toColor();
    final darker = hsl.withLightness((hsl.lightness - 0.10).clamp(0.0, 1.0)).toColor();

    for (var i = 0; i < petals; i++) {
      final a = (i / petals) * 2 * pi;
      final cx = center.dx + ringR * cos(a);
      final cy = center.dy + ringR * sin(a);
      // Each petal is a small radial-shaded oval.
      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: petalR * 2,
        height: petalR * 2,
      );
      canvas.drawCircle(
        Offset(cx, cy),
        petalR,
        Paint()
          ..shader = RadialGradient(
            colors: [lighter, color, darker],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(rect),
      );
    }
  }

  void _drawTails(Canvas canvas, Offset discCenter, double outerR) {
    final disc = style.size;
    final tailLen = disc * 0.7;
    final tailWidth = outerR * 0.42;
    // Two tails fanning out slightly.
    final angles = style.tails.length == 1 ? [pi / 2] : [pi / 2 - 0.22, pi / 2 + 0.22];
    for (var i = 0; i < angles.length; i++) {
      final color = style.tails[i % style.tails.length];
      final dir = Offset(cos(angles[i]), sin(angles[i]));
      // Tail top sits just below the disc center.
      final top = discCenter + dir * (outerR * 0.65);
      _drawTailPath(canvas, top, dir, tailWidth, tailLen, color);
    }
  }

  void _drawTailPath(Canvas canvas, Offset top, Offset dir,
      double tailWidth, double length, Color color) {
    // Perpendicular for width.
    final perp = Offset(-dir.dy, dir.dx);
    final halfW = tailWidth / 2;
    final tl = top + perp * halfW;
    final tr = top - perp * halfW;
    final bl = top + dir * length + perp * halfW;
    final br = top + dir * length - perp * halfW;

    final hsl = HSLColor.fromColor(color);
    final highlight = hsl.withLightness((hsl.lightness + 0.10).clamp(0.0, 1.0)).toColor();
    final shadow = hsl.withLightness((hsl.lightness - 0.10).clamp(0.0, 1.0)).toColor();

    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [highlight, color, shadow],
    ).createShader(Rect.fromPoints(tl, br));

    // Zigzag along the bottom edge between bl and br.
    final path = Path()..moveTo(tl.dx, tl.dy);
    path.lineTo(tr.dx, tr.dy);
    const teeth = 3;
    final stepX = (br.dx - bl.dx) / teeth;
    final stepY = (br.dy - bl.dy) / teeth;
    final cutDepth = tailWidth * 0.25;
    final cutDx = perp.dx * 0 + dir.dx * cutDepth;
    final cutDy = perp.dy * 0 + dir.dy * cutDepth;
    final startBR = br;
    final startBL = bl;
    // Walk from br -> bl, in zigzag teeth.
    for (var i = 0; i < teeth; i++) {
      final segEnd = Offset(
        startBR.dx - (i + 1) * stepX,
        startBR.dy - (i + 1) * stepY,
      );
      final segMid = Offset(
        startBR.dx - (i + 0.5) * stepX + cutDx,
        startBR.dy - (i + 0.5) * stepY + cutDy,
      );
      if (i == 0) path.lineTo(startBR.dx, startBR.dy);
      path.lineTo(segMid.dx, segMid.dy);
      path.lineTo(segEnd.dx, segEnd.dy);
    }
    // ignore: unused_local_variable
    final _ = startBL;
    path.close();

    canvas.drawPath(path, Paint()..shader = shader);

    // Center sheen.
    final mid1 = Offset((tl.dx + tr.dx) / 2, (tl.dy + tr.dy) / 2);
    final mid2 = Offset((bl.dx + br.dx) / 2, (bl.dy + br.dy) / 2);
    final sheen = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = tailWidth * 0.16
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(mid1, mid2, sheen);
  }

  Color _readableOn(Color bg) {
    final brightness = ThemeData.estimateBrightnessForColor(bg);
    return brightness == Brightness.dark ? Colors.white : const Color(0xFF1B1B1B);
  }

  @override
  bool shouldRepaint(_RosettePainter old) =>
      old.style.pleats != style.pleats ||
      old.style.center != style.center ||
      old.style.outline != style.outline ||
      old.style.elaborate != style.elaborate ||
      old.label != label;
}
