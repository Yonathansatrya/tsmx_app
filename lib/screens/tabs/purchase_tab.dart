import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../models/purchase_order.dart';

class PurchaseTab extends StatefulWidget {
  const PurchaseTab({super.key});

  @override
  State<PurchaseTab> createState() => _PurchaseTabState();
}

class _PurchaseTabState extends State<PurchaseTab> {
  PurchaseOrderStatus? _selectedStatusFilter; // null means 'All'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.refreshPurchaseOrders();
    });
  }

  // Vendors list for dropdown
  final List<String> _vendorsList = [
    'Steel Alloys Corp',
    'Sinotech Electronics',
    'Paper Products Ltd',
    'Global Logistics Parts',
    'Nippon Polymers',
    'TexChem Indonesia',
    'Sinar Mas Group',
  ];

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    // Filter purchase orders
    final filteredPO = appState.purchaseOrders.where((po) {
      return _selectedStatusFilter == null ||
          po.status == _selectedStatusFilter;
    }).toList();

    final isLoading = appState.isPurchaseOrdersLoading;
    final errorText = appState.purchaseOrdersError;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.01),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SUPPLY CHAIN INBOUNDS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${appState.purchaseOrders.where((p) => p.status == PurchaseOrderStatus.inTransit).length} IN TRANSIT',
                      style: const TextStyle(
                        fontFamily: 'HankenGrotesk',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF135E39),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Total Delayed orders: ${appState.purchaseOrders.where((p) => p.status == PurchaseOrderStatus.delayed).length}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showAddPoBottomSheet(context, appState),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'NEW PO',
                        style: TextStyle(
                          fontFamily: 'HankenGrotesk',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF135E39),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 34,
                      child: OutlinedButton.icon(
                        onPressed: () => appState.refreshPurchaseOrders(),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text(
                          'REFRESH',
                          style: TextStyle(
                            fontFamily: 'HankenGrotesk',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF135E39),
                          side: const BorderSide(color: Color(0xFF135E39)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (errorText != null) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Text(
                'Unable to load purchase orders: $errorText',
                style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (isLoading) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(),
            ),
            const SizedBox(height: 12),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Supply', null),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Approval Pending',
                    PurchaseOrderStatus.pendingApproval,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip('In Transit', PurchaseOrderStatus.inTransit),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Delayed Warnings',
                    PurchaseOrderStatus.delayed,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Completed Receipts',
                    PurchaseOrderStatus.completed,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Purchase Orders list
          Expanded(
            child: filteredPO.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredPO.length,
                    itemBuilder: (context, index) {
                      final po = filteredPO[index];
                      return _buildPoCard(context, appState, po);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, PurchaseOrderStatus? status) {
    final isSelected = _selectedStatusFilter == status;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF64748B),
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          _selectedStatusFilter = status;
        });
      },
      selectedColor: const Color(0xFF135E39),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.transparent : Colors.grey.shade200,
        ),
      ),
    );
  }

  Widget _buildPoCard(
    BuildContext context,
    AppState appState,
    PurchaseOrder po,
  ) {
    Color statusColor = Colors.orange;
    String statusLabel = 'PENDING APPROVAL';
    IconData statusIcon = Icons.rule;

    switch (po.status) {
      case PurchaseOrderStatus.pendingApproval:
        statusColor = const Color(0xFFFFB300);
        statusLabel = 'PENDING APPROVAL';
        statusIcon = Icons.lock_clock;
        break;
      case PurchaseOrderStatus.inTransit:
        statusColor = Colors.blue;
        statusLabel = 'IN TRANSIT';
        statusIcon = Icons.local_shipping;
        break;
      case PurchaseOrderStatus.delayed:
        statusColor = Colors.red;
        statusLabel = 'DELAYED';
        statusIcon = Icons.error_outline;
        break;
      case PurchaseOrderStatus.completed:
        statusColor = Colors.green;
        statusLabel = 'COMPLETED';
        statusIcon = Icons.check_circle;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                po.id,
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
          const SizedBox(height: 10),
          Text(
            po.vendor,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Units: ${po.itemsCount} items  •  ETA: ${po.eta}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              Text(
                'Rp ${_formatCurrency(po.totalValue)}',
                style: const TextStyle(
                  fontFamily: 'HankenGrotesk',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF135E39),
                ),
              ),
            ],
          ),
          if (po.status == PurchaseOrderStatus.pendingApproval)
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      appState.approvePurchaseOrder(po.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'PO ${po.id} approved! Order status is now In Transit.',
                          ),
                          backgroundColor: const Color(0xFF135E39),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF135E39),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'APPROVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showAddPoBottomSheet(BuildContext context, AppState appState) {
    String? selectedVendor = _vendorsList[0];
    final itemsController = TextEditingController(text: '100');
    final valueController = TextEditingController(text: '45000000');
    final etaController = TextEditingController(text: '2026-05-28');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 24.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'CREATE NEW PURCHASE ORDER',
                          style: TextStyle(
                            fontFamily: 'HankenGrotesk',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 12),
                    // Vendor selection
                    const Text(
                      'Vendor Supplier',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedVendor,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(vertical: 0),
                      ),
                      items: _vendorsList.map((vendor) {
                        return DropdownMenuItem(
                          value: vendor,
                          child: Text(
                            vendor,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() {
                          selectedVendor = val;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Items quantity
                    const Text(
                      'Items Quantity (Units)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    TextFormField(
                      controller: itemsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Enter total units...',
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      validator: (val) {
                        if (val == null ||
                            val.isEmpty ||
                            int.tryParse(val) == null) {
                          return 'Please enter a valid count';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Total Value IDR
                    const Text(
                      'Total Value (IDR)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    TextFormField(
                      controller: valueController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Enter value in IDR...',
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      validator: (val) {
                        if (val == null ||
                            val.isEmpty ||
                            double.tryParse(val) == null) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Estimated Arrival Date (ETA)
                    const Text(
                      'Estimated Time of Arrival (ETA)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    TextFormField(
                      controller: etaController,
                      decoration: const InputDecoration(
                        hintText: 'YYYY-MM-DD',
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter ETA date';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          appState.addPurchaseOrder(
                            vendor: selectedVendor!,
                            itemsCount: int.parse(itemsController.text),
                            totalValue: double.parse(valueController.text),
                            eta: etaController.text,
                          );

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'New Purchase Order submitted! Approval requested.',
                              ),
                              backgroundColor: const Color(0xFF135E39),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF135E39),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'SUBMIT PURCHASE ORDER',
                        style: TextStyle(
                          fontFamily: 'HankenGrotesk',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.assignment_late_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No purchase orders match filters',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
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
