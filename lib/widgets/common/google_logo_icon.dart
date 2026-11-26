import 'package:flutter/material.dart';

/// Renders the official 4-color Google "G" brand mark as a crisp vector icon.
class GoogleLogoIcon extends StatelessWidget {
  final double size;

  const GoogleLogoIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24.0;
    final sy = size.height / 24.0;
    canvas.save();
    canvas.scale(sx, sy);

    // Blue
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(23.49, 12.275)
      ..cubicTo(23.49, 11.49, 23.42, 10.73, 23.29, 10.0)
      ..lineTo(12.0, 10.0)
      ..lineTo(12.0, 14.51)
      ..lineTo(18.47, 14.51)
      ..cubicTo(18.18, 15.99, 17.34, 17.25, 16.08, 18.1)
      ..lineTo(19.95, 21.1)
      ..cubicTo(22.2, 19.01, 23.49, 15.92, 23.49, 12.275)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green
    final greenPaint = Paint()..color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(12.0, 24.0)
      ..cubicTo(15.24, 24.0, 17.95, 22.92, 19.95, 21.1)
      ..lineTo(16.08, 18.1)
      ..cubicTo(15.0, 18.83, 13.62, 19.25, 12.0, 19.25)
      ..cubicTo(8.87, 19.25, 6.22, 17.14, 5.27, 14.29)
      ..lineTo(1.28, 17.38)
      ..cubicTo(3.26, 21.32, 7.31, 24.0, 12.0, 24.0)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(5.27, 14.29)
      ..cubicTo(5.02, 13.57, 4.89, 12.8, 4.89, 12.0)
      ..cubicTo(4.89, 11.2, 5.02, 10.43, 5.27, 9.71)
      ..lineTo(1.28, 6.62)
      ..cubicTo(0.46, 8.23, 0.0, 10.06, 0.0, 12.0)
      ..cubicTo(0.0, 13.94, 0.46, 15.77, 1.28, 17.38)
      ..lineTo(5.27, 14.29)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red
    final redPaint = Paint()..color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(12.0, 4.75)
      ..cubicTo(13.77, 4.75, 15.35, 5.36, 16.6, 6.55)
      ..lineTo(20.04, 3.12)
      ..cubicTo(17.95, 1.19, 15.24, 0.0, 12.0, 0.0)
      ..cubicTo(7.31, 0.0, 3.26, 2.68, 1.28, 6.62)
      ..lineTo(5.27, 9.71)
      ..cubicTo(6.22, 6.86, 8.87, 4.75, 12.0, 4.75)
      ..close();
    canvas.drawPath(redPath, redPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
