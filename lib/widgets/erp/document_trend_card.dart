import 'package:flutter/material.dart';

import '../../models/erp_summary.dart';
import '../../theme/app_colors.dart';
import '../../utils/erp_format.dart';

class DocumentTrendCard extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final List<DocumentTrendPoint> points;
  final int selectedYear;
  final int selectedMonth;

  const DocumentTrendCard({
    super.key,
    required this.title,
    required this.emptyMessage,
    required this.points,
    required this.selectedYear,
    required this.selectedMonth,
  });

  @override
  Widget build(BuildContext context) {
    final total = points.fold<double>(0, (sum, point) => sum + point.value);
    final maxValue = points.fold<double>(
      0,
      (max, point) => point.value > max ? point.value : max,
    );
    final lastValue = points.isEmpty ? 0.0 : points.last.value;
    final previousValue = points.length < 2
        ? 0.0
        : points[points.length - 2].value;
    final delta = lastValue - previousValue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedMonth == 0
                          ? 'Statistik $title Bulanan'
                          : 'Statistik $title Mingguan',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      selectedMonth == 0
                          ? 'Akumulasi per bulan $selectedYear'
                          : 'Akumulasi per minggu',
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _DocumentTrendBadge(value: delta),
            ],
          ),
          const SizedBox(height: 12),
          if (total <= 0)
            _DocumentEmptyTrend(message: emptyMessage)
          else
            _DocumentTrendLineChart(
              points: points,
              maxValue: maxValue,
              total: total,
              periodLabel: selectedMonth == 0
                  ? 'Total tahun $selectedYear'
                  : 'Total bulan ini',
            ),
        ],
      ),
    );
  }
}

class _DocumentTrendLineChart extends StatelessWidget {
  final List<DocumentTrendPoint> points;
  final double maxValue;
  final double total;
  final String periodLabel;

  const _DocumentTrendLineChart({
    required this.points,
    required this.maxValue,
    required this.total,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final visibleLabels = _visibleLabels();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 150,
                width: double.infinity,
                child: CustomPaint(
                  painter: _DocumentTrendLinePainter(
                    points: points,
                    maxValue: maxValue,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: visibleLabels
                    .map(
                      (label) => Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.slate,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  periodLabel,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'Rp ${formatErpCurrency(total)}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _visibleLabels() {
    if (points.isEmpty) return const [];
    if (points.length <= 5) return points.map((point) => point.label).toList();
    return [
      points.first.label,
      points[(points.length * 0.25).floor()].label,
      points[(points.length * 0.5).floor()].label,
      points[(points.length * 0.75).floor()].label,
      points.last.label,
    ];
  }
}

class _DocumentTrendBadge extends StatelessWidget {
  final double value;

  const _DocumentTrendBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value == 0
        ? AppColors.slate
        : value > 0
        ? AppColors.success
        : AppColors.danger;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            value == 0
                ? Icons.remove_rounded
                : value > 0
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            value == 0
                ? 'Stabil'
                : '${value > 0 ? '+' : '-'}Rp ${formatErpCurrency(value.abs())}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentTrendLinePainter extends CustomPainter {
  final List<DocumentTrendPoint> points;
  final double maxValue;

  const _DocumentTrendLinePainter({
    required this.points,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.isEmpty || maxValue <= 0) return;

    final chartPoints = <Offset>[];
    final step = points.length <= 1 ? 0.0 : size.width / (points.length - 1);
    for (var i = 0; i < points.length; i++) {
      final x = points.length <= 1 ? size.width / 2 : step * i;
      final normalized = (points[i].value / maxValue).clamp(0.0, 1.0);
      final y = size.height - (normalized * (size.height - 12)) - 6;
      chartPoints.add(Offset(x, y));
    }

    final fillPath = Path()..moveTo(chartPoints.first.dx, size.height);
    for (final point in chartPoints) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(chartPoints.last.dx, size.height);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primary.withValues(alpha: 0.18),
          AppColors.primary.withValues(alpha: 0.02),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(fillPath, fillPaint);

    final linePath = Path()..moveTo(chartPoints.first.dx, chartPoints.first.dy);
    for (var i = 1; i < chartPoints.length; i++) {
      final previous = chartPoints[i - 1];
      final current = chartPoints[i];
      final midX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        midX,
        previous.dy,
        midX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final linePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = AppColors.primary;
    final dotBorderPaint = Paint()..color = AppColors.white;
    for (final point in chartPoints) {
      canvas.drawCircle(point, 5, dotBorderPaint);
      canvas.drawCircle(point, 3.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DocumentTrendLinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.maxValue != maxValue;
  }
}

class _DocumentEmptyTrend extends StatelessWidget {
  final String message;

  const _DocumentEmptyTrend({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.slate,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
