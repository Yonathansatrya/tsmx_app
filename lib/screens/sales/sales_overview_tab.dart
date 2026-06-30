import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sales_workspace.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/date_range_presets.dart';
import '../../utils/erp_format.dart';
import '../../widgets/erp/erp_empty_state.dart';
import '../../widgets/erp/erp_error_box.dart';
import '../../widgets/erp/erp_status_badge.dart';
import 'collection/collection_widgets.dart';
import 'sales_ui.dart';

class SalesOverviewTab extends StatefulWidget {
  final ValueChanged<int> onMenuSelected;
  final ValueChanged<int>? onOrderTabSelected;

  const SalesOverviewTab({
    super.key,
    required this.onMenuSelected,
    this.onOrderTabSelected,
  });

  @override
  State<SalesOverviewTab> createState() => _SalesOverviewTabState();
}

class _SalesOverviewTabState extends State<SalesOverviewTab> {
  late DateRangePreset _rankingRange;
  List<CollectionRanking> _ranking = const [];
  bool _rankingLoading = true;
  String? _rankingError;

  @override
  void initState() {
    super.initState();
    _rankingRange = DateRangePresets.monthToDateRange();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRanking());
  }

  Future<void> _loadRanking() async {
    final state = context.read<AppState>();
    if (!_canViewRanking(state)) {
      if (mounted) {
        setState(() {
          _ranking = const [];
          _rankingLoading = false;
          _rankingError = null;
        });
      }
      return;
    }
    setState(() {
      _rankingLoading = true;
      _rankingError = null;
    });
    try {
      final ranking = await state.fetchCollectionRanking(
        from: _rankingRange.from,
        to: _rankingRange.to,
      );
      if (mounted) setState(() => _ranking = ranking);
    } catch (error) {
      if (mounted) setState(() => _rankingError = error.toString());
    } finally {
      if (mounted) setState(() => _rankingLoading = false);
    }
  }

  Future<void> _pickRankingRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _rankingRange.from,
        end: _rankingRange.to,
      ),
    );
    if (picked == null) return;
    setState(() {
      _rankingRange = DateRangePreset(from: picked.start, to: picked.end);
    });
    await _loadRanking();
  }

  bool _canViewRanking(AppState state) {
    return state.isSalesManagerRole ||
        state.mobileAccess.isAdministrator ||
        state.mobileAccess.isDeveloper ||
        state.mobileAccess.isCompanyAdministrator ||
        state.mobileAccess.isDirector;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final canViewRanking = _canViewRanking(state);
    final orders = state.salesOrders;
    final outstanding = state.salesInvoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.outstandingAmount,
    );
    return RefreshIndicator(
      onRefresh: () async {
        await state.refreshDataForCurrentRole();
        await _loadRanking();
      },
      child: ListView(
        padding: SalesUi.screenPadding,
        children: [
          SalesHeroCard(
            title: 'Sales Workspace',
            subtitle: 'Pantau order, stok, customer, collection, dan visit',
            icon: Icons.point_of_sale_rounded,
          ),
          SalesUi.gap(14),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Order',
                  value: '${orders.length}',
                  icon: Icons.receipt_long_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  label: 'Draft',
                  value: '${orders.where((o) => o.docStatus == 0).length}',
                  icon: Icons.edit_note_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Metric(
                  label: 'Outstanding',
                  value: 'Rp ${formatErpCurrency(outstanding)}',
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
            ],
          ),
          SalesUi.gap(18),
          const SalesSectionTitle(
            title: 'Menu Cepat',
            subtitle: 'Aksi harian yang paling sering dipakai sales',
          ),
          SalesUi.gap(10),
          _QuickMenuGrid(
            items: [
              _QuickMenuItem(
                label: 'Sales Order',
                icon: Icons.receipt_long,
                tap: () {
                  widget.onOrderTabSelected?.call(0);
                  widget.onMenuSelected(1);
                },
              ),
              _QuickMenuItem(
                label: 'Delivery Note',
                icon: Icons.local_shipping_outlined,
                tap: () {
                  widget.onOrderTabSelected?.call(1);
                  widget.onMenuSelected(1);
                },
              ),
              _QuickMenuItem(
                label: 'Invoice',
                icon: Icons.request_quote_outlined,
                tap: () {
                  widget.onOrderTabSelected?.call(2);
                  widget.onMenuSelected(1);
                },
              ),
              _QuickMenuItem(
                label: 'Collection',
                icon: Icons.account_balance_wallet,
                tap: () => widget.onMenuSelected(2),
              ),
              _QuickMenuItem(
                label: 'Sales Visit',
                icon: Icons.route_rounded,
                tap: () => widget.onMenuSelected(3),
                fullWidth: true,
              ),
            ],
          ),
          SalesUi.gap(22),
          const SalesSectionTitle(
            title: 'Order Terbaru',
            subtitle: 'Status order terakhir yang perlu dipantau',
          ),
          SalesUi.gap(10),
          if (orders.isEmpty) ...[
            const ErpEmptyState(
              title: 'Belum ada Sales Order',
              message: 'Tekan menu Sales Order untuk membuat order pertama.',
            ),
            FilledButton.icon(
              onPressed: () {
                widget.onOrderTabSelected?.call(0);
                widget.onMenuSelected(1);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Buat Sales Order'),
            ),
          ] else
            ...orders
                .take(5)
                .map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SalesInfoCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.id,
                                  style: const TextStyle(
                                    color: AppColors.navy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${order.customer} - ${order.date}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.slate,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          ErpStatusBadge(statusText: order.statusText),
                        ],
                      ),
                    ),
                  ),
                ),
          if (canViewRanking) ...[
            SalesUi.gap(18),
            CollectionSectionHeader(
              title: 'Ranking Collection',
              subtitle: 'Berdasarkan nilai Sales Order dari Sales Team',
              icon: Icons.emoji_events_rounded,
              trailing: IconButton.filledTonal(
                tooltip: 'Pilih periode',
                onPressed: _pickRankingRange,
                icon: const Icon(Icons.date_range_rounded),
              ),
            ),
            SalesUi.gap(10),
            if (_rankingLoading)
              const LinearProgressIndicator()
            else if (_rankingError != null)
              ErpErrorBox(message: _rankingError!)
            else if (_ranking.isEmpty)
              const ErpEmptyState(
                title: 'Belum ada Sales Order pada periode ini',
                message:
                    'Ranking dibaca dari Sales Team pada Sales Order sesuai periode.',
              )
            else
              ..._ranking
                  .take(5)
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SalesInfoCard(
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: row.rank <= 3
                                  ? AppColors.accentYellow.withValues(
                                      alpha: 0.35,
                                    )
                                  : AppColors.softGreen,
                              foregroundColor: AppColors.primaryDark,
                              child: Text(
                                '${row.rank}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                row.salesPerson,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              'Rp ${formatErpCurrency(row.amount)}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Metric({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 82),
    padding: const EdgeInsets.all(12),
    decoration: SalesUi.cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.softGreen,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 16),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.slate,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _QuickMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback tap;
  final bool fullWidth;

  const _QuickMenuItem({
    required this.label,
    required this.icon,
    required this.tap,
    this.fullWidth = false,
  });
}

class _QuickMenuGrid extends StatelessWidget {
  final List<_QuickMenuItem> items;

  const _QuickMenuGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final itemWidth = (MediaQuery.sizeOf(context).width - 42) / 2;
    final fullWidth = MediaQuery.sizeOf(context).width - 32;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          _Menu(item: item, width: item.fullWidth ? fullWidth : itemWidth),
      ],
    );
  }
}

class _Menu extends StatelessWidget {
  final _QuickMenuItem item;
  final double width;

  const _Menu({required this.item, required this.width});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: SalesInfoCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      onTap: item.tap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.softGreen,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(item.icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.slate,
            size: 18,
          ),
        ],
      ),
    ),
  );
}
