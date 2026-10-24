import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An open book standing for one mushaf page: the page's own half is filled
/// and shows its number. Odd pages fill the right half and even pages the
/// left, as the two pages of a printed spread.
class PageBookIcon extends StatelessWidget {
  const PageBookIcon({
    super.key,
    required this.page,
    required this.label,
    required this.background,
  });

  final int page;

  /// [page] in the reader's digits.
  final String label;

  /// Color behind the icon, used to cut the ribbon out of the lines.
  final Color background;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final right = page.isOdd;
    return AspectRatio(
      aspectRatio: 1.6,
      child: LayoutBuilder(
        builder: (context, box) => CustomPaint(
          painter: _BookPainter(
            color: colors.primary,
            background: background,
            fillRight: right,
          ),
          child: Align(
            // Centered on the filled half, above the stacked page lines.
            alignment: Alignment(right ? 0.5 : -0.5, -0.25),
            child: SizedBox(
              width: box.maxWidth * 0.4,
              height: box.maxHeight * 0.6,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: box.maxHeight * 0.36,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookPainter extends CustomPainter {
  _BookPainter({
    required this.color,
    required this.background,
    required this.fillRight,
  });

  final Color color;
  final Color background;
  final bool fillRight;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sw = math.max(1.2, w * 0.022);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;
    final fill = Paint()..color = color;

    final bottom = h * 0.76;
    final left = Rect.fromLTRB(sw / 2, sw / 2, w / 2, bottom);
    final right = Rect.fromLTRB(w / 2, sw / 2, w - sw / 2, bottom);
    canvas.drawRect(fillRight ? right : left, fill);
    canvas
      ..drawRect(left, stroke)
      ..drawRect(right, stroke);

    // The edges of the pages under the open spread.
    for (final y in [h * 0.83, h * 0.91]) {
      canvas.drawLine(Offset(0, y), Offset(w, y), stroke);
    }

    // A ribbon hanging from the middle, with a notched end.
    final cx = w / 2;
    final rw = w * 0.09;
    final ribbon = Path()
      ..moveTo(cx - rw / 2, bottom)
      ..lineTo(cx - rw / 2, h - sw / 2)
      ..lineTo(cx, h - sw / 2 - rw * 0.45)
      ..lineTo(cx + rw / 2, h - sw / 2)
      ..lineTo(cx + rw / 2, bottom);
    canvas
      ..drawPath(ribbon, Paint()..color = background)
      ..drawPath(ribbon, stroke);
  }

  @override
  bool shouldRepaint(_BookPainter old) =>
      old.color != color ||
      old.background != background ||
      old.fillRight != fillRight;
}

/// The mark of a quarter (rub') in the index: a ring with the hizb number
/// at the start of a hizb, then a quarter, half and three quarters filled.
class RubIcon extends StatelessWidget {
  const RubIcon({super.key, required this.rub, required this.hizbLabel});

  /// 1 to 240.
  final int rub;

  /// The hizb number in the reader's digits, shown on the first quarter.
  final String hizbLabel;

  /// Brown, as quarter marks are printed in many mushafs.
  static Color colorOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFD9A86C)
      : const Color(0xFF8B5422);

  @override
  Widget build(BuildContext context) {
    final color = colorOf(context);
    final quarter = (rub - 1) % 4;
    return SizedBox.square(
      dimension: 36,
      child: CustomPaint(
        painter: _RubPainter(color: color, quarters: quarter),
        child: quarter == 0
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: FittedBox(
                    child: Text(
                      hizbLabel,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _RubPainter extends CustomPainter {
  _RubPainter({required this.color, required this.quarters});

  final Color color;
  final int quarters;

  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width * 0.075;
    final circle = Offset.zero & size;
    canvas.drawOval(
      circle.deflate(sw / 2),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );
    if (quarters == 0) return;
    // Filled clockwise from the top, like a clock.
    canvas.drawArc(
      circle.deflate(sw * 2),
      -math.pi / 2,
      quarters * math.pi / 2,
      true,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_RubPainter old) =>
      old.color != color || old.quarters != quarters;
}
