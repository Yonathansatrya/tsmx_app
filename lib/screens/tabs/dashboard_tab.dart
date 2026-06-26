import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sales_workspace.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/dashboard/dashboard_module_launcher.dart';
import '../../widgets/dashboard/live_operations_tracking_card.dart';

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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
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

            const DashboardModuleLauncher(),

            const SizedBox(height: 18),

            LiveOperationsTrackingCard(
              points: _trackingPoints(appState),
              loading: _isTrackingLoading,
              error: _trackingError,
              onRefresh: _loadSalesTracking,
            ),
          ],
        ),
      ),
    );
  }

  List<LiveTrackingPoint> _trackingPoints(AppState appState) {
    final salesPoints = _salesTrackingPoints.map(
      (point) => LiveTrackingPoint(
        type: LiveTrackingType.sales,
        title: point.salesPerson.isEmpty
            ? 'Salesman belum dipetakan'
            : point.salesPerson,
        subtitle: point.customer.isEmpty
            ? 'Customer belum tersedia'
            : point.customer,
        capturedAt: point.capturedAt,
        latitude: point.latitude,
        longitude: point.longitude,
      ),
    );
    final driverPoint = appState.latestDeliveryDriverLocation;
    final activeDeliveryNote = appState.activeDeliveryTrackingNote;
    final fleetPoints = driverPoint == null || activeDeliveryNote == null
        ? const <LiveTrackingPoint>[]
        : [
            LiveTrackingPoint(
              type: LiveTrackingType.fleet,
              title: 'Armada aktif',
              subtitle: activeDeliveryNote,
              capturedAt: driverPoint.capturedAt,
              latitude: driverPoint.latitude,
              longitude: driverPoint.longitude,
            ),
          ];
    return [...salesPoints, ...fleetPoints];
  }
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
        borderRadius: BorderRadius.circular(16),
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
