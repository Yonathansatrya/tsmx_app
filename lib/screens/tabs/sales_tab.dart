import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sales_order.dart';
import '../../state/app_state.dart';
import '../../theme/app_colors.dart';

class SalesTab extends StatefulWidget {
  const SalesTab({super.key});

  @override
  State<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<SalesTab> {
  String _searchQuery = '';
  SalesOrderStatus? _selectedStatusFilter;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();

      if (appState.salesOrders.isEmpty) {
        appState.refreshSalesOrders();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final filteredOrders = appState.salesOrders.where((order) {
      final query = _searchQuery.toLowerCase();

      final matchesSearch =
          order.id.toLowerCase().contains(query) ||
          order.customer.toLowerCase().contains(query);

      final matchesStatus =
          _selectedStatusFilter == null ||
          order.status == _selectedStatusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    final totalSalesValue = filteredOrders.fold<double>(
      0,
      (sum, order) => sum + order.value,
    );

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: appState.refreshSalesOrders,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          _SalesSummaryCard(
            totalSalesValue: totalSalesValue,
            orderCount: filteredOrders.length,
            isLoading: appState.isSalesOrdersLoading,
          ),

          const SizedBox(height: 14),

          _SalesSearchAndFilter(
            searchQuery: _searchQuery,
            selectedStatus: _selectedStatusFilter,
            errorText: appState.salesOrdersError,
            onSearchChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            onStatusChanged: (status) {
              setState(() {
                _selectedStatusFilter = status;
              });
            },
          ),

          const SizedBox(height: 14),

          if (filteredOrders.isEmpty)
            const _SalesEmptyState()
          else
            ...filteredOrders.map(
              (order) => _SalesOrderCard(
                order: order,
                onTap: () => _showOrderDetailsBottomSheet(context, order),
              ),
            ),
        ],
      ),
    );
  }

  void _showOrderDetailsBottomSheet(BuildContext context, SalesOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
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
                          order.id,
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

                  Text(
                    order.customer,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate,
                    ),
                  ),

                  const SizedBox(height: 20),

                  _DetailCard(
                    children: [
                      _DetailRow('Customer', order.customer),
                      _DetailRow('Transaction Date', order.date),
                      _DetailRow('Total Items', '${order.itemsCount} items'),
                      _DetailRow(
                        'Net Value',
                        'Rp ${_formatCurrency(order.value)}',
                      ),
                      _DetailRow(
                        'Status',
                        order.status.name.toUpperCase().replaceAll('_', ' '),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Order Items',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                    ),
                  ),

                  const SizedBox(height: 10),

                  _OrderItemsTable(order: order),

                  const SizedBox(height: 18),

                  const Text(
                    'Timeline',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _TimelineStep(
                    time: '${order.date} 08:30',
                    message: 'Sales order created and confirmed.',
                    isLast: false,
                  ),
                  if (order.status == SalesOrderStatus.shipped ||
                      order.status == SalesOrderStatus.delivered ||
                      order.status == SalesOrderStatus.completed)
                    _TimelineStep(
                      time: '${order.date} 10:15',
                      message: 'Order prepared for delivery.',
                      isLast: false,
                    ),
                  if (order.status == SalesOrderStatus.delivered ||
                      order.status == SalesOrderStatus.completed)
                    _TimelineStep(
                      time: '${order.date} 14:00',
                      message: 'Order delivered to customer.',
                      isLast: true,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SalesSummaryCard extends StatelessWidget {
  final double totalSalesValue;
  final int orderCount;
  final bool isLoading;

  const _SalesSummaryCard({
    required this.totalSalesValue,
    required this.orderCount,
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
                  Icons.receipt_long_rounded,
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
                      'Sales Orders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Ringkasan transaksi penjualan',
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
            'Rp ${_formatCurrency(totalSalesValue)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              _MiniBadge(
                label: '$orderCount orders',
                icon: Icons.shopping_bag_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesSearchAndFilter extends StatelessWidget {
  final String searchQuery;
  final SalesOrderStatus? selectedStatus;
  final String? errorText;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SalesOrderStatus?> onStatusChanged;

  const _SalesSearchAndFilter({
    required this.searchQuery,
    required this.selectedStatus,
    required this.errorText,
    required this.onSearchChanged,
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
          TextField(
            onChanged: onSearchChanged,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
            decoration: InputDecoration(
              hintText: 'Search order or customer...',
              hintStyle: const TextStyle(
                color: AppColors.slate,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.primary.withOpacity(0.06),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.3,
                ),
              ),
            ),
          ),

          if (errorText != null) ...[
            const SizedBox(height: 10),
            _ErrorBox(message: errorText!),
          ],

          const SizedBox(height: 12),

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
                  status: SalesOrderStatus.draft,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'Pending',
                  status: SalesOrderStatus.pending,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'To Bill',
                  status: SalesOrderStatus.toBill,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'Overdue',
                  status: SalesOrderStatus.overdue,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'Shipped',
                  status: SalesOrderStatus.shipped,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'Delivered',
                  status: SalesOrderStatus.delivered,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'Completed',
                  status: SalesOrderStatus.completed,
                  selectedStatus: selectedStatus,
                  onSelected: onStatusChanged,
                ),
                _FilterChipItem(
                  label: 'Closed',
                  status: SalesOrderStatus.closed,
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
  final SalesOrderStatus? status;
  final SalesOrderStatus? selectedStatus;
  final ValueChanged<SalesOrderStatus?> onSelected;

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

class _SalesOrderCard extends StatelessWidget {
  final SalesOrder order;
  final VoidCallback onTap;

  const _SalesOrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusStyle = _salesStatusStyle(order.status);

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
                    Icons.receipt_long_rounded,
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
                        order.id,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.customer,
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
                        '${order.itemsCount} items • ${order.date}',
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
                      'Rp ${_formatCurrency(order.value)}',
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
        'Unable to load sales orders. $message',
        style: const TextStyle(
          color: Colors.red,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SalesEmptyState extends StatelessWidget {
  const _SalesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: const [
          Icon(Icons.search_off_rounded, size: 48, color: AppColors.slate),
          SizedBox(height: 12),
          Text(
            'No sales orders found',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.navy,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Try changing your search or status filter.',
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
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemsTable extends StatelessWidget {
  final SalesOrder order;

  const _OrderItemsTable({required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.items.isEmpty) {
      return const Text(
        'No item details available.',
        style: TextStyle(color: AppColors.slate, fontSize: 12),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          const _OrderItemsHeader(),
          ...order.items.map(
            (item) => _OrderItemRow(
              name: item.itemName,
              qty: item.qty.toString(),
              price: 'Rp ${_formatCurrency(item.rate)}',
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemsHeader extends StatelessWidget {
  const _OrderItemsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              'ITEM',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppColors.slate,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'QTY',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppColors.slate,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'PRICE',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppColors.slate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final String name;
  final String qty;
  final String price;

  const _OrderItemRow({
    required this.name,
    required this.qty,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.primary.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              qty,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              price,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String time;
  final String message;
  final bool isLast;

  const _TimelineStep({
    required this.time,
    required this.message,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(width: 1.5, height: 28, color: AppColors.softGreen),
          ],
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.slate,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(fontSize: 12, color: AppColors.navy),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SalesStatusStyle {
  final String label;
  final Color color;
  final IconData icon;

  const _SalesStatusStyle({
    required this.label,
    required this.color,
    required this.icon,
  });
}

_SalesStatusStyle _salesStatusStyle(SalesOrderStatus status) {
  switch (status) {
    case SalesOrderStatus.draft:
      return const _SalesStatusStyle(
        label: 'DRAFT',
        color: AppColors.slate,
        icon: Icons.edit_rounded,
      );
    case SalesOrderStatus.pending:
      return const _SalesStatusStyle(
        label: 'PENDING',
        color: Color(0xFFF59E0B),
        icon: Icons.hourglass_top_rounded,
      );
    case SalesOrderStatus.overdue:
      return const _SalesStatusStyle(
        label: 'OVERDUE',
        color: Color(0xFFDC2626),
        icon: Icons.error_outline_rounded,
      );
    case SalesOrderStatus.toBill:
      return const _SalesStatusStyle(
        label: 'TO BILL',
        color: Color.fromARGB(255, 183, 141, 15),
        icon: Icons.receipt_rounded,
      );
    case SalesOrderStatus.shipped:
      return const _SalesStatusStyle(
        label: 'SHIPPED',
        color: Color(0xFF2563EB),
        icon: Icons.local_shipping_rounded,
      );
    case SalesOrderStatus.delivered:
      return const _SalesStatusStyle(
        label: 'DELIVERED',
        color: Color(0xFF059669),
        icon: Icons.check_circle_outline_rounded,
      );
    case SalesOrderStatus.completed:
      return const _SalesStatusStyle(
        label: 'COMPLETED',
        color: Color(0xFF0F766E),
        icon: Icons.done_all_rounded,
      );
    case SalesOrderStatus.closed:
      return const _SalesStatusStyle(
        label: 'CLOSED',
        color: Color(0xFF4F46E5),
        icon: Icons.lock_rounded,
      );
    case SalesOrderStatus.toReceive:
      return const _SalesStatusStyle(
        label: 'TO RECEIVE',
        color: Color(0xFF6366F1),
        icon: Icons.inbox_rounded,
      );
    case SalesOrderStatus.toReceiveAndBill:
      return const _SalesStatusStyle(
        label: 'TO RECEIVE + BILL',
        color: Color(0xFFDB2777),
        icon: Icons.playlist_add_check_rounded,
      );
    case SalesOrderStatus.delayed:
      return const _SalesStatusStyle(
        label: 'DELAYED',
        color: Color(0xFFE11D48),
        icon: Icons.warning_rounded,
      );
    case SalesOrderStatus.cancelled:
      return const _SalesStatusStyle(
        label: 'CANCELLED',
        color: Color(0xFF64748B),
        icon: Icons.cancel_rounded,
      );
    default:
      return const _SalesStatusStyle(
        label: 'UNKNOWN',
        color: Colors.grey,
        icon: Icons.help_outline_rounded,
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
