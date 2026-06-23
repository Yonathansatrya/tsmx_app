import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sales_order.dart';
import '../widgets/notifications/notification_sheet.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/erp_doc_utils.dart';
import '../utils/erp_format.dart';
import 'auth/login_screen.dart';
import 'logistics/logistics_main_screen.dart';
import 'profile/profile_screen.dart';
import 'purchase/purchase_main_screen.dart';
import 'sales/sales_main_screen.dart';
import 'warehouse/warehouse_main_screen.dart';

import 'tabs/dashboard_tab.dart';
import 'tabs/buying_tab.dart';
import 'tabs/selling_tab.dart';
import 'tabs/stock_tab.dart';
import 'purchase/purchase_order/create_purchase_order_screen.dart';
import 'purchase/purchase_invoice/create_purchase_invoice_screen.dart';
import 'purchase/purchase_receipt/create_purchase_receipt_screen.dart';
import 'stock/stock_entry/create_stock_entry_screen.dart';
import 'sales/sales_order/create_sales_order_screen.dart';
import 'todo/todo_list.dart';

class AppMainScreen extends StatefulWidget {
  const AppMainScreen({super.key});

  @override
  State<AppMainScreen> createState() => _AppMainScreenState();
}

class _AppMainScreenState extends State<AppMainScreen> {
  int _currentIndex = 0;
  String _salesSegment = 'so';
  String _buyingSegment = 'po';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().refreshNotifications(silent: true);
    });
  }

  List<Widget> get _tabs => [
    const DashboardTab(),
    SellingTab(
      selectedSegment: _salesSegment,
      onSegmentChanged: (segment) => setState(() => _salesSegment = segment),
    ),
    const SalesOrderApprovalScreen(embedded: true),
    BuyingTab(
      selectedSegment: _buyingSegment,
      onSegmentChanged: (segment) => setState(() => _buyingSegment = segment),
    ),
    const StockTab(),
  ];

  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    if (!appState.isAuthenticated) {
      _redirectToLogin();

      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (appState.isSalesAreaRole) {
      return const SalesMainScreen();
    }
    if (appState.userRole == 'Warehouse') {
      return const WarehouseMainScreen();
    }
    if (appState.userRole == 'Logistics') {
      return const LogisticsMainScreen();
    }
    if (appState.userRole == 'Purchase') {
      return const PurchaseMainScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _buildFloatingActionButton(context, appState),
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 14,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(5),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TMSX ERP',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    appState.currentUser ?? 'Operator',
                    maxLines: 1,
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
          ],
        ),
        actions: [
          IconButton(
            tooltip: appState.salesOrderApprovalTodoCount > 0
                ? '${appState.salesOrderApprovalTodoCount} approval menunggu'
                : 'Tidak ada approval menunggu',
            onPressed: () => _changeTab(2),
            icon: _todoIcon(
              Icons.assignment_turned_in_outlined,
              appState.salesOrderApprovalTodoCount,
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.primary,
                ),
                if (appState.hasUnreadNotifications)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              NotificationSheet.show(
                context,
                notifications: appState.notifications,
                onMarkAllRead: () async {
                  await appState.markAllNotificationsRead();
                },
                onNotificationTap: (notification) {
                  appState.markNotificationRead(notification.id);
                },
              );
            },
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(
            top: BorderSide(color: AppColors.primary.withValues(alpha: 0.06)),
          ),
          boxShadow: AppColors.cardShadow,
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _changeTab,
          height: 64,
          elevation: 0,
          backgroundColor: AppColors.white,
          indicatorColor: AppColors.softGreen,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            const NavigationDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale_rounded),
              label: 'Sales',
            ),
            NavigationDestination(
              icon: _todoIcon(
                Icons.checklist_outlined,
                appState.salesOrderApprovalTodoCount,
              ),
              selectedIcon: _todoIcon(
                Icons.checklist_rounded,
                appState.salesOrderApprovalTodoCount,
              ),
              label: 'Todo',
            ),
            const NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag_rounded),
              label: 'Buying',
            ),
            const NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: 'Stock',
            ),
          ],
        ),
      ),
    );
  }

  Widget _todoIcon(IconData icon, int count) {
    if (count <= 0) return Icon(icon);
    return Badge.count(
      count: count,
      backgroundColor: AppColors.danger,
      textColor: AppColors.white,
      child: Icon(icon),
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context, AppState appState) {
    switch (_currentIndex) {
      case 1:
        final segment = _salesSegment;
        if (segment == 'dn') {
          return FloatingActionButton.extended(
            onPressed: () => _createDeliveryNoteFromSalesOrder(context),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Delivery Note'),
          );
        }
        if (segment == 'si') {
          return FloatingActionButton.extended(
            onPressed: () => _createSalesInvoiceFromSalesOrder(context),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Sales Invoice'),
          );
        }
        if (segment != 'so') {
          return null;
        }
        return FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateSalesOrderScreen()),
            );
          },
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Sales Order'),
        );

      case 3:
        if (_buyingSegment == 'pr') {
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreatePurchaseReceiptScreen(),
                ),
              );
            },
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.inventory_outlined),
            label: const Text('Purchase Receipt'),
          );
        }
        if (_buyingSegment == 'pi') {
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreatePurchaseInvoiceScreen(),
                ),
              );
            },
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Purchase Invoice'),
          );
        }
        if (_buyingSegment != 'po') {
          return null;
        }
        return FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CreatePurchaseOrderScreen(),
              ),
            );
          },
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Purchase Order'),
        );

      case 4:
        return FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateStockEntryScreen()),
            );
          },
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Stock Entry'),
        );

      default:
        return null;
    }
  }

  Future<void> _createDeliveryNoteFromSalesOrder(BuildContext context) async {
    final selection = await _pickSalesOrderFor(
      context,
      doctype: 'Delivery Note',
      title: 'Create Delivery Note',
      emptyMessage: 'Tidak ada Sales Order submitted yang masih perlu dikirim.',
      canUse: (order) =>
          isDocSubmitted(order.docStatus) && order.perDelivered < 100,
    );
    if (selection == null || !context.mounted) return;

    await _runSalesOrderCreateAction(
      context,
      action: () => context.read<AppState>().createDeliveryNoteFromSalesOrder(
        selection.order.id,
        namingSeries: selection.namingSeries,
      ),
      successMessage:
          'Delivery Note berhasil dibuat dari ${selection.order.id}',
      failurePrefix: 'Gagal membuat Delivery Note',
    );
  }

  Future<void> _createSalesInvoiceFromSalesOrder(BuildContext context) async {
    final selection = await _pickSalesOrderFor(
      context,
      doctype: 'Sales Invoice',
      title: 'Create Sales Invoice',
      emptyMessage: 'Tidak ada Sales Order submitted yang masih perlu ditagih.',
      canUse: (order) =>
          isDocSubmitted(order.docStatus) && order.perBilled < 100,
    );
    if (selection == null || !context.mounted) return;

    await _runSalesOrderCreateAction(
      context,
      action: () => context.read<AppState>().createSalesInvoiceFromSalesOrder(
        selection.order.id,
        namingSeries: selection.namingSeries,
      ),
      successMessage:
          'Sales Invoice berhasil dibuat dari ${selection.order.id}',
      failurePrefix: 'Gagal membuat Sales Invoice',
    );
  }

  Future<_SalesOrderDraftSelection?> _pickSalesOrderFor(
    BuildContext context, {
    required String doctype,
    required String title,
    required String emptyMessage,
    required bool Function(SalesOrder order) canUse,
  }) async {
    final appState = context.read<AppState>();
    if (!appState.hasFullOrderSummary) {
      await appState.refreshOrderSummaries();
      if (!context.mounted) return null;
    }

    final candidates = appState.dashboardSalesOrders.where(canUse).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emptyMessage), backgroundColor: Colors.orange),
      );
      return null;
    }

    List<String> namingSeries;
    try {
      namingSeries = await appState.fetchNamingSeries(doctype);
    } catch (error) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat naming series $doctype: $error'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return null;
    }
    if (namingSeries.isEmpty || !context.mounted) return null;

    return showModalBottomSheet<_SalesOrderDraftSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        var query = '';
        SalesOrder? selectedOrder;
        String selectedSeries = namingSeries.first;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final normalized = query.trim().toLowerCase();
            final filtered = normalized.isEmpty
                ? candidates.take(60).toList()
                : candidates.where((order) {
                    return order.id.toLowerCase().contains(normalized) ||
                        order.customer.toLowerCase().contains(normalized);
                  }).toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      autofocus: true,
                      onChanged: (value) => setSheetState(() => query = value),
                      decoration: InputDecoration(
                        labelText: 'Search Sales Order / customer',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSeries,
                      decoration: const InputDecoration(
                        labelText: 'Naming Series',
                      ),
                      items: namingSeries
                          .map(
                            (series) => DropdownMenuItem(
                              value: series,
                              child: Text(series),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => selectedSeries = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: MediaQuery.of(sheetContext).size.height * 0.48,
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text(
                                'Sales Order tidak ditemukan',
                                style: TextStyle(color: AppColors.slate),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final order = filtered[index];
                                return ListTile(
                                  selected: selectedOrder?.id == order.id,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    order.id,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${order.customer} - ${order.date}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    'Rp ${formatErpCurrency(order.value)}',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onTap: () => setSheetState(
                                    () => selectedOrder = order,
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: selectedOrder == null
                          ? null
                          : () => Navigator.pop(
                              sheetContext,
                              _SalesOrderDraftSelection(
                                order: selectedOrder!,
                                namingSeries: selectedSeries,
                              ),
                            ),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Buat Draft'),
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

  Future<void> _runSalesOrderCreateAction(
    BuildContext context, {
    required Future<dynamic> Function() action,
    required String successMessage,
    required String failurePrefix,
  }) async {
    try {
      await action();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$failurePrefix: $err'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

class _SalesOrderDraftSelection {
  final SalesOrder order;
  final String namingSeries;

  const _SalesOrderDraftSelection({
    required this.order,
    required this.namingSeries,
  });
}
