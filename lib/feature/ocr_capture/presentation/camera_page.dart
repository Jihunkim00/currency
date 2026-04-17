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
import 'overlay_painter.dart';
import 'side_sum_panel.dart';

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
  Size? _previewSize;

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
              _previewSize = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onTapUp: (details) {
                  final tapped = _hitTest(
                    details.localPosition,
                    capture.imageSize,
                    _previewSize!,
                    capture.candidates,
                    controller.description.sensorOrientation,
                  );
                  if (tapped == null) return;
                  HapticFeedback.selectionClick();
                  ref.read(calcProvider.notifier).add(tapped);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(controller),
                    if (_previewSize != null)
                      CustomPaint(
                        painter: OverlayPainter(
                          imageSize: capture.imageSize,
                          previewSize: _previewSize!,
                          candidates: capture.candidates,
                          rotation: controller.description.sensorOrientation,
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
        ],
      ),
    );
  }

  MoneyCandidate? _hitTest(
      Offset tap,
      Size imageSize,
      Size previewSize,
      List<MoneyCandidate> candidates,
      int rotation,
      ) {
    if (imageSize.width == 0 || imageSize.height == 0) return null;

    final mapper = OverlayPainter(
      imageSize: imageSize,
      previewSize: previewSize,
      candidates: const [],
      rotation: rotation,
    );

    for (final candidate in candidates) {
      final rect = mapper.mapRect(candidate.box.bbox, imageSize, previewSize, rotation);
      if (rect.inflate(8).contains(tap)) return candidate;
    }
    return null;
  }
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
      color: Colors.black.withOpacity(0.55),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1) Point camera  2) Tap detected amount  3) Review total',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(isScanning ? 'Scanning…' : 'Waiting for next frame', style: const TextStyle(color: Colors.white70)),
            Text(rateStatus, style: const TextStyle(color: Colors.white70)),
            if (warning != null)
              Text(warning!, style: const TextStyle(color: Colors.amberAccent)),
          ],
        ),
      ),
    );
  }
}