import 'package:flutter/material.dart';

import '../domain/entities.dart';

class OverlayPainter extends CustomPainter {
  final Size imageSize;
  final Size previewSize;
  final List<MoneyCandidate> candidates;
  final int rotation;

  OverlayPainter({
    required this.imageSize,
    required this.previewSize,
    required this.candidates,
    required this.rotation,
  });

  Rect mapRect(Rect r, Size imageSize, Size previewSize, int rotation) {
    if (imageSize.width == 0 || imageSize.height == 0) return Rect.zero;

    final sx = previewSize.width / imageSize.height;
    final sy = previewSize.height / imageSize.width;

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
    }

    final sx0 = previewSize.width / imageSize.width;
    final sy0 = previewSize.height / imageSize.height;
    return Rect.fromLTWH(r.left * sx0, r.top * sy0, r.width * sx0, r.height * sy0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) return;

    for (final m in candidates) {
      final mapped = mapRect(m.box.bbox, imageSize, previewSize, rotation);
      final color = m.inferredCurrency ? Colors.orangeAccent : Colors.lightGreenAccent;
      final rectPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = color;
      final labelBg = Paint()..color = Colors.black.withOpacity(.72);

      canvas.drawRRect(
        RRect.fromRectAndRadius(mapped, const Radius.circular(8)),
        rectPaint,
      );

      final text = '${m.sourceCurrency} ${m.amount.toStringAsFixed(2)}';
      final tp = _tp(text, color);
      const padH = 7.0;
      const padV = 4.0;
      final rect = Rect.fromLTWH(
        mapped.left,
        (mapped.top - tp.height - padV * 2 - 4).clamp(0, size.height - tp.height - (padV * 2)),
        tp.width + padH * 2,
        tp.height + padV * 2,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(7)), labelBg);
      tp.paint(canvas, Offset(rect.left + padH, rect.top + padV));
    }
  }

  TextPainter _tp(String s, Color c) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    );
    tp.layout();
    return tp;
  }

  @override
  bool shouldRepaint(covariant OverlayPainter old) {
    return old.candidates != candidates ||
        old.imageSize != imageSize ||
        old.previewSize != previewSize ||
        old.rotation != rotation;
  }
}