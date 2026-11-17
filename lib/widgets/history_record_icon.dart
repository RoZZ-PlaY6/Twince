import 'package:flutter/material.dart';

/// A document with an overlapping clock, drawn at the ambient icon size.
class HistoryRecordIcon extends StatelessWidget {
  const HistoryRecordIcon({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = IconTheme.of(context).size ?? 24;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _HistoryRecordPainter(color)),
    );
  }
}

class _HistoryRecordPainter extends CustomPainter {
  const _HistoryRecordPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Leave a gap in the page outline where the clock overlaps it.
    final page = Path()
      ..moveTo(10.2, 3.4)
      ..lineTo(19.3, 3.4)
      ..quadraticBezierTo(20.5, 3.4, 20.5, 4.6)
      ..lineTo(20.5, 20.3)
      ..quadraticBezierTo(20.5, 21.5, 19.3, 21.5)
      ..lineTo(7, 21.5)
      ..quadraticBezierTo(5.8, 21.5, 5.8, 20.3)
      ..lineTo(5.8, 11.4);
    canvas.drawPath(page, stroke);
    canvas.drawLine(const Offset(12.1, 8.2), const Offset(17.6, 8.2), stroke);
    canvas.drawLine(const Offset(9, 12.2), const Offset(17.6, 12.2), stroke);
    canvas.drawLine(const Offset(9, 16.2), const Offset(17.6, 16.2), stroke);

    const center = Offset(6.7, 6.7);
    canvas.drawCircle(center, 4.2, stroke);
    canvas.drawLine(center, const Offset(6.7, 4.3), stroke);
    canvas.drawLine(center, const Offset(8.5, 7.7), stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HistoryRecordPainter oldDelegate) =>
      oldDelegate.color != color;
}
