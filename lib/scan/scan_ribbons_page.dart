import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/q.dart';
import '../repo/repo.dart';
import 'review_ribbons_page.dart';
import 'ribbon_parser.dart';

const bool _kDebugScanner = true;

/// Scanner-gun page: hold the phone over a ribbon sticker, the app
/// auto-captures when text stabilizes, and pans to the next ribbon.
/// Tap "Done" to review.
class ScanRibbonsPage extends StatefulWidget {
  const ScanRibbonsPage({super.key, required this.repo});
  final Repo repo;

  @override
  State<ScanRibbonsPage> createState() => _ScanRibbonsPageState();
}

class _ScanRibbonsPageState extends State<ScanRibbonsPage>
    with WidgetsBindingObserver {
  CameraController? _cam;
  final TextRecognizer _recognizer = TextRecognizer();
  late final RibbonParser _parser;

  bool _processing = false;
  bool _cooldown = false;
  String? _initError;

  // Stability: collect recent *semantic* fingerprints (what the parser
  // thinks the ribbon means, not the raw text). Raw OCR jitters
  // letter-by-letter even on a still sticker; the parsed Q is much
  // steadier.
  final List<String> _recentPrints = <String>[];
  static const int _stabilityFrames = 2;

  // Session captures (in chronological order).
  final List<ParsedRibbon> _captures = [];

  // Dedup-within-session: text fingerprints we've already locked on.
  final Set<String> _seenPrints = <String>{};

  // Diagnostics — surfaced in the debug HUD so we can see why captures
  // do or don't fire on real ribbons.
  int _framesProcessed = 0;
  int _framesWithText = 0;
  String? _lastRecognizedText;
  Set<String> _lastMatched = const {};
  String? _lastRejection;
  ParsedRibbon? _lastParsed;
  DateTime _lastUiTick = DateTime.fromMillisecondsSinceEpoch(0);

  bool _showDebug = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _parser = RibbonParser(dogs: widget.repo.dogs);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _initError = 'No camera available.');
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await ctrl.initialize();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      _cam = ctrl;
      debugPrint(
          '[scan] camera initialized: ${back.name} '
          'lens=${back.lensDirection.name} sensor=${back.sensorOrientation} '
          'preview=${ctrl.value.previewSize}');
      await ctrl.startImageStream(_handleFrame);
      setState(() {});
    } catch (e) {
      debugPrint('[scan] camera init failed: $e');
      setState(() => _initError = 'Camera init failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _disposeCamera() async {
    final cam = _cam;
    _cam = null;
    if (cam == null) return;
    try {
      if (cam.value.isStreamingImages) await cam.stopImageStream();
    } catch (_) {}
    try {
      await cam.dispose();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    _recognizer.close();
    super.dispose();
  }

  Future<void> _handleFrame(CameraImage image) async {
    if (_processing || _cooldown) return;
    _processing = true;
    try {
      _framesProcessed++;
      final framed = _toInputImage(image);
      if (framed == null) {
        _lastRejection = 'image conversion failed';
        _pingHud();
        return;
      }
      RecognizedText result;
      try {
        result = await _recognizer.processImage(framed.input);
      } catch (e) {
        _lastRejection = 'recognizer error: $e';
        _pingHud();
        return;
      }
      // Filter to text blocks centered inside the reticle so neighbor
      // stickers can't cross-contaminate the parsed Q.
      final raw = _textInsideReticle(result, framed.rotatedSize);
      if (raw != _lastRecognizedText && raw.trim().isNotEmpty) {
        debugPrint('[scan] OCR: ${raw.replaceAll('\n', ' | ')}');
      }
      _lastRecognizedText = raw;
      if (raw.trim().length < 4) {
        _recentPrints.clear();
        _lastRejection = 'no text';
        _lastMatched = const {};
        _lastParsed = null;
        _pingHud();
        return;
      }
      _framesWithText++;
      final parsed = _parser.parse(raw);
      _lastParsed = parsed;
      _lastMatched = parsed.matchedFields;
      final semantic = _semanticFingerprint(parsed);
      _recentPrints.add(semantic);
      if (_recentPrints.length > _stabilityFrames) {
        _recentPrints.removeAt(0);
      }
      if (!parsed.isUseful) {
        _lastRejection =
            'not useful (matched ${parsed.matchedFields.join(",")})';
        _pingHud();
        return;
      }
      final stable = _recentPrints.length == _stabilityFrames &&
          _recentPrints.every((p) => p == _recentPrints.last);
      if (!stable) {
        _lastRejection =
            'building stability (${_recentPrints.length}/$_stabilityFrames)';
        _pingHud();
        return;
      }
      if (_seenPrints.contains(parsed.textFingerprint) ||
          _seenPrints.contains(semantic)) {
        _lastRejection = 'already captured';
        _pingHud();
        return;
      }
      _lastRejection = null;
      _seenPrints.add(semantic);
      await _lockCapture(parsed);
    } catch (e) {
      _lastRejection = 'frame error: $e';
      _pingHud();
    } finally {
      _processing = false;
    }
  }

  /// Throttle HUD redraws to ~10 Hz so we don't rebuild the whole tree
  /// on every frame.
  void _pingHud() {
    if (!_kDebugScanner || !_showDebug) return;
    final now = DateTime.now();
    if (now.difference(_lastUiTick).inMilliseconds < 100) return;
    _lastUiTick = now;
    if (mounted) setState(() {});
  }

  /// Force-capture whatever text is currently visible, ignoring
  /// stability + usefulness checks. Used by the "Snap" button for
  /// occluded/partial stickers.
  Future<void> _manualSnap() async {
    final parsed = _lastParsed;
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nothing recognized yet — hold over the sticker.'),
      ));
      return;
    }
    final sem = _semanticFingerprint(parsed);
    if (_seenPrints.contains(parsed.textFingerprint) ||
        _seenPrints.contains(sem)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Already captured this ribbon.'),
      ));
      return;
    }
    _seenPrints.add(sem);
    await _lockCapture(parsed);
  }

  String _semanticFingerprint(ParsedRibbon p) {
    final q = p.q;
    final m = p.matchedFields;
    String? f(String key, String v) => m.contains(key) ? v : null;
    return [
      p.dogId ?? '?',
      q.sport.name,
      f('agilityClass', q.agilityClass?.name ?? '') ?? '?',
      f('level', q.level?.name ?? '') ?? '?',
      f('preferred', q.preferred ? 'pref' : 'reg') ?? '?',
      q.scentElement?.name ?? '?',
      q.scentLevel?.name ?? '?',
      m.contains('date')
          ? '${q.date.year}-${q.date.month}-${q.date.day}'
          : '?',
      m.contains('placement') ? '${q.placement}' : '?',
    ].join('|');
  }

  Future<void> _lockCapture(ParsedRibbon parsed) async {
    _seenPrints.add(parsed.textFingerprint);
    _captures.add(parsed);
    HapticFeedback.mediumImpact();
    unawaited(SystemSound.play(SystemSoundType.click));
    if (!mounted) return;
    setState(() {});
    _startCooldown();
  }

  void _startCooldown() {
    _cooldown = true;
    Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _cooldown = false;
      _recentPrints.clear();
    });
  }

  /// Build the InputImage and report the dimensions ML Kit will
  /// produce bounding-box coordinates in (i.e. after our declared
  /// rotation is applied). The rotated size is what we need for the
  /// reticle filter.
  ({InputImage input, Size rotatedSize})? _toInputImage(CameraImage image) {
    final cam = _cam;
    if (cam == null) return null;
    final desc = cam.description;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(desc.sensorOrientation);
    } else if (Platform.isAndroid) {
      var sensor = desc.sensorOrientation;
      final deviceRot = _deviceRotationDegrees();
      var compensated = (sensor - deviceRot + 360) % 360;
      if (desc.lensDirection == CameraLensDirection.front) {
        compensated = (sensor + deviceRot) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(compensated);
    }
    rotation ??= InputImageRotation.rotation0deg;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (image.planes.isEmpty) return null;
    final plane = image.planes.first;
    final input = InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
    // Bounding boxes from ML Kit come back in the *rotated* frame —
    // width and height swap on 90°/270° rotations.
    final rotated = rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    final rotatedSize = rotated
        ? Size(image.height.toDouble(), image.width.toDouble())
        : Size(image.width.toDouble(), image.height.toDouble());
    return (input: input, rotatedSize: rotatedSize);
  }

  /// Width/height fraction of the image we treat as the reticle.
  /// 60% × 60% covers a centered ribbon sticker but excludes most of
  /// a neighboring sticker — empirically tuned; bump down if cross-
  /// talk persists.
  static const double _reticleFraction = 0.60;

  /// Filter ML Kit's text blocks to those whose centers fall inside
  /// the reticle crop, then concatenate their text. Keeps neighboring
  /// stickers (which OCR happily reads from the edges of the frame)
  /// from contaminating the parsed Q.
  String _textInsideReticle(RecognizedText result, Size imgSize) {
    final hw = imgSize.width * _reticleFraction / 2;
    final hh = imgSize.height * _reticleFraction / 2;
    final cx = imgSize.width / 2;
    final cy = imgSize.height / 2;
    final lines = <String>[];
    for (final block in result.blocks) {
      final bb = block.boundingBox;
      final bcx = (bb.left + bb.right) / 2;
      final bcy = (bb.top + bb.bottom) / 2;
      if (bcx >= cx - hw &&
          bcx <= cx + hw &&
          bcy >= cy - hh &&
          bcy <= cy + hh) {
        lines.add(block.text);
      }
    }
    return lines.join('\n');
  }

  int _deviceRotationDegrees() {
    // Without a separate device-orientation listener, default to 0
    // (portrait). The TextRecognizer is robust to small rotations
    // and this is the common case for ribbon-scanning posture.
    return 0;
  }

  Future<void> _onDone() async {
    if (_captures.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    await _disposeCamera();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewRibbonsPage(
          repo: widget.repo,
          captures: _captures,
        ),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _discardCapture(int i) {
    if (i < 0 || i >= _captures.length) return;
    final removed = _captures.removeAt(i);
    _seenPrints.remove(removed.textFingerprint);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scan ribbons (${_captures.length})'),
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        foregroundColor: Colors.white,
        actions: [
          if (_kDebugScanner)
            IconButton(
              tooltip: 'Toggle debug HUD',
              icon: Icon(_showDebug ? Icons.bug_report : Icons.bug_report_outlined),
              onPressed: () => setState(() => _showDebug = !_showDebug),
            ),
          TextButton(
            onPressed: _onDone,
            child: Text(
              _captures.isEmpty ? 'Cancel' : 'Done',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: (_cam?.value.isInitialized ?? false)
          ? FloatingActionButton.extended(
              onPressed: _manualSnap,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Snap'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (kIsWeb) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Ribbon scanning is only available on Android/iOS.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _initError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(cam),
        _reticleOverlay(),
        if (_kDebugScanner && _showDebug) _debugHud(),
        _bottomStrip(),
        if (_cooldown) _cooldownDim(),
      ],
    );
  }

  Widget _debugHud() {
    final text = (_lastRecognizedText ?? '').trim();
    final lines = text.split('\n').take(6).join('\n');
    return Positioned(
      top: 8,
      left: 8,
      right: 8,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'frames: $_framesProcessed  '
                  'with text: $_framesWithText  '
                  'stable: ${_recentPrints.length}/$_stabilityFrames',
                ),
                Text(
                  'matched: ${_lastMatched.isEmpty ? "—" : _lastMatched.join(",")}',
                ),
                if (_lastRejection != null)
                  Text(
                    'rejected: $_lastRejection',
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                if (lines.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    lines,
                    style: const TextStyle(color: Colors.greenAccent),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _reticleOverlay() {
    // Stability progress: how many of the last N frames agreed on the
    // parsed meaning. Goes 0/N → N/N as the OCR settles.
    final progress = _recentPrints.length / _stabilityFrames;
    final hasMeaning = _lastParsed != null && _lastMatched.isNotEmpty;
    final color = _cooldown
        ? Colors.greenAccent
        : hasMeaning
            ? Colors.yellowAccent
            : Colors.white70;
    final label = _cooldown
        ? 'Captured!'
        : !hasMeaning
            ? 'Hold over sticker'
            : 'Locking… ${_recentPrints.length}/$_stabilityFrames';
    return IgnorePointer(
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 280,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            // Stability bar across the top of the reticle that fills
            // left→right as consecutive matching frames accumulate.
            Positioned(
              top: -2,
              left: 0,
              right: 0,
              child: SizedBox(
                width: 280,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _cooldown ? 1.0 : progress.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cooldownDim() {
    return IgnorePointer(
      child: Container(
        color: Colors.greenAccent.withValues(alpha: 0.10),
      ),
    );
  }

  Widget _bottomStrip() {
    if (_captures.isEmpty) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.black.withValues(alpha: 0.55),
          child: const Text(
            'Pan over each ribbon — auto-captures when text stabilizes.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      );
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 120,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: Colors.black.withValues(alpha: 0.65),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _captures.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => _CaptureChip(
            index: i + 1,
            parsed: _captures[i],
            dogName: _dogNameFor(_captures[i]),
            onDiscard: () => _discardCapture(i),
          ),
        ),
      ),
    );
  }

  String? _dogNameFor(ParsedRibbon p) {
    final id = p.dogId;
    if (id == null) return null;
    return widget.repo.dogById(id)?.callName;
  }
}

class _CaptureChip extends StatelessWidget {
  const _CaptureChip({
    required this.index,
    required this.parsed,
    required this.dogName,
    required this.onDiscard,
  });
  final int index;
  final ParsedRibbon parsed;
  final String? dogName;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final q = parsed.q;
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 150,
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#$index ${dogName ?? '(no dog)'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                q.sport.short,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                _summary(q),
                style: const TextStyle(fontSize: 11),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          Positioned(
            top: -4,
            right: -4,
            child: IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onDiscard,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              tooltip: 'Discard',
            ),
          ),
        ],
      ),
    );
  }

  String _summary(Q q) {
    final bits = <String>[];
    if (parsed.matchedFields.contains('date')) {
      bits.add('${q.date.month}/${q.date.day}');
    }
    if (parsed.matchedFields.contains('agilityClass') &&
        q.agilityClass != null) {
      bits.add(q.agilityClass!.short);
    }
    if (parsed.matchedFields.contains('level') && q.level != null) {
      bits.add(q.level!.label);
    }
    if (parsed.matchedFields.contains('scentElement')) {
      bits.add(q.scentElement!.label);
    }
    if (parsed.matchedFields.contains('scentLevel')) {
      bits.add(q.scentLevel!.label);
    }
    return bits.isEmpty ? '(needs review)' : bits.join(' · ');
  }
}
