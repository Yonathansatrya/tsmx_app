import 'dart:math';
import 'package:flutter/material.dart';

class WarehouseGauge extends StatefulWidget {
  final double percentage; // 0.0 to 1.0
  final String label;

  const WarehouseGauge({
    super.key,
    required this.percentage,
    required this.label,
  });

  @override
  State<WarehouseGauge> createState() => _WarehouseGaugeState();
}

class _WarehouseGaugeState extends State<WarehouseGauge> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _percentageAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _percentageAnimation = Tween<double>(begin: 0.0, end: widget.percentage).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant WarehouseGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage) {
      _percentageAnimation = Tween<double>(
        begin: oldWidget.percentage,
        end: widget.percentage,
      ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic),
      );
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _percentageAnimation,
      builder: (context, child) {
        final currentPct = _percentageAnimation.value;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: CustomPaint(
                  painter: GaugePainter(
                    percentage: currentPct,
                    activeColor: _getColorForCapacity(currentPct),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(currentPct * 100).toInt()}%',
                          style: TextStyle(
                            fontFamily: 'HankenGrotesk',
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: _getColorForCapacity(currentPct),
                          ),
                        ),
                        const Text(
                          'CAPACITY',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: 'HankenGrotesk',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getCapacityStatusText(currentPct),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getColorForCapacity(currentPct),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getColorForCapacity(double pct) {
    if (pct < 0.6) return const Color(0xFF135e39); // Green
    if (pct < 0.85) return const Color(0xFFFFB300); // Yellow/Amber
    return const Color(0xFFE11D48); // Red
  }

  String _getCapacityStatusText(double pct) {
    if (pct < 0.6) return 'Optimal Operation';
    if (pct < 0.85) return 'Approaching Threshold';
    return 'Critical Capacity Alert';
  }
}

class GaugePainter extends CustomPainter {
  final double percentage;
  final Color activeColor;

  GaugePainter({required this.percentage, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 8;

    final backgroundPaint = Paint()
      ..color = Colors.grey.shade100
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw the full background arc (220 degrees, pointing upwards)
    // Starting from 160 degrees to 380 degrees (which is 20 deg)
    const startAngle = 135 * pi / 180;
    const sweepAngle = 270 * pi / 180;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    // Draw active arc based on percentage
    final activeSweep = sweepAngle * percentage;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      activeSweep,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant GaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.activeColor != activeColor;
  }
}
