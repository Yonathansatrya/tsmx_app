import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sales_workspace.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dashboard/dashboard_kpi_card.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  List<SalesTrackingPoint> _salesTrackingPoints = const [];
  bool _isTrackingLoading = false;
  String? _trackingError;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();

      if (appState.salesOrders.isEmpty) appState.refreshSalesOrders();
      if (appState.purchaseOrders.isEmpty) appState.refreshPurchaseOrders();
      if (appState.warehouses.isEmpty) appState.refreshWarehouses();
      if (appState.inventory.isEmpty) appState.refreshInventory();
      if (appState.salesInvoices.isEmpty) appState.refreshSalesInvoices();
      if (appState.purchaseInvoices.isEmpty) {
        appState.refreshPurchaseInvoices();
      }
      if (!appState.hasFullOrderSummary) {
        appState.refreshOrderSummaries();
      }
      appState.fetchSalesOrderApprovals();
      _loadSalesTracking();
    });
  }

  Future<void> _loadSalesTracking() async {
    if (!mounted || _isTrackingLoading) return;
    setState(() {
      _isTrackingLoading = true;
      _trackingError = null;
    });
    try {
      final rows = await context
          .read<AppState>()
          .fetchLatestSalesTrackingPoints();
      if (!mounted) return;
      setState(() => _salesTrackingPoints = rows);
    } catch (error) {
      if (!mounted) return;
      setState(() => _trackingError = error.toString());
    } finally {
      if (mounted) setState(() => _isTrackingLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final summary = appState.dashboardSummary;
    final pendingPurchasesCount = summary.purchasePendingCount;
    final openSalesCount = summary.salesOpenCount;
    final lowStockCount = summary.stockAlerts;
    final unpaidSiCount = summary.unpaidSalesInvoices;
    final overduePiCount = summary.overduePurchaseInvoices;

    final salesStats = _SalesMoneyStats(
      total: summary.salesTotal,
      open: summary.salesOpen,
      completed: summary.salesCompleted,
      draftCount: summary.salesDraftCount,
      openCount: summary.salesOpenCount,
      completedCount: summary.salesCompletedCount,
    );
    final purchaseStats = _PurchaseMoneyStats(
      total: summary.purchaseTotal,
      pending: summary.purchasePending,
      delayed: summary.purchaseDelayed,
      draftCount: summary.purchaseDraftCount,
      pendingCount: summary.purchasePendingCount,
      completedCount: summary.purchaseCompletedCount,
    );

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await Future.wait([
          appState.refreshSalesOrders(),
          appState.refreshPurchaseOrders(),
          appState.refreshSalesInvoices(),
          appState.refreshPurchaseInvoices(),
          appState.refreshInventory(),
          appState.refreshAllSummaries(),
          appState.fetchSalesOrderApprovals(),
          _loadSalesTracking(),
        ]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OperationsSnapshot(
              openSales: openSalesCount,
              unpaidInvoices: unpaidSiCount,
              pendingPurchases: pendingPurchasesCount,
              stockAlerts: lowStockCount,
            ),
            if (appState.isOrderSummaryLoading) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            if (appState.orderSummaryError != null) ...[
              const SizedBox(height: 10),
              Text(
                'Summary sync failed: ${appState.orderSummaryError}',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],

            const SizedBox(height: 18),

            _SalesmanLiveMapCard(
              points: _salesTrackingPoints,
              loading: _isTrackingLoading,
              error: _trackingError,
              onRefresh: _loadSalesTracking,
            ),

            const SizedBox(height: 18),

            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              children: [
                DashboardKpiCard(
                  title: 'UNPAID SALES INVOICES',
                  value: '$unpaidSiCount',
                  trend: unpaidSiCount > 0 ? 'Unpaid' : 'Clear',
                  trendColor: unpaidSiCount > 0
                      ? Colors.orange
                      : AppColors.tertiary,
                  icon: Icons.receipt_long_outlined,
                  iconColor: AppColors.primary,
                ),
                DashboardKpiCard(
                  title: 'OVERDUE PURCHASE INVOICES',
                  value: '$overduePiCount',
                  trend: overduePiCount > 0 ? 'Overdue' : 'Clear',
                  trendColor: overduePiCount > 0
                      ? Colors.red
                      : AppColors.tertiary,
                  icon: Icons.payments_outlined,
                  iconColor: overduePiCount > 0
                      ? Colors.red
                      : const Color(0xFFCA8A04),
                ),
                DashboardKpiCard(
                  title: 'PENDING PURCHASE ORDERS',
                  value: '$pendingPurchasesCount',
                  trend: 'Pending',
                  trendColor: AppColors.accentYellow,
                  icon: Icons.local_shipping_outlined,
                  iconColor: const Color(0xFFCA8A04),
                ),
                DashboardKpiCard(
                  title: 'STOCK ALERTS',
                  value: '$lowStockCount',
                  trend: lowStockCount > 0 ? 'Low Stock' : 'Clear',
                  trendColor: lowStockCount > 0
                      ? Colors.red
                      : AppColors.tertiary,
                  icon: Icons.warning_amber_outlined,
                  iconColor: lowStockCount > 0
                      ? Colors.red
                      : AppColors.primaryLight,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SalesmanLiveMapCard extends StatelessWidget {
  final List<SalesTrackingPoint> points;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;

  const _SalesmanLiveMapCard({
    required this.points,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final activePoints = points
        .where((point) => point.latitude != 0 || point.longitude != 0)
        .toList();

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
                      'Live Sales Tracking',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      activePoints.isEmpty
                          ? 'Belum ada lokasi salesman aktif'
                          : '${activePoints.length} salesman terpantau',
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
                        painter: _SalesTrackingMapPainter(activePoints),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 12,
                              top: 12,
                              child: _MapLegend(count: activePoints.length),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
          if (activePoints.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...activePoints.take(3).map((point) => _TrackingPointRow(point)),
            if (activePoints.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '+${activePoints.length - 3} salesman lainnya',
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
                ? 'Mulai perjalanan sales untuk menampilkan marker hijau.'
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
  final int count;

  const _MapLegend({required this.count});

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
        const SizedBox(width: 6),
        Text(
          '$count aktif',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _TrackingPointRow extends StatelessWidget {
  final SalesTrackingPoint point;

  const _TrackingPointRow(this.point);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.softGreen,
          foregroundColor: AppColors.primary,
          child: Icon(Icons.two_wheeler_rounded, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                point.salesPerson.isEmpty
                    ? 'Salesman belum dipetakan'
                    : point.salesPerson,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              Text(
                point.customer.isEmpty
                    ? 'Customer belum tersedia'
                    : point.customer,
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
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );

  String _timeLabel(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _SalesTrackingMapPainter extends CustomPainter {
  final List<SalesTrackingPoint> points;

  const _SalesTrackingMapPainter(this.points);

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
    final markerPaint = Paint()..color = AppColors.primary;
    final markerShadowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final dx = lngSpan == 0
          ? size.width / 2
          : 22 + ((point.longitude - minLng) / lngSpan) * (size.width - 44);
      final dy = latSpan == 0
          ? size.height / 2
          : 22 + ((maxLat - point.latitude) / latSpan) * (size.height - 44);
      final offset = Offset(dx.toDouble(), dy.toDouble());

      canvas.drawCircle(offset, 18, markerShadowPaint);
      canvas.drawCircle(offset, 13, markerPaint);
      _paintVehicleIcon(canvas, offset);
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

  void _paintVehicleIcon(Canvas canvas, Offset center) {
    const icon = Icons.two_wheeler_rounded;
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
  bool shouldRepaint(covariant _SalesTrackingMapPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _SalesMoneyStats {
  final double total;
  final double open;
  final double completed;
  final int draftCount;
  final int openCount;
  final int completedCount;

  const _SalesMoneyStats({
    required this.total,
    required this.open,
    required this.completed,
    required this.draftCount,
    required this.openCount,
    required this.completedCount,
  });
}

class _PurchaseMoneyStats {
  final double total;
  final double pending;
  final double delayed;
  final int draftCount;
  final int pendingCount;
  final int completedCount;

  const _PurchaseMoneyStats({
    required this.total,
    required this.pending,
    required this.delayed,
    required this.draftCount,
    required this.pendingCount,
    required this.completedCount,
  });
}

class _OperationsSnapshot extends StatelessWidget {
  final int openSales;
  final int unpaidInvoices;
  final int pendingPurchases;
  final int stockAlerts;

  const _OperationsSnapshot({
    required this.openSales,
    required this.unpaidInvoices,
    required this.pendingPurchases,
    required this.stockAlerts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prioritas Hari Ini',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _priorityMessage,
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SnapshotMetric(
                  icon: Icons.point_of_sale_rounded,
                  label: 'Open SO',
                  value: openSales,
                ),
              ),
              Expanded(
                child: _SnapshotMetric(
                  icon: Icons.receipt_long_rounded,
                  label: 'Unpaid',
                  value: unpaidInvoices,
                ),
              ),
              Expanded(
                child: _SnapshotMetric(
                  icon: Icons.shopping_bag_rounded,
                  label: 'Pending PO',
                  value: pendingPurchases,
                ),
              ),
              Expanded(
                child: _SnapshotMetric(
                  icon: Icons.warning_amber_rounded,
                  label: 'Stock',
                  value: stockAlerts,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _priorityMessage {
    if (stockAlerts > 0) {
      return 'Cek stok kritis sebelum membuat transaksi baru.';
    }
    if (unpaidInvoices > 0) {
      return 'Ada invoice sales yang perlu ditindaklanjuti.';
    }
    if (pendingPurchases > 0) {
      return 'Pantau PO yang belum selesai dan jadwal penerimaan.';
    }
    return 'Operasional terlihat aman. Tarik layar untuk sinkronisasi.';
  }
}

class _SnapshotMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _SnapshotMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.white, size: 18),
        ),
        const SizedBox(height: 7),
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.white.withValues(alpha: 0.72),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
