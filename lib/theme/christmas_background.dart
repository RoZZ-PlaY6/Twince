import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A bounded, non-interactive background shared by all Christmas routes.
class ChristmasBackground extends StatefulWidget {
  const ChristmasBackground({super.key});

  @override
  State<ChristmasBackground> createState() => _ChristmasBackgroundState();
}

class _ChristmasBackgroundState extends State<ChristmasBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: ClipRect(
            child: RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey('christmas-background'),
                painter: _ChristmasPainter(
                  animation: _controller,
                  topInset: MediaQuery.paddingOf(context).top,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      );
}

class _ChristmasPainter extends CustomPainter {
  _ChristmasPainter({required this.animation, required this.topInset})
      : super(repaint: animation);

  final Animation<double> animation;
  final double topInset;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = Offset.zero & size;
    canvas.drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF120D27), Color(0xFF211344), Color(0xFF142D62)],
          ).createShader(bounds));
    for (final glow in <(Offset, Color)>[
      (Offset(size.width * .18, size.height * .12), const Color(0x487957FF)),
      (Offset(size.width * .84, size.height * .88), const Color(0x2E41BEFF)),
    ]) {
      canvas.drawCircle(
        glow.$1,
        size.longestSide * .55,
        Paint()
          ..shader = RadialGradient(colors: [glow.$2, Colors.transparent])
              .createShader(Rect.fromCircle(
                  center: glow.$1, radius: size.longestSide * .55)),
      );
    }

    final random = math.Random(428);
    final count = (size.width * size.height / 10500).floor().clamp(20, 90);
    final t = animation.value;
    for (var i = 0; i < count; i++) {
      final x = random.nextDouble();
      final y = random.nextDouble();
      final radius = .7 + random.nextDouble() * 2;
      final speed = 1 + random.nextInt(3);
      final opacity = .28 + random.nextDouble() * .45;
      final drift = math.sin((t * 2 * math.pi) + i) * 8;
      canvas.drawCircle(
        Offset((x * size.width + drift) % size.width,
            ((y + t * speed) % 1) * size.height),
        radius,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }

    const lights = [Color(0xFF67D5FF), Color(0xFFA78BFA), Color(0xFF8B9DFF)];
    for (var i = 0; i < 8; i++) {
      final center = Offset(size.width * (i + 1) / 9, topInset + 4);
      final opacity = .45 + .25 * (1 + math.sin(t * math.pi * 4 + i)) / 2;
      final color = lights[i % lights.length].withValues(alpha: opacity);
      canvas.drawCircle(
          center,
          5,
          Paint()
            ..color = color.withValues(alpha: opacity * .18)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawCircle(center, 1.8, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _ChristmasPainter oldDelegate) =>
      oldDelegate.animation != animation || oldDelegate.topInset != topInset;
}
