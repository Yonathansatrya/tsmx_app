import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sales_order.dart';
import '../widgets/notifications/notification_sheet.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../utils/erp_doc_utils.dart';
import '../utils/erp_format.dart';
import '../config/mobile_role_registry.dart';
import 'auth/login_screen.dart';
import 'profile/profile_screen.dart';

import 'tabs/dashboard_tab.dart';
import 'purchase/purchase_order/create_purchase_order_screen.dart';
import 'purchase/purchase_invoice/create_purchase_invoice_screen.dart';
import 'purchase/purchase_receipt/create_purchase_receipt_screen.dart';
import 'purchase/material_request/create_material_request_screen.dart';
import 'stock/stock_entry/create_stock_entry_screen.dart';
import 'sales/create_sales_order_screen.dart';
import 'todo/todo_list.dart';

class AppMainScreen extends StatefulWidget {
  const AppMainScreen({super.key});

  @override
  State<AppMainScreen> createState() => _AppMainScreenState();
}

class _AppMainScreenState extends State<AppMainScreen> {
  static const _profileTabKey = 'profile';

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().refreshNotifications(silent: true);
    });
  }

  int _totalTodoCount(AppState appState) => appState.approvalTodoCount;

  List<_MainTabItem> _tabs(AppState appState) {
    final tabs = <_MainTabItem>[
      _MainTabItem(
        keyName: MobileModule.dashboard,
        child: const DashboardTab(),
        destination: NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(Icons.home_rounded),
          label: _moduleLabel(appState, MobileModule.dashboard, 'Beranda'),
        ),
        navIcon: Icons.home_outlined,
        selectedNavIcon: Icons.home_rounded,
      ),
    ];

    if (appState.canUseApprovals) {
      final todoCount = _totalTodoCount(appState);
      tabs.add(
        _MainTabItem(
          keyName: MobileModule.approvals,
          child: const SalesOrderApprovalScreen(
            embedded: true,
            title: 'Approval Dokumen',
          ),
          destination: NavigationDestination(
            icon: _todoIcon(Icons.checklist_outlined, todoCount),
            selectedIcon: _todoIcon(Icons.checklist_rounded, todoCount),
            label: _moduleLabel(appState, MobileModule.approvals, 'Todo'),
          ),
          navIcon: Icons.checklist_outlined,
          selectedNavIcon: Icons.checklist_rounded,
          badgeCount: todoCount,
        ),
      );
    }

    tabs.add(
      _MainTabItem(
        keyName: _profileTabKey,
        child: const ProfileScreen(showBackButton: false),
        destination: const NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profil',
        ),
        navIcon: Icons.person_outline_rounded,
        selectedNavIcon: Icons.person_rounded,
      ),
    );

    return tabs;
  }

  String _moduleLabel(AppState appState, String module, String fallback) {
    final bootMenus = (appState.mobileBoot?.menus ?? const [])
        .map((menu) => (module: menu.module, label: menu.label))
        .toList();
    return MobileRoleRegistry.moduleLabel(
      module,
      bootMenus: bootMenus,
      fallback: fallback,
    );
  }

  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
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

    final tabs = _tabs(appState);
    final selectedIndex = _currentIndex.clamp(0, tabs.length - 1);
    if (selectedIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = selectedIndex);
      });
    }
    final selectedTab = tabs[selectedIndex];
    final showShellAppBar = selectedTab.keyName != _profileTabKey;
    final showCreateFab = selectedTab.keyName == MobileModule.dashboard;

    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selectedIndex != 0) {
          _changeTab(0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: showShellAppBar
            ? AppBar(
                toolbarHeight: 68,
                backgroundColor: AppColors.white,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                centerTitle: false,
                titleSpacing: 16,
                title: _TmsxHeaderTitle(appState: appState),
                actions: [
                  if (appState.canUseApprovals)
                    IconButton(
                      tooltip: _totalTodoCount(appState) > 0
                          ? '${_totalTodoCount(appState)} approval menunggu'
                          : 'Tidak ada approval menunggu',
                      onPressed: () {
                        final todoIndex = tabs.indexWhere(
                          (tab) => tab.keyName == MobileModule.approvals,
                        );
                        if (todoIndex >= 0) _changeTab(todoIndex);
                      },
                      icon: _todoIcon(
                        Icons.assignment_turned_in_outlined,
                        _totalTodoCount(appState),
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              )
            : null,
        body: IndexedStack(
          index: selectedIndex,
          children: tabs.map((tab) => tab.child).toList(),
        ),
        floatingActionButton: showCreateFab
            ? Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _CreateButton(
                  onTap: () => _showQuickCreateSheet(context, appState),
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: _TmsxBottomNav(
          tabs: tabs,
          selectedIndex: selectedIndex,
          onSelected: _changeTab,
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

  Future<void> _showQuickCreateSheet(
    BuildContext context,
    AppState appState,
  ) async {
    final groups = <_QuickCreateGroup>[
      if (appState.isSalesUserRole)
        _QuickCreateGroup(
          title: 'Sales',
          icon: Icons.point_of_sale_rounded,
          actions: [
            _QuickCreateAction(
              title: 'Sales Order',
              subtitle: 'Order customer baru',
              icon: Icons.point_of_sale_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateSalesOrderScreen(),
                ),
              ),
            ),
            _QuickCreateAction(
              title: 'Delivery Note',
              subtitle: 'Dari Sales Order submitted',
              icon: Icons.local_shipping_outlined,
              onTap: () => _createDeliveryNoteFromSalesOrder(context),
            ),
            _QuickCreateAction(
              title: 'Sales Invoice',
              subtitle: 'Tagihan dari Sales Order',
              icon: Icons.receipt_long_outlined,
              onTap: () => _createSalesInvoiceFromSalesOrder(context),
            ),
          ],
        ),
      if (appState.canUsePurchase)
        _QuickCreateGroup(
          title: 'Purchase',
          icon: Icons.shopping_bag_rounded,
          actions: [
            _QuickCreateAction(
              title: 'Purchase Order',
              subtitle: 'PO supplier',
              icon: Icons.add_shopping_cart_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreatePurchaseOrderScreen(),
                ),
              ),
            ),
            _QuickCreateAction(
              title: 'Purchase Receipt',
              subtitle: 'Terima barang',
              icon: Icons.move_to_inbox_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreatePurchaseReceiptScreen(),
                ),
              ),
            ),
            _QuickCreateAction(
              title: 'Purchase Invoice',
              subtitle: 'Invoice supplier',
              icon: Icons.receipt_long_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreatePurchaseInvoiceScreen(),
                ),
              ),
            ),
            _QuickCreateAction(
              title: 'Material Request',
              subtitle: 'Kebutuhan barang',
              icon: Icons.assignment_add,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateMaterialRequestScreen(),
                ),
              ),
            ),
          ],
        ),
      if (appState.canUseStock)
        _QuickCreateGroup(
          title: 'Stock',
          icon: Icons.inventory_2_rounded,
          actions: [
            _QuickCreateAction(
              title: 'Stock Entry',
              subtitle: 'Transfer, receipt, issue',
              icon: Icons.inventory_2_outlined,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateStockEntryScreen(),
                ),
              ),
            ),
          ],
        ),
    ];
    final actionsCount = groups.fold<int>(
      0,
      (total, group) => total + group.actions.length,
    );

    if (actionsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada aksi create untuk role ini.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.78,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Create Document',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        for (final group in groups)
                          _QuickCreateSection(
                            group: group,
                            onActionTap: (action) async {
                              Navigator.pop(sheetContext);
                              await Future<void>.delayed(
                                const Duration(milliseconds: 120),
                              );
                              if (!context.mounted) return;
                              await action.onTap();
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
    if (appState.dashboardSalesOrders.isEmpty) {
      await appState.refreshSalesOrders();
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

class _QuickCreateAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Future<void> Function() onTap;

  const _QuickCreateAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _QuickCreateGroup {
  final String title;
  final IconData icon;
  final List<_QuickCreateAction> actions;

  const _QuickCreateGroup({
    required this.title,
    required this.icon,
    required this.actions,
  });
}

class _QuickCreateSection extends StatelessWidget {
  final _QuickCreateGroup group;
  final ValueChanged<_QuickCreateAction> onActionTap;

  const _QuickCreateSection({required this.group, required this.onActionTap});

  @override
  Widget build(BuildContext context) {
    if (group.actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Row(
              children: [
                Icon(group.icon, color: AppColors.primary, size: 18),
                const SizedBox(width: 7),
                Text(
                  group.title,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (var index = 0; index < group.actions.length; index++) ...[
                  _QuickCreateTile(
                    action: group.actions[index],
                    onTap: () => onActionTap(group.actions[index]),
                  ),
                  if (index < group.actions.length - 1)
                    const Divider(height: 1, color: AppColors.border),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCreateTile extends StatelessWidget {
  final _QuickCreateAction action;
  final VoidCallback onTap;

  const _QuickCreateTile({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(action.icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    action.subtitle,
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
            const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
          ],
        ),
      ),
    ),
  );
}

class _MainTabItem {
  final String keyName;
  final Widget child;
  final NavigationDestination destination;
  final IconData navIcon;
  final IconData selectedNavIcon;
  final int badgeCount;

  const _MainTabItem({
    required this.keyName,
    required this.child,
    required this.destination,
    required this.navIcon,
    required this.selectedNavIcon,
    this.badgeCount = 0,
  });
}

class _TmsxHeaderTitle extends StatelessWidget {
  final AppState appState;

  const _TmsxHeaderTitle({required this.appState});

  @override
  Widget build(BuildContext context) {
    final tenant = appState.selectedSiteName.trim();
    final user = appState.currentUser ?? 'Operator';
    final subtitle = tenant.isNotEmpty ? tenant : user;

    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(6),
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appState.appDisplayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
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
    );
  }
}

class _TmsxBottomNav extends StatelessWidget {
  final List<_MainTabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _TmsxBottomNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: 0),
            AppColors.background,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(14, 3, 14, bottomPadding > 0 ? 6 : 10),
        child: SizedBox(
          height: 58,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var index = 0; index < tabs.length; index++)
                  Expanded(
                    child: _TmsxBottomNavItem(
                      tab: tabs[index],
                      selected: index == selectedIndex,
                      compact: tabs.length >= 4,
                      onTap: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.16),
                blurRadius: 11,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_rounded,
              color: AppColors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _TmsxBottomNavItem extends StatelessWidget {
  final _MainTabItem tab;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _TmsxBottomNavItem({
    required this.tab,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = tab.destination.label;
    final color = selected ? AppColors.primary : AppColors.slate;
    final icon = selected ? tab.selectedNavIcon : tab.navIcon;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: double.infinity,
          margin: EdgeInsets.symmetric(horizontal: compact ? 1 : 2),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 3 : 7,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.softGreen.withValues(alpha: 0.78)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _BottomNavIcon(icon: icon, color: color, count: tab.badgeCount),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: compact ? 9.5 : 10.5,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;

  const _BottomNavIcon({
    required this.icon,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, color: color, size: 22);
    if (count <= 0) return iconWidget;
    return Badge.count(
      count: count,
      backgroundColor: AppColors.danger,
      textColor: AppColors.white,
      smallSize: 7,
      textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
      child: iconWidget,
    );
  }
}
