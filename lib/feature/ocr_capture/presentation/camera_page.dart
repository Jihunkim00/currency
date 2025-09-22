import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'dart:typed_data';
import '../../../core/di/providers.dart';
import '../domain/entities.dart';
import '../data/ocr_service.dart';
import 'overlay_painter.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;
import 'dart:math' as math; // ⬅️ 추가



class CameraPage extends StatefulHookConsumerWidget {
  const CameraPage({super.key});
  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  // Portrait: width 그대로(0.40), height 절반(0.22 → 0.11)
  static const double _roiWidthPortrait = 0.40;
  static const double _roiHeightPortrait = 0.10;

  // Landscape: height 두배(0.09 → 0.18), width 1/3(0.40 → ~0.1333)
  static const double _roiWidthLandscape = 0.30; // 0.40 / 3
  static const double _roiHeightLandscape = 0.18;

  bool _isPortrait = true; // build에서 갱신

  // 프리뷰에 실제로 보이는 "이미지 내부 영역"을 이미지 좌표계로 계산
  Rect _visibleImageRectInImageSpace(Size imageSize, Size previewSize, int rotationDeg) {
    final bool swap = (rotationDeg % 180) != 0; // 90 or 270
    final Size logicalImage = swap ? Size(imageSize.height, imageSize.width) : imageSize;

    // CameraPreview는 cover 스케일을 사용(중앙 크롭)
    final double scale = math.max(
      previewSize.width / logicalImage.width,
      previewSize.height / logicalImage.height,
    );

    final double visW = previewSize.width / scale;
    final double visH = previewSize.height / scale;

    final double left = (logicalImage.width  - visW) / 2.0;
    final double top  = (logicalImage.height - visH) / 2.0;

    return Rect.fromLTWH(left, top, visW, visH);
  }

// 프리뷰 중앙 ROI에 해당하는 "이미지 좌표계 ROI"를 계산
  Rect _imageRoiFromPreview(Size imageSize, Size previewSize) {
    final rot = _controller.description.sensorOrientation;
    final vis = _visibleImageRectInImageSpace(imageSize, previewSize, rot);

    final double wRatio = _isPortrait ? _roiWidthPortrait  : _roiWidthLandscape;
    final double hRatio = _isPortrait ? _roiHeightPortrait : _roiHeightLandscape;

    final double roiW = vis.width  * wRatio;
    final double roiH = vis.height * hRatio;

    return Rect.fromCenter(center: vis.center, width: roiW, height: roiH);
  }

  // 프리뷰 좌표계(화면)에서 중앙 ROI 사각형 계산
  Rect _previewRoi(Size previewSize) {
    final double wRatio = _isPortrait ? _roiWidthPortrait  : _roiWidthLandscape;
    final double hRatio = _isPortrait ? _roiHeightPortrait : _roiHeightLandscape;

    final double w = previewSize.width  * wRatio;
    final double h = previewSize.height * hRatio;

    return Rect.fromCenter(
      center: Offset(previewSize.width / 2, previewSize.height / 2),
      width: w,
      height: h,
    );
  }



  late CameraController _controller;
  final _ocr = OcrService();

  bool _busy = false;
  int _frame = 0;
  static const _nth = 4;

  bool _initialized = false;

  Size? _lastPreviewSize; // ⬅️ 추가


  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      _controller = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller.initialize();
      await _controller.startImageStream(_onImage);
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('카메라 초기화 실패: $e')),
        );
      }
    }
  }



  Uint8List _yuv420toNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final int ySize = width * height;
    final int uvSize = ySize ~/ 2;
    final nv21 = Uint8List(ySize + uvSize);

    final Plane y = image.planes[0];
    int offset = 0;
    for (int row = 0; row < height; row++) {
      final int start = row * y.bytesPerRow;
      nv21.setRange(offset, offset + width, y.bytes.sublist(start, start + width));
      offset += width;
    }

    final Plane u = image.planes[1];
    final Plane v = image.planes[2];
    final int uRowStride = u.bytesPerRow;
    final int uPixelStride = u.bytesPerPixel ?? 1;
    final int vRowStride = v.bytesPerRow;
    final int vPixelStride = v.bytesPerPixel ?? 1;

    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        final int uIndex = row * uRowStride + col * uPixelStride;
        final int vIndex = row * vRowStride + col * vPixelStride;
        nv21[offset++] = v.bytes[vIndex];
        nv21[offset++] = u.bytes[uIndex];
      }
    }

    return nv21;
  }

  Future<void> _onImage(CameraImage img) async {
    _frame++;
    if (_busy || _frame % _nth != 0) return;
    _busy = true;

    try {
      final bytes = _yuv420toNv21(img);
      final imageSize = Size(img.width.toDouble(), img.height.toDouble());

      final meta = InputImageMetadata(
        size: imageSize,
        rotation: InputImageRotationValue.fromRawValue(
          _controller.description.sensorOrientation,
        ) ??
            InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: img.planes.first.bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: meta);
      final boxes = await _ocr.recognizeFromInputImage(inputImage);

// ✅ 프리뷰 중앙 ROI를 '이미지 좌표'로 환산해서 필터링
      List<OcrBox> filtered = boxes;
      if (_lastPreviewSize != null) {
        final roiImage = _imageRoiFromPreview(imageSize, _lastPreviewSize!);
        filtered = boxes.where((c) {
          final r = c.bbox; // OcrBox.bbox는 이미지 좌표
          return roiImage.overlaps(r) || roiImage.contains(r.center);
        }).toList();
      }


      if (filtered.isNotEmpty) {
        final settingsAV = ref.read(settingsProvider);
        final dollarDefault = settingsAV.asData?.value.dollarDefault ?? 'USD';
        final autoInfer = settingsAV.asData?.value.autoInferSourceCurrency ?? true;

        await ref.read(captureProvider.notifier).updateWithLocation(
          imageSize,
          filtered,
          dollarDefault,
          autoInfer,
        );


        await Future.delayed(const Duration(seconds: 1));
      }
    } catch (e, s) {
      debugPrint('OCR error: $e\n$s');
    } finally {
      _busy = false;
    }
  }


  @override
  void dispose() {
    if (_initialized) {
      _controller.dispose();
    }
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    _isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    final cap = ref.watch(captureProvider);
    final screenW = MediaQuery.of(context).size.width;
    final showSidePanel = screenW >= 480;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, cons) {
          final previewSize = Size(cons.maxWidth - (showSidePanel ? 220.0 : 0.0), cons.maxHeight);
          _lastPreviewSize = previewSize; // ⬅️ 추가
          return Stack(
            children: [
                 Positioned(
                     left: 0,
                     top: 0,
                     bottom: 0,
                     right: showSidePanel ? 220 : 0, // ✅ 사이드패널 폭 제외
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                     final roiPreview = _previewRoi(previewSize);
                     if (roiPreview.contains(d.localPosition)) {
                       // 중앙 픽 패널이 처리하므로 여기서는 무시
                       return;
                     }

                    final tapped = _hitTest(
                      d.localPosition,
                      cap.imageSize,
                      previewSize,
                      cap.candidates,
                    );
                    if (tapped != null) {
                      ref.read(calcProvider.notifier).add(tapped);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('항목 추가됨'),
                          duration: Duration(milliseconds: 400),
                        ),
                      );
                    }
                  },

                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(_controller),
                      // ✅ 중앙 ROI 마스크(투명 창 + 반투명 배경 + 흰 테두리)
                      CustomPaint(
                        painter: _RoiMaskPainter(
                          roi: _previewRoi(previewSize),
                        ),
                      ),
                       // ✅ 중앙 고정 선택 패널 (반투명, 큼직, 클릭 쉬움)
                       Positioned.fromRect(
                             rect: _previewRoi(previewSize),
                         child: _CenterPickPanel(candidates: cap.candidates),
                     ),
                    ],
                  ),
                ),
              ),
              if (showSidePanel)
                const Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 220,
                  child: SideSumPanel(),
                )
              else
                Positioned(
                  // 설정 버튼과 같은 우측 정렬 (사이드패널 있으면 +220 안쪽)
                  right: showSidePanel ? 220.0 + 8.0 : 8.0,
                  // 상단 안전영역 + (설정 버튼 여백 8) + (설정 버튼 대략 48) + 추가 여백(세로:8, 가로:20)
                  top: MediaQuery.of(context).padding.top + 8.0 + 48.0 + (_isPortrait ? 10.0 : 20.0),
                  child: const _MiniSum(),
                ),
             // ✅ 프리뷰 위 우상단 오버레이 설정 버튼
             Positioned(
               top: 8,
               right: showSidePanel ? 220.0 + 8.0 : 8.0,
               child: SafeArea(
                 child: Container(
                   decoration: BoxDecoration(
                     color: Colors.black.withOpacity(0.35),
                     shape: BoxShape.circle,
                   ),
                   child: IconButton(
                     tooltip: 'Settings',
                     onPressed: () => context.push('/settings'),
                     icon: const Icon(Icons.settings, color: Colors.white),
                   ),
                 ),
               ),
             ),
            ],
          );
        },
      ),
    );
  }

  /// ✅ OverlayPainter와 동일한 매핑 로직을 사용
  MoneyCandidate? _hitTest(
      Offset tap,
      Size imageSize,
      Size previewSize,
      List<MoneyCandidate> items,
      ) {
    if (imageSize.width == 0 || imageSize.height == 0) return null;

    for (final c in items) {
      final mapped = OverlayPainter(
        imageSize: imageSize,
        previewSize: previewSize,
        candidates: const [],
        rotation: _controller.description.sensorOrientation,
      ).mapRect(
        c.box.bbox,
        imageSize,
        previewSize,
        _controller.description.sensorOrientation,
      );

      if (mapped.inflate(6).contains(tap)) return c;
    }
    return null;
  }
}

class _MiniSum extends HookConsumerWidget {
  const _MiniSum();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calc = ref.watch(calcProvider);
    final rates = ref.watch(ratesProvider).asData?.value;
    final settings = ref.watch(settingsProvider).asData?.value;
    final display = settings?.displayCurrency ?? 'KRW';

    double sum = 0;
    if (rates != null) {
      for (final m in calc.selected) {
        final v = rates.convert(m.sourceCurrency, display, m.amount);
        if (v != null) sum += v;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$display ${sum.toStringAsFixed(2)}',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

class SideSumPanel extends HookConsumerWidget {
  const SideSumPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calc = ref.watch(calcProvider);
    final rates = ref.watch(ratesProvider).asData?.value;
    final settings = ref.watch(settingsProvider).asData?.value;
    final display = settings?.displayCurrency ?? 'KRW';

    double sum = 0;
    if (rates != null) {
      for (final m in calc.selected) {
        final v = rates.convert(m.sourceCurrency, display, m.amount);
        if (v != null) sum += v;
      }
    }

    return Container(
      color: Colors.black.withOpacity(.45),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '합계 ($display)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$display ${sum.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 22),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => ref.read(calcProvider.notifier).clear(),
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }
}

class _RoiMaskPainter extends CustomPainter {
  final Rect roi;
  _RoiMaskPainter({required this.roi});

  @override
  void paint(Canvas canvas, Size size) {
    // 배경 경로(전체) - ROI 구멍 뚫기
    final bg = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRRect(
      RRect.fromRectAndRadius(roi, const Radius.circular(12)),
    );
    final mask = Path.combine(PathOperation.difference, bg, hole);

    // 반투명 배경
    final overlay = Paint()..color = Colors.black.withOpacity(0.35);
    canvas.drawPath(mask, overlay);

    // 테두리
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(roi, const Radius.circular(12)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant _RoiMaskPainter oldDelegate) =>
      roi != oldDelegate.roi;
}
class _CenterPickPanel extends HookConsumerWidget {
  final List<MoneyCandidate> candidates;
  const _CenterPickPanel({required this.candidates});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (candidates.isEmpty) return const SizedBox.shrink();

    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final fontSize = isPortrait ? 20.0 : 16.0; // 세로는 조금 크게, 가로는 살짝 작게
    final showCount = isPortrait ? 4 : 3;      // 너무 많이 띄워서 가리는 것 방지

    // 크거나 유력한 후보 위주로 정렬
    final sorted = [...candidates]..sort((a, b) {
      final ra = a.box.bbox;
      final rb = b.box.bbox;
      final areaA = ra.width * ra.height;
      final areaB = rb.width * rb.height;
      final byArea = areaB.compareTo(areaA);
      if (byArea != 0) return byArea;
      return b.amount.compareTo(a.amount);
    });
    final top = sorted.take(showCount).toList();

    // ✅ ROI 전체를 덮는 큰 박스 제거!
    //    중앙에 "칩"들만 배치해서 뒤 숫자가 그대로 보이도록.
    return Align(
      alignment: Alignment.center,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final m in top)
            _PickChip(
              label: '${m.sourceCurrency} ${m.amount.toStringAsFixed(2)}',
              fontSize: fontSize,
              onTap: () {
                ref.read(calcProvider.notifier).add(m);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${m.sourceCurrency} ${m.amount.toStringAsFixed(2)} 추가됨'),
                    duration: const Duration(milliseconds: 500),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// 반투명 + Blur 칩 (최소 면적만 덮어 뒤 숫자가 보임)
class _PickChip extends StatelessWidget {
  final String label;
  final double fontSize;
  final VoidCallback onTap;
  const _PickChip({
    required this.label,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // 유리효과: 뒤는 보이고 살짝 흐림
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              color: Colors.black.withOpacity(0.18), // 아주 옅은 배경
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        // 어떤 배경에서도 읽히도록 그림자
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black87, offset: Offset(0, 1)),
                          Shadow(blurRadius: 8, color: Colors.black54, offset: Offset(0, 0)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

