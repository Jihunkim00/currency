import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/entities.dart';
import 'camera_overlay_mapper.dart';

class OverlayPainter extends CustomPainter {
  final CameraOverlayMapper mapper;
  final List<MoneyCandidate> candidates;

  OverlayPainter({
    required this.mapper,
    required this.candidates,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final previewRect = mapper.getDisplayedPreviewRect();
    if (previewRect.isEmpty) return;

    final ranked = [...candidates]..sort((a, b) => b.score.compareTo(a.score));
    final labelCount = math.min(3, ranked.length);

    for (var i = 0; i < ranked.length; i++) {
      final candidate = ranked[i];
      final rect = mapper.mapImageRectToPreview(candidate.box.bbox);
      if (rect.width < 3 || rect.height < 3) continue;
      if (!rect.overlaps(Rect.fromLTWH(0, 0, size.width, size.height))) continue;

      final isPrimary = i < 2 && !candidate.inferredCurrency;
      final borderColor = isPrimary ? const Color(0xFF57D9A3) : const Color(0x99A8B2C1);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isPrimary ? 2.0 : 1.2
        ..color = borderColor;

      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), paint);

      final shouldDrawLabel = i < labelCount && (candidate.score >= 0.75 || isPrimary);
      if (!shouldDrawLabel) continue;

      final labelText = '${candidate.sourceCurrency} ${candidate.amount.toStringAsFixed(2)}';
      final tp = _tp(labelText, isPrimary ? Colors.white : const Color(0xFFD8DEE8));
      const padH = 6.0;
      const padV = 3.0;
      final labelWidth = tp.width + padH * 2;
      final labelHeight = tp.height + padV * 2;
      final preferredTop = rect.top - labelHeight - 4;
      final labelLeft = rect.left.clamp(2.0, size.width - labelWidth - 2.0);
      final labelTop = preferredTop < 0
          ? (rect.bottom + 4).clamp(2.0, size.height - labelHeight - 2.0)
          : preferredTop;
      final bgRect = Rect.fromLTWH(labelLeft, labelTop, labelWidth, labelHeight);
      final labelBg = Paint()
        ..color = isPrimary ? const Color(0xCC0F1720) : const Color(0xAA0F1720)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(6)), labelBg);
      tp.paint(canvas, Offset(bgRect.left + padH, bgRect.top + padV));
    }
  }

  TextPainter _tp(String s, Color c) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w600),
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
    return old.candidates != candidates || old.mapper != mapper;
  }
}