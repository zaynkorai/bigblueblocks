import 'package:flutter/material.dart';
import 'dart:math';
import 'main.dart';

// ═══════════════════════════════════════════════════════
//  SHAPE HUD PAINTER (mini piece preview)
// ═══════════════════════════════════════════════════════

class ShapeHudPainter extends CustomPainter {
  final List<GameCoordinate> targetShape;
  final int colorIndex;

  ShapeHudPainter(this.targetShape, this.colorIndex);

  @override
  void paint(Canvas canvas, Size size) {
    if (targetShape.isEmpty) return;
    int maxW = targetShape.map((e) => e.x).reduce(max) + 1;
    int maxH = targetShape.map((e) => e.y).reduce(max) + 1;

    double cs = min(size.width / 4, size.height / 4);

    double offX = (size.width - (maxW * cs)) / 2;
    double offY = (size.height - (maxH * cs)) / 2;

    // Guard color index bounds
    Color color = (colorIndex >= 0 && colorIndex < shapeColors.length)
        ? shapeColors[colorIndex]
        : Colors.grey;

    for (var c in targetShape) {
      Rect rect =
          Rect.fromLTWH(offX + c.x * cs, offY + c.y * cs, cs, cs).deflate(2.0);

      Paint p = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.6), color],
        ).createShader(rect);

      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cs * 0.25)), p);

      Paint highlight = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              rect.deflate(1.0), Radius.circular(cs * 0.20)),
          highlight);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════
//  GAME BOARD PAINTER
// ═══════════════════════════════════════════════════════

class GamePainter extends CustomPainter {
  final int gridSize;
  final List<List<int>> grid;
  final Offset visualPlayerOffset;
  final Set<GameCoordinate> activeTrace;
  final int activeColorIndex;
  final List<GameCoordinate>? hintTrace;
  final double fingerAnimValue;
  final Set<GameCoordinate> clearingCells;
  final double clearAnimValue;

  final Set<GameCoordinate> thudCells;
  final double thudAnimValue;

  GamePainter(
      this.gridSize,
      this.grid,
      this.visualPlayerOffset,
      this.activeTrace,
      this.activeColorIndex,
      this.hintTrace,
      this.fingerAnimValue,
      this.clearingCells,
      this.clearAnimValue,
      this.thudCells,
      this.thudAnimValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (grid.isEmpty) return;

    double cellSize = size.width / gridSize;
    double inset = 3.0;
    double radius = 8.0;

    Paint gridPaint = Paint()
      ..color = cardDarkBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    Paint hurdleXPaint = Paint()
      ..color = bgDarkBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Guard color index for trace paint
    Color traceColor =
        (activeColorIndex >= 0 && activeColorIndex < shapeColors.length)
            ? shapeColors[activeColorIndex]
            : Colors.grey;
    Paint tracePaint = Paint()..color = traceColor.withValues(alpha: 0.45);

    for (int x = 0; x < gridSize; x++) {
      for (int y = 0; y < gridSize; y++) {
        Rect rect =
            Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize);
        Rect cellRect = rect.deflate(inset);
        RRect rrect =
            RRect.fromRectAndRadius(cellRect, Radius.circular(radius));

        if (grid[x][y] == 1) {
          // Hurdle: glowing red gradient
          Paint hurdleGradient = Paint()
            ..shader = const RadialGradient(
              colors: [Color(0xFFFF7A7A), Color(0xFFD61C1C)],
              focal: Alignment.center,
              radius: 0.8,
            ).createShader(cellRect);
          canvas.drawRRect(rrect, hurdleGradient);

          double xi = cellRect.width * 0.28;
          canvas.drawLine(
            Offset(cellRect.left + xi, cellRect.top + xi),
            Offset(cellRect.right - xi, cellRect.bottom - xi),
            hurdleXPaint,
          );
          canvas.drawLine(
            Offset(cellRect.right - xi, cellRect.top + xi),
            Offset(cellRect.left + xi, cellRect.bottom - xi),
            hurdleXPaint,
          );
        } else if (grid[x][y] >= 2) {
          bool isThudding = thudCells.contains(GameCoordinate(x, y));
          int ci = grid[x][y];
          Color cellColor = (ci >= 0 && ci < shapeColors.length)
              ? shapeColors[ci]
              : Colors.grey;

          bool isClearing = clearingCells.contains(GameCoordinate(x, y));
          if (isClearing) {
            // Block Blast style clear: Pop up slightly, flash white, then shrink to 0
            double scl;
            if (clearAnimValue < 0.3) {
              scl = 1.0 + (clearAnimValue / 0.3) * 0.2; // 1.0 -> 1.2
            } else {
              // 1.2 -> 0.0 with ease-in
              double t = (clearAnimValue - 0.3) / 0.7;
              scl = 1.2 * (1.0 - t * t); 
            }
            if (scl < 0) scl = 0;

            double centerDX = cellRect.center.dx;
            double centerDY = cellRect.center.dy;

            // Draw expanding glowing backdrop
            double glowScl = 1.0 + clearAnimValue;
            double glowOpacity = (1.0 - clearAnimValue).clamp(0.0, 1.0) * 0.6;
            Rect glowRect = Rect.fromCenter(
                center: Offset(centerDX, centerDY),
                width: cellSize * glowScl,
                height: cellSize * glowScl);
            Paint glowPaint = Paint()
              ..color = Colors.white.withValues(alpha: glowOpacity)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
            canvas.drawRect(glowRect, glowPaint);

            cellRect = Rect.fromCenter(
                center: Offset(centerDX, centerDY),
                width: cellRect.width * scl,
                height: cellRect.height * scl);
            rrect = RRect.fromRectAndRadius(
                cellRect, Radius.circular(radius * scl));

            // Flash cell color to pure white at the beginning
            double flashAmount = (1.0 - clearAnimValue * 2.5).clamp(0.0, 1.0);
            cellColor = Color.lerp(cellColor, Colors.white, flashAmount) ?? Colors.white;

            // Skip drawing if the cell has fully shrunk away
            if (scl <= 0.01) continue;
          }

          Paint capturedPaint = Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cellColor.withValues(alpha: 0.6),
                cellColor,
              ],
            ).createShader(cellRect);

          if (isThudding && !isClearing) {
            double bounce = 1.0 + sin(thudAnimValue * pi) * 0.12;
            double cx = cellRect.center.dx;
            double cy = cellRect.center.dy;
            Rect bounced = Rect.fromCenter(
                center: Offset(cx, cy),
                width: cellRect.width * bounce,
                height: cellRect.height * bounce);
            rrect = RRect.fromRectAndRadius(bounced, Radius.circular(radius));
          }
          canvas.drawRRect(rrect, capturedPaint);

          // Subtle inner border for depth
          Paint innerBorder = Paint()
            ..color = Colors.white.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  cellRect.deflate(1.5), Radius.circular(radius - 1)),
              innerBorder);
        }
      }
    }

    // Active trace highlight
    for (var t in activeTrace) {
      Rect rect =
          Rect.fromLTWH(t.x * cellSize, t.y * cellSize, cellSize, cellSize);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              rect.deflate(inset + 1), Radius.circular(radius)),
          tracePaint);
    }

    // Grid lines
    for (int i = 0; i <= gridSize; i++) {
      double pos = i * cellSize;
      canvas.drawLine(Offset(pos, 0), Offset(pos, size.height), gridPaint);
      canvas.drawLine(Offset(0, pos), Offset(size.width, pos), gridPaint);
    }

    // Player cursor (sliding shape)
    if (activeTrace.isNotEmpty && activeColorIndex != 0) {
      Color cursorColor =
          (activeColorIndex >= 0 && activeColorIndex < shapeColors.length)
              ? shapeColors[activeColorIndex]
              : Colors.grey;

      Rect pRect = Rect.fromLTWH(visualPlayerOffset.dx * cellSize,
              visualPlayerOffset.dy * cellSize, cellSize, cellSize)
          .deflate(inset);

      RRect pRRect = RRect.fromRectAndRadius(pRect, Radius.circular(radius));

      Paint playerCore = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cursorColor.withValues(alpha: 0.6),
            cursorColor,
          ],
        ).createShader(pRect);

      canvas.drawRRect(pRRect, playerCore);

      // Subtle inner border for depth
      Paint innerBorder = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              pRect.deflate(1.5), Radius.circular(radius - 1)),
          innerBorder);
    }

    // Hint Trace / Hand animation
    if (hintTrace != null && hintTrace!.isNotEmpty) {
      int n = hintTrace!.length;
      double progress = fingerAnimValue;

      double traceProg = ((progress - 0.2) / 0.6).clamp(0.0, 1.0);
      double opacity = 1.0;
      if (progress < 0.2) opacity = progress / 0.2;
      if (progress > 0.8) opacity = 1.0 - ((progress - 0.8) / 0.2);

      // Draw Trace Outline (Ghost)
      Paint ghostPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15 * opacity)
        ..style = PaintingStyle.fill;

      Paint ghostBorderPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      for (var hc in hintTrace!) {
        Rect rect =
            Rect.fromLTWH(hc.x * cellSize, hc.y * cellSize, cellSize, cellSize)
                .deflate(inset);
        RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
        canvas.drawRRect(rrect, ghostPaint);
        canvas.drawRRect(rrect.deflate(1.0), ghostBorderPaint);
      }

      // Compute finger position
      double totalDist = (n - 1).toDouble();
      double currentPos = traceProg * totalDist;
      int idx = currentPos.floor();
      int nextIdx = min(idx + 1, n - 1);
      double frac = currentPos - idx;

      GameCoordinate c1 = hintTrace![idx];
      GameCoordinate c2 = hintTrace![nextIdx];

      double px1 = c1.x * cellSize + cellSize / 2;
      double py1 = c1.y * cellSize + cellSize / 2;
      double px2 = c2.x * cellSize + cellSize / 2;
      double py2 = c2.y * cellSize + cellSize / 2;

      double fx = px1 + (px2 - px1) * frac;
      double fy = py1 + (py2 - py1) * frac;

      // Draw finger icon
      TextPainter textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(Icons.touch_app.codePoint),
          style: TextStyle(
              color: Colors.white.withValues(alpha: opacity),
              fontSize: cellSize * 1.5,
              fontFamily: Icons.touch_app.fontFamily,
              package: Icons.touch_app.fontPackage),
        ),
      );
      textPainter.layout();
      Offset textOffset =
          Offset(fx - textPainter.width / 2.5, fy - textPainter.height / 4);
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    return true;
  }
}
