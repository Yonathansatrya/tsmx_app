import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/erp/erp_filter_tools.dart';
import '../shared/role_main_screen.dart';
import 'material_request/create_material_request_screen.dart';
import 'material_request/material_request_panel.dart';
import 'purchase_invoice/create_purchase_invoice_screen.dart';
import 'purchase_invoice/purchase_invoice_panel.dart';
import 'purchase_order/create_purchase_order_screen.dart';
import 'purchase_order/purchase_order_panel.dart';
import 'purchase_overview_tab.dart';
import 'purchase_receipt/create_purchase_receipt_screen.dart';
import 'purchase_receipt/purchase_receipt_panel.dart';

class PurchaseMainScreen extends StatefulWidget {
  const PurchaseMainScreen({super.key});

  @override
  State<PurchaseMainScreen> createState() => _PurchaseMainScreenState();
}

class _PurchaseMainScreenState extends State<PurchaseMainScreen> {
  Future<_PurchaseDoctypePermissions>? _permissionsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _permissionsFuture ??= _loadPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PurchaseDoctypePermissions>(
      future: _permissionsFuture,
      builder: (context, snapshot) {
        final permissions = snapshot.data;
        if (permissions == null) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        return _buildRoleScreen(permissions);
      },
    );
  }

  Widget _buildRoleScreen(_PurchaseDoctypePermissions permissions) {
    final entries = _buildMenuEntries(permissions);
    if (entries.isEmpty) return const _NoPurchaseAccessScreen();

    return RoleMainScreen(
      title: 'Purchase',
      fallbackUsername: 'Purchase',
      onInitialize: (state) async {
        await state.loadBuyingFilterOptions();
        await Future.wait([
          if (permissions.canReadPurchaseOrder) state.refreshPurchaseOrders(),
          if (permissions.canReadPurchaseReceipt)
            state.refreshPurchaseReceipts(),
          if (permissions.canReadPurchaseInvoice)
            state.refreshPurchaseInvoices(),
          if (permissions.canReadMaterialRequest)
            state.refreshMaterialRequests(),
        ]);
      },
      screensBuilder: (onMenuSelected) => entries
          .map((entry) => entry.builder(onMenuSelected))
          .toList(growable: false),
      floatingActionButtonBuilder: (context, currentIndex) =>
          _buildPurchaseFab(context, currentIndex, entries),
      destinations: entries.map((entry) => entry.destination).toList(),
    );
  }

  List<_PurchaseMenuEntry> _buildMenuEntries(
    _PurchaseDoctypePermissions permissions,
  ) {
    final entries = <_PurchaseMenuEntry>[];
    final canShowOverview =
        permissions.canReadPurchaseOrder ||
        permissions.canReadPurchaseReceipt ||
        permissions.canReadPurchaseInvoice;

    if (canShowOverview) {
      entries.add(
        _PurchaseMenuEntry(
          key: 'home',
          destination: const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          builder: (onMenuSelected) =>
              PurchaseOverviewTab(onMenuSelected: onMenuSelected),
        ),
      );
    }
    if (permissions.canReadPurchaseOrder) {
      entries.add(
        _PurchaseMenuEntry(
          key: 'po',
          destination: const NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag_rounded),
            label: 'PO',
          ),
          builder: (_) => const _PurchasePane(
            doctypeKey: 'po',
            child: PurchaseOrderPanel(),
          ),
          canCreate: permissions.canCreatePurchaseOrder,
        ),
      );
    }
    if (permissions.canReadPurchaseReceipt) {
      entries.add(
        _PurchaseMenuEntry(
          key: 'pr',
          destination: const NavigationDestination(
            icon: Icon(Icons.move_to_inbox_outlined),
            selectedIcon: Icon(Icons.move_to_inbox_rounded),
            label: 'Receipt',
          ),
          builder: (_) => const _PurchasePane(
            doctypeKey: 'pr',
            child: PurchaseReceiptPanel(),
          ),
          canCreate: permissions.canCreatePurchaseReceipt,
        ),
      );
    }
    if (permissions.canReadPurchaseInvoice) {
      entries.add(
        _PurchaseMenuEntry(
          key: 'pi',
          destination: const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Invoice',
          ),
          builder: (_) => const _PurchasePane(
            doctypeKey: 'pi',
            child: PurchaseInvoicePanel(),
          ),
          canCreate: permissions.canCreatePurchaseInvoice,
        ),
      );
    }
    if (permissions.canReadMaterialRequest) {
      entries.add(
        _PurchaseMenuEntry(
          key: 'mr',
          destination: const NavigationDestination(
            icon: Icon(Icons.assignment_turned_in_outlined),
            selectedIcon: Icon(Icons.assignment_turned_in_rounded),
            label: 'Request',
          ),
          builder: (_) => const _PurchasePane(
            doctypeKey: 'mr',
            child: MaterialRequestPanel(),
          ),
          canCreate: permissions.canCreateMaterialRequest,
        ),
      );
    }
    return entries;
  }

  Future<_PurchaseDoctypePermissions> _loadPermissions() async {
    final state = context.read<AppState>();
    if (state.mobileAccess.isAdministrator ||
        state.mobileAccess.isDeveloper ||
        state.mobileAccess.isCompanyAdministrator ||
        state.mobileAccess.isDirector) {
      return _PurchaseDoctypePermissions.fullAccess();
    }
    final results = await Future.wait([
      state.canReadDoctype('Purchase Order'),
      state.canCreateDoctype('Purchase Order'),
      state.canReadDoctype('Purchase Receipt'),
      state.canCreateDoctype('Purchase Receipt'),
      state.canReadDoctype('Purchase Invoice'),
      state.canCreateDoctype('Purchase Invoice'),
      state.canReadDoctype('Material Request'),
      state.canCreateDoctype('Material Request'),
    ]);
    final permissions = _PurchaseDoctypePermissions(
      canReadPurchaseOrder: results[0],
      canCreatePurchaseOrder: results[1],
      canReadPurchaseReceipt: results[2],
      canCreatePurchaseReceipt: results[3],
      canReadPurchaseInvoice: results[4],
      canCreatePurchaseInvoice: results[5],
      canReadMaterialRequest: results[6],
      canCreateMaterialRequest: results[7],
    );
    if (!permissions.hasAnyAccess && state.canUsePurchase) {
      return _PurchaseDoctypePermissions.legacyModuleAccess();
    }
    return permissions;
  }

  Widget? _buildPurchaseFab(
    BuildContext context,
    int currentIndex,
    List<_PurchaseMenuEntry> entries,
  ) {
    if (currentIndex < 0 || currentIndex >= entries.length) return null;
    final entry = entries[currentIndex];
    if (!entry.canCreate) return null;
    return FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      onPressed: () => _openPurchaseCreate(context, entry.key),
      icon: Icon(switch (entry.key) {
        'pr' => Icons.move_to_inbox_outlined,
        'pi' => Icons.receipt_long_outlined,
        'mr' => Icons.assignment_add,
        _ => Icons.add_shopping_cart_rounded,
      }),
      label: Text(switch (entry.key) {
        'pr' => 'Terima Barang',
        'pi' => 'Buat Invoice',
        'mr' => 'Buat Request',
        _ => 'Buat PO',
      }),
    );
  }

  Future<void> _openPurchaseCreate(BuildContext context, String key) async {
    final route = switch (key) {
      'pr' => MaterialPageRoute<void>(
        builder: (_) => const CreatePurchaseReceiptScreen(),
      ),
      'pi' => MaterialPageRoute<void>(
        builder: (_) => const CreatePurchaseInvoiceScreen(),
      ),
      'mr' => MaterialPageRoute<void>(
        builder: (_) => const CreateMaterialRequestScreen(),
      ),
      _ => MaterialPageRoute<void>(
        builder: (_) => const CreatePurchaseOrderScreen(),
      ),
    };

    await Navigator.of(context).push(route);
    if (!context.mounted) return;

    final state = context.read<AppState>();
    await switch (key) {
      'pr' => state.refreshPurchaseReceipts(),
      'pi' => state.refreshPurchaseInvoices(),
      'mr' => state.refreshMaterialRequests(),
      _ => state.refreshPurchaseOrders(),
    };
  }
}

class _PurchasePane extends StatelessWidget {
  final String doctypeKey;
  final Widget child;

  const _PurchasePane({required this.doctypeKey, required this.child});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await switch (doctypeKey) {
          'pr' => state.refreshPurchaseReceipts(),
          'pi' => state.refreshPurchaseInvoices(),
          'mr' => state.refreshMaterialRequests(),
          _ => state.refreshPurchaseOrders(),
        };
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          ErpPeriodFilterCard(
            title: 'Filter Pembelian',
            subtitle: state.buyingPeriodMonth == 0
                ? 'Daftar dokumen mengikuti tahun ini'
                : 'Daftar dokumen mengikuti bulan ini',
            icon: Icons.shopping_bag_rounded,
            selectedYear: state.buyingPeriodYear,
            selectedMonth: state.buyingPeriodMonth,
            loading: state.isOrderSummaryLoading,
            companyOptions: state.buyingCompanies,
            selectedCompany: state.buyingCompanyFilter,
            onCompanyChanged: (company) {
              context.read<AppState>().setBuyingPeriod(
                year: state.buyingPeriodYear,
                month: state.buyingPeriodMonth,
                company: company,
              );
            },
            selectedCustomerType: state.buyingSupplierTypeFilter,
            onCustomerTypeChanged: (supplierType) {
              context.read<AppState>().setBuyingPeriod(
                year: state.buyingPeriodYear,
                month: state.buyingPeriodMonth,
                supplierType: supplierType,
              );
            },
            partnerTypeLabel: 'Supplier',
            partnerTypeIcon: Icons.storefront_rounded,
            onChanged: (year, month) {
              context.read<AppState>().setBuyingPeriod(
                year: year,
                month: month,
              );
            },
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PurchaseDoctypePermissions {
  final bool canReadPurchaseOrder;
  final bool canCreatePurchaseOrder;
  final bool canReadPurchaseReceipt;
  final bool canCreatePurchaseReceipt;
  final bool canReadPurchaseInvoice;
  final bool canCreatePurchaseInvoice;
  final bool canReadMaterialRequest;
  final bool canCreateMaterialRequest;

  const _PurchaseDoctypePermissions({
    required this.canReadPurchaseOrder,
    required this.canCreatePurchaseOrder,
    required this.canReadPurchaseReceipt,
    required this.canCreatePurchaseReceipt,
    required this.canReadPurchaseInvoice,
    required this.canCreatePurchaseInvoice,
    required this.canReadMaterialRequest,
    required this.canCreateMaterialRequest,
  });

  factory _PurchaseDoctypePermissions.fullAccess() {
    return const _PurchaseDoctypePermissions(
      canReadPurchaseOrder: true,
      canCreatePurchaseOrder: true,
      canReadPurchaseReceipt: true,
      canCreatePurchaseReceipt: true,
      canReadPurchaseInvoice: true,
      canCreatePurchaseInvoice: true,
      canReadMaterialRequest: true,
      canCreateMaterialRequest: true,
    );
  }

  factory _PurchaseDoctypePermissions.legacyModuleAccess() {
    return _PurchaseDoctypePermissions.fullAccess();
  }

  bool get hasAnyAccess =>
      canReadPurchaseOrder ||
      canReadPurchaseReceipt ||
      canReadPurchaseInvoice ||
      canReadMaterialRequest;
}

class _PurchaseMenuEntry {
  final String key;
  final NavigationDestination destination;
  final Widget Function(ValueChanged<int> onMenuSelected) builder;
  final bool canCreate;

  const _PurchaseMenuEntry({
    required this.key,
    required this.destination,
    required this.builder,
    this.canCreate = false,
  });
}

class _NoPurchaseAccessScreen extends StatelessWidget {
  const _NoPurchaseAccessScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.background,
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Tidak ada akses Purchase yang tersedia untuk user ini.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.slate,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
