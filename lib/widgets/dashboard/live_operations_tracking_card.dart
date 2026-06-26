import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

enum LiveTrackingType { sales, fleet }

class LiveTrackingPoint {
  final LiveTrackingType type;
  final String title;
  final String subtitle;
  final DateTime? capturedAt;
  final double latitude;
  final double longitude;

  const LiveTrackingPoint({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.capturedAt,
    required this.latitude,
    required this.longitude,
  });

  bool get hasLocation => latitude != 0 || longitude != 0;
}

class LiveOperationsTrackingCard extends StatelessWidget {
  final List<LiveTrackingPoint> points;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  const LiveOperationsTrackingCard({
    super.key,
    required this.points,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final activePoints = points.where((point) => point.hasLocation).toList();
    final salesCount = activePoints
        .where((point) => point.type == LiveTrackingType.sales)
        .length;
    final fleetCount = activePoints
        .where((point) => point.type == LiveTrackingType.fleet)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.softGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.map_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live Tracking Operasional',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      activePoints.isEmpty
                          ? 'Belum ada sales atau armada aktif'
                          : '$salesCount sales | $fleetCount armada aktif',
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh lokasi',
                onPressed: loading ? null : onRefresh,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 190,
              width: double.infinity,
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFFEAF5EF)),
                child: activePoints.isEmpty
                    ? _TrackingMapEmptyState(error: error)
                    : CustomPaint(
                        painter: _LiveTrackingMapPainter(activePoints),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 12,
                              top: 12,
                              child: _MapLegend(
                                salesCount: salesCount,
                                fleetCount: fleetCount,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          if (activePoints.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...activePoints.take(4).map((point) => _TrackingPointRow(point)),
            if (activePoints.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '+${activePoints.length - 4} titik lainnya',
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TrackingMapEmptyState extends StatelessWidget {
  final String? error;

  const _TrackingMapEmptyState({this.error});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_off_outlined,
            color: AppColors.primary,
            size: 36,
          ),
          const SizedBox(height: 8),
          Text(
            error == null ? 'Lokasi belum tersedia' : 'Lokasi gagal dimuat',
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            error == null
                ? 'Mulai tracking sales atau driver untuk menampilkan marker.'
                : error!,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.slate,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MapLegend extends StatelessWidget {
  final int salesCount;
  final int fleetCount;

  const _MapLegend({required this.salesCount, required this.fleetCount});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.two_wheeler_rounded,
          color: AppColors.primary,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '$salesCount',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 10),
        const Icon(
          Icons.local_shipping_rounded,
          color: AppColors.warning,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '$fleetCount',
          style: const TextStyle(
            color: AppColors.warning,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _TrackingPointRow extends StatelessWidget {
  final LiveTrackingPoint point;

  const _TrackingPointRow(this.point);

  @override
  Widget build(BuildContext context) {
    final isFleet = point.type == LiveTrackingType.fleet;
    final color = isFleet ? AppColors.warning : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isFleet
                ? AppColors.warning.withValues(alpha: 0.12)
                : AppColors.softGreen,
            foregroundColor: color,
            child: Icon(
              isFleet
                  ? Icons.local_shipping_rounded
                  : Icons.two_wheeler_rounded,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                Text(
                  point.subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.slate,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _timeLabel(point.capturedAt),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _LiveTrackingMapPainter extends CustomPainter {
  final List<LiveTrackingPoint> points;

  const _LiveTrackingMapPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    _paintMapBackground(canvas, size);
    if (points.isEmpty) return;

    final latitudes = points.map((point) => point.latitude).toList();
    final longitudes = points.map((point) => point.longitude).toList();
    final minLat = latitudes.reduce((a, b) => a < b ? a : b);
    final maxLat = latitudes.reduce((a, b) => a > b ? a : b);
    final minLng = longitudes.reduce((a, b) => a < b ? a : b);
    final maxLng = longitudes.reduce((a, b) => a > b ? a : b);
    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final color = point.type == LiveTrackingType.fleet
          ? AppColors.warning
          : AppColors.primary;
      final dx = lngSpan == 0
          ? size.width / 2
          : 22 + ((point.longitude - minLng) / lngSpan) * (size.width - 44);
      final dy = latSpan == 0
          ? size.height / 2
          : 22 + ((maxLat - point.latitude) / latSpan) * (size.height - 44);
      final offset = Offset(dx.toDouble(), dy.toDouble());

      canvas.drawCircle(
        offset,
        18,
        Paint()
          ..color = color.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(offset, 13, Paint()..color = color);
      _paintVehicleIcon(canvas, offset, point.type);
      _paintMarkerLabel(canvas, offset, i + 1);
    }
  }

  void _paintMapBackground(Canvas canvas, Size size) {
    final base = Paint()..color = const Color(0xFFEAF5EF);
    canvas.drawRect(Offset.zero & size, base);

    final roadPaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final roadLinePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final pathA = Path()
      ..moveTo(-10, size.height * 0.74)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.54,
        size.width * 0.43,
        size.height * 0.88,
        size.width + 10,
        size.height * 0.56,
      );
    final pathB = Path()
      ..moveTo(size.width * 0.18, -10)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.28,
        size.width * 0.18,
        size.height * 0.56,
        size.width * 0.42,
        size.height + 10,
      );
    canvas.drawPath(pathA, roadPaint);
    canvas.drawPath(pathB, roadPaint);
    canvas.drawPath(pathA, roadLinePaint);
    canvas.drawPath(pathB, roadLinePaint);

    final blockPaint = Paint()..color = AppColors.white.withValues(alpha: 0.35);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62, 24, 72, 42),
        const Radius.circular(12),
      ),
      blockPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(22, size.height * 0.18, 86, 48),
        const Radius.circular(14),
      ),
      blockPaint,
    );
  }

  void _paintVehicleIcon(Canvas canvas, Offset center, LiveTrackingType type) {
    final icon = type == LiveTrackingType.fleet
        ? Icons.local_shipping_rounded
        : Icons.two_wheeler_rounded;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: AppColors.white,
          fontSize: 17,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _paintMarkerLabel(Canvas canvas, Offset center, int index) {
    final painter = TextPainter(
      text: TextSpan(
        text: '$index',
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center + const Offset(14, -22));
  }

  @override
  bool shouldRepaint(covariant _LiveTrackingMapPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
