import 'package:flutter/material.dart';
import '../domain/entities.dart';

class OverlayPainter extends CustomPainter {
  final Size imageSize, previewSize;
  final List<MoneyCandidate> candidates;
  final int rotation; // ✅ 센서 회전값 (90, 270 등)

  OverlayPainter({
    required this.imageSize,
    required this.previewSize,
    required this.candidates,
    required this.rotation,
  });

  /// ✅ 좌표 변환 (Camera → Preview)
  Rect mapRect(Rect r, Size imageSize, Size previewSize, int rotation) {
    if (imageSize.width == 0 || imageSize.height == 0) return Rect.zero;

    // 기본 스케일 (센서가 세로/가로 90도 기준이라 뒤집혀 있음)
    final sx = previewSize.width / imageSize.height;
    final sy = previewSize.height / imageSize.width;

    // ML Kit은 이미지 좌표 기준 (왼쪽 상단 원점), camera preview는 회전된 좌표계
    if (rotation == 90) {
      return Rect.fromLTWH(
        r.top * sx,
        (imageSize.width - r.right) * sy,
        r.height * sx,
        r.width * sy,
      );
    } else if (rotation == 270) {
      return Rect.fromLTWH(
        (imageSize.height - r.bottom) * sx,
        r.left * sy,
        r.height * sx,
        r.width * sy,
      );
    } else {
      // 기본 (0deg)
      final sx0 = previewSize.width / imageSize.width;
      final sy0 = previewSize.height / imageSize.height;
      return Rect.fromLTWH(
        r.left * sx0,
        r.top * sy0,
        r.width * sx0,
        r.height * sy0,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) return;

    final rectPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white70;
    final labelBg = Paint()..color = Colors.black.withOpacity(.6);

    for (final m in candidates) {
      final mapped = mapRect(m.box.bbox, imageSize, previewSize, rotation);
      canvas.drawRect(mapped, rectPaint);

      final text = '${m.sourceCurrency} ${m.amount.toStringAsFixed(2)}';
      final tp = _tp(text);
      final pad = const EdgeInsets.symmetric(horizontal: 6, vertical: 4);
      final label = Size(tp.width + pad.horizontal, tp.height + pad.vertical);
      final rect = Rect.fromLTWH(
        mapped.left,
        (mapped.top - label.height - 2).clamp(0, size.height - label.height),
        label.width,
        label.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        labelBg,
      );
      tp.paint(canvas, Offset(rect.left + pad.left, rect.top + pad.top));
    }
  }

  TextPainter _tp(String s) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    );
    tp.layout();
    return tp;
  }

  @override
  bool shouldRepaint(covariant OverlayPainter old) =>
      old.candidates != candidates ||
          old.imageSize != imageSize ||
          old.previewSize != previewSize ||
          old.rotation != rotation;
}
