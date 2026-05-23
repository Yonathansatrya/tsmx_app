import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../models/sales_order.dart';
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
      final appState = Provider.of<AppState>(context, listen: false);
      appState.refreshSalesOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    final filteredOrders = appState.salesOrders.where((order) {
      final matchesSearch =
          order.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.customer.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus =
          _selectedStatusFilter == null ||
          order.status == _selectedStatusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    double totalSalesValue = filteredOrders.fold(
      0,
      (sum, order) => sum + order.value,
    );

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF135E39).withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF135E39).withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
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
                      color: const Color(0xFF135E39).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: Color(0xFF135E39),
                      size: 22,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Sales Analytics',
                          style: TextStyle(
                            fontFamily: 'HankenGrotesk',
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                          ),
                        ),

                        SizedBox(height: 2),

                        Text(
                          'Realtime Transaction Value',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F3E6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Sync with Frappe ERP',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF135E39),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Text(
                'Rp ${_formatCurrency(totalSalesValue)}',
                style: const TextStyle(
                  fontFamily: 'HankenGrotesk',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF135E39),
                  height: 1,
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F3E6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${filteredOrders.length} Active Orders',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF135E39),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Text(
                    'Updated realtime from ERPNext',
                    style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF135E39).withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F2618).withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by Order ID or Customer...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFF135E39),
                      size: 20,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF135E39),
                        width: 1.2,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                if (appState.salesOrdersError != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.15)),
                    ),
                    child: Text(
                      'API error: ${appState.salesOrdersError}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: appState.isSalesOrdersLoading
                              ? null
                              : () => appState.fetchSalesOrdersFromFrappe(
                                  baseUrl: 'http://apps.willshine.id:8014',
                                ),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFF135E39),
                            disabledBackgroundColor: const Color(
                              0xFF135E39,
                            ).withOpacity(0.45),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(
                            Icons.cloud_download_outlined,
                            size: 17,
                          ),
                          label: Text(
                            appState.isSalesOrdersLoading
                                ? 'Loading...'
                                : 'Refresh dari Frappe',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (appState.isSalesOrdersLoading) ...[
                      const SizedBox(width: 12),
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Color(0xFF135E39),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', null),
                      const SizedBox(width: 8),
                      _buildFilterChip('Draft', SalesOrderStatus.draft),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending', SalesOrderStatus.pending),
                      const SizedBox(width: 8),
                      _buildFilterChip('To Bill', SalesOrderStatus.to_bill),
                      const SizedBox(width: 8),
                      _buildFilterChip('Overdue', SalesOrderStatus.overdue),
                      const SizedBox(width: 8),
                      _buildFilterChip('Shipped', SalesOrderStatus.shipped),
                      const SizedBox(width: 8),
                      _buildFilterChip('Delivered', SalesOrderStatus.delivered),
                      const SizedBox(width: 8),
                      _buildFilterChip('Completed', SalesOrderStatus.completed),
                      const SizedBox(width: 8),
                      _buildFilterChip('Closed', SalesOrderStatus.closed),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: filteredOrders.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return _buildOrderCard(context, order);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, SalesOrderStatus? status) {
    final isSelected = _selectedStatusFilter == status;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF64748B),
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedStatusFilter = status;
        });
      },
      selectedColor: AppColors.primary,
      backgroundColor: const Color(0xFFF8FAFC),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.grey.shade200,
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, SalesOrder order) {
    Color statusColor = Colors.grey;
    String statusLabel = 'UNKNOWN';
    IconData statusIcon = Icons.help;

    switch (order.status) {
      case SalesOrderStatus.draft:
        statusColor = Colors.grey;
        statusLabel = 'DRAFT';
        statusIcon = Icons.edit;
        break;
      case SalesOrderStatus.pending:
        statusColor = Colors.orange;
        statusLabel = 'PENDING';
        statusIcon = Icons.hourglass_top;
        break;
      case SalesOrderStatus.overdue:
        statusColor = Colors.red;
        statusLabel = 'OVERDUE';
        statusIcon = Icons.error;
        break;
      case SalesOrderStatus.to_bill:
        statusColor = Colors.amber;
        statusLabel = 'TO BILL';
        statusIcon = Icons.receipt;
        break;
      case SalesOrderStatus.shipped:
        statusColor = Colors.blue;
        statusLabel = 'SHIPPED';
        statusIcon = Icons.local_shipping;
        break;
      case SalesOrderStatus.delivered:
        statusColor = Colors.green;
        statusLabel = 'DELIVERED';
        statusIcon = Icons.check_circle;
        break;
      case SalesOrderStatus.completed:
        statusColor = Colors.teal;
        statusLabel = 'COMPLETED';
        statusIcon = Icons.done_all;
        break;
      case SalesOrderStatus.closed:
        statusColor = Colors.indigo;
        statusLabel = 'CLOSED';
        statusIcon = Icons.lock;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF135E39).withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.receipt_long, color: Color(0xFF135E39)),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              order.id,
              style: const TextStyle(
                fontFamily: 'HankenGrotesk',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1E293B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, color: statusColor, size: 10),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              order.customer,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 4),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order.itemsCount} items  •  ${order.date}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  'Rp ${_formatCurrency(order.value)}',
                  style: const TextStyle(
                    fontFamily: 'HankenGrotesk',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF135E39),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _showOrderDetailsBottomSheet(context, order),
      ),
    );
  }

  void _showOrderDetailsBottomSheet(BuildContext context, SalesOrder order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order details: ${order.id}',
                    style: const TextStyle(
                      fontFamily: 'HankenGrotesk',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const Divider(),

              const SizedBox(height: 8),

              _buildDetailRow('Customer', order.customer),
              _buildDetailRow('Transaction Date', order.date),
              _buildDetailRow('Total Items Count', '${order.itemsCount} units'),
              _buildDetailRow(
                'Net Value',
                'Rp ${_formatCurrency(order.value)}',
              ),
              _buildDetailRow('Status', order.status.name.toUpperCase()),

              const SizedBox(height: 18),

              const Text(
                'ORDER ITEMS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 10),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        children: const [
                          Expanded(
                            flex: 5,
                            child: Text(
                              'ITEM',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF64748B),
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
                                color: Color(0xFF64748B),
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
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    ...order.items.map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade100),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                item.itemName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),

                            Expanded(
                              flex: 2,
                              child: Text(
                                '${item.qty}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),

                            Expanded(
                              flex: 3,
                              child: Text(
                                'Rp ${_formatCurrency(item.rate)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF135E39),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Text(
                'LOGISTICS TRACKING TIMELINE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 12),

              _buildTimelineStep(
                '2026-05-21 08:30',
                'Order finalized and processed via API',
              ),
              if (order.status == SalesOrderStatus.shipped ||
                  order.status == SalesOrderStatus.delivered)
                _buildTimelineStep(
                  '2026-05-21 10:15',
                  'Cargo dispatched from Jakarta Depot (Gate A)',
                ),
              if (order.status == SalesOrderStatus.delivered)
                _buildTimelineStep(
                  '2026-05-21 14:00',
                  'Handed over and verified at destination',
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String time, String message) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF135E39),
                shape: BoxShape.circle,
              ),
            ),
            Container(width: 1.5, height: 25, color: Colors.grey.shade300),
          ],
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                message,
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.search_off, size: 48, color: Colors.grey),

          SizedBox(height: 12),

          Text(
            'No sales orders found',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          Text(
            'Try adjusting your search query or status filter.',
            style: TextStyle(color: Colors.grey, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
}
