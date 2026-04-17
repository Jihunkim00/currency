import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/painting.dart';

class CameraOverlayMapper {
  const CameraOverlayMapper({
    required this.imageSize,
    required this.viewportSize,
    required this.sensorOrientation,
    required this.lensDirection,
    this.fit = BoxFit.cover,
    this.previewSourceSize,
  });

  final Size imageSize;
  final Size viewportSize;
  final int sensorOrientation;
  final CameraLensDirection lensDirection;
  final BoxFit fit;
  final Size? previewSourceSize;

  bool get _hasValidSizes =>
      imageSize.width > 0 && imageSize.height > 0 && viewportSize.width > 0 && viewportSize.height > 0;

  Size get _rotatedImageSize {
    if (!_hasValidSizes) return Size.zero;
    final quarterTurns = ((sensorOrientation % 360) ~/ 90) % 4;
    if (quarterTurns == 1 || quarterTurns == 3) {
      return Size(imageSize.height, imageSize.width);
    }
    return imageSize;
  }

  Rect getDisplayedPreviewRect() {
    if (!_hasValidSizes) return Rect.zero;
    final source = _resolveSourceSize();
    final fitted = applyBoxFit(fit, source, viewportSize);
    final dx = (viewportSize.width - fitted.destination.width) / 2;
    final dy = (viewportSize.height - fitted.destination.height) / 2;
    return Rect.fromLTWH(dx, dy, fitted.destination.width, fitted.destination.height);
  }

  Rect mapImageRectToPreview(Rect imageRect) {
    if (!_hasValidSizes || imageRect.isEmpty) return Rect.zero;
    final tl = mapImagePointToPreview(imageRect.topLeft);
    final tr = mapImagePointToPreview(imageRect.topRight);
    final bl = mapImagePointToPreview(imageRect.bottomLeft);
    final br = mapImagePointToPreview(imageRect.bottomRight);

    final left = math.min(math.min(tl.dx, tr.dx), math.min(bl.dx, br.dx));
    final right = math.max(math.max(tl.dx, tr.dx), math.max(bl.dx, br.dx));
    final top = math.min(math.min(tl.dy, tr.dy), math.min(bl.dy, br.dy));
    final bottom = math.max(math.max(tl.dy, tr.dy), math.max(bl.dy, br.dy));

    return Rect.fromLTRB(left, top, right, bottom);
  }

  Offset mapImagePointToPreview(Offset point) {
    if (!_hasValidSizes) return Offset.zero;

    final orientedPoint = _rotatePoint(point);
    final orientedSize = _rotatedImageSize;

    final nx = (orientedPoint.dx / orientedSize.width).clamp(0.0, 1.0);
    final ny = (orientedPoint.dy / orientedSize.height).clamp(0.0, 1.0);

    final previewRect = getDisplayedPreviewRect();
    final mirroredX = _shouldMirror ? (1.0 - nx) : nx;

    return Offset(
      previewRect.left + (previewRect.width * mirroredX),
      previewRect.top + (previewRect.height * ny),
    );
  }

  Offset _rotatePoint(Offset p) {
    final w = imageSize.width;
    final h = imageSize.height;

    switch ((sensorOrientation % 360 + 360) % 360) {
      case 90:
        return Offset(p.dy, w - p.dx);
      case 180:
        return Offset(w - p.dx, h - p.dy);
      case 270:
        return Offset(h - p.dy, p.dx);
      case 0:
      default:
        return p;
    }
  }

  Size _resolveSourceSize() {
    final rotated = _rotatedImageSize;
    if (previewSourceSize == null || previewSourceSize == Size.zero) {
      return rotated;
    }

    final preview = previewSourceSize!;

    if ((preview.width / preview.height - rotated.width / rotated.height).abs() < 0.02) {
      return preview;
    }
    return rotated;
  }

  bool get _shouldMirror => lensDirection == CameraLensDirection.front;
}