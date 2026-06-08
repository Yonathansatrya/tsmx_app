import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sales_order.dart';
import '../models/purchase_order.dart';
import '../models/delivery_note.dart';
import '../models/sales_invoice.dart';
import '../models/purchase_receipt.dart';
import '../models/purchase_invoice.dart';
import '../models/stock_entry.dart';
import '../models/material_request.dart';
import '../models/stock_ledger_movement.dart';
import '../models/inventory_item.dart';
import '../utils/date_range_presets.dart';
import '../models/warehouse_info.dart';
import '../models/stock_area_option.dart';
import '../services/frappe_service.dart';
import '../utils/erp_doc_utils.dart';
import '../utils/num_parse.dart';
import '../widgets/notifications/notification_model.dart';

class AppState with ChangeNotifier {
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  String? _currentUser;
  String? get currentUser => _currentUser;

  bool _rememberDevice = true;
  bool get rememberDevice => _rememberDevice;

  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;

  List<SalesOrder> _salesOrders = [];
  List<PurchaseOrder> _purchaseOrders = [];
  List<DeliveryNote> _deliveryNotes = [];
  List<SalesInvoice> _salesInvoices = [];
  List<PurchaseReceipt> _purchaseReceipts = [];
  List<PurchaseInvoice> _purchaseInvoices = [];
  List<StockEntry> _stockEntries = [];
  List<MaterialRequest> _materialRequests = [];
  List<InventoryItem> _inventory = [];
  List<SalesOrder> _summarySalesOrders = [];
  List<PurchaseOrder> _summaryPurchaseOrders = [];

  List<SalesOrder> get salesOrders => _salesOrders;
  List<PurchaseOrder> get purchaseOrders => _purchaseOrders;
  List<DeliveryNote> get deliveryNotes => _deliveryNotes;
  List<SalesInvoice> get salesInvoices => _salesInvoices;
  List<PurchaseReceipt> get purchaseReceipts => _purchaseReceipts;
  List<PurchaseInvoice> get purchaseInvoices => _purchaseInvoices;
  List<StockEntry> get stockEntries => _stockEntries;
  List<MaterialRequest> get materialRequests => _materialRequests;
  List<InventoryItem> get inventory => _inventory;
  List<SalesOrder> get dashboardSalesOrders =>
      _summarySalesOrders.isEmpty ? _salesOrders : _summarySalesOrders;
  List<PurchaseOrder> get dashboardPurchaseOrders =>
      _summaryPurchaseOrders.isEmpty ? _purchaseOrders : _summaryPurchaseOrders;

  List<WarehouseInfo> _warehouses = [];
  List<WarehouseInfo> get warehouses => _warehouses;

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;
  bool get hasUnreadNotifications =>
      _notifications.any((notification) => !notification.isRead);

  bool _isNotificationsLoading = false;
  bool get isNotificationsLoading => _isNotificationsLoading;

  Timer? _notificationPollTimer;
  static const Duration _notificationPollInterval = Duration(seconds: 30);

  bool _isSalesOrdersLoading = false;
  bool get isSalesOrdersLoading => _isSalesOrdersLoading;

  bool _isMoreSalesOrdersLoading = false;
  bool get isMoreSalesOrdersLoading => _isMoreSalesOrdersLoading;

  bool _hasMoreSalesOrders = true;
  bool get hasMoreSalesOrders => _hasMoreSalesOrders;

  String? _salesOrdersError;
  String? get salesOrdersError => _salesOrdersError;

  bool _isPurchaseOrdersLoading = false;
  bool get isPurchaseOrdersLoading => _isPurchaseOrdersLoading;

  bool _isMorePurchaseOrdersLoading = false;
  bool get isMorePurchaseOrdersLoading => _isMorePurchaseOrdersLoading;

  bool _hasMorePurchaseOrders = true;
  bool get hasMorePurchaseOrders => _hasMorePurchaseOrders;

  String? _purchaseOrdersError;
  String? get purchaseOrdersError => _purchaseOrdersError;

  Future<void>? _orderSummaryJob;
  bool _isOrderSummaryLoading = false;
  bool get isOrderSummaryLoading => _isOrderSummaryLoading;
  String? _orderSummaryError;
  String? get orderSummaryError => _orderSummaryError;
  bool get hasFullOrderSummary =>
      _summarySalesOrders.isNotEmpty && _summaryPurchaseOrders.isNotEmpty;

  bool _isDeliveryNotesLoading = false;
  bool get isDeliveryNotesLoading => _isDeliveryNotesLoading;
  String? _deliveryNotesError;
  String? get deliveryNotesError => _deliveryNotesError;

  bool _isSalesInvoicesLoading = false;
  bool get isSalesInvoicesLoading => _isSalesInvoicesLoading;
  String? _salesInvoicesError;
  String? get salesInvoicesError => _salesInvoicesError;

  bool _isPurchaseReceiptsLoading = false;
  bool get isPurchaseReceiptsLoading => _isPurchaseReceiptsLoading;
  String? _purchaseReceiptsError;
  String? get purchaseReceiptsError => _purchaseReceiptsError;

  bool _isPurchaseInvoicesLoading = false;
  bool get isPurchaseInvoicesLoading => _isPurchaseInvoicesLoading;
  String? _purchaseInvoicesError;
  String? get purchaseInvoicesError => _purchaseInvoicesError;

  bool _isStockEntriesLoading = false;
  bool get isStockEntriesLoading => _isStockEntriesLoading;
  String? _stockEntriesError;
  String? get stockEntriesError => _stockEntriesError;

  bool _isMaterialRequestsLoading = false;
  bool get isMaterialRequestsLoading => _isMaterialRequestsLoading;
  String? _materialRequestsError;
  String? get materialRequestsError => _materialRequestsError;

  bool _isInventoryLoading = false;
  bool get isInventoryLoading => _isInventoryLoading;

  String? _inventoryError;
  String? get inventoryError => _inventoryError;

  static const String _defaultFrappeBaseUrl = 'http://apps.willshine.id:8014';
  static const int _frappePageSize = 500;
  static const int _defaultFetchRowLimit = 500;
  static const int _documentPageSize = 50;
  static const String _prefsFrappeConfigKey = 'frappe_config';

  final FrappeService _frappeService = FrappeService();

  FrappeService get frappeService => _frappeService;

  Future<void> _restoreFrappeConfig() async {
    final cfg = await _loadFrappeConfig();
    if (cfg == null) return;

    _frappeService.baseUrl = cfg['baseUrl'] ?? _defaultFrappeBaseUrl;
    if (cfg['username'] != null) {
      _frappeService.username = cfg['username'];
    }
    if (cfg['password'] != null) {
      _frappeService.password = cfg['password'];
    }
  }

  AppState() {
    () async {
      await _restoreFrappeConfig();
      _isInitializing = false;
      notifyListeners();
    }();
  }

  /// Called from splash — restores session and prefetches core data.
  Future<bool> initApp() async {
    _isInitializing = true;
    notifyListeners();

    final ok = await restoreSession();

    _isInitializing = false;
    notifyListeners();
    return ok;
  }

  Future<bool> restoreSession() async {
    await _restoreFrappeConfig();

    final cfg = await _loadFrappeConfig();
    final password = cfg?['password'] ?? '';
    if (cfg == null || !cfg.containsKey('username') || password.isEmpty) {
      return false;
    }

    try {
      _frappeService.baseUrl = cfg['baseUrl'] ?? _defaultFrappeBaseUrl;
      await _frappeService.login(cfg['username']!, password);
      _isAuthenticated = true;
      _currentUser = cfg['username'];
      _startNotificationPolling();
      await prefetchInitialData();
      notifyListeners();
      return true;
    } catch (_) {
      await clearSessionConfig();
      _isAuthenticated = false;
      _currentUser = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> prefetchInitialData() async {
    try {
      await fetchWarehousesFromFrappe();
      await fetchInventoryFromFrappe();
      await Future.wait([
        fetchSalesOrdersFromFrappe(),
        fetchPurchaseOrdersFromFrappe(),
        fetchSalesInvoicesFromFrappe(),
        fetchPurchaseInvoicesFromFrappe(),
      ]);
      await fetchDeliveryNotesFromFrappe();
      await fetchPurchaseReceiptsFromFrappe();
      await refreshNotifications(silent: true);
      unawaited(refreshOrderSummaries(silent: true));
    } catch (_) {
      // Prefetch failures should not block login.
    }
    notifyListeners();
  }

  Future<void> clearSessionConfig() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_prefsFrappeConfigKey);
    } catch (_) {}
    _frappeService.username = null;
    _frappeService.password = null;
  }

  void setRememberDevice(bool value) {
    _rememberDevice = value;
    notifyListeners();
  }

  Future<bool> login(
    String username,
    String password, {
    String baseUrl = FrappeService.defaultBaseUrl,
  }) async {
    try {
      _frappeService.baseUrl = baseUrl;
      await _frappeService.login(username, password);
      _isAuthenticated = true;
      _currentUser = username;
      await refreshNotifications();
      _startNotificationPolling();
      notifyListeners();
      return true;
    } catch (_) {
      _isAuthenticated = false;
      _currentUser = null;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _stopNotificationPolling();
    _notifications = [];
    _isAuthenticated = false;
    _currentUser = null;
    await clearSessionConfig();
    notifyListeners();
  }

  void _startNotificationPolling() {
    _notificationPollTimer?.cancel();
    _notificationPollTimer = Timer.periodic(
      _notificationPollInterval,
      (_) => refreshNotifications(silent: true),
    );
  }

  void _stopNotificationPolling() {
    _notificationPollTimer?.cancel();
    _notificationPollTimer = null;
  }

  Future<void> refreshNotifications({bool silent = false}) async {
    if (!_isAuthenticated || _currentUser == null) return;

    if (!silent) {
      _isNotificationsLoading = true;
      notifyListeners();
    }

    try {
      await _frappeService.ensureLoggedIn();
      _notifications = await _fetchNotificationsFromFrappe();
    } catch (_) {
      // Keep previous notifications on transient errors.
    } finally {
      if (!silent) {
        _isNotificationsLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsRead() async {
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;

    for (final notification in unread) {
      if (notification.source != 'notification_log') continue;
      try {
        await _frappeService.updateDocument(
          'Notification Log',
          notification.id,
          {'read': 1},
        );
      } catch (_) {}
    }

    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    notifyListeners();
  }

  Future<void> markNotificationRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index < 0 || _notifications[index].isRead) return;

    final notification = _notifications[index];
    if (notification.source == 'notification_log') {
      try {
        await _frappeService.updateDocument(
          'Notification Log',
          notification.id,
          {'read': 1},
        );
      } catch (_) {}
    }

    _notifications[index] = notification.copyWith(isRead: true);
    notifyListeners();
  }

  Future<List<AppNotification>> _fetchNotificationsFromFrappe() async {
    final user = _currentUser!;
    final merged = <String, AppNotification>{};

    Future<void> loadNotificationLogs() async {
      try {
        final rows = await _fetchResourceWithFieldFallback(
          doctype: 'Notification Log',
          fields: const [
            'name',
            'subject',
            'email_content',
            'document_type',
            'document_name',
            'read',
            'creation',
            'modified',
            'type',
          ],
          limit: 200,
          orderBy: 'modified desc',
          filters: [
            ['for_user', '=', user],
          ],
        );
        for (final row in rows) {
          final item = AppNotification.fromNotificationLog(row);
          if (item.id.isNotEmpty) merged[item.id] = item;
        }
      } catch (_) {
        final rows = await _fetchResourceWithFieldFallback(
          doctype: 'Notification Log',
          fields: const [
            'name',
            'subject',
            'email_content',
            'document_type',
            'document_name',
            'read',
            'creation',
            'modified',
            'type',
          ],
          limit: 200,
          orderBy: 'modified desc',
        );
        for (final row in rows) {
          final item = AppNotification.fromNotificationLog(row);
          if (item.id.isNotEmpty) merged[item.id] = item;
        }
      }
    }

    Future<void> loadActivityLogs() async {
      try {
        final rows = await _fetchResourceWithFieldFallback(
          doctype: 'Activity Log',
          fields: const [
            'name',
            'subject',
            'content',
            'operation',
            'reference_doctype',
            'reference_name',
            'creation',
            'modified',
          ],
          limit: 120,
          orderBy: 'creation desc',
        );
        for (final row in rows) {
          final item = AppNotification.fromActivityLog(row);
          if (item.id.isNotEmpty) merged[item.id] = item;
        }
      } catch (_) {}
    }

    await loadNotificationLogs();
    await loadActivityLogs();

    final list = merged.values.toList()
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

    return list;
  }

  @override
  void dispose() {
    _stopNotificationPolling();
    super.dispose();
  }

  Future<SalesOrder> loadSalesOrderDetail(String orderId) async {
    await _frappeService.ensureLoggedIn();
    final doc = await _frappeService.fetchDocument('Sales Order', orderId);
    return SalesOrder.fromJson(doc);
  }

  Future<SalesOrder> createSalesOrder({
    required String customer,
    required String itemCode,
    required double qty,
    String? warehouse,
    double? rate,
    String? series,
    String? costCenter,
    String? company,
    required String salesPerson,
    DateTime? transactionDate,
    DateTime? deliveryDate,
  }) async {
    await _frappeService.ensureLoggedIn();

    final payload = <String, dynamic>{
      'customer': customer,
      if (company != null && company.trim().isNotEmpty)
        'company': company.trim(),
      'transaction_date': (transactionDate ?? DateTime.now())
          .toIso8601String()
          .split('T')
          .first,
      'delivery_date': (deliveryDate ?? transactionDate ?? DateTime.now())
          .toIso8601String()
          .split('T')
          .first,
      if (series != null && series.trim().isNotEmpty)
        'naming_series': series.trim(),
      if (costCenter != null && costCenter.trim().isNotEmpty)
        'cost_center': costCenter.trim(),
      'sales_team': [
        {'sales_person': salesPerson.trim(), 'allocated_percentage': 100},
      ],
      'items': [
        {
          'item_code': itemCode,
          'qty': qty,
          'delivery_date': (deliveryDate ?? transactionDate ?? DateTime.now())
              .toIso8601String()
              .split('T')
              .first,
          if (rate != null && rate > 0) 'rate': rate,
          if (warehouse != null && warehouse.trim().isNotEmpty)
            'warehouse': warehouse.trim(),
          if (costCenter != null && costCenter.trim().isNotEmpty)
            'cost_center': costCenter.trim(),
        },
      ],
      if (warehouse != null && warehouse.trim().isNotEmpty)
        'set_warehouse': warehouse.trim(),
    };

    final created = await _frappeService.createDocument('Sales Order', payload);
    final order = SalesOrder.fromJson(created);
    _salesOrders = [order, ..._salesOrders];
    notifyListeners();
    await refreshSalesOrders();
    unawaited(refreshOrderSummaries(silent: true));
    return order;
  }

  Future<Map<String, dynamic>> createCustomer({
    required String customerName,
    required String customerType,
    required String namingSeries,
    required String paymentTerms,
    required String company,
    String? customerGroup,
    String? territory,
  }) async {
    await _frappeService.ensureLoggedIn();

    final payload = <String, dynamic>{
      'naming_series': namingSeries.trim(),
      'customer_name': customerName.trim(),
      'customer_type': customerType.trim(),
      'payment_terms': paymentTerms.trim(),
      if (customerGroup != null && customerGroup.trim().isNotEmpty)
        'customer_group': customerGroup.trim(),
      if (territory != null && territory.trim().isNotEmpty)
        'territory': territory.trim(),
      if (company.trim().isNotEmpty)
        'accounts': [
          {'company': company.trim()},
        ],
    };

    return _frappeService.createDocument('Customer', payload);
  }

  Future<SalesOrder> updateSalesOrder({
    required String orderId,
    String? customer,
    String? itemCode,
    double? qty,
    String? warehouse,
    double? rate,
    String? costCenter,
    String? company,
    String? salesPerson,
    DateTime? transactionDate,
    DateTime? deliveryDate,
    String? status,
  }) async {
    await _frappeService.ensureLoggedIn();

    final updates = <String, dynamic>{
      if (customer != null && customer.trim().isNotEmpty) 'customer': customer,
      if (company != null && company.trim().isNotEmpty)
        'company': company.trim(),
      if (transactionDate != null)
        'transaction_date': transactionDate.toIso8601String().split('T').first,
      if (deliveryDate != null)
        'delivery_date': deliveryDate.toIso8601String().split('T').first,
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (costCenter != null && costCenter.trim().isNotEmpty)
        'cost_center': costCenter.trim(),
      if (salesPerson != null && salesPerson.trim().isNotEmpty)
        'sales_team': [
          {'sales_person': salesPerson.trim(), 'allocated_percentage': 100},
        ],
      if (warehouse != null && warehouse.trim().isNotEmpty)
        'set_warehouse': warehouse.trim(),
      if (itemCode != null && itemCode.trim().isNotEmpty && qty != null)
        'items': [
          {
            'item_code': itemCode.trim(),
            'qty': qty,
            if (deliveryDate != null)
              'delivery_date': deliveryDate.toIso8601String().split('T').first,
            if (rate != null && rate > 0) 'rate': rate,
            if (warehouse != null && warehouse.trim().isNotEmpty)
              'warehouse': warehouse.trim(),
            if (costCenter != null && costCenter.trim().isNotEmpty)
              'cost_center': costCenter.trim(),
          },
        ],
    };

    if (updates.isEmpty) {
      throw Exception('No fields to update.');
    }

    await _frappeService.updateDocument('Sales Order', orderId, updates);
    final updatedDoc = await _frappeService.fetchDocument(
      'Sales Order',
      orderId,
    );
    final updatedOrder = SalesOrder.fromJson(updatedDoc);
    _salesOrders = _salesOrders
        .map((o) => o.id == orderId ? updatedOrder : o)
        .toList();
    notifyListeners();
    await refreshSalesOrders();
    unawaited(refreshOrderSummaries(silent: true));
    return updatedOrder;
  }

  Future<void> deleteSalesOrder(String orderId) async {
    await _frappeService.ensureLoggedIn();
    await _frappeService.deleteDocument('Sales Order', orderId);
    _salesOrders.removeWhere((o) => o.id == orderId);
    notifyListeners();
    await refreshSalesOrders();
    unawaited(refreshOrderSummaries(silent: true));
  }

  Future<PurchaseOrder> loadPurchaseOrderDetail(String orderId) async {
    await _frappeService.ensureLoggedIn();
    final doc = await _frappeService.fetchDocument('Purchase Order', orderId);
    return PurchaseOrder.fromJson(doc);
  }

  Future<DeliveryNote> loadDeliveryNoteDetail(String id) async {
    await _frappeService.ensureLoggedIn();
    final doc = await _frappeService.fetchDocument('Delivery Note', id);
    return DeliveryNote.fromJson(doc);
  }

  Future<SalesInvoice> loadSalesInvoiceDetail(String id) async {
    await _frappeService.ensureLoggedIn();
    final doc = await _frappeService.fetchDocument('Sales Invoice', id);
    return SalesInvoice.fromJson(doc);
  }

  Future<PurchaseReceipt> loadPurchaseReceiptDetail(String id) async {
    await _frappeService.ensureLoggedIn();
    final doc = await _frappeService.fetchDocument('Purchase Receipt', id);
    return PurchaseReceipt.fromJson(doc);
  }

  Future<PurchaseInvoice> loadPurchaseInvoiceDetail(String id) async {
    await _frappeService.ensureLoggedIn();
    final doc = await _frappeService.fetchDocument('Purchase Invoice', id);
    return PurchaseInvoice.fromJson(doc);
  }

  Future<PurchaseInvoice> createPurchaseInvoice({
    required String supplier,
    required String itemCode,
    required double qty,
    required String namingSeries,
    required DateTime postingDate,
    required DateTime dueDate,
    required bool updateStock,
    String? warehouse,
    double? rate,
    String? company,
  }) async {
    await _frappeService.ensureLoggedIn();
    final warehouseName = warehouse?.trim() ?? '';
    if (updateStock && warehouseName.isEmpty) {
      throw Exception('Warehouse wajib dipilih saat Update Stock aktif.');
    }

    final payload = <String, dynamic>{
      'supplier': supplier.trim(),
      'naming_series': namingSeries.trim(),
      'posting_date': postingDate.toIso8601String().split('T').first,
      'due_date': dueDate.toIso8601String().split('T').first,
      'update_stock': updateStock ? 1 : 0,
      if (company != null && company.trim().isNotEmpty)
        'company': company.trim(),
      if (updateStock) 'set_warehouse': warehouseName,
      'items': [
        {
          'item_code': itemCode.trim(),
          'qty': qty,
          if (rate != null && rate >= 0) 'rate': rate,
          if (updateStock) 'warehouse': warehouseName,
        },
      ],
    };

    final created = await _frappeService.createDocument(
      'Purchase Invoice',
      payload,
    );
    await refreshPurchaseInvoices();
    return PurchaseInvoice.fromJson(created);
  }

  Future<PurchaseOrder> createPurchaseOrder({
    required String supplier,
    required String itemCode,
    required double qty,
    required String namingSeries,
    required DateTime requiredBy,
    String? warehouse,
    double? rate,
    DateTime? transactionDate,
  }) async {
    await _frappeService.ensureLoggedIn();

    final payload = <String, dynamic>{
      'supplier': supplier,
      'naming_series': namingSeries.trim(),
      'transaction_date': (transactionDate ?? DateTime.now())
          .toIso8601String()
          .split('T')
          .first,
      'schedule_date': requiredBy.toIso8601String().split('T').first,
      'items': [
        {
          'item_code': itemCode,
          'qty': qty,
          'schedule_date': requiredBy.toIso8601String().split('T').first,
          if (rate != null && rate > 0) 'rate': rate,
          if (warehouse != null && warehouse.trim().isNotEmpty)
            'warehouse': warehouse.trim(),
        },
      ],
    };

    final created = await _frappeService.createDocument(
      'Purchase Order',
      payload,
    );
    final order = PurchaseOrder.fromJson(created);
    _purchaseOrders = [order, ..._purchaseOrders];
    notifyListeners();
    await refreshPurchaseOrders();
    return order;
  }

  Future<PurchaseOrder> updatePurchaseOrder({
    required String orderId,
    String? supplier,
    String? itemCode,
    double? qty,
    String? warehouse,
    double? rate,
    DateTime? transactionDate,
    DateTime? requiredBy,
  }) async {
    await _frappeService.ensureLoggedIn();

    final updates = <String, dynamic>{
      if (supplier != null && supplier.trim().isNotEmpty)
        'supplier': supplier.trim(),
      if (transactionDate != null)
        'transaction_date': transactionDate.toIso8601String().split('T').first,
      if (requiredBy != null)
        'schedule_date': requiredBy.toIso8601String().split('T').first,
      if (itemCode != null && itemCode.trim().isNotEmpty && qty != null)
        'items': [
          {
            'item_code': itemCode.trim(),
            'qty': qty,
            if (requiredBy != null)
              'schedule_date': requiredBy.toIso8601String().split('T').first,
            if (rate != null && rate > 0) 'rate': rate,
            if (warehouse != null && warehouse.trim().isNotEmpty)
              'warehouse': warehouse.trim(),
          },
        ],
    };

    if (updates.isEmpty) {
      throw Exception('No fields to update.');
    }

    await _frappeService.updateDocument('Purchase Order', orderId, updates);
    final updatedDoc = await _frappeService.fetchDocument(
      'Purchase Order',
      orderId,
    );
    final updatedOrder = PurchaseOrder.fromJson(updatedDoc);
    _purchaseOrders = _purchaseOrders
        .map((o) => o.id == orderId ? updatedOrder : o)
        .toList();
    notifyListeners();
    await refreshPurchaseOrders();
    return updatedOrder;
  }

  Future<void> createPurchaseReceipt({
    required String supplier,
    required String itemCode,
    required double qty,
    required String namingSeries,
    required String warehouse,
    required DateTime postingDate,
    double? rate,
    String? company,
  }) async {
    final payload = <String, dynamic>{
      'supplier': supplier.trim(),
      'naming_series': namingSeries.trim(),
      'posting_date': postingDate.toIso8601String().split('T').first,
      'set_warehouse': warehouse.trim(),
      if (company != null && company.trim().isNotEmpty)
        'company': company.trim(),
      'items': [
        {
          'item_code': itemCode.trim(),
          'qty': qty,
          'warehouse': warehouse.trim(),
          if (rate != null && rate >= 0) 'rate': rate,
        },
      ],
    };
    await _frappeService.createDocument('Purchase Receipt', payload);
    await refreshPurchaseReceipts();
  }

  Future<void> createMaterialRequest({
    required String itemCode,
    required double qty,
    required String namingSeries,
    required String warehouse,
    required DateTime requiredBy,
    String? company,
  }) async {
    final date = requiredBy.toIso8601String().split('T').first;
    final payload = <String, dynamic>{
      'naming_series': namingSeries.trim(),
      'material_request_type': 'Purchase',
      'transaction_date': DateTime.now().toIso8601String().split('T').first,
      'schedule_date': date,
      if (company != null && company.trim().isNotEmpty)
        'company': company.trim(),
      'items': [
        {
          'item_code': itemCode.trim(),
          'qty': qty,
          'schedule_date': date,
          'warehouse': warehouse.trim(),
        },
      ],
    };
    await _frappeService.createDocument('Material Request', payload);
    await refreshMaterialRequests();
  }

  Future<void> deletePurchaseOrder(String orderId) async {
    await _frappeService.ensureLoggedIn();
    await _frappeService.deleteDocument('Purchase Order', orderId);
    _purchaseOrders.removeWhere((o) => o.id == orderId);
    notifyListeners();
    await refreshPurchaseOrders();
  }

  Future<StockEntry> createStockEntry({
    required String stockEntryType,
    required List<Map<String, dynamic>> items,
    DateTime? postingDate,
  }) async {
    await _frappeService.ensureLoggedIn();

    final payload = <String, dynamic>{
      'stock_entry_type': stockEntryType,
      'posting_date': (postingDate ?? DateTime.now())
          .toIso8601String()
          .split('T')
          .first,
      'items': items,
    };

    final created = await _frappeService.createDocument('Stock Entry', payload);
    final entry = StockEntry.fromJson(created);
    _stockEntries = [entry, ..._stockEntries];
    notifyListeners();
    await refreshStockEntries();
    return entry;
  }

  Future<void> fetchSalesOrdersFromFrappe({
    String baseUrl = _defaultFrappeBaseUrl,
    String? username,
    String? password,
  }) async {
    _isSalesOrdersLoading = true;
    _salesOrdersError = null;
    _hasMoreSalesOrders = true;
    notifyListeners();

    try {
      _frappeService.baseUrl = baseUrl;
      if (username != null && password != null) {
        await _frappeService.login(username, password);
      } else {
        await _frappeService.ensureLoggedIn();
      }

      final orders = await _fetchSalesOrderPage(limitStart: 0);
      _salesOrders = orders;
      _hasMoreSalesOrders = orders.length == _documentPageSize;
    } catch (error) {
      _salesOrdersError = error.toString();
    } finally {
      _isSalesOrdersLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPurchaseOrdersFromFrappe({
    String baseUrl = _defaultFrappeBaseUrl,
    String? username,
    String? password,
  }) async {
    _frappeService.baseUrl = baseUrl;
    _isPurchaseOrdersLoading = true;
    _purchaseOrdersError = null;
    _hasMorePurchaseOrders = true;
    notifyListeners();

    try {
      if (username != null && password != null) {
        await _frappeService.login(username, password);
      } else {
        await _frappeService.ensureLoggedIn();
      }

      final orders = await _fetchPurchaseOrderPage(limitStart: 0);
      _purchaseOrders = orders;
      _hasMorePurchaseOrders = orders.length == _documentPageSize;

      _purchaseOrdersError = null;
    } catch (err) {
      _purchaseOrdersError = err.toString();
    } finally {
      _isPurchaseOrdersLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreSalesOrders() async {
    if (_isSalesOrdersLoading ||
        _isMoreSalesOrdersLoading ||
        !_hasMoreSalesOrders) {
      return;
    }

    _isMoreSalesOrdersLoading = true;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final nextPage = await _fetchSalesOrderPage(
        limitStart: _salesOrders.length,
      );
      final existingIds = _salesOrders.map((order) => order.id).toSet();
      _salesOrders = [
        ..._salesOrders,
        ...nextPage.where((order) => existingIds.add(order.id)),
      ];
      _hasMoreSalesOrders = nextPage.length == _documentPageSize;
      _salesOrdersError = null;
    } catch (err) {
      _salesOrdersError = err.toString();
    } finally {
      _isMoreSalesOrdersLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMorePurchaseOrders() async {
    if (_isPurchaseOrdersLoading ||
        _isMorePurchaseOrdersLoading ||
        !_hasMorePurchaseOrders) {
      return;
    }

    _isMorePurchaseOrdersLoading = true;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final nextPage = await _fetchPurchaseOrderPage(
        limitStart: _purchaseOrders.length,
      );
      final existingIds = _purchaseOrders.map((order) => order.id).toSet();
      _purchaseOrders = [
        ..._purchaseOrders,
        ...nextPage.where((order) => existingIds.add(order.id)),
      ];
      _hasMorePurchaseOrders = nextPage.length == _documentPageSize;
      _purchaseOrdersError = null;
    } catch (err) {
      _purchaseOrdersError = err.toString();
    } finally {
      _isMorePurchaseOrdersLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshOrderSummaries({bool silent = false}) {
    if (!_isAuthenticated) return Future.value();

    final activeJob = _orderSummaryJob;
    if (activeJob != null) return activeJob;

    final job = _refreshOrderSummaries(silent: silent);
    _orderSummaryJob = job.whenComplete(() {
      _orderSummaryJob = null;
    });
    return _orderSummaryJob!;
  }

  Future<void> _refreshOrderSummaries({required bool silent}) async {
    if (!silent) {
      _isOrderSummaryLoading = true;
      _orderSummaryError = null;
      notifyListeners();
    }

    try {
      await _frappeService.ensureLoggedIn();
      final sales = await _fetchAllSalesOrderSummary();
      final purchases = await _fetchAllPurchaseOrderSummary();
      _summarySalesOrders = sales;
      _summaryPurchaseOrders = purchases;
      _orderSummaryError = null;
    } catch (err) {
      _orderSummaryError = err.toString();
    } finally {
      _isOrderSummaryLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDeliveryNotesFromFrappe() async {
    _isDeliveryNotesLoading = true;
    _deliveryNotesError = null;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final data = await _fetchAllResourcePages(
        doctype: 'Delivery Note',
        fields: const [
          'name',
          'customer',
          'customer_name',
          'status',
          'docstatus',
          'posting_date',
          'grand_total',
          'total_qty',
        ],
        orderBy: 'posting_date desc',
      );
      _deliveryNotes = data.map((e) => DeliveryNote.fromJson(e)).toList();
      _deliveryNotesError = null;
    } catch (err) {
      _deliveryNotesError = err.toString();
    } finally {
      _isDeliveryNotesLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSalesInvoicesFromFrappe() async {
    _isSalesInvoicesLoading = true;
    _salesInvoicesError = null;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final data = await _fetchAllResourcePages(
        doctype: 'Sales Invoice',
        fields: const [
          'name',
          'customer',
          'customer_name',
          'status',
          'docstatus',
          'posting_date',
          'grand_total',
          'outstanding_amount',
          'due_date',
        ],
        orderBy: 'posting_date desc',
      );
      _salesInvoices = data.map((e) => SalesInvoice.fromJson(e)).toList();
      _salesInvoicesError = null;
    } catch (err) {
      _salesInvoicesError = err.toString();
    } finally {
      _isSalesInvoicesLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPurchaseReceiptsFromFrappe() async {
    _isPurchaseReceiptsLoading = true;
    _purchaseReceiptsError = null;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final data = await _fetchAllResourcePages(
        doctype: 'Purchase Receipt',
        fields: const [
          'name',
          'supplier',
          'supplier_name',
          'status',
          'docstatus',
          'posting_date',
          'grand_total',
          'total_qty',
        ],
        orderBy: 'posting_date desc',
      );
      _purchaseReceipts = data.map((e) => PurchaseReceipt.fromJson(e)).toList();
      _purchaseReceiptsError = null;
    } catch (err) {
      _purchaseReceiptsError = err.toString();
    } finally {
      _isPurchaseReceiptsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchPurchaseInvoicesFromFrappe() async {
    _isPurchaseInvoicesLoading = true;
    _purchaseInvoicesError = null;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final data = await _fetchAllResourcePages(
        doctype: 'Purchase Invoice',
        fields: const [
          'name',
          'supplier',
          'supplier_name',
          'status',
          'docstatus',
          'posting_date',
          'grand_total',
          'outstanding_amount',
          'due_date',
        ],
        orderBy: 'posting_date desc',
      );
      _purchaseInvoices = data.map((e) => PurchaseInvoice.fromJson(e)).toList();
      _purchaseInvoicesError = null;
    } catch (err) {
      _purchaseInvoicesError = err.toString();
    } finally {
      _isPurchaseInvoicesLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDeliveryNotes() => fetchDeliveryNotesFromFrappe();
  Future<void> refreshSalesInvoices() => fetchSalesInvoicesFromFrappe();
  Future<void> refreshPurchaseReceipts() => fetchPurchaseReceiptsFromFrappe();
  Future<void> refreshPurchaseInvoices() => fetchPurchaseInvoicesFromFrappe();
  Future<void> fetchStockEntriesFromFrappe() async {
    _isStockEntriesLoading = true;
    _stockEntriesError = null;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final data = await _fetchAllResourcePages(
        doctype: 'Stock Entry',
        fields: const [
          'name',
          'stock_entry_type',
          'status',
          'docstatus',
          'posting_date',
          'total_qty',
        ],
        orderBy: 'posting_date desc',
      );
      _stockEntries = data.map((e) => StockEntry.fromJson(e)).toList();
      _stockEntriesError = null;
    } catch (err) {
      _stockEntriesError = err.toString();
    } finally {
      _isStockEntriesLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMaterialRequestsFromFrappe() async {
    _isMaterialRequestsLoading = true;
    _materialRequestsError = null;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final data = await _fetchAllResourcePages(
        doctype: 'Material Request',
        fields: const [
          'name',
          'material_request_type',
          'status',
          'docstatus',
          'transaction_date',
          'total_qty',
        ],
        orderBy: 'transaction_date desc',
      );
      _materialRequests = data.map((e) => MaterialRequest.fromJson(e)).toList();
      _materialRequestsError = null;
    } catch (err) {
      _materialRequestsError = err.toString();
    } finally {
      _isMaterialRequestsLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshStockEntries() => fetchStockEntriesFromFrappe();
  Future<void> refreshMaterialRequests() => fetchMaterialRequestsFromFrappe();

  Future<void> fetchWarehousesFromFrappe({
    String baseUrl = _defaultFrappeBaseUrl,
    String? username,
    String? password,
  }) async {
    _frappeService.baseUrl = baseUrl;

    try {
      if (username != null && password != null) {
        await _frappeService.login(username, password);
      } else {
        await _frappeService.ensureLoggedIn();
      }

      List<Map<String, dynamic>> data;
      try {
        data = await _fetchAllResourcePages(
          doctype: 'Warehouse',
          fields: const [
            'name',
            'warehouse_name',
            'company',
            'parent_warehouse',
            'is_group',
            'disabled',
          ],
          orderBy: 'name asc',
          filters: [
            ['is_group', '=', 0],
            ['disabled', '=', 0],
          ],
        );
      } catch (_) {
        data = await _fetchAllResourcePages(
          doctype: 'Warehouse',
          fields: const [
            'name',
            'warehouse_name',
            'company',
            'parent_warehouse',
            'is_group',
            'disabled',
          ],
          orderBy: 'name asc',
        );
      }

      _warehouses = data
          .map((row) => WarehouseInfo.fromJson(row))
          .where((w) => w.name.isNotEmpty && !w.isGroup && w.isDisabled != true)
          .toList();
    } catch (_) {
      // Warehouse list is optional; stock can fall back to name filters.
    } finally {
      notifyListeners();
    }
  }

  List<MapEntry<String, String>> get stockCompanies {
    final labels = <String, String>{};
    for (final w in _warehouses) {
      if (w.company.isEmpty) continue;
      labels.putIfAbsent(w.company, () => w.company);
    }
    final entries = labels.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries;
  }

  bool _warehouseBelongsToCompany(WarehouseInfo warehouse, String company) {
    return warehouse.company == company;
  }

  List<StockAreaOption> stockWarehousesForCompany(String company) {
    final seen = <String>{};
    final areas = <StockAreaOption>[];

    for (final w in _warehouses.where(
      (w) => _warehouseBelongsToCompany(w, company),
    )) {
      final areaId = w.name;
      if (areaId.isEmpty || seen.contains(areaId)) continue;
      seen.add(areaId);
      areas.add(
        StockAreaOption(
          areaId: areaId,
          title: w.name,
          subtitle: w.displayName == w.name ? '' : w.displayName,
          icon: _iconForWarehouseName(w.name),
          warehouseType: _typeForWarehouseName(w.name),
          maxCapacity: _capacityForWarehouseName(w.name),
        ),
      );
    }

    return areas;
  }

  List<String> erpWarehouseNamesForCompany(String company) {
    if (_warehouses.isEmpty) return [];
    return _warehouses
        .where((w) => _warehouseBelongsToCompany(w, company))
        .map((w) => w.name)
        .toList();
  }

  Future<void> fetchInventoryFromFrappe({
    String baseUrl = _defaultFrappeBaseUrl,
    String? username,
    String? password,
    List<List<dynamic>>? filters,
  }) async {
    _frappeService.baseUrl = baseUrl;
    _isInventoryLoading = true;
    _inventoryError = null;
    notifyListeners();

    try {
      if (username != null && password != null) {
        await _frappeService.login(username, password);
      } else {
        await _frappeService.ensureLoggedIn();
      }

      if (_warehouses.isEmpty) {
        await fetchWarehousesFromFrappe(
          baseUrl: baseUrl,
          username: username,
          password: password,
        );
      }

      final maxRows = filters == null ? _defaultFetchRowLimit : null;
      List<Map<String, dynamic>> data;
      try {
        data = await _fetchAllResourcePages(
          doctype: 'Bin',
          fields: const [
            'item_code',
            'warehouse',
            'actual_qty',
            'reserved_qty',
            'projected_qty',
          ],
          filters: filters,
          maxRows: maxRows,
        );
      } catch (_) {
        data = await _fetchAllResourcePages(
          doctype: 'Bin',
          fields: const ['item_code', 'warehouse', 'actual_qty'],
          filters: filters,
          maxRows: maxRows,
        );
      }

      final List<InventoryItem> items = [];
      for (final rawItem in data) {
        final rawWarehouse =
            rawItem['warehouse']?.toString() ??
            rawItem['warehouse_id']?.toString() ??
            '';

        final inv = InventoryItem.fromJson(rawItem);
        if (rawWarehouse.isEmpty) continue;
        items.add(inv.copyWith(warehouseId: rawWarehouse));
      }

      final itemMeta = await _fetchItemMeta(
        items.map((i) => i.sku).where((s) => s.isNotEmpty).toSet(),
      );

      _inventory = items.map((inv) {
        final meta = itemMeta[inv.sku];
        if (meta == null) return inv;

        var updated = inv;
        if (meta.name.isNotEmpty && meta.name != inv.sku) {
          updated = updated.copyWith(name: meta.name);
        }
        if (meta.reorderLevel > 0) {
          updated = updated.copyWith(minStockThreshold: meta.reorderLevel);
        }
        if (meta.valuationRate > 0) {
          updated = updated.copyWith(unitValue: meta.valuationRate);
        }
        return updated.withRecalculatedStatus();
      }).toList();
      _inventoryError = null;
    } catch (err) {
      _inventoryError = err.toString();
    } finally {
      _isInventoryLoading = false;
      notifyListeners();
    }
  }

  Future<void> submitDocument(String doctype, String name) async {
    await _frappeService.submitDocument(doctype, name);
    await _refreshAfterDocChange(doctype);
    if (doctype == 'Sales Order' ||
        doctype == 'Delivery Note' ||
        doctype == 'Sales Invoice') {
      unawaited(refreshOrderSummaries(silent: true));
    }
  }

  Future<List<String>> fetchNamingSeries(String doctype) {
    return _frappeService.fetchNamingSeries(doctype);
  }

  Future<void> cancelDocument(String doctype, String name) async {
    await _frappeService.cancelDocument(doctype, name);
    await _refreshAfterDocChange(doctype);
  }

  Future<void> _refreshAfterDocChange(String doctype) async {
    switch (doctype) {
      case 'Sales Order':
        await refreshSalesOrders();
      case 'Delivery Note':
        await refreshDeliveryNotes();
      case 'Sales Invoice':
        await refreshSalesInvoices();
      case 'Purchase Order':
        await refreshPurchaseOrders();
      case 'Purchase Receipt':
        await refreshPurchaseReceipts();
      case 'Purchase Invoice':
        await refreshPurchaseInvoices();
      case 'Material Request':
        await refreshMaterialRequests();
    }
    notifyListeners();
  }

  Future<DeliveryNote> createDeliveryNoteFromSalesOrder(
    String soId, {
    required String namingSeries,
  }) async {
    final so = await _frappeService.fetchDocument('Sales Order', soId);
    final items = buildDeliveryNoteItemsFromSalesOrder(so);
    if (items.isEmpty) {
      throw Exception('No pending items to deliver for this Sales Order.');
    }

    final payload = <String, dynamic>{
      'naming_series': namingSeries.trim(),
      'customer': so['customer'],
      'company': so['company'],
      'posting_date': DateTime.now().toIso8601String().split('T').first,
      'items': items,
    };

    final created = await _frappeService.createDocument(
      'Delivery Note',
      payload,
    );
    await refreshDeliveryNotes();
    await refreshSalesOrders();
    unawaited(refreshOrderSummaries(silent: true));
    return DeliveryNote.fromJson(created);
  }

  Future<SalesInvoice> createSalesInvoiceFromSalesOrder(
    String soId, {
    required String namingSeries,
  }) async {
    final so = await _frappeService.fetchDocument('Sales Order', soId);
    final items = buildSalesInvoiceItemsFromSalesOrder(so);
    if (items.isEmpty) {
      throw Exception('No pending items to bill for this Sales Order.');
    }

    final payload = <String, dynamic>{
      'naming_series': namingSeries.trim(),
      'customer': so['customer'],
      'company': so['company'],
      'posting_date': DateTime.now().toIso8601String().split('T').first,
      'items': items,
    };

    final created = await _frappeService.createDocument(
      'Sales Invoice',
      payload,
    );
    await refreshSalesInvoices();
    await refreshSalesOrders();
    unawaited(refreshOrderSummaries(silent: true));
    return SalesInvoice.fromJson(created);
  }

  Future<PurchaseReceipt> createPurchaseReceiptFromPurchaseOrder(
    String poId,
  ) async {
    final po = await _frappeService.fetchDocument('Purchase Order', poId);
    final items = buildPurchaseReceiptItemsFromPurchaseOrder(po);
    if (items.isEmpty) {
      throw Exception('No pending items to receive for this Purchase Order.');
    }

    final payload = <String, dynamic>{
      'supplier': po['supplier'],
      'company': po['company'],
      'posting_date': DateTime.now().toIso8601String().split('T').first,
      'items': items,
    };

    final created = await _frappeService.createDocument(
      'Purchase Receipt',
      payload,
    );
    await refreshPurchaseReceipts();
    await refreshPurchaseOrders();
    return PurchaseReceipt.fromJson(created);
  }

  Future<PurchaseInvoice> createPurchaseInvoiceFromPurchaseOrder(
    String poId,
  ) async {
    final po = await _frappeService.fetchDocument('Purchase Order', poId);
    final items = buildPurchaseInvoiceItemsFromPurchaseOrder(po);
    if (items.isEmpty) {
      throw Exception('No pending items to bill for this Purchase Order.');
    }

    final payload = <String, dynamic>{
      'supplier': po['supplier'],
      'company': po['company'],
      'posting_date': DateTime.now().toIso8601String().split('T').first,
      'items': items,
    };

    final created = await _frappeService.createDocument(
      'Purchase Invoice',
      payload,
    );
    await refreshPurchaseInvoices();
    await refreshPurchaseOrders();
    return PurchaseInvoice.fromJson(created);
  }

  Future<List<DeliveryNote>> fetchDeliveryNotesForSalesOrder(
    String soId,
  ) async {
    await _frappeService.ensureLoggedIn();
    final data = await _fetchAllResourcePages(
      doctype: 'Delivery Note',
      fields: const [
        'name',
        'customer',
        'customer_name',
        'status',
        'docstatus',
        'posting_date',
        'grand_total',
        'total_qty',
      ],
      filters: [
        ['Delivery Note Item', 'against_sales_order', '=', soId],
      ],
    );
    return data.map((e) => DeliveryNote.fromJson(e)).toList();
  }

  Future<List<SalesInvoice>> fetchSalesInvoicesForSalesOrder(
    String soId,
  ) async {
    await _frappeService.ensureLoggedIn();
    try {
      final data = await _fetchAllResourcePages(
        doctype: 'Sales Invoice',
        fields: const [
          'name',
          'customer',
          'customer_name',
          'status',
          'docstatus',
          'posting_date',
          'grand_total',
          'outstanding_amount',
          'due_date',
        ],
        filters: [
          ['Sales Invoice Item', 'sales_order', '=', soId],
        ],
      );
      return data.map((e) => SalesInvoice.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  int get unpaidSalesInvoicesCount => _salesInvoices
      .where(
        (i) =>
            i.statusKey == InvoiceStatusKey.unpaid ||
            i.statusKey == InvoiceStatusKey.overdue ||
            i.statusKey == InvoiceStatusKey.partlyPaid,
      )
      .length;

  int get overduePurchaseInvoicesCount => _purchaseInvoices
      .where((i) => i.statusKey == InvoiceStatusKey.overdue)
      .length;

  Future<StockLedgerResult> fetchStockLedgerForItem({
    required String itemCode,
    required DateTime from,
    required DateTime to,
  }) async {
    await _frappeService.ensureLoggedIn();

    final fromDate = DateRangePresets.toFrappeDate(from);
    final toDate = DateRangePresets.toFrappeDate(to);

    final data = await _fetchAllResourcePages(
      doctype: 'Stock Ledger Entry',
      fields: const [
        'posting_date',
        'posting_time',
        'item_code',
        'warehouse',
        'actual_qty',
        'qty_after_transaction',
        'voucher_type',
        'voucher_no',
        'stock_value_difference',
      ],
      orderBy: 'posting_date desc, posting_time desc',
      filters: [
        ['item_code', '=', itemCode],
        ['posting_date', '>=', fromDate],
        ['posting_date', '<=', toDate],
      ],
    );

    final movements = data.map((e) => StockLedgerMovement.fromJson(e)).toList();
    return StockLedgerResult.fromMovements(movements);
  }

  Future<void> refreshSalesOrders() => fetchSalesOrdersFromFrappe();
  Future<void> refreshPurchaseOrders() => fetchPurchaseOrdersFromFrappe();
  Future<void> refreshInventory() => fetchInventoryFromFrappe();

  Future<void> refreshWarehouses() => fetchWarehousesFromFrappe();

  Future<void> refreshInventoryForCompany(String company) async {
    if (_warehouses.isEmpty) {
      await fetchWarehousesFromFrappe();
    }

    final erpNames = erpWarehouseNamesForCompany(company);
    if (erpNames.isNotEmpty) {
      await fetchInventoryFromFrappe(
        filters: [
          ['warehouse', 'in', erpNames],
        ],
      );
      return;
    }

    _inventory = [];
    notifyListeners();
  }

  Future<void> saveFrappeConfig({
    required String baseUrl,
    required String username,
    String? password,
    bool savePassword = true,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final shouldSavePassword =
        savePassword || _rememberDevice || password != null;
    final cfg = {
      'baseUrl': baseUrl,
      'username': username,
      if (shouldSavePassword && password != null) 'password': password,
    };
    await sp.setString(_prefsFrappeConfigKey, jsonEncode(cfg));

    _frappeService.baseUrl = baseUrl;
    _frappeService.username = username;
    if (shouldSavePassword && password != null) {
      _frappeService.password = password;
    }
  }

  Future<Map<String, String>?> _loadFrappeConfig() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_prefsFrappeConfigKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return null;
    }
  }

  Future<List<SalesOrder>> _fetchSalesOrderPage({
    required int limitStart,
  }) async {
    final data = await _fetchResourceWithFieldFallback(
      doctype: 'Sales Order',
      fields: const [
        'name',
        'customer',
        'customer_name',
        'grand_total',
        'status',
        'docstatus',
        'transaction_date',
        'total_qty',
        'per_delivered',
        'per_billed',
      ],
      limit: _documentPageSize,
      limitStart: limitStart,
      orderBy: 'transaction_date desc',
    );

    var orders = data.map((item) => SalesOrder.fromJson(item)).toList();
    orders = await _attachSalesOrderItems(orders);
    return orders;
  }

  Future<List<SalesOrder>> _fetchAllSalesOrderSummary() async {
    final data = await _fetchAllResourcePages(
      doctype: 'Sales Order',
      fields: const [
        'name',
        'customer',
        'customer_name',
        'grand_total',
        'status',
        'docstatus',
        'transaction_date',
        'total_qty',
        'per_delivered',
        'per_billed',
      ],
      orderBy: 'transaction_date desc',
      maxRows: null,
    );

    return data.map((item) => SalesOrder.fromJson(item)).toList();
  }

  Future<List<PurchaseOrder>> _fetchPurchaseOrderPage({
    required int limitStart,
  }) async {
    final data = await _fetchResourceWithFieldFallback(
      doctype: 'Purchase Order',
      fields: const [
        'name',
        'supplier',
        'supplier_name',
        'status',
        'docstatus',
        'transaction_date',
        'schedule_date',
        'total_qty',
        'grand_total',
        'creation',
      ],
      limit: _documentPageSize,
      limitStart: limitStart,
      orderBy: 'modified desc',
    );

    var orders = data.map((item) => PurchaseOrder.fromJson(item)).toList();
    orders = await _attachPurchaseOrderItems(orders);
    return orders;
  }

  Future<List<PurchaseOrder>> _fetchAllPurchaseOrderSummary() async {
    final data = await _fetchAllResourcePages(
      doctype: 'Purchase Order',
      fields: const [
        'name',
        'supplier',
        'supplier_name',
        'status',
        'docstatus',
        'transaction_date',
        'schedule_date',
        'total_qty',
        'grand_total',
        'creation',
      ],
      orderBy: 'modified desc',
      maxRows: null,
    );

    return data.map((item) => PurchaseOrder.fromJson(item)).toList();
  }

  Future<List<SalesOrder>> _attachSalesOrderItems(
    List<SalesOrder> orders,
  ) async {
    if (orders.isEmpty) return orders;
    try {
      final rows = await _fetchAllResourcePages(
        doctype: 'Sales Order Item',
        fields: const [
          'parent',
          'item_code',
          'item_name',
          'qty',
          'rate',
          'warehouse',
        ],
        filters: [
          ['parent', 'in', orders.map((order) => order.id).toList()],
        ],
        maxRows: 2000,
      );
      final grouped = <String, List<SalesOrderItem>>{};
      for (final row in rows) {
        final parent = row['parent']?.toString() ?? '';
        if (parent.isEmpty) continue;
        grouped.putIfAbsent(parent, () => []).add(SalesOrderItem.fromJson(row));
      }
      return orders
          .map(
            (order) => order.copyWith(items: grouped[order.id] ?? order.items),
          )
          .toList();
    } catch (_) {
      return orders;
    }
  }

  Future<List<PurchaseOrder>> _attachPurchaseOrderItems(
    List<PurchaseOrder> orders,
  ) async {
    if (orders.isEmpty) return orders;
    try {
      final rows = await _fetchAllResourcePages(
        doctype: 'Purchase Order Item',
        fields: const [
          'parent',
          'item_code',
          'item_name',
          'qty',
          'rate',
          'warehouse',
        ],
        filters: [
          ['parent', 'in', orders.map((order) => order.id).toList()],
        ],
        maxRows: 2000,
      );
      final grouped = <String, List<PurchaseOrderItem>>{};
      for (final row in rows) {
        final parent = row['parent']?.toString() ?? '';
        if (parent.isEmpty) continue;
        grouped
            .putIfAbsent(parent, () => [])
            .add(PurchaseOrderItem.fromJson(row));
      }
      return orders
          .map(
            (order) => order.copyWith(items: grouped[order.id] ?? order.items),
          )
          .toList();
    } catch (_) {
      return orders;
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAllResourcePages({
    required String doctype,
    required List<String> fields,
    String? orderBy,
    List<List<dynamic>>? filters,
    int? maxRows = _defaultFetchRowLimit,
  }) async {
    final all = <Map<String, dynamic>>[];
    var start = 0;

    while (true) {
      final remaining = maxRows == null ? null : maxRows - all.length;
      if (remaining != null && remaining <= 0) break;
      final pageLimit = remaining == null
          ? _frappePageSize
          : math.min(_frappePageSize, remaining);
      final page = await _fetchResourceWithFieldFallback(
        doctype: doctype,
        fields: fields,
        limit: pageLimit,
        limitStart: start,
        orderBy: orderBy,
        filters: filters,
      );
      all.addAll(page);
      if (page.length < pageLimit) break;
      start += pageLimit;
    }

    return all;
  }

  Future<List<Map<String, dynamic>>> _fetchResourceWithFieldFallback({
    required String doctype,
    required List<String> fields,
    required int limit,
    int limitStart = 0,
    String? orderBy,
    List<List<dynamic>>? filters,
  }) async {
    var remainingFields = List<String>.from(fields);
    var currentOrderBy = orderBy;

    while (remainingFields.isNotEmpty) {
      try {
        return await _frappeService.fetchResource(
          doctype,
          fields: remainingFields,
          limit: limit,
          limitStart: limitStart,
          orderBy: currentOrderBy,
          filters: filters,
        );
      } catch (err) {
        final errStr = err.toString();

        final fieldReg = RegExp(
          r'Field not permitted in query:\s*([a-zA-Z0-9_]+)',
        );
        final fieldMatch = fieldReg.firstMatch(errStr);

        if (fieldMatch != null) {
          final badField = fieldMatch.group(1);
          if (badField != null && remainingFields.contains(badField)) {
            remainingFields.remove(badField);
            continue;
          }
        }

        if (currentOrderBy != null &&
            (errStr.contains('order_by') || errStr.contains('Order By'))) {
          currentOrderBy = null;
          continue;
        }

        rethrow;
      }
    }

    throw Exception('No permitted fields available for $doctype.');
  }

  Future<Map<String, ({String name, int reorderLevel, double valuationRate})>>
  _fetchItemMeta(Set<String> itemCodes) async {
    if (itemCodes.isEmpty) return {};

    final codes = itemCodes.toList();
    final meta =
        <String, ({String name, int reorderLevel, double valuationRate})>{};

    for (var i = 0; i < codes.length; i += 80) {
      final chunk = codes.sublist(
        i,
        i + 80 > codes.length ? codes.length : i + 80,
      );
      try {
        final data = await _fetchResourceWithFieldFallback(
          doctype: 'Item',
          fields: const [
            'name',
            'item_name',
            'reorder_level',
            'valuation_rate',
          ],
          limit: chunk.length,
          filters: [
            ['name', 'in', chunk],
          ],
        );
        for (final row in data) {
          final code = row['name']?.toString() ?? '';
          if (code.isEmpty) continue;
          meta[code] = (
            name: row['item_name']?.toString() ?? code,
            reorderLevel: NumParse.asInt(row['reorder_level']),
            valuationRate: NumParse.asDouble(row['valuation_rate']),
          );
        }
      } catch (_) {
        try {
          final data = await _fetchResourceWithFieldFallback(
            doctype: 'Item',
            fields: const ['name', 'item_name'],
            limit: chunk.length,
            filters: [
              ['name', 'in', chunk],
            ],
          );
          for (final row in data) {
            final code = row['name']?.toString() ?? '';
            if (code.isEmpty) continue;
            meta[code] = (
              name: row['item_name']?.toString() ?? code,
              reorderLevel: 0,
              valuationRate: 0,
            );
          }
        } catch (_) {}
      }
    }

    return meta;
  }

  IconData _iconForWarehouseName(String name) {
    final w = name.toLowerCase();
    if (w.contains('inbound') || w.contains('masuk')) {
      return Icons.move_to_inbox_outlined;
    }
    if (w.contains('ripen') || w.contains('matang') || w.contains('pematang')) {
      return Icons.eco_outlined;
    }
    if (w.contains('stores') || w.contains('siap jual')) {
      return Icons.storefront_outlined;
    }
    return Icons.inventory_2_outlined;
  }

  WarehouseType _typeForWarehouseName(String name) {
    final w = name.toLowerCase();
    if (w.contains('inbound') ||
        w.contains('masuk') ||
        w.contains('datang') ||
        w.contains('receiving')) {
      return WarehouseType.inbound;
    }
    if (w.contains('ripen') ||
        w.contains('rippen') ||
        w.contains('matang') ||
        w.contains('pematang')) {
      return WarehouseType.ripening;
    }
    return WarehouseType.stores;
  }

  int _capacityForWarehouseName(String name) {
    final type = _typeForWarehouseName(name);
    if (type == WarehouseType.inbound) return 2000;
    return 900;
  }
}
