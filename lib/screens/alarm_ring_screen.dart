import 'package:flutter/material.dart';

import '../services/alarm_restart.dart';

/// Visual ringing screen matching the Twince alarm reference.
///
/// The Android lock-screen alarm is drawn natively so it can appear before
/// Flutter starts. This widget is the same layout for tests and previews.
class AlarmRingScreen extends StatelessWidget {
  const AlarmRingScreen({
    super.key,
    required this.timeLabel,
    required this.title,
    required this.onDismiss,
    required this.onRestart,
    required this.onSnooze,
  });

  final String timeLabel;
  final String title;
  final VoidCallback onDismiss;
  final VoidCallback onRestart;
  final ValueChanged<int> onSnooze;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF07102F), Color(0xFF120A38), Color(0xFF1A0A3C)],
        ),
      ),
      child: Stack(
        children: const [
          _Glow(
              alignment: Alignment(1.15, -1.05),
              color: Color(0xAA6D28D9),
              radius: 220),
          _Glow(
              alignment: Alignment(-1.2, 0.15),
              color: Color(0x6638BDF8),
              radius: 180),
          _Glow(
              alignment: Alignment(0.8, 1.15),
              color: Color(0x887C3AED),
              radius: 200),
        ],
      )._withChild(
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final circle =
                  ((constraints.maxWidth - 72) / 2).clamp(108.0, 148.0);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 50),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'TWINCE',
                        style: TextStyle(
                          color: Color(0xFF9AADD6),
                          fontSize: 13,
                          letterSpacing: 4.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        timeLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 64,
                          fontWeight: FontWeight.w400,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Alarm',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _Bell(),
                      const SizedBox(height: 18),
                      Text(
                        title.trim().isEmpty ? 'Task alarm' : title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Time to start your task',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFC4B5FD),
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CircleAction(
                            label: 'Dismiss',
                            icon: Icons.close_rounded,
                            glow: const Color(0xFF38BDF8),
                            fill: const Color(0xE60B1E3A),
                            size: circle,
                            onPressed: onDismiss,
                          ),
                          const SizedBox(width: 18),
                          _CircleAction(
                            label: 'Restart',
                            icon: Icons.restart_alt_rounded,
                            glow: const Color(0xFFC4B5FD),
                            fill: const Color(0xE61A1040),
                            size: circle,
                            onPressed: onRestart,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          for (final minutes in alarmSnoozeMinutes) ...[
                            if (minutes != alarmSnoozeMinutes.first)
                              const SizedBox(width: 12),
                            Expanded(
                              child: _SnoozePill(
                                label: 'Snooze ${minutes}min',
                                glow: minutes == 5
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFFA78BFA),
                                onPressed: () => onSnooze(minutes),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

extension on Stack {
  Widget _withChild(Widget child) =>
      Stack(fit: StackFit.expand, children: [...children, child]);
}

class _Glow extends StatelessWidget {
  const _Glow(
      {required this.alignment, required this.color, required this.radius});

  final Alignment alignment;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: radius,
        height: radius,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 92,
      height: 78,
      child: CustomPaint(painter: _BellPainter()),
    );
  }
}

class _BellPainter extends CustomPainter {
  const _BellPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.46);
    canvas.drawCircle(
      center,
      28,
      Paint()
        ..color = const Color(0x6638BDF8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF7DD3FC), Color(0xFFC4B5FD)],
      ).createShader(Offset.zero & size);
    final bell = Path()
      ..moveTo(center.dx - 14, center.dy - 8)
      ..quadraticBezierTo(center.dx, center.dy - 26, center.dx + 14, center.dy - 8)
      ..lineTo(center.dx + 20, center.dy + 12)
      ..quadraticBezierTo(center.dx + 22, center.dy + 20, center.dx + 12, center.dy + 20)
      ..lineTo(center.dx - 12, center.dy + 20)
      ..quadraticBezierTo(center.dx - 22, center.dy + 20, center.dx - 20, center.dy + 12)
      ..close();
    canvas.drawPath(bell, stroke);
    canvas.drawCircle(Offset(center.dx, center.dy - 20), 2.4, stroke);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 24),
        width: 14,
        height: 10,
      ),
      0,
      3.15,
      false,
      stroke,
    );
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF7DD3FC);
    for (final scale in [1.0, 1.45]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(center.dx - 26, center.dy),
          width: 16 * scale,
          height: 26 * scale,
        ),
        1.15,
        1.7,
        false,
        wave,
      );
    }
    wave.color = const Color(0xFFC4B5FD);
    for (final scale in [1.0, 1.45]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(center.dx + 26, center.dy),
          width: 16 * scale,
          height: 26 * scale,
        ),
        3.45,
        1.7,
        false,
        wave,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.label,
    required this.icon,
    required this.glow,
    required this.fill,
    required this.size,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color glow;
  final Color fill;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(color: glow, width: 2.2),
            boxShadow: [
              BoxShadow(color: glow.withValues(alpha: 0.55), blurRadius: 22),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SnoozePill extends StatelessWidget {
  const _SnoozePill({
    required this.label,
    required this.glow,
    required this.onPressed,
  });

  final String label;
  final Color glow;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF102044),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: glow, width: 1.6),
            boxShadow: [
              BoxShadow(color: glow.withValues(alpha: 0.28), blurRadius: 14),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ),
    );
  }
}
