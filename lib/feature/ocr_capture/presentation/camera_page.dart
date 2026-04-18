import 'dart:io' show Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../router/app_router.dart';
import '../../settings/domain/entities.dart';
import '../data/ocr_service.dart';
import '../domain/entities.dart';
import 'camera_overlay_mapper.dart';
import 'overlay_painter.dart';
import 'side_sum_panel.dart';

const _calibOffsetStep = 1.0;
const _calibScaleStep = 0.01;


class CameraPage extends StatefulHookConsumerWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  final _ocr = OcrService();
  CameraController? _controller;
  bool _initializing = true;
  String? _cameraError;
  DateTime _lastOcrAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _ocrInFlight = false;

  static const _ocrMinInterval = Duration(milliseconds: 220);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = 'No camera available on this device.';
          _initializing = false;
        });
        return;
      }

      final back = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      await controller.startImageStream(_onImage);

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      setState(() {
        _cameraError = 'Camera initialization failed: $e';
        _initializing = false;
      });
    }
  }

  Future<void> _onImage(CameraImage img) async {
    final now = DateTime.now();
    if (_ocrInFlight || now.difference(_lastOcrAt) < _ocrMinInterval) return;
    _ocrInFlight = true;
    _lastOcrAt = now;

    try {
      final controller = _controller;
      if (controller == null) return;

      final input = _buildInputImage(controller, img);
      if (input == null) return;

      final boxes = await _ocr.recognizeFromInputImage(input);
      final settings = ref.read(settingsProvider).asData?.value ?? const AppSettings();

      await ref.read(captureProvider.notifier).update(
        imageSize: ui.Size(img.width.toDouble(), img.height.toDouble()),
        boxes: boxes,
        settings: settings,
        locale: WidgetsBinding.instance.platformDispatcher.locale,
      );
    } catch (_) {
      // keep UX quiet; state carries user-facing warning
    } finally {
      _ocrInFlight = false;
    }
  }

  InputImage? _buildInputImage(CameraController controller, CameraImage img) {
    final rotation = InputImageRotationValue.fromRawValue(
      controller.description.sensorOrientation,
    ) ??
        InputImageRotation.rotation0deg;

    if (Platform.isIOS && img.planes.length == 1) {
      final plane = img.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: ui.Size(img.width.toDouble(), img.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    final bytes = _yuv420toNv21(img);
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: ui.Size(img.width.toDouble(), img.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: img.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _yuv420toNv21(CameraImage image) {
    if (image.planes.length < 3) return image.planes.first.bytes;
    final width = image.width;
    final height = image.height;
    final ySize = width * height;
    final uvSize = ySize ~/ 2;
    final nv21 = Uint8List(ySize + uvSize);

    final y = image.planes[0];
    var offset = 0;
    for (var row = 0; row < height; row++) {
      final start = row * y.bytesPerRow;
      nv21.setRange(offset, offset + width, y.bytes.sublist(start, start + width));
      offset += width;
    }

    final u = image.planes[1];
    final v = image.planes[2];
    for (var row = 0; row < height ~/ 2; row++) {
      for (var col = 0; col < width ~/ 2; col++) {
        final uIndex = row * u.bytesPerRow + col * (u.bytesPerPixel ?? 1);
        final vIndex = row * v.bytesPerRow + col * (v.bytesPerPixel ?? 1);
        nv21[offset++] = v.bytes[vIndex];
        nv21[offset++] = u.bytes[uIndex];
      }
    }
    return nv21;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capture = ref.watch(captureProvider);
    final calc = ref.watch(calcProvider);
    final rates = ref.watch(ratesProvider);
    final settings = ref.watch(settingsProvider).asData?.value ?? const AppSettings();

    if (_initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_cameraError != null) {
      return Scaffold(body: Center(child: Text(_cameraError!)));
    }

    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: Text('Camera unavailable.')));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
              final raw = controller.value.previewSize;
              final previewRenderSize = raw == null ? null : Size(raw.height, raw.width);

              final mapper = CameraOverlayMapper(
                imageSize: capture.imageSize,
                viewportSize: viewportSize,
                sensorOrientation: controller.description.sensorOrientation,
                lensDirection: controller.description.lensDirection,
                previewSourceSize: previewRenderSize,
                isPortrait: viewportSize.height >= viewportSize.width,
                overlayOffsetX: settings.overlayOffsetX,
                overlayOffsetY: settings.overlayOffsetY,
                overlayScaleX: settings.overlayScaleX,
                overlayScaleY: settings.overlayScaleY,
                portraitPreviewScaleX: settings.portraitPreviewScaleX,
                portraitPreviewScaleY: settings.portraitPreviewScaleY,
              );

              return GestureDetector(
                onTapUp: (details) {
                  final tapped = _hitTest(
                    details.localPosition,
                    capture.candidates,
                    mapper,
                  );
                  if (tapped == null) return;
                  HapticFeedback.selectionClick();
                  ref.read(calcProvider.notifier).add(tapped);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _PreviewSurface(
                      controller: controller,
                      isPortrait: viewportSize.height >= viewportSize.width,
                      portraitPreviewScaleX: settings.portraitPreviewScaleX,
                      portraitPreviewScaleY: settings.portraitPreviewScaleY,
                    ),
                    CustomPaint(
                      painter: OverlayPainter(
                        mapper: mapper,
                        candidates: capture.candidates,
                        labelOffsetX: settings.labelOffsetX,
                        labelOffsetY: settings.labelOffsetY,
                        labelScale: settings.labelScale,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            right: 12,
            child: _StatusCard(
              isScanning: capture.isProcessing,
              warning: capture.warning,
              ratesState: rates,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: IconButton.filledTonal(
              onPressed: () => context.pushNamed(AppRoutes.settingsName),
              icon: const Icon(Icons.settings),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SideSumPanel(
              displayCurrency: settings.displayCurrency,
              selected: calc.selected,
            ),
          ),
          if (settings.calibrationModeEnabled)
            Positioned(
              top: MediaQuery.of(context).padding.top + 74,
              right: 12,
              child: _CalibrationPanel(
                settings: settings,
                onToggleMode: () => ref.read(settingsProvider.notifier).setCalibrationModeEnabled(false),
                onReset: () => ref.read(settingsProvider.notifier).resetCalibration(),
                onChange: (next) => ref.read(settingsProvider.notifier).update(next),
              ),
            ),
        ],
      ),
    );
  }

  MoneyCandidate? _hitTest(
      Offset tap,
      List<MoneyCandidate> candidates,
      CameraOverlayMapper mapper,
      ) {
    if (candidates.isEmpty) return null;
    final hits = <_HitCandidate>[];
    for (final candidate in candidates) {
      final rect = mapper.mapImageRectToPreview(candidate.box.bbox);
      if (rect.isEmpty) continue;
      final expanded = rect.inflate(10);
      if (!expanded.contains(tap)) continue;
      hits.add(_HitCandidate(candidate, rect));
    }
    if (hits.isEmpty) return null;

    hits.sort((a, b) {
      final aArea = a.rect.width * a.rect.height;
      final bArea = b.rect.width * b.rect.height;

      final byArea = aArea.compareTo(bArea);
      if (byArea != 0) return byArea;

      final byScore = b.candidate.score.compareTo(a.candidate.score);
      if (byScore != 0) return byScore;

      return (a.candidate.inferredCurrency ? 1 : 0)
          .compareTo(b.candidate.inferredCurrency ? 1 : 0);
    });

    return hits.first.candidate;
  }
}

class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({
    required this.controller,
    required this.isPortrait,
    required this.portraitPreviewScaleX,
    required this.portraitPreviewScaleY,
  });

  final CameraController controller;
  final bool isPortrait;
  final double portraitPreviewScaleX;
  final double portraitPreviewScaleY;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);

    final child = ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.height,
            height: size.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );

    if (!isPortrait) return child;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(
        portraitPreviewScaleX,
        portraitPreviewScaleY,
        1.0,
      ),
      child: child,
    );
  }
}

class _CalibrationPanel extends StatelessWidget {
  const _CalibrationPanel({
    required this.settings,
    required this.onChange,
    required this.onReset,
    required this.onToggleMode,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onChange;
  final VoidCallback onReset;
  final VoidCallback onToggleMode;

  String _f(double v) => v.toStringAsFixed(3);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Card(
        color: Colors.black.withOpacity(0.72),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Calibration (temp)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggleMode,
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
                ],
              ),
              _ControlRow(
                label: 'overlayOffsetX',
                value: _f(settings.overlayOffsetX),
                minusText: 'X-',
                plusText: 'X+',
                onMinus: () => onChange(settings.copyWith(overlayOffsetX: settings.overlayOffsetX - _calibOffsetStep)),
                onPlus: () => onChange(settings.copyWith(overlayOffsetX: settings.overlayOffsetX + _calibOffsetStep)),
              ),
              _ControlRow(
                label: 'overlayOffsetY',
                value: _f(settings.overlayOffsetY),
                minusText: 'Y-',
                plusText: 'Y+',
                onMinus: () => onChange(settings.copyWith(overlayOffsetY: settings.overlayOffsetY - _calibOffsetStep)),
                onPlus: () => onChange(settings.copyWith(overlayOffsetY: settings.overlayOffsetY + _calibOffsetStep)),
              ),
              _ControlRow(
                label: 'overlayScaleX',
                value: _f(settings.overlayScaleX),
                minusText: 'BoxScaleX-',
                plusText: 'BoxScaleX+',
                onMinus: () => onChange(settings.copyWith(overlayScaleX: settings.overlayScaleX - _calibScaleStep)),
                onPlus: () => onChange(settings.copyWith(overlayScaleX: settings.overlayScaleX + _calibScaleStep)),
              ),
              _ControlRow(
                label: 'overlayScaleY',
                value: _f(settings.overlayScaleY),
                minusText: 'BoxScaleY-',
                plusText: 'BoxScaleY+',
                onMinus: () => onChange(settings.copyWith(overlayScaleY: settings.overlayScaleY - _calibScaleStep)),
                onPlus: () => onChange(settings.copyWith(overlayScaleY: settings.overlayScaleY + _calibScaleStep)),
              ),
              _ControlRow(
                label: 'labelOffsetX',
                value: _f(settings.labelOffsetX),
                minusText: 'LabelX-',
                plusText: 'LabelX+',
                onMinus: () => onChange(settings.copyWith(labelOffsetX: settings.labelOffsetX - _calibOffsetStep)),
                onPlus: () => onChange(settings.copyWith(labelOffsetX: settings.labelOffsetX + _calibOffsetStep)),
              ),
              _ControlRow(
                label: 'labelOffsetY',
                value: _f(settings.labelOffsetY),
                minusText: 'LabelY-',
                plusText: 'LabelY+',
                onMinus: () => onChange(settings.copyWith(labelOffsetY: settings.labelOffsetY - _calibOffsetStep)),
                onPlus: () => onChange(settings.copyWith(labelOffsetY: settings.labelOffsetY + _calibOffsetStep)),
              ),
              _ControlRow(
                label: 'labelScale',
                value: _f(settings.labelScale),
                minusText: 'LabelScale-',
                plusText: 'LabelScale+',
                onMinus: () => onChange(settings.copyWith(labelScale: settings.labelScale - _calibScaleStep)),
                onPlus: () => onChange(settings.copyWith(labelScale: settings.labelScale + _calibScaleStep)),
              ),
              _ControlRow(
                label: 'portraitPreviewScaleX',
                value: _f(settings.portraitPreviewScaleX),
                minusText: 'PreviewScaleX-',
                plusText: 'PreviewScaleX+',
                onMinus: () => onChange(settings.copyWith(
                  portraitPreviewScaleX: settings.portraitPreviewScaleX - _calibScaleStep,
                )),
                onPlus: () => onChange(settings.copyWith(
                  portraitPreviewScaleX: settings.portraitPreviewScaleX + _calibScaleStep,
                )),
              ),
              _ControlRow(
                label: 'portraitPreviewScaleY',
                value: _f(settings.portraitPreviewScaleY),
                minusText: 'PreviewScaleY-',
                plusText: 'PreviewScaleY+',
                onMinus: () => onChange(settings.copyWith(
                  portraitPreviewScaleY: settings.portraitPreviewScaleY - _calibScaleStep,
                )),
                onPlus: () => onChange(settings.copyWith(
                  portraitPreviewScaleY: settings.portraitPreviewScaleY + _calibScaleStep,
                )),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onReset,
                  child: const Text('Reset'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.label,
    required this.value,
    required this.minusText,
    required this.plusText,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final String value;
  final String minusText;
  final String plusText;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: $value',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onMinus,
                  child: Text(minusText, style: const TextStyle(fontSize: 10)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onPlus,
                  child: Text(plusText, style: const TextStyle(fontSize: 10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HitCandidate {
  const _HitCandidate(this.candidate, this.rect);

  final MoneyCandidate candidate;
  final Rect rect;
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.isScanning,
    required this.warning,
    required this.ratesState,
  });

  final bool isScanning;
  final String? warning;
  final AsyncValue ratesState;

  @override
  Widget build(BuildContext context) {
    final rateStatus = ratesState.when(
      data: (_) => 'Rates ready',
      loading: () => 'Loading rates...',
      error: (_, __) => 'Rate fetch failed - using previous if available',
    );

    return Card(
      elevation: 0,
      color: Colors.black.withOpacity(0.33),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1) Point camera  2) Tap detected amount  3) Review total',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(isScanning ? 'Scanning…' : 'Waiting for next frame', style: const TextStyle(color: Colors.white60, fontSize: 12)),
            Text(rateStatus, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            if (warning != null)
              Text(warning!, style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}