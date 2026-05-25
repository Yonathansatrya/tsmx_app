import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/purchase_order.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

class PurchaseTab extends StatefulWidget {
  const PurchaseTab({super.key});

  @override
  State<PurchaseTab> createState() => _PurchaseTabState();
}

class _PurchaseTabState extends State<PurchaseTab> {
  PurchaseOrderStatus? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();

      if (appState.purchaseOrders.isEmpty) {
        appState.refreshPurchaseOrders();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final filteredPurchaseOrders = appState.purchaseOrders.where((po) {
      return _selectedStatusFilter == null ||
          po.status == _selectedStatusFilter;
    }).toList();

    final toReceiveCount = appState.purchaseOrders
        .where(
          (po) =>
              po.status == PurchaseOrderStatus.toReceive ||
              po.status == PurchaseOrderStatus.toReceiveAndBill,
        )
        .length;

    final delayedCount = appState.purchaseOrders
        .where((po) => po.status == PurchaseOrderStatus.delayed)
        .length;

    final totalValue = filteredPurchaseOrders.fold<double>(
      0,
      (sum, po) => sum + po.totalValue,
    );

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: appState.refreshPurchaseOrders,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          _PurchaseSummaryCard(
            totalValue: totalValue,
            totalOrders: filteredPurchaseOrders.length,
            toReceiveCount: toReceiveCount,
            delayedCount: delayedCount,
            isLoading: appState.isPurchaseOrdersLoading,
          ),

          const SizedBox(height: 14),

          _PurchaseFilterSection(
            selectedStatus: _selectedStatusFilter,
            errorText: appState.purchaseOrdersError,
            onStatusChanged: (status) {
              setState(() {
                _selectedStatusFilter = status;
              });
            },
          ),

          const SizedBox(height: 14),

          if (filteredPurchaseOrders.isEmpty)
            const _PurchaseEmptyState()
          else
            ...filteredPurchaseOrders.map(
              (po) => _PurchaseOrderCard(
                po: po,
                onTap: () => _showPurchaseOrderDetail(context, po),
              ),
            ),
        ],
      ),
    );
  }

  void _showPurchaseOrderDetail(BuildContext context, PurchaseOrder po) {
    final statusStyle = _purchaseStatusStyle(po.status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      po.id,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              Text(
                po.vendor,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate,
                ),
              ),

              const SizedBox(height: 16),

              _StatusBadge(
                label: statusStyle.label,
                color: statusStyle.color,
                icon: statusStyle.icon,
              ),

              const SizedBox(height: 18),

              _DetailCard(
                children: [
                  _DetailRow('Supplier', po.vendor),
                  _DetailRow('Status ERP', po.statusText),
                  _DetailRow('Expected Date', po.eta.isEmpty ? '-' : po.eta),
                  _DetailRow('Total Qty', '${po.itemsCount}'),
                  _DetailRow(
                    'Total Value',
                    'Rp ${_formatCurrency(po.totalValue)}',
                  ),
                ],
              ),

              const SizedBox(height: 18),

              const Text(
                'Note',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.navy,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Data ini dibaca dari Purchase Order ERPNext. Untuk create/edit PO asli, nanti perlu dibuat API POST/PUT ke Frappe.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppColors.slate,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PurchaseSummaryCard extends StatelessWidget {
  final double totalValue;
  final int totalOrders;
  final int toReceiveCount;
  final int delayedCount;
  final bool isLoading;

  const _PurchaseSummaryCard({
    required this.totalValue,
    required this.totalOrders,
    required this.toReceiveCount,
    required this.delayedCount,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
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
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Purchase Orders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ringkasan pembelian',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Live',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 22),

          Text(
            'Rp ${_formatCurrency(totalValue)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),

          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _MiniBadge(
                  label: '$totalOrders orders',
                  icon: Icons.assignment_outlined,
                ),
                const SizedBox(width: 8),
                _MiniBadge(
                  label: '$toReceiveCount to receive',
                  icon: Icons.inventory_2_outlined,
                ),
                const SizedBox(width: 8),
                _MiniBadge(
                  label: '$delayedCount delayed',
                  icon: Icons.warning_amber_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseFilterSection extends StatelessWidget {
  final PurchaseOrderStatus? selectedStatus;
  final String? errorText;
  final ValueChanged<PurchaseOrderStatus?> onStatusChanged;

  const _PurchaseFilterSection({
    required this.selectedStatus,
    required this.errorText,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          if (errorText != null) ...[
            _ErrorBox(message: errorText!),
            const SizedBox(height: 12),
          ],

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChipItem(
                  label: 'All',
                  status: null,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'Draft',
                  status: PurchaseOrderStatus.draft,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'Pending',
                  status: PurchaseOrderStatus.pending,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'To Receive',
                  status: PurchaseOrderStatus.toReceive,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'To Bill',
                  status: PurchaseOrderStatus.toBill,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'Receive & Bill',
                  status: PurchaseOrderStatus.toReceiveAndBill,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'Delayed',
                  status: PurchaseOrderStatus.delayed,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'Completed',
                  status: PurchaseOrderStatus.completed,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'Closed',
                  status: PurchaseOrderStatus.closed,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'Cancelled',
                  status: PurchaseOrderStatus.cancelled,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final String label;
  final PurchaseOrderStatus? status;
  final PurchaseOrderStatus? selectedStatus;
  final ValueChanged<PurchaseOrderStatus?> onSelected;

  const _FilterChipItem({
    required this.label,
    required this.status,
    required this.selectedStatus,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedStatus == status;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.slate,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => onSelected(status),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.background,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.08),
          ),
        ),
      ),
    );
  }
}

class _PurchaseOrderCard extends StatelessWidget {
  final PurchaseOrder po;
  final VoidCallback onTap;

  const _PurchaseOrderCard({required this.po, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusStyle = _purchaseStatusStyle(po.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        po.id,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        po.vendor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${po.itemsCount} qty • ETA ${po.eta.isEmpty ? '-' : po.eta}',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.slate.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rp ${_formatCurrency(po.totalValue)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusBadge(
                      label: statusStyle.label,
                      color: statusStyle.color,
                      icon: statusStyle.icon,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MiniBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.15)),
      ),
      child: Text(
        'Unable to load purchase orders. $message',
        style: const TextStyle(
          color: Colors.red,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PurchaseEmptyState extends StatelessWidget {
  const _PurchaseEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: const [
          Icon(
            Icons.assignment_late_outlined,
            size: 48,
            color: AppColors.slate,
          ),
          SizedBox(height: 12),
          Text(
            'No purchase orders found',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Try changing the status filter or pull down to refresh.',
            style: TextStyle(color: AppColors.slate, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;

  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.06)),
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.slate, fontSize: 12),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseStatusStyle {
  final String label;
  final Color color;
  final IconData icon;

  const _PurchaseStatusStyle({
    required this.label,
    required this.color,
    required this.icon,
  });
}

_PurchaseStatusStyle _purchaseStatusStyle(PurchaseOrderStatus status) {
  switch (status) {
    case PurchaseOrderStatus.draft:
      return const _PurchaseStatusStyle(
        label: 'DRAFT',
        color: AppColors.slate,
        icon: Icons.edit_rounded,
      );
    case PurchaseOrderStatus.pending:
      return const _PurchaseStatusStyle(
        label: 'PENDING',
        color: Color(0xFFF59E0B),
        icon: Icons.hourglass_top_rounded,
      );
    case PurchaseOrderStatus.toReceive:
      return const _PurchaseStatusStyle(
        label: 'TO RECEIVE',
        color: Color(0xFF2563EB),
        icon: Icons.inventory_2_rounded,
      );
    case PurchaseOrderStatus.toBill:
      return const _PurchaseStatusStyle(
        label: 'TO BILL',
        color: Color(0xFFEAB308),
        icon: Icons.receipt_long_rounded,
      );
    case PurchaseOrderStatus.toReceiveAndBill:
      return const _PurchaseStatusStyle(
        label: 'RECEIVE & BILL',
        color: Color(0xFF7C3AED),
        icon: Icons.sync_alt_rounded,
      );
    case PurchaseOrderStatus.delayed:
      return const _PurchaseStatusStyle(
        label: 'DELAYED',
        color: Color(0xFFDC2626),
        icon: Icons.error_outline_rounded,
      );
    case PurchaseOrderStatus.completed:
      return const _PurchaseStatusStyle(
        label: 'COMPLETED',
        color: Color(0xFF16A34A),
        icon: Icons.check_circle_rounded,
      );
    case PurchaseOrderStatus.closed:
      return const _PurchaseStatusStyle(
        label: 'CLOSED',
        color: Color(0xFF4F46E5),
        icon: Icons.lock_rounded,
      );
    case PurchaseOrderStatus.cancelled:
      return const _PurchaseStatusStyle(
        label: 'CANCELLED',
        color: Color(0xFF64748B),
        icon: Icons.cancel_rounded,
      );
  }
}

String _formatCurrency(double val) {
  final strVal = val.toInt().toString();
  final buffer = StringBuffer();
  int count = 0;

  for (int i = strVal.length - 1; i >= 0; i--) {
    buffer.write(strVal[i]);
    count++;

    if (count == 3 && i > 0) {
      buffer.write('.');
      count = 0;
    }
  }

  return buffer.toString().split('').reversed.join('');
}
