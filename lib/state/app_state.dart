import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/sales_order.dart';
import '../models/sales_order_approval.dart';
import '../models/purchase_order.dart';
import '../models/delivery_note.dart';
import '../models/sales_invoice.dart';
import '../models/purchase_receipt.dart';
import '../models/purchase_invoice.dart';
import '../models/quality_inspection_record.dart';
import '../models/stock_entry.dart';
import '../models/stock_ledger_movement.dart';
import '../models/inventory_item.dart';
import '../utils/date_range_presets.dart';
import '../models/warehouse_info.dart';
import '../models/warehouse_tracking_record.dart';
import '../models/stock_area_option.dart';
import '../models/erp_summary.dart';
import '../models/sales_order_insight.dart';
import '../models/sales_workspace.dart';
import '../services/domains/auth_service.dart';
import '../services/domains/customer_service.dart';
import '../services/domains/purchase_invoice_service.dart';
import '../services/domains/purchase_order_service.dart';
import '../services/domains/sales_invoice_service.dart';
import '../services/domains/sales_order_service.dart';
import '../services/erp_services.dart';
import '../services/frappe_service.dart';
import '../services/sales_visit_location_service.dart';
import '../utils/erp_doc_utils.dart';
import '../utils/num_parse.dart';
import '../utils/frappe_page_walker.dart';
import '../widgets/notifications/notification_model.dart';

class AppState with ChangeNotifier {
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  String? _currentUser;
  String? get currentUser => _currentUser;
  String? _currentEmployee;
  String? get currentEmployee => _currentEmployee;
  Map<String, dynamic> _currentEmployeeProfile = const {};
  Map<String, dynamic> get currentEmployeeProfile => _currentEmployeeProfile;
  String? _currentSalesPerson;
  String? get currentSalesPerson => _currentSalesPerson;
  String? _salesIdentityError;
  String? get salesIdentityError => _salesIdentityError;

  bool _rememberDevice = true;
  bool get rememberDevice => _rememberDevice;

  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;
  String? _lastAuthError;
  String? get lastAuthError => _lastAuthError;

  String _userRole = 'Unassigned';
  String get userRole => _userRole;
  bool get isSalesUserRole => _userRole == 'Sales';
  bool get isSalesManagerRole => _userRole == 'Sales Manager';
  bool get isSalesAreaRole => isSalesUserRole || isSalesManagerRole;
  bool get _shouldScopeSalesData => _userRole == 'Sales';

  static const String _prefsUserRoleKey = 'user_role';

  Future<void> refreshDataForCurrentRole() async {
    if (!_isAuthenticated) return;
    if (isSalesUserRole) {
      await resolveCurrentSalesIdentity();
      await Future.wait([
        fetchSalesOrdersFromFrappe(),
        fetchSalesInvoicesFromFrappe(),
        fetchInventoryFromFrappe(
          filters: const [
            ['warehouse', '=', 'Stores - Jakarta'],
          ],
        ),
      ]);
      return;
    }
    await prefetchInitialData();
  }

  Future<void> syncCurrentUserRoleFromFrappe() async {
    final currentUser = _currentUser?.trim() ?? '';
    if (currentUser.isEmpty) {
      throw Exception('User login Frappe tidak tersedia.');
    }
    final access = await _authService.fetchCurrentUserAccess(currentUser);
    await _applyCurrentRole(access.roleProfile);
  }

  Future<void> _applyCurrentRole(String roleProfile) async {
    _userRole = _normalizeRoleProfile(roleProfile);
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_prefsUserRoleKey, _userRole);
    notifyListeners();
  }

  String _normalizeRoleProfile(String roleProfile) {
    final normalized = roleProfile.trim();
    final lower = normalized.toLowerCase();
    if (lower == 'administrator') return 'Administrator';
    if (lower == 'sales' || lower == 'sales user') return 'Sales';
    if (lower == 'sales manager') return 'Sales Manager';
    if (lower == 'warehouse') return 'Warehouse';
    if (lower == 'logistics') return 'Logistics';
    if (lower == 'null' || lower == 'none' || lower == 'undefined') {
      return 'Unassigned';
    }
    return normalized;
  }

  Future<String?> resolveCurrentSalesIdentity() async {
    _currentEmployee = null;
    _currentEmployeeProfile = const {};
    _currentSalesPerson = null;
    _salesIdentityError = null;
    if (_currentUser == null || _currentUser!.isEmpty) {
      _salesIdentityError = 'User login ERPNext tidak tersedia.';
      notifyListeners();
      return null;
    }
    try {
      final identity = await _authService.resolveSalesIdentity(_currentUser!);
      _currentEmployee = identity.employee;
      _currentEmployeeProfile = identity.employeeProfile;
      _currentSalesPerson = identity.salesPerson;
    } catch (error) {
      _salesIdentityError = error.toString();
    }
    notifyListeners();
    return _currentSalesPerson;
  }

  List<SalesOrder> _salesOrders = [];
  List<PurchaseOrder> _purchaseOrders = [];
  List<DeliveryNote> _deliveryNotes = [];
  List<SalesInvoice> _salesInvoices = [];
  List<PurchaseReceipt> _purchaseReceipts = [];
  List<PurchaseInvoice> _purchaseInvoices = [];
  List<StockEntry> _stockEntries = [];
  List<StockReconciliationSummary> _stockReconciliations = [];
  List<InventoryItem> _inventory = [];
  DocumentSummary _salesOrderSummary = const DocumentSummary();
  DocumentSummary _deliveryNoteSummary = const DocumentSummary();
  DocumentSummary _salesInvoiceSummary = const DocumentSummary();
  DocumentSummary _purchaseOrderSummary = const DocumentSummary();
  DocumentSummary _purchaseReceiptSummary = const DocumentSummary();
  DocumentSummary _purchaseInvoiceSummary = const DocumentSummary();
  DashboardSummary _dashboardSummary = const DashboardSummary();
  List<DocumentTrendPoint> _salesOrderTrendPoints = const [];
  List<DocumentTrendPoint> _deliveryNoteTrendPoints = const [];
  List<DocumentTrendPoint> _salesInvoiceTrendPoints = const [];
  List<DocumentTrendPoint> _purchaseOrderTrendPoints = const [];
  List<DocumentTrendPoint> _purchaseReceiptTrendPoints = const [];
  List<DocumentTrendPoint> _purchaseInvoiceTrendPoints = const [];

  DocumentSummary get salesOrderSummary => _salesOrderSummary;
  DocumentSummary get deliveryNoteSummary => _deliveryNoteSummary;
  DocumentSummary get salesInvoiceSummary => _salesInvoiceSummary;
  DocumentSummary get purchaseOrderSummary => _purchaseOrderSummary;
  DocumentSummary get purchaseReceiptSummary => _purchaseReceiptSummary;
  DocumentSummary get purchaseInvoiceSummary => _purchaseInvoiceSummary;
  DashboardSummary get dashboardSummary => _dashboardSummary;
  List<DocumentTrendPoint> get salesOrderTrendPoints => _salesOrderTrendPoints;
  List<DocumentTrendPoint> get deliveryNoteTrendPoints =>
      _deliveryNoteTrendPoints;
  List<DocumentTrendPoint> get salesInvoiceTrendPoints =>
      _salesInvoiceTrendPoints;
  List<DocumentTrendPoint> get purchaseOrderTrendPoints =>
      _purchaseOrderTrendPoints;
  List<DocumentTrendPoint> get purchaseReceiptTrendPoints =>
      _purchaseReceiptTrendPoints;
  List<DocumentTrendPoint> get purchaseInvoiceTrendPoints =>
      _purchaseInvoiceTrendPoints;

  List<SalesOrder> get salesOrders => _salesOrders;
  List<PurchaseOrder> get purchaseOrders => _purchaseOrders;
  List<DeliveryNote> get deliveryNotes => _deliveryNotes;
  List<SalesInvoice> get salesInvoices => _salesInvoices;
  List<PurchaseReceipt> get purchaseReceipts => _purchaseReceipts;
  List<PurchaseInvoice> get purchaseInvoices => _purchaseInvoices;
  List<StockEntry> get stockEntries => _stockEntries;
  List<StockReconciliationSummary> get stockReconciliations =>
      _stockReconciliations;
  List<InventoryItem> get inventory => _inventory;
  List<SalesOrder> get dashboardSalesOrders => _salesOrders;
  List<PurchaseOrder> get dashboardPurchaseOrders => _purchaseOrders;

  List<WarehouseInfo> _warehouses = [];
  List<WarehouseInfo> get warehouses => _warehouses;

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;
  bool get hasUnreadNotifications =>
      _notifications.any((notification) => !notification.isRead);

  int _salesOrderApprovalTodoCount = 0;
  int get salesOrderApprovalTodoCount => _salesOrderApprovalTodoCount;

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
  String _salesOrderSearch = '';
  String? _salesOrderStatus;
  int _salesOrderQueryVersion = 0;

  int _sellingPeriodYear = DateTime.now().year;
  int _sellingPeriodMonth = DateTime.now().month;
  int get sellingPeriodYear => _sellingPeriodYear;
  int get sellingPeriodMonth => _sellingPeriodMonth;
  DateTime get sellingPeriodFrom => _sellingPeriodMonth == 0
      ? DateTime(_sellingPeriodYear, 1, 1)
      : DateTime(_sellingPeriodYear, _sellingPeriodMonth, 1);
  DateTime get sellingPeriodTo => _sellingPeriodMonth == 0
      ? DateTime(_sellingPeriodYear, 12, 31)
      : DateTime(_sellingPeriodYear, _sellingPeriodMonth + 1, 0);

  bool _isPurchaseOrdersLoading = false;
  bool get isPurchaseOrdersLoading => _isPurchaseOrdersLoading;

  bool _isMorePurchaseOrdersLoading = false;
  bool get isMorePurchaseOrdersLoading => _isMorePurchaseOrdersLoading;

  bool _hasMorePurchaseOrders = true;
  bool get hasMorePurchaseOrders => _hasMorePurchaseOrders;

  String? _purchaseOrdersError;
  String? get purchaseOrdersError => _purchaseOrdersError;
  String _purchaseOrderSearch = '';
  String? _purchaseOrderStatus;
  int _purchaseOrderQueryVersion = 0;

  int _buyingPeriodYear = DateTime.now().year;
  int _buyingPeriodMonth = DateTime.now().month;
  int get buyingPeriodYear => _buyingPeriodYear;
  int get buyingPeriodMonth => _buyingPeriodMonth;
  DateTime get buyingPeriodFrom => _buyingPeriodMonth == 0
      ? DateTime(_buyingPeriodYear, 1, 1)
      : DateTime(_buyingPeriodYear, _buyingPeriodMonth, 1);
  DateTime get buyingPeriodTo => _buyingPeriodMonth == 0
      ? DateTime(_buyingPeriodYear, 12, 31)
      : DateTime(_buyingPeriodYear, _buyingPeriodMonth + 1, 0);

  Future<void>? _orderSummaryJob;
  bool _isOrderSummaryLoading = false;
  bool get isOrderSummaryLoading => _isOrderSummaryLoading;
  String? _orderSummaryError;
  String? get orderSummaryError => _orderSummaryError;
  SummarySyncStatus _summarySyncStatus = SummarySyncStatus.idle;
  SummarySyncStatus get summarySyncStatus => _summarySyncStatus;
  int _summaryProcessedRows = 0;
  int get summaryProcessedRows => _summaryProcessedRows;
  String get summarySyncSubtitle => switch (_summarySyncStatus) {
    SummarySyncStatus.syncing =>
      'Syncing all ERP data: $_summaryProcessedRows processed',
    SummarySyncStatus.completed => 'Synced from all ERP data',
    SummarySyncStatus.error => 'Showing last complete sync',
    SummarySyncStatus.idle => 'Waiting for full ERP sync',
  };
  bool get hasFullOrderSummary =>
      _salesOrderSummary.documentCount > 0 ||
      _dashboardSummary.purchasePendingCount > 0;

  bool _isDeliveryNotesLoading = false;
  bool get isDeliveryNotesLoading => _isDeliveryNotesLoading;
  bool _isMoreDeliveryNotesLoading = false;
  bool get isMoreDeliveryNotesLoading => _isMoreDeliveryNotesLoading;
  bool _hasMoreDeliveryNotes = true;
  bool get hasMoreDeliveryNotes => _hasMoreDeliveryNotes;
  String? _deliveryNotesError;
  String? get deliveryNotesError => _deliveryNotesError;
  String _deliveryNoteSearch = '';
  String? _deliveryNoteStatus;
  int _deliveryNoteQueryVersion = 0;

  bool _isSalesInvoicesLoading = false;
  bool get isSalesInvoicesLoading => _isSalesInvoicesLoading;
  bool _isMoreSalesInvoicesLoading = false;
  bool get isMoreSalesInvoicesLoading => _isMoreSalesInvoicesLoading;
  bool _hasMoreSalesInvoices = true;
  bool get hasMoreSalesInvoices => _hasMoreSalesInvoices;
  String? _salesInvoicesError;
  String? get salesInvoicesError => _salesInvoicesError;
  String _salesInvoiceSearch = '';
  String? _salesInvoiceStatus;
  int _salesInvoiceQueryVersion = 0;

  bool _isPurchaseReceiptsLoading = false;
  bool get isPurchaseReceiptsLoading => _isPurchaseReceiptsLoading;
  bool _isMorePurchaseReceiptsLoading = false;
  bool get isMorePurchaseReceiptsLoading => _isMorePurchaseReceiptsLoading;
  bool _hasMorePurchaseReceipts = true;
  bool get hasMorePurchaseReceipts => _hasMorePurchaseReceipts;
  String? _purchaseReceiptsError;
  String? get purchaseReceiptsError => _purchaseReceiptsError;
  String _purchaseReceiptSearch = '';
  String? _purchaseReceiptStatus;
  int _purchaseReceiptQueryVersion = 0;

  bool _isPurchaseInvoicesLoading = false;
  bool get isPurchaseInvoicesLoading => _isPurchaseInvoicesLoading;
  bool _isMorePurchaseInvoicesLoading = false;
  bool get isMorePurchaseInvoicesLoading => _isMorePurchaseInvoicesLoading;
  bool _hasMorePurchaseInvoices = true;
  bool get hasMorePurchaseInvoices => _hasMorePurchaseInvoices;
  String? _purchaseInvoicesError;
  String? get purchaseInvoicesError => _purchaseInvoicesError;
  String _purchaseInvoiceSearch = '';
  String? _purchaseInvoiceStatus;
  int _purchaseInvoiceQueryVersion = 0;

  bool _isStockEntriesLoading = false;
  bool get isStockEntriesLoading => _isStockEntriesLoading;
  String? _stockEntriesError;
  String? get stockEntriesError => _stockEntriesError;

  bool _isInventoryLoading = false;
  bool get isInventoryLoading => _isInventoryLoading;

  String? _inventoryError;
  String? get inventoryError => _inventoryError;

  static const int _frappePageSize = 500;
  static const int _defaultFetchRowLimit = 500;
  static const int _documentPageSize = 50;
  static const String _prefsFrappeConfigKey = 'frappe_config';
  static const String _prefsSummaryCacheKey = 'erp_summary_cache';

  final ErpServices services;
  final SalesVisitLocationService _visitLocationService =
      SalesVisitLocationService();
  SalesVisit? _activeSalesVisit;
  SalesVisit? get activeSalesVisit => _activeSalesVisit;
  VisitLocationPoint? _latestVisitLocation;
  VisitLocationPoint? get latestVisitLocation => _latestVisitLocation;
  String? _activeDeliveryTrackingNote;
  String? get activeDeliveryTrackingNote => _activeDeliveryTrackingNote;
  String? _latestDeliveryTrackingNote;
  String? get latestDeliveryTrackingNote => _latestDeliveryTrackingNote;
  VisitLocationPoint? _latestDeliveryDriverLocation;
  VisitLocationPoint? get latestDeliveryDriverLocation =>
      _latestDeliveryDriverLocation;
  bool get isDeliveryDriverTrackingActive =>
      _activeDeliveryTrackingNote?.isNotEmpty == true;

  FrappeService get _frappeService => services.frappe;
  AuthService get _authService => services.auth;
  CustomerService get _customerService => services.customer;
  SalesOrderService get _salesOrderService => services.salesOrder;
  PurchaseOrderService get _purchaseOrderService => services.purchaseOrder;
  SalesInvoiceService get _salesInvoiceService => services.salesInvoice;
  PurchaseInvoiceService get _purchaseInvoiceService =>
      services.purchaseInvoice;

  FrappeService get frappeService => _frappeService;

  Future<Map<String, dynamic>> fetchCurrentUserProfile() {
    final user = _currentUser?.trim() ?? '';
    if (user.isEmpty) throw Exception('User login tidak tersedia.');
    return _authService.fetchCurrentUserProfile(user);
  }

  Future<String> uploadCurrentUserImage(String filePath) {
    final user = _currentUser?.trim() ?? '';
    if (user.isEmpty) throw Exception('User login tidak tersedia.');
    return _authService.uploadCurrentUserImage(user, filePath);
  }

  Future<void> changeCurrentUserPassword({
    required String oldPassword,
    required String newPassword,
    bool logoutAllSessions = false,
  }) {
    return _authService.changeCurrentUserPassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
      logoutAllSessions: logoutAllSessions,
    );
  }

  Future<void> _restoreFrappeConfig() async {
    final cfg = await _loadFrappeConfig();
    if (cfg == null) return;

    _frappeService.baseUrl = AppConfig.normalizedFrappeBaseUrl;
    if (cfg['username'] != null) {
      _frappeService.username = cfg['username'];
    }
    if (cfg['password'] != null) {
      _frappeService.password = cfg['password'];
    }
  }

  AppState({ErpServices? services}) : services = services ?? ErpServices() {
    () async {
      await _restoreFrappeConfig();
      await _restoreSummaryCache();
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
      _frappeService.baseUrl = AppConfig.normalizedFrappeBaseUrl;
      _userRole = 'Unassigned';
      await _frappeService.login(cfg['username']!, password);
      _isAuthenticated = true;
      _currentUser = cfg['username'];
      await syncCurrentUserRoleFromFrappe();
      _startNotificationPolling();
      await prefetchInitialData();
      notifyListeners();
      return true;
    } catch (_) {
      await clearSessionConfig();
      _isAuthenticated = false;
      _currentUser = null;
      _userRole = 'Unassigned';
      notifyListeners();
      return false;
    }
  }

  Future<void> prefetchInitialData() async {
    try {
      await fetchWarehousesFromFrappe();
      await fetchInventoryFromFrappe(
        filters: _shouldScopeSalesData
            ? const [
                ['warehouse', '=', 'Stores - Jakarta'],
              ]
            : null,
      );
      if (_shouldScopeSalesData) {
        await Future.wait([
          fetchSalesOrdersFromFrappe(),
          fetchSalesInvoicesFromFrappe(),
        ]);
        await refreshNotifications(silent: true);
        return;
      }
      await Future.wait([
        fetchSalesOrdersFromFrappe(),
        fetchPurchaseOrdersFromFrappe(),
        fetchSalesInvoicesFromFrappe(),
        fetchPurchaseInvoicesFromFrappe(),
      ]);
      await fetchDeliveryNotesFromFrappe();
      await fetchPurchaseReceiptsFromFrappe();
      await refreshNotifications(silent: true);
      unawaited(refreshAllSummaries(silent: true));
    } catch (_) {
      // Prefetch failures should not block login.
    }
    notifyListeners();
  }

  Future<void> _restoreSummaryCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_prefsSummaryCacheKey);
      if (raw == null) return;
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      DocumentSummary documentSummary(String key) {
        final value = json[key];
        return value is Map
            ? DocumentSummary.fromJson(Map<String, dynamic>.from(value))
            : const DocumentSummary();
      }

      _salesOrderSummary = DocumentSummary.fromJson(
        Map<String, dynamic>.from(json['salesOrder'] as Map),
      );
      _deliveryNoteSummary = DocumentSummary.fromJson(
        Map<String, dynamic>.from(json['deliveryNote'] as Map),
      );
      _salesInvoiceSummary = DocumentSummary.fromJson(
        Map<String, dynamic>.from(json['salesInvoice'] as Map),
      );
      _purchaseOrderSummary = documentSummary('purchaseOrder');
      _purchaseReceiptSummary = documentSummary('purchaseReceipt');
      _purchaseInvoiceSummary = documentSummary('purchaseInvoice');
      _dashboardSummary = DashboardSummary.fromJson(
        Map<String, dynamic>.from(json['dashboard'] as Map),
      );
    } catch (_) {}
  }

  Future<void> _saveSummaryCache() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _prefsSummaryCacheKey,
      jsonEncode({
        'salesOrder': _salesOrderSummary.toJson(),
        'deliveryNote': _deliveryNoteSummary.toJson(),
        'salesInvoice': _salesInvoiceSummary.toJson(),
        'purchaseOrder': _purchaseOrderSummary.toJson(),
        'purchaseReceipt': _purchaseReceiptSummary.toJson(),
        'purchaseInvoice': _purchaseInvoiceSummary.toJson(),
        'dashboard': _dashboardSummary.toJson(),
      }),
    );
  }

  Future<void> clearSessionConfig() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_prefsFrappeConfigKey);
      await sp.remove(_prefsUserRoleKey);
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
    String? baseUrl,
  }) async {
    try {
      _lastAuthError = null;
      _frappeService.baseUrl = baseUrl ?? AppConfig.normalizedFrappeBaseUrl;
      _userRole = 'Unassigned';
      await _frappeService.login(username, password);
      _isAuthenticated = true;
      _currentUser = username;
      await syncCurrentUserRoleFromFrappe();
      await refreshNotifications();
      _startNotificationPolling();
      notifyListeners();
      return true;
    } catch (e, st) {
      _lastAuthError = e.toString();
      if (!kReleaseMode) {
        developer.log('Login failed', error: e, stackTrace: st);
      }
      _isAuthenticated = false;
      _currentUser = null;
      _userRole = 'Unassigned';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _stopNotificationPolling();
    await _visitLocationService.stopTracking();
    _activeSalesVisit = null;
    _latestVisitLocation = null;
    _notifications = [];
    _salesOrderApprovalTodoCount = 0;
    _isAuthenticated = false;
    _currentUser = null;
    _userRole = 'Unassigned';
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
    unawaited(_visitLocationService.stopTracking());
    super.dispose();
  }

  Future<SalesOrder> loadSalesOrderDetail(String orderId) async {
    return _salesOrderService.load(orderId);
  }

  List<List<dynamic>> get _salesOwnerFilter => _shouldScopeSalesData
      ? [
          ['owner', '=', _currentUser ?? '__unmapped_sales_user__'],
        ]
      : const [];

  Future<List<SalesCustomerOption>> fetchSalesCustomers() async {
    if (_shouldScopeSalesData &&
        (_currentSalesPerson == null || _currentSalesPerson!.isEmpty)) {
      await resolveCurrentSalesIdentity();
    }
    if (_shouldScopeSalesData &&
        (_currentSalesPerson == null || _currentSalesPerson!.isEmpty)) {
      throw Exception(
        _salesIdentityError ?? 'Sales Person user login belum tersedia.',
      );
    }
    return _customerService.fetchSalesCustomers(
      salesPerson: _shouldScopeSalesData ? _currentSalesPerson : null,
    );
  }

  Future<List<SalesInvoice>> fetchCollectionOutstandingInvoices() async {
    Set<String>? permittedCustomers;
    if (_shouldScopeSalesData) {
      final customers = await fetchSalesCustomers();
      permittedCustomers = customers.map((customer) => customer.id).toSet();
      if (permittedCustomers.isEmpty) return const [];
    }
    final rows = await _fetchAllResourcePages(
      doctype: 'Sales Invoice',
      fields: const [
        'name',
        'owner',
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
        ['docstatus', '=', 1],
        ['outstanding_amount', '>', 0],
      ],
      orderBy: 'due_date asc, name asc',
      maxRows: null,
    );
    return rows
        .where(
          (row) =>
              permittedCustomers == null ||
              permittedCustomers.contains(row['customer']?.toString() ?? ''),
        )
        .map(SalesInvoice.fromJson)
        .toList();
  }

  Future<List<CollectionRanking>> fetchCollectionRanking({
    DateTime? from,
    DateTime? to,
  }) async {
    final totals = <String, double>{};
    final salesPersons = await _fetchAllResourcePages(
      doctype: 'Sales Person',
      fields: const ['name', 'enabled', 'is_group'],
      filters: const [
        ['is_group', '=', 0],
      ],
      orderBy: 'name asc',
      maxRows: null,
    );
    for (final row in salesPersons) {
      final name = row['name']?.toString() ?? '';
      final enabled = row['enabled'];
      if (name.isEmpty || enabled == 0 || enabled == false) continue;
      totals[name] = 0;
    }

    final orderRows = await _fetchAllResourcePages(
      doctype: 'Sales Order',
      fields: const ['name', 'grand_total', 'net_total', 'transaction_date'],
      filters: [
        ['docstatus', '!=', 2],
        if (from != null)
          ['transaction_date', '>=', DateRangePresets.toFrappeDate(from)],
        if (to != null)
          ['transaction_date', '<=', DateRangePresets.toFrappeDate(to)],
      ],
      orderBy: 'transaction_date desc, name desc',
      maxRows: null,
    );
    if (orderRows.isEmpty) return _collectionRankingRows(totals);

    final orderAmounts = <String, double>{};
    for (final order in orderRows) {
      final id = order['name']?.toString() ?? '';
      if (id.isEmpty) continue;
      final amount = NumParse.asDouble(
        order['grand_total'] ?? order['net_total'],
      );
      orderAmounts[id] = amount.clamp(0, double.infinity);
    }
    if (orderAmounts.isEmpty) return _collectionRankingRows(totals);

    final orderDocuments = await _fetchDocumentsInBatches(
      'Sales Order',
      orderAmounts.keys,
    );
    for (final order in orderAmounts.entries) {
      final document = orderDocuments[order.key];
      if (document == null) continue;
      for (final team in _documentChildRows(document['sales_team'])) {
        final salesPerson = team['sales_person']?.toString() ?? '';
        if (salesPerson.isEmpty) continue;
        final percentage = NumParse.asDouble(team['allocated_percentage']);
        final ratio = percentage > 0 ? percentage / 100 : 1.0;
        totals[salesPerson] =
            (totals[salesPerson] ?? 0) +
            order.value.clamp(0, double.infinity) * ratio;
      }
    }

    return _collectionRankingRows(totals);
  }

  static List<CollectionRanking> _collectionRankingRows(
    Map<String, double> totals,
  ) {
    final sorted = totals.entries.toList()
      ..sort((a, b) {
        final valueComparison = b.value.compareTo(a.value);
        return valueComparison != 0 ? valueComparison : a.key.compareTo(b.key);
      });
    return [
      for (var index = 0; index < sorted.length; index++)
        CollectionRanking(
          salesPerson: sorted[index].key,
          amount: sorted[index].value,
          rank: index + 1,
        ),
    ];
  }

  Future<List<CollectionPayment>> fetchCollectionPayments({
    DateTime? from,
    DateTime? to,
    bool scopeToCurrentSales = true,
  }) async {
    Set<String>? permittedCustomers;
    if (_shouldScopeSalesData && scopeToCurrentSales) {
      final customers = await fetchSalesCustomers();
      permittedCustomers = customers.map((customer) => customer.id).toSet();
      if (permittedCustomers.isEmpty) return const [];
    }

    final rows = await _fetchAllResourcePages(
      doctype: 'Payment Entry',
      fields: const [
        'name',
        'party',
        'party_name',
        'posting_date',
        'paid_amount',
        'received_amount',
        'reference_no',
        'remarks',
      ],
      filters: [
        ['docstatus', '=', 1],
        ['payment_type', '=', 'Receive'],
        ['party_type', '=', 'Customer'],
        if (from != null)
          ['posting_date', '>=', DateRangePresets.toFrappeDate(from)],
        if (to != null)
          ['posting_date', '<=', DateRangePresets.toFrappeDate(to)],
      ],
      orderBy: 'posting_date desc, name desc',
      maxRows: null,
    );
    final payments = rows
        .where(
          (row) =>
              permittedCustomers == null ||
              permittedCustomers.contains(row['party']?.toString() ?? ''),
        )
        .map(CollectionPayment.fromJson)
        .where((payment) => payment.id.isNotEmpty)
        .toList();
    if (payments.isEmpty) return payments;

    final documents = await _fetchDocumentsInBatches(
      'Payment Entry',
      payments.map((payment) => payment.id),
    );
    return payments.map((payment) {
      final document = documents[payment.id];
      if (document != null) {
        final references = _documentChildRows(
          document['references'],
        ).map(CollectionPaymentReference.fromJson).toList();
        return payment.copyWithReferences(references);
      }
      return payment;
    }).toList();
  }

  Future<List<SalesVisit>> fetchSalesVisits() async {
    final rows = await _fetchAllResourcePages(
      doctype: 'Sales Visit',
      fields: const [
        'name',
        'customer',
        'check_in_time',
        'check_out_time',
        'status',
        'notes',
        'sales_person',
        'journey_start_time',
        'address',
        'target_latitude',
        'target_longitude',
        'check_in_latitude',
        'check_in_longitude',
        'check_out_latitude',
        'check_out_longitude',
        'check_in_distance',
      ],
      filters: _shouldScopeSalesData
          ? [
              ['owner', '=', _currentUser ?? '__unmapped_sales_user__'],
            ]
          : null,
      orderBy: 'check_in_time desc, name desc',
      maxRows: 300,
    );
    final visits = rows.map(SalesVisit.fromJson).toList();
    if (_shouldScopeSalesData) {
      _activeSalesVisit = null;
      for (final visit in visits) {
        final status = visit.status.toLowerCase();
        if (status == 'traveling' || status == 'checked in') {
          _activeSalesVisit = visit;
          if (status == 'traveling') {
            await _resumeSalesVisitTracking(visit);
          }
          break;
        }
      }
    }
    return visits;
  }

  Future<List<SalesTrackingPoint>> fetchLatestSalesTrackingPoints() async {
    final rows = await _fetchAllResourcePages(
      doctype: 'Sales Tracking Point',
      fields: const [
        'name',
        'sales_visit',
        'sales_person',
        'customer',
        'captured_at',
        'latitude',
        'longitude',
        'accuracy',
      ],
      orderBy: 'captured_at desc, name desc',
      maxRows: 200,
    );
    final latest = <String, SalesTrackingPoint>{};
    for (final row in rows) {
      final point = SalesTrackingPoint.fromJson(row);
      final key = point.salesPerson.isNotEmpty
          ? point.salesPerson
          : point.salesVisit;
      if (key.isNotEmpty) latest.putIfAbsent(key, () => point);
    }
    return latest.values.toList();
  }

  Future<CustomerVisitLocation> fetchCustomerVisitLocation(String customer) {
    return _customerService.fetchVisitLocation(customer);
  }

  Future<VisitLocationPoint> getCurrentVisitLocation() async {
    final point = await _visitLocationService.currentPosition();
    _latestVisitLocation = point;
    notifyListeners();
    return point;
  }

  double visitDistanceTo(
    CustomerVisitLocation target,
    VisitLocationPoint from,
  ) {
    return _visitLocationService.distanceMeters(
      fromLatitude: from.latitude,
      fromLongitude: from.longitude,
      toLatitude: target.latitude,
      toLongitude: target.longitude,
    );
  }

  Future<SalesVisit> startSalesVisitJourney({
    required String customer,
    required CustomerVisitLocation target,
  }) async {
    if (_activeSalesVisit != null) {
      throw Exception('Selesaikan perjalanan aktif sebelum memulai yang baru.');
    }
    final point = await getCurrentVisitLocation();
    final created = await _frappeService.createDocument('Sales Visit', {
      'customer': customer,
      'address': target.addressId,
      if (_currentSalesPerson?.isNotEmpty == true)
        'sales_person': _currentSalesPerson,
      'status': 'Traveling',
      'journey_start_time': DateTime.now().toIso8601String(),
      'target_latitude': target.latitude,
      'target_longitude': target.longitude,
    });
    final visit = SalesVisit.fromJson(created);
    _activeSalesVisit = visit;
    await _saveTrackingPoint(visit, point);
    await _resumeSalesVisitTracking(visit);
    notifyListeners();
    return visit;
  }

  Future<void> _resumeSalesVisitTracking(SalesVisit visit) async {
    final startedAt = DateTime.tryParse(visit.journeyStartTime);
    if (startedAt != null &&
        DateTime.now().difference(startedAt) >= const Duration(hours: 4)) {
      await cancelSalesVisitJourney(visit.id);
      return;
    }
    await _visitLocationService.startTracking((next) async {
      final journeyStart = DateTime.tryParse(visit.journeyStartTime);
      if (journeyStart != null &&
          DateTime.now().difference(journeyStart) >= const Duration(hours: 4)) {
        await cancelSalesVisitJourney(visit.id);
        return;
      }
      _latestVisitLocation = next;
      notifyListeners();
      await _saveTrackingPoint(visit, next);
      await _flushTrackingQueue(visit);
    });
  }

  Future<SalesVisit> checkInSalesVisit({
    required SalesVisit visit,
    required CustomerVisitLocation target,
    required String photoPath,
    String? notes,
    List<Map<String, dynamic>> competitors = const [],
    List<Map<String, dynamic>> potentialOrders = const [],
  }) async {
    final point = await getCurrentVisitLocation();
    final distance = visitDistanceTo(target, point);
    if (point.accuracy > 50) {
      throw Exception(
        'Akurasi GPS ${point.accuracy.toStringAsFixed(0)} meter terlalu rendah.',
      );
    }
    if (distance > target.geofenceRadius) {
      throw Exception(
        'Anda masih ${distance.toStringAsFixed(0)} meter dari customer. '
        'Check-in maksimal ${target.geofenceRadius.toStringAsFixed(0)} meter.',
      );
    }
    await uploadAttachment(
      doctype: 'Sales Visit',
      documentName: visit.id,
      filePath: photoPath,
    );
    await _frappeService.updateDocument('Sales Visit', visit.id, {
      'status': 'Checked In',
      'check_in_time': DateTime.now().toIso8601String(),
      'check_in_latitude': point.latitude,
      'check_in_longitude': point.longitude,
      'check_in_distance': distance,
      if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
      if (competitors.isNotEmpty) 'competitors': competitors,
      if (potentialOrders.isNotEmpty) 'potential_orders': potentialOrders,
    });
    await _visitLocationService.stopTracking();
    await _flushTrackingQueue(visit);
    final updated = SalesVisit.fromJson(
      await _frappeService.fetchDocument('Sales Visit', visit.id),
    );
    _activeSalesVisit = updated;
    notifyListeners();
    return updated;
  }

  Future<void> checkOutSalesVisit(String visitId) async {
    final point = await getCurrentVisitLocation();
    await _frappeService.updateDocument('Sales Visit', visitId, {
      'check_out_time': DateTime.now().toIso8601String(),
      'status': 'Checked Out',
      'check_out_latitude': point.latitude,
      'check_out_longitude': point.longitude,
    });
    await _visitLocationService.stopTracking();
    _activeSalesVisit = null;
    notifyListeners();
  }

  Future<void> cancelSalesVisitJourney(String visitId) async {
    await _frappeService.updateDocument('Sales Visit', visitId, {
      'status': 'Cancelled',
    });
    await _visitLocationService.stopTracking();
    _activeSalesVisit = null;
    notifyListeners();
  }

  Future<void> _saveTrackingPoint(
    SalesVisit visit,
    VisitLocationPoint point,
  ) async {
    await _frappeService.createDocument('Sales Tracking Point', {
      'sales_visit': visit.id,
      if (_currentSalesPerson?.isNotEmpty == true)
        'sales_person': _currentSalesPerson,
      'customer': visit.customer,
      'captured_at': point.capturedAt.toIso8601String(),
      'latitude': point.latitude,
      'longitude': point.longitude,
      'accuracy': point.accuracy,
    });
  }

  Future<void> _flushTrackingQueue(SalesVisit visit) async {
    final queued = await _visitLocationService.queuedPoints();
    if (queued.isEmpty) return;
    for (final point in queued) {
      try {
        await _saveTrackingPoint(visit, point);
      } catch (_) {
        return;
      }
    }
    await _visitLocationService.clearQueue();
  }

  Future<CustomerSalesInsight> fetchCustomerSalesInsight(
    String customer, {
    String? company,
  }) => _customerService.fetchSalesInsight(customer, company: company);

  Future<ItemSalesInsight> fetchItemSalesInsight(
    String itemCode, {
    String? customer,
    String? company,
    String? priceList,
    String? currency,
    String? warehouse,
    DateTime? transactionDate,
    double qty = 1,
    bool ignorePricingRule = false,
  }) async {
    await _frappeService.ensureLoggedIn();
    Map<String, dynamic> pricing = const {};
    if (customer != null &&
        customer.isNotEmpty &&
        company != null &&
        company.isNotEmpty) {
      try {
        pricing = await _frappeService.fetchSalesItemPricing(
          itemCode: itemCode,
          customer: customer,
          company: company,
          transactionDate: (transactionDate ?? DateTime.now())
              .toIso8601String()
              .split('T')
              .first,
          qty: qty,
          warehouse: warehouse,
          priceList: priceList,
          currency: currency,
          ignorePricingRule: ignorePricingRule,
        );
      } catch (_) {}
    }
    final priceFilters = <List<dynamic>>[
      ['item_code', '=', itemCode],
      ['selling', '=', 1],
      if (priceList != null && priceList.isNotEmpty)
        ['price_list', '=', priceList],
    ];
    List<Map<String, dynamic>> prices;
    try {
      prices = await _fetchResourceWithFieldFallback(
        doctype: 'Item Price',
        fields: const ['name', 'price_list', 'price_list_rate', 'currency'],
        limit: 1,
        orderBy: 'valid_from desc, modified desc',
        filters: priceFilters,
      );
    } catch (_) {
      prices = await _fetchResourceWithFieldFallback(
        doctype: 'Item Price',
        fields: const ['name', 'price_list', 'price_list_rate', 'currency'],
        limit: 1,
        orderBy: 'modified desc',
        filters: [
          ['item_code', '=', itemCode],
          if (priceList != null && priceList.isNotEmpty)
            ['price_list', '=', priceList],
        ],
      );
    }
    final price = prices.isEmpty ? const <String, dynamic>{} : prices.first;
    final resolvedPriceListRate = NumParse.asDouble(
      pricing['price_list_rate'] ?? price['price_list_rate'],
    );
    final resolvedRate = NumParse.asDouble(
      pricing['rate'] ?? pricing['net_rate'] ?? resolvedPriceListRate,
    );

    final bins = await _fetchAllResourcePages(
      doctype: 'Bin',
      fields: const [
        'name',
        'warehouse',
        'actual_qty',
        'reserved_qty',
        'projected_qty',
      ],
      filters: [
        ['item_code', '=', itemCode],
        if (warehouse != null && warehouse.isNotEmpty)
          ['warehouse', '=', warehouse],
      ],
      maxRows: null,
    );
    final stocks =
        bins
            .map(
              (row) => WarehouseStockInsight(
                warehouse: row['warehouse']?.toString() ?? '',
                actualQty: NumParse.asDouble(row['actual_qty']),
                reservedQty: NumParse.asDouble(row['reserved_qty']),
                projectedQty: NumParse.asDouble(row['projected_qty']),
              ),
            )
            .where((row) => row.warehouse.isNotEmpty)
            .toList()
          ..sort((a, b) => a.warehouse.compareTo(b.warehouse));

    return ItemSalesInsight(
      itemCode: itemCode,
      priceList:
          pricing['price_list']?.toString() ??
          price['price_list']?.toString() ??
          priceList ??
          '',
      priceListRate: resolvedPriceListRate,
      price: resolvedRate,
      currency:
          pricing['price_list_currency']?.toString() ??
          pricing['currency']?.toString() ??
          price['currency']?.toString() ??
          currency ??
          '',
      discountPercentage: NumParse.asDouble(pricing['discount_percentage']),
      pricingRule: pricing['pricing_rule']?.toString() ?? '',
      stocks: stocks,
    );
  }

  Future<List<CustomerPurchaseHistory>> fetchCustomerPurchaseHistory({
    required String customer,
    required String doctype,
    String? company,
    int offset = 0,
    int limit = 20,
  }) => _customerService.fetchPurchaseHistory(
    customer: customer,
    doctype: doctype,
    company: company,
    offset: offset,
    limit: limit,
  );

  Future<Map<String, dynamic>> loadSalesHistoryDetail(
    String doctype,
    String name,
  ) {
    return _frappeService.fetchDocument(doctype, name);
  }

  Future<void> uploadSalesOrderAttachment(String orderId, String filePath) {
    return _salesOrderService.uploadAttachment(orderId, filePath);
  }

  Future<void> uploadAttachment({
    required String doctype,
    required String documentName,
    required String filePath,
  }) {
    return _frappeService
        .uploadFile(
          filePath: filePath,
          doctype: doctype,
          documentName: documentName,
        )
        .then((_) {});
  }

  Future<void> uploadDeliveryNoteProof({
    required String deliveryNoteId,
    required String filePath,
  }) {
    return uploadAttachment(
      doctype: 'Delivery Note',
      documentName: deliveryNoteId,
      filePath: filePath,
    );
  }

  Future<VisitLocationPoint> recordDeliveryDriverLocation(
    DeliveryNote deliveryNote,
  ) async {
    final point = await _visitLocationService.currentPosition();
    await _saveDeliveryTrackingPoint(deliveryNote, point);
    _latestDeliveryTrackingNote = deliveryNote.id;
    _latestDeliveryDriverLocation = point;
    notifyListeners();
    return point;
  }

  Future<VisitLocationPoint> startDeliveryDriverTracking(
    DeliveryNote deliveryNote,
  ) async {
    if (_activeSalesVisit != null) {
      throw Exception(
        'Selesaikan tracking sales visit sebelum tracking driver.',
      );
    }
    if (_activeDeliveryTrackingNote != null &&
        _activeDeliveryTrackingNote != deliveryNote.id) {
      throw Exception(
        'Selesaikan tracking ${_activeDeliveryTrackingNote!} sebelum memulai yang baru.',
      );
    }

    final firstPoint = await recordDeliveryDriverLocation(deliveryNote);
    _activeDeliveryTrackingNote = deliveryNote.id;
    notifyListeners();
    await _visitLocationService.startTracking(
      (point) async {
        _latestDeliveryTrackingNote = deliveryNote.id;
        _latestDeliveryDriverLocation = point;
        notifyListeners();
        await _saveDeliveryTrackingPoint(deliveryNote, point);
      },
      notificationTitle: 'Tracking driver aktif',
      notificationText: 'TMSX mencatat lokasi driver tiap 5 menit.',
      queueFailedPoints: false,
    );
    return firstPoint;
  }

  Future<void> stopDeliveryDriverTracking() async {
    await _visitLocationService.stopTracking();
    _activeDeliveryTrackingNote = null;
    notifyListeners();
  }

  Future<void> _saveDeliveryTrackingPoint(
    DeliveryNote deliveryNote,
    VisitLocationPoint point,
  ) async {
    await _frappeService.createDocument('Delivery Tracking Point', {
      'delivery_note': deliveryNote.id,
      'customer': deliveryNote.customer,
      if (_currentUser?.isNotEmpty == true) 'driver': _currentUser,
      'captured_at': point.capturedAt.toIso8601String(),
      'latitude': point.latitude,
      'longitude': point.longitude,
      'accuracy': point.accuracy,
    });
  }

  Future<List<Map<String, dynamic>>> fetchDocumentAttachments({
    required String doctype,
    required String documentName,
  }) async {
    return _frappeService.fetchResource(
      'File',
      fields: const ['name', 'file_name', 'file_url', 'creation'],
      filters: [
        ['attached_to_doctype', '=', doctype],
        ['attached_to_name', '=', documentName],
      ],
      orderBy: 'creation desc',
      limit: 50,
    );
  }

  Future<SalesOrder> createSalesOrder({
    required String customer,
    String? itemCode,
    double? qty,
    List<Map<String, dynamic>>? items,
    String? warehouse,
    double? rate,
    String? series,
    String? costCenter,
    String? company,
    String? currency,
    String? sellingPriceList,
    String? priceListCurrency,
    bool ignorePricingRule = false,
    String? salesPerson,
    List<Map<String, dynamic>>? salesTeam,
    DateTime? transactionDate,
    DateTime? deliveryDate,
  }) async {
    await _frappeService.ensureLoggedIn();
    final orderItems =
        items ??
        [
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
        ];
    if (orderItems.isEmpty ||
        orderItems.any(
          (item) =>
              item['item_code']?.toString().trim().isEmpty != false ||
              NumParse.asDouble(item['qty']) <= 0,
        )) {
      throw Exception(
        'Sales Order wajib memiliki minimal satu item yang valid.',
      );
    }

    final payload = <String, dynamic>{
      'customer': customer,
      if (company != null && company.trim().isNotEmpty)
        'company': company.trim(),
      if (currency != null && currency.trim().isNotEmpty)
        'currency': currency.trim(),
      if (sellingPriceList != null && sellingPriceList.trim().isNotEmpty)
        'selling_price_list': sellingPriceList.trim(),
      if (priceListCurrency != null && priceListCurrency.trim().isNotEmpty)
        'price_list_currency': priceListCurrency.trim(),
      'ignore_pricing_rule': ignorePricingRule ? 1 : 0,
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
      if (salesTeam?.isNotEmpty == true)
        'sales_team': salesTeam
      else if (salesPerson?.trim().isNotEmpty == true)
        'sales_team': [
          {'sales_person': salesPerson!.trim(), 'allocated_percentage': 100},
        ],
      'items': orderItems,
      if (warehouse != null && warehouse.trim().isNotEmpty)
        'set_warehouse': warehouse.trim(),
    };

    final order = await _salesOrderService.create(payload);
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
    List<Map<String, dynamic>>? items,
    String? warehouse,
    double? rate,
    String? costCenter,
    String? company,
    String? currency,
    String? sellingPriceList,
    String? priceListCurrency,
    bool? ignorePricingRule,
    String? salesPerson,
    List<Map<String, dynamic>>? salesTeam,
    DateTime? transactionDate,
    DateTime? deliveryDate,
    String? status,
  }) async {
    await _frappeService.ensureLoggedIn();
    if (items != null &&
        (items.isEmpty ||
            items.any(
              (item) =>
                  item['item_code']?.toString().trim().isEmpty != false ||
                  NumParse.asDouble(item['qty']) <= 0,
            ))) {
      throw Exception(
        'Sales Order wajib memiliki minimal satu item yang valid.',
      );
    }

    final updates = <String, dynamic>{
      if (customer != null && customer.trim().isNotEmpty) 'customer': customer,
      if (company != null && company.trim().isNotEmpty)
        'company': company.trim(),
      if (currency != null && currency.trim().isNotEmpty)
        'currency': currency.trim(),
      if (sellingPriceList != null && sellingPriceList.trim().isNotEmpty)
        'selling_price_list': sellingPriceList.trim(),
      if (priceListCurrency != null && priceListCurrency.trim().isNotEmpty)
        'price_list_currency': priceListCurrency.trim(),
      if (ignorePricingRule != null)
        'ignore_pricing_rule': ignorePricingRule ? 1 : 0,
      if (transactionDate != null)
        'transaction_date': transactionDate.toIso8601String().split('T').first,
      if (deliveryDate != null)
        'delivery_date': deliveryDate.toIso8601String().split('T').first,
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (costCenter != null && costCenter.trim().isNotEmpty)
        'cost_center': costCenter.trim(),
      if (salesTeam?.isNotEmpty == true)
        'sales_team': salesTeam
      else if (salesPerson != null && salesPerson.trim().isNotEmpty)
        'sales_team': [
          {'sales_person': salesPerson.trim(), 'allocated_percentage': 100},
        ],
      if (warehouse != null && warehouse.trim().isNotEmpty)
        'set_warehouse': warehouse.trim(),
      if (items != null)
        'items': items
      else if (itemCode != null && itemCode.trim().isNotEmpty && qty != null)
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

    final updatedOrder = await _salesOrderService.update(orderId, updates);
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
    await _salesOrderService.delete(orderId);
    _salesOrders.removeWhere((o) => o.id == orderId);
    notifyListeners();
    await refreshSalesOrders();
    unawaited(refreshOrderSummaries(silent: true));
  }

  Future<PurchaseOrder> loadPurchaseOrderDetail(String orderId) async {
    return _purchaseOrderService.load(orderId);
  }

  Future<DeliveryNote> loadDeliveryNoteDetail(String id) async {
    await _frappeService.ensureLoggedIn();
    final doc = await _frappeService.fetchDocument('Delivery Note', id);
    return DeliveryNote.fromJson(doc);
  }

  Future<SalesInvoice> loadSalesInvoiceDetail(String id) async {
    return _salesInvoiceService.load(id);
  }

  Future<PurchaseReceipt> loadPurchaseReceiptDetail(String id) async {
    await _frappeService.ensureLoggedIn();
    final doc = await _frappeService.fetchDocument('Purchase Receipt', id);
    return PurchaseReceipt.fromJson(doc);
  }

  Future<PurchaseInvoice> loadPurchaseInvoiceDetail(String id) async {
    return _purchaseInvoiceService.load(id);
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

    final invoice = await _purchaseInvoiceService.create(payload);
    await refreshPurchaseInvoices();
    unawaited(refreshAllSummaries(silent: true));
    return invoice;
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

    final order = await _purchaseOrderService.create(payload);
    _purchaseOrders = [order, ..._purchaseOrders];
    notifyListeners();
    await refreshPurchaseOrders();
    unawaited(refreshAllSummaries(silent: true));
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

    final updatedOrder = await _purchaseOrderService.update(orderId, updates);
    _purchaseOrders = _purchaseOrders
        .map((o) => o.id == orderId ? updatedOrder : o)
        .toList();
    notifyListeners();
    await refreshPurchaseOrders();
    unawaited(refreshAllSummaries(silent: true));
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
    unawaited(refreshAllSummaries(silent: true));
  }

  Future<void> deletePurchaseOrder(String orderId) async {
    await _frappeService.ensureLoggedIn();
    await _purchaseOrderService.delete(orderId);
    _purchaseOrders.removeWhere((o) => o.id == orderId);
    notifyListeners();
    await refreshPurchaseOrders();
    unawaited(refreshAllSummaries(silent: true));
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

  Future<Map<String, dynamic>> createStockReconciliation({
    required String company,
    required String warehouse,
    required List<Map<String, dynamic>> items,
    DateTime? postingDate,
  }) async {
    await _frappeService.ensureLoggedIn();
    if (company.trim().isEmpty) {
      throw Exception('Company gudang belum tersedia.');
    }
    if (warehouse.trim().isEmpty) {
      throw Exception('Warehouse wajib dipilih.');
    }
    if (items.isEmpty) {
      throw Exception('Tambahkan minimal satu item stock opname.');
    }
    return _frappeService.createDocument('Stock Reconciliation', {
      'company': company.trim(),
      'purpose': 'Stock Reconciliation',
      'posting_date': (postingDate ?? DateTime.now())
          .toIso8601String()
          .split('T')
          .first,
      'items': [
        for (final item in items) {...item, 'warehouse': warehouse.trim()},
      ],
    });
  }

  Future<void> fetchSalesOrdersFromFrappe({
    String? baseUrl,
    String? username,
    String? password,
  }) async {
    _isSalesOrdersLoading = true;
    _salesOrdersError = null;
    _hasMoreSalesOrders = true;
    _isMoreSalesOrdersLoading = false;
    final version = ++_salesOrderQueryVersion;
    notifyListeners();

    try {
      _frappeService.baseUrl = baseUrl ?? AppConfig.normalizedFrappeBaseUrl;
      if (username != null && password != null) {
        await _frappeService.login(username, password);
      } else {
        await _frappeService.ensureLoggedIn();
      }

      final orders = await _fetchSalesOrderPage(limitStart: 0);
      if (version != _salesOrderQueryVersion) return;
      _salesOrders = orders;
      _hasMoreSalesOrders = orders.isNotEmpty;
    } catch (error) {
      if (version != _salesOrderQueryVersion) return;
      _salesOrdersError = error.toString();
    } finally {
      if (version == _salesOrderQueryVersion) {
        _isSalesOrdersLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchPurchaseOrdersFromFrappe({
    String? baseUrl,
    String? username,
    String? password,
  }) async {
    _frappeService.baseUrl = baseUrl ?? AppConfig.normalizedFrappeBaseUrl;
    _isPurchaseOrdersLoading = true;
    _purchaseOrdersError = null;
    _hasMorePurchaseOrders = true;
    _isMorePurchaseOrdersLoading = false;
    final version = ++_purchaseOrderQueryVersion;
    notifyListeners();

    try {
      if (username != null && password != null) {
        await _frappeService.login(username, password);
      } else {
        await _frappeService.ensureLoggedIn();
      }

      final orders = await _fetchPurchaseOrderPage(limitStart: 0);
      if (version != _purchaseOrderQueryVersion) return;
      _purchaseOrders = orders;
      _hasMorePurchaseOrders = orders.isNotEmpty;

      _purchaseOrdersError = null;
    } catch (err) {
      if (version != _purchaseOrderQueryVersion) return;
      _purchaseOrdersError = err.toString();
    } finally {
      if (version == _purchaseOrderQueryVersion) {
        _isPurchaseOrdersLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreSalesOrders() async {
    if (_isSalesOrdersLoading ||
        _isMoreSalesOrdersLoading ||
        !_hasMoreSalesOrders) {
      return;
    }

    _isMoreSalesOrdersLoading = true;
    final version = _salesOrderQueryVersion;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final nextPage = await _fetchSalesOrderPage(
        limitStart: _salesOrders.length,
      );
      if (version != _salesOrderQueryVersion) return;
      final existingIds = _salesOrders.map((order) => order.id).toSet();
      _salesOrders = [
        ..._salesOrders,
        ...nextPage.where((order) => existingIds.add(order.id)),
      ];
      _hasMoreSalesOrders = nextPage.isNotEmpty;
      _salesOrdersError = null;
    } catch (err) {
      if (version != _salesOrderQueryVersion) return;
      _salesOrdersError = err.toString();
    } finally {
      if (version == _salesOrderQueryVersion) {
        _isMoreSalesOrdersLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMorePurchaseOrders() async {
    if (_isPurchaseOrdersLoading ||
        _isMorePurchaseOrdersLoading ||
        !_hasMorePurchaseOrders) {
      return;
    }

    _isMorePurchaseOrdersLoading = true;
    final version = _purchaseOrderQueryVersion;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final nextPage = await _fetchPurchaseOrderPage(
        limitStart: _purchaseOrders.length,
      );
      if (version != _purchaseOrderQueryVersion) return;
      final existingIds = _purchaseOrders.map((order) => order.id).toSet();
      _purchaseOrders = [
        ..._purchaseOrders,
        ...nextPage.where((order) => existingIds.add(order.id)),
      ];
      _hasMorePurchaseOrders = nextPage.isNotEmpty;
      _purchaseOrdersError = null;
    } catch (err) {
      if (version != _purchaseOrderQueryVersion) return;
      _purchaseOrdersError = err.toString();
    } finally {
      if (version == _purchaseOrderQueryVersion) {
        _isMorePurchaseOrdersLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshOrderSummaries({bool silent = false}) {
    return refreshAllSummaries(silent: silent);
  }

  Future<void> refreshSellingSummaries() async {
    _isOrderSummaryLoading = true;
    _orderSummaryError = null;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final salesTrend = _emptySellingTrendPoints();
      final deliveryTrend = _emptySellingTrendPoints();
      final invoiceTrend = _emptySellingTrendPoints();
      var salesTotal = 0.0;
      var salesDocumentCount = 0;
      await _forEachResourcePage(
        doctype: 'Sales Order',
        fields: const ['name', 'grand_total', 'transaction_date'],
        filters: _sellingPeriodFilters('transaction_date'),
        onRow: (row) {
          final value = NumParse.asDouble(row['grand_total']);
          salesTotal += value;
          salesDocumentCount++;
          _addSellingTrendPoint(
            salesTrend,
            dateRaw: row['transaction_date'],
            amount: value,
          );
        },
      );

      var deliveryTotal = 0.0;
      var deliveryCount = 0;
      await _forEachResourcePage(
        doctype: 'Delivery Note',
        fields: const ['name', 'grand_total', 'posting_date'],
        filters: _sellingPeriodFilters('posting_date'),
        onRow: (row) {
          final value = NumParse.asDouble(row['grand_total']);
          deliveryTotal += value;
          deliveryCount++;
          _addSellingTrendPoint(
            deliveryTrend,
            dateRaw: row['posting_date'],
            amount: value,
          );
        },
      );

      var invoiceTotal = 0.0;
      var invoiceCount = 0;
      await _forEachResourcePage(
        doctype: 'Sales Invoice',
        fields: const ['name', 'grand_total', 'posting_date'],
        filters: _sellingPeriodFilters('posting_date'),
        onRow: (row) {
          final value = NumParse.asDouble(row['grand_total']);
          invoiceTotal += value;
          invoiceCount++;
          _addSellingTrendPoint(
            invoiceTrend,
            dateRaw: row['posting_date'],
            amount: value,
          );
        },
      );

      _salesOrderSummary = DocumentSummary(
        totalValue: salesTotal,
        documentCount: salesDocumentCount,
      );
      _salesOrderTrendPoints = salesTrend;
      _deliveryNoteTrendPoints = deliveryTrend;
      _salesInvoiceTrendPoints = invoiceTrend;
      _deliveryNoteSummary = DocumentSummary(
        totalValue: deliveryTotal,
        documentCount: deliveryCount,
      );
      _salesInvoiceSummary = DocumentSummary(
        totalValue: invoiceTotal,
        documentCount: invoiceCount,
      );
      _orderSummaryError = null;
    } catch (err) {
      _orderSummaryError = err.toString();
    } finally {
      _isOrderSummaryLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSellingPeriod({required int year, required int month}) async {
    if (_sellingPeriodYear == year && _sellingPeriodMonth == month) return;
    _sellingPeriodYear = year;
    _sellingPeriodMonth = month;
    notifyListeners();
    await Future.wait([
      fetchSalesOrdersFromFrappe(),
      fetchDeliveryNotesFromFrappe(),
      fetchSalesInvoicesFromFrappe(),
      refreshSellingSummaries(),
    ]);
  }

  List<DocumentTrendPoint> _emptySellingTrendPoints() {
    if (_sellingPeriodMonth == 0) {
      const labels = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return [for (final label in labels) DocumentTrendPoint(label: label)];
    }

    return [
      for (var i = 0; i < 4; i++) DocumentTrendPoint(label: 'Minggu ${i + 1}'),
    ];
  }

  void _addSellingTrendPoint(
    List<DocumentTrendPoint> points, {
    required dynamic dateRaw,
    required double amount,
  }) {
    final date = DateTime.tryParse(dateRaw?.toString() ?? '');
    if (date == null || date.year != _sellingPeriodYear) return;

    final index = _sellingPeriodMonth == 0
        ? date.month - 1
        : ((date.day - 1) ~/ 7).clamp(0, points.length - 1);
    if (index < 0 || index >= points.length) return;
    points[index] = points[index].add(amount);
  }

  Future<void> refreshBuyingSummaries() async {
    _isOrderSummaryLoading = true;
    _orderSummaryError = null;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final purchaseTrend = _emptyBuyingTrendPoints();
      final receiptTrend = _emptyBuyingTrendPoints();
      final invoiceTrend = _emptyBuyingTrendPoints();
      var purchaseTotal = 0.0;
      var purchaseDocumentCount = 0;
      await _forEachResourcePage(
        doctype: 'Purchase Order',
        fields: const ['name', 'grand_total', 'transaction_date'],
        filters: _buyingPeriodFilters('transaction_date'),
        onRow: (row) {
          final value = NumParse.asDouble(row['grand_total']);
          purchaseTotal += value;
          purchaseDocumentCount++;
          _addBuyingTrendPoint(
            purchaseTrend,
            dateRaw: row['transaction_date'],
            amount: value,
          );
        },
      );

      var receiptTotal = 0.0;
      var receiptCount = 0;
      await _forEachResourcePage(
        doctype: 'Purchase Receipt',
        fields: const ['name', 'grand_total', 'posting_date'],
        filters: _buyingPeriodFilters('posting_date'),
        onRow: (row) {
          final value = NumParse.asDouble(row['grand_total']);
          receiptTotal += value;
          receiptCount++;
          _addBuyingTrendPoint(
            receiptTrend,
            dateRaw: row['posting_date'],
            amount: value,
          );
        },
      );

      var invoiceTotal = 0.0;
      var invoiceCount = 0;
      await _forEachResourcePage(
        doctype: 'Purchase Invoice',
        fields: const ['name', 'grand_total', 'posting_date'],
        filters: _buyingPeriodFilters('posting_date'),
        onRow: (row) {
          final value = NumParse.asDouble(row['grand_total']);
          invoiceTotal += value;
          invoiceCount++;
          _addBuyingTrendPoint(
            invoiceTrend,
            dateRaw: row['posting_date'],
            amount: value,
          );
        },
      );

      _purchaseOrderSummary = DocumentSummary(
        totalValue: purchaseTotal,
        documentCount: purchaseDocumentCount,
      );
      _purchaseReceiptSummary = DocumentSummary(
        totalValue: receiptTotal,
        documentCount: receiptCount,
      );
      _purchaseInvoiceSummary = DocumentSummary(
        totalValue: invoiceTotal,
        documentCount: invoiceCount,
      );
      _purchaseOrderTrendPoints = purchaseTrend;
      _purchaseReceiptTrendPoints = receiptTrend;
      _purchaseInvoiceTrendPoints = invoiceTrend;
      _orderSummaryError = null;
    } catch (err) {
      _orderSummaryError = err.toString();
    } finally {
      _isOrderSummaryLoading = false;
      notifyListeners();
    }
  }

  Future<void> setBuyingPeriod({required int year, required int month}) async {
    if (_buyingPeriodYear == year && _buyingPeriodMonth == month) return;
    _buyingPeriodYear = year;
    _buyingPeriodMonth = month;
    notifyListeners();
    await Future.wait([
      fetchPurchaseOrdersFromFrappe(),
      fetchPurchaseReceiptsFromFrappe(),
      fetchPurchaseInvoicesFromFrappe(),
      refreshBuyingSummaries(),
    ]);
  }

  List<DocumentTrendPoint> _emptyBuyingTrendPoints() {
    if (_buyingPeriodMonth == 0) {
      const labels = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return [for (final label in labels) DocumentTrendPoint(label: label)];
    }

    return [
      for (var i = 0; i < 4; i++) DocumentTrendPoint(label: 'Minggu ${i + 1}'),
    ];
  }

  void _addBuyingTrendPoint(
    List<DocumentTrendPoint> points, {
    required dynamic dateRaw,
    required double amount,
  }) {
    final date = DateTime.tryParse(dateRaw?.toString() ?? '');
    if (date == null || date.year != _buyingPeriodYear) return;

    final index = _buyingPeriodMonth == 0
        ? date.month - 1
        : ((date.day - 1) ~/ 7).clamp(0, points.length - 1);
    if (index < 0 || index >= points.length) return;
    points[index] = points[index].add(amount);
  }

  Future<void> refreshAllSummaries({bool silent = false}) {
    if (!_isAuthenticated) return Future.value();

    final activeJob = _orderSummaryJob;
    if (activeJob != null) return activeJob;

    final job = _refreshAllSummaries(silent: silent);
    _orderSummaryJob = job.whenComplete(() {
      _orderSummaryJob = null;
    });
    return _orderSummaryJob!;
  }

  Future<void> _refreshAllSummaries({required bool silent}) async {
    _isOrderSummaryLoading = true;
    _summarySyncStatus = SummarySyncStatus.syncing;
    _summaryProcessedRows = 0;
    _orderSummaryError = null;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      var salesTotal = 0.0;
      var salesOpen = 0.0;
      var salesCompleted = 0.0;
      var salesDraftCount = 0;
      var salesOpenCount = 0;
      var salesCompletedCount = 0;
      var salesDocumentCount = 0;
      await _forEachResourcePage(
        doctype: 'Sales Order',
        fields: const [
          'name',
          'grand_total',
          'status',
          'docstatus',
          'delivery_date',
        ],
        filters: _sellingPeriodFilters('transaction_date'),
        onRow: (row) {
          final order = SalesOrder.fromJson(row);
          salesDocumentCount++;
          salesTotal += order.value;
          if (order.docStatus == 0) salesDraftCount++;
          if (order.statusKey == SalesOrderStatusKey.completed) {
            salesCompleted += order.value;
            salesCompletedCount++;
          } else if (order.statusKey != SalesOrderStatusKey.cancelled &&
              order.statusKey != SalesOrderStatusKey.closed) {
            salesOpen += order.value;
            salesOpenCount++;
          }
        },
      );

      var deliveryTotal = 0.0;
      var deliveryCount = 0;
      await _forEachResourcePage(
        doctype: 'Delivery Note',
        fields: const ['name', 'grand_total'],
        filters: _sellingPeriodFilters('posting_date'),
        onRow: (row) {
          deliveryTotal += NumParse.asDouble(row['grand_total']);
          deliveryCount++;
        },
      );

      var invoiceTotal = 0.0;
      var invoiceCount = 0;
      var unpaidSalesInvoices = 0;
      await _forEachResourcePage(
        doctype: 'Sales Invoice',
        fields: const ['name', 'grand_total', 'status', 'docstatus'],
        filters: _sellingPeriodFilters('posting_date'),
        onRow: (row) {
          final invoice = SalesInvoice.fromJson(row);
          invoiceTotal += invoice.value;
          invoiceCount++;
          if (invoice.statusKey == InvoiceStatusKey.unpaid ||
              invoice.statusKey == InvoiceStatusKey.overdue ||
              invoice.statusKey == InvoiceStatusKey.partlyPaid) {
            unpaidSalesInvoices++;
          }
        },
      );

      var purchaseTotal = 0.0;
      var purchasePending = 0.0;
      var purchaseDelayed = 0.0;
      var purchaseDraftCount = 0;
      var purchasePendingCount = 0;
      var purchaseCompletedCount = 0;
      var purchaseDocumentCount = 0;
      await _forEachResourcePage(
        doctype: 'Purchase Order',
        fields: const [
          'name',
          'grand_total',
          'status',
          'docstatus',
          'transaction_date',
          'schedule_date',
        ],
        filters: _buyingPeriodFilters('transaction_date'),
        onRow: (row) {
          final order = PurchaseOrder.fromJson(row);
          purchaseDocumentCount++;
          purchaseTotal += order.totalValue;
          if (order.docStatus == 0) purchaseDraftCount++;
          if (order.statusKey == PurchaseOrderStatusKey.completed) {
            purchaseCompletedCount++;
          } else if (order.statusKey != PurchaseOrderStatusKey.cancelled &&
              order.statusKey != PurchaseOrderStatusKey.closed) {
            purchasePending += order.totalValue;
            purchasePendingCount++;
          }
          if (order.isDelayed) purchaseDelayed += order.totalValue;
        },
      );

      var purchaseReceiptTotal = 0.0;
      var purchaseReceiptCount = 0;
      await _forEachResourcePage(
        doctype: 'Purchase Receipt',
        fields: const ['name', 'grand_total'],
        filters: _buyingPeriodFilters('posting_date'),
        onRow: (row) {
          purchaseReceiptTotal += NumParse.asDouble(row['grand_total']);
          purchaseReceiptCount++;
        },
      );

      var purchaseInvoiceTotal = 0.0;
      var purchaseInvoiceCount = 0;
      var overduePurchaseInvoices = 0;
      await _forEachResourcePage(
        doctype: 'Purchase Invoice',
        fields: const ['name', 'grand_total', 'status', 'docstatus'],
        filters: _buyingPeriodFilters('posting_date'),
        onRow: (row) {
          final invoice = PurchaseInvoice.fromJson(row);
          purchaseInvoiceTotal += invoice.value;
          purchaseInvoiceCount++;
          if (invoice.statusKey == InvoiceStatusKey.overdue) {
            overduePurchaseInvoices++;
          }
        },
      );

      final stockRows = <({String itemCode, int quantity})>[];
      await _forEachResourcePage(
        doctype: 'Bin',
        fields: const ['name', 'item_code', 'actual_qty'],
        onRow: (row) {
          final itemCode = row['item_code']?.toString() ?? '';
          if (itemCode.isEmpty) return;
          stockRows.add((
            itemCode: itemCode,
            quantity: NumParse.asInt(row['actual_qty']),
          ));
        },
      );
      final stockMeta = await _fetchItemMeta(
        stockRows.map((row) => row.itemCode).toSet(),
      );
      final stockAlerts = stockRows.where((row) {
        final reorderLevel = stockMeta[row.itemCode]?.reorderLevel ?? 0;
        return reorderLevel > 0
            ? row.quantity <= reorderLevel
            : row.quantity <= 0;
      }).length;

      _salesOrderSummary = DocumentSummary(
        totalValue: salesTotal,
        documentCount: salesDocumentCount,
      );
      _deliveryNoteSummary = DocumentSummary(
        totalValue: deliveryTotal,
        documentCount: deliveryCount,
      );
      _salesInvoiceSummary = DocumentSummary(
        totalValue: invoiceTotal,
        documentCount: invoiceCount,
      );
      _purchaseOrderSummary = DocumentSummary(
        totalValue: purchaseTotal,
        documentCount: purchaseDocumentCount,
      );
      _purchaseReceiptSummary = DocumentSummary(
        totalValue: purchaseReceiptTotal,
        documentCount: purchaseReceiptCount,
      );
      _purchaseInvoiceSummary = DocumentSummary(
        totalValue: purchaseInvoiceTotal,
        documentCount: purchaseInvoiceCount,
      );
      _dashboardSummary = DashboardSummary(
        salesTotal: salesTotal,
        salesOpen: salesOpen,
        salesCompleted: salesCompleted,
        salesDraftCount: salesDraftCount,
        salesOpenCount: salesOpenCount,
        salesCompletedCount: salesCompletedCount,
        purchaseTotal: purchaseTotal,
        purchasePending: purchasePending,
        purchaseDelayed: purchaseDelayed,
        purchaseDraftCount: purchaseDraftCount,
        purchasePendingCount: purchasePendingCount,
        purchaseCompletedCount: purchaseCompletedCount,
        unpaidSalesInvoices: unpaidSalesInvoices,
        overduePurchaseInvoices: overduePurchaseInvoices,
        stockAlerts: stockAlerts,
      );
      await _saveSummaryCache();
      _orderSummaryError = null;
      _summarySyncStatus = SummarySyncStatus.completed;
    } catch (err) {
      _orderSummaryError = err.toString();
      _summarySyncStatus = SummarySyncStatus.error;
    } finally {
      _isOrderSummaryLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchDeliveryNotesFromFrappe() async {
    _isDeliveryNotesLoading = true;
    _deliveryNotesError = null;
    _hasMoreDeliveryNotes = true;
    _isMoreDeliveryNotesLoading = false;
    final version = ++_deliveryNoteQueryVersion;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final docs = await _fetchDeliveryNotePage(limitStart: 0);
      if (version != _deliveryNoteQueryVersion) return;
      _deliveryNotes = docs;
      _hasMoreDeliveryNotes = docs.isNotEmpty;
      _deliveryNotesError = null;
    } catch (err) {
      if (version != _deliveryNoteQueryVersion) return;
      _deliveryNotesError = err.toString();
    } finally {
      if (version == _deliveryNoteQueryVersion) {
        _isDeliveryNotesLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchSalesInvoicesFromFrappe() async {
    _isSalesInvoicesLoading = true;
    _salesInvoicesError = null;
    _hasMoreSalesInvoices = true;
    _isMoreSalesInvoicesLoading = false;
    final version = ++_salesInvoiceQueryVersion;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final docs = await _fetchSalesInvoicePage(limitStart: 0);
      if (version != _salesInvoiceQueryVersion) return;
      _salesInvoices = docs;
      _hasMoreSalesInvoices = docs.isNotEmpty;
      _salesInvoicesError = null;
    } catch (err) {
      if (version != _salesInvoiceQueryVersion) return;
      _salesInvoicesError = err.toString();
    } finally {
      if (version == _salesInvoiceQueryVersion) {
        _isSalesInvoicesLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchPurchaseReceiptsFromFrappe() async {
    _isPurchaseReceiptsLoading = true;
    _purchaseReceiptsError = null;
    _hasMorePurchaseReceipts = true;
    _isMorePurchaseReceiptsLoading = false;
    final version = ++_purchaseReceiptQueryVersion;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final docs = await _fetchPurchaseReceiptPage(limitStart: 0);
      if (version != _purchaseReceiptQueryVersion) return;
      _purchaseReceipts = docs;
      _hasMorePurchaseReceipts = docs.isNotEmpty;
      _purchaseReceiptsError = null;
    } catch (err) {
      if (version != _purchaseReceiptQueryVersion) return;
      _purchaseReceiptsError = err.toString();
    } finally {
      if (version == _purchaseReceiptQueryVersion) {
        _isPurchaseReceiptsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchPurchaseInvoicesFromFrappe() async {
    _isPurchaseInvoicesLoading = true;
    _purchaseInvoicesError = null;
    _hasMorePurchaseInvoices = true;
    _isMorePurchaseInvoicesLoading = false;
    final version = ++_purchaseInvoiceQueryVersion;
    notifyListeners();

    try {
      await _frappeService.ensureLoggedIn();
      final docs = await _fetchPurchaseInvoicePage(limitStart: 0);
      if (version != _purchaseInvoiceQueryVersion) return;
      _purchaseInvoices = docs;
      _hasMorePurchaseInvoices = docs.isNotEmpty;
      _purchaseInvoicesError = null;
    } catch (err) {
      if (version != _purchaseInvoiceQueryVersion) return;
      _purchaseInvoicesError = err.toString();
    } finally {
      if (version == _purchaseInvoiceQueryVersion) {
        _isPurchaseInvoicesLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshDeliveryNotes() => fetchDeliveryNotesFromFrappe();
  Future<void> refreshSalesInvoices() => fetchSalesInvoicesFromFrappe();

  Future<void> setSalesOrderQuery({String? search, String? status}) async {
    _salesOrderSearch = search?.trim() ?? _salesOrderSearch;
    _salesOrderStatus = status;
    await fetchSalesOrdersFromFrappe();
  }

  Future<void> setDeliveryNoteQuery({String? search, String? status}) async {
    _deliveryNoteSearch = search?.trim() ?? _deliveryNoteSearch;
    _deliveryNoteStatus = status;
    await fetchDeliveryNotesFromFrappe();
  }

  Future<void> setSalesInvoiceQuery({String? search, String? status}) async {
    _salesInvoiceSearch = search?.trim() ?? _salesInvoiceSearch;
    _salesInvoiceStatus = status;
    await fetchSalesInvoicesFromFrappe();
  }

  Future<void> loadMoreDeliveryNotes() async {
    if (_isDeliveryNotesLoading ||
        _isMoreDeliveryNotesLoading ||
        !_hasMoreDeliveryNotes) {
      return;
    }
    _isMoreDeliveryNotesLoading = true;
    final version = _deliveryNoteQueryVersion;
    notifyListeners();
    try {
      final page = await _fetchDeliveryNotePage(
        limitStart: _deliveryNotes.length,
      );
      if (version != _deliveryNoteQueryVersion) return;
      final ids = _deliveryNotes.map((e) => e.id).toSet();
      _deliveryNotes = [..._deliveryNotes, ...page.where((e) => ids.add(e.id))];
      _hasMoreDeliveryNotes = page.isNotEmpty;
    } catch (err) {
      if (version != _deliveryNoteQueryVersion) return;
      _deliveryNotesError = err.toString();
    } finally {
      if (version == _deliveryNoteQueryVersion) {
        _isMoreDeliveryNotesLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreSalesInvoices() async {
    if (_isSalesInvoicesLoading ||
        _isMoreSalesInvoicesLoading ||
        !_hasMoreSalesInvoices) {
      return;
    }
    _isMoreSalesInvoicesLoading = true;
    final version = _salesInvoiceQueryVersion;
    notifyListeners();
    try {
      final page = await _fetchSalesInvoicePage(
        limitStart: _salesInvoices.length,
      );
      if (version != _salesInvoiceQueryVersion) return;
      final ids = _salesInvoices.map((e) => e.id).toSet();
      _salesInvoices = [..._salesInvoices, ...page.where((e) => ids.add(e.id))];
      _hasMoreSalesInvoices = page.isNotEmpty;
    } catch (err) {
      if (version != _salesInvoiceQueryVersion) return;
      _salesInvoicesError = err.toString();
    } finally {
      if (version == _salesInvoiceQueryVersion) {
        _isMoreSalesInvoicesLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshPurchaseReceipts() => fetchPurchaseReceiptsFromFrappe();
  Future<void> refreshPurchaseInvoices() => fetchPurchaseInvoicesFromFrappe();

  Future<void> setPurchaseOrderQuery({String? search, String? status}) async {
    _purchaseOrderSearch = search?.trim() ?? _purchaseOrderSearch;
    _purchaseOrderStatus = status;
    await fetchPurchaseOrdersFromFrappe();
  }

  Future<void> setPurchaseReceiptQuery({String? search, String? status}) async {
    _purchaseReceiptSearch = search?.trim() ?? _purchaseReceiptSearch;
    _purchaseReceiptStatus = status;
    await fetchPurchaseReceiptsFromFrappe();
  }

  Future<void> setPurchaseInvoiceQuery({String? search, String? status}) async {
    _purchaseInvoiceSearch = search?.trim() ?? _purchaseInvoiceSearch;
    _purchaseInvoiceStatus = status;
    await fetchPurchaseInvoicesFromFrappe();
  }

  Future<void> loadMorePurchaseReceipts() async {
    if (_isPurchaseReceiptsLoading ||
        _isMorePurchaseReceiptsLoading ||
        !_hasMorePurchaseReceipts) {
      return;
    }
    _isMorePurchaseReceiptsLoading = true;
    final version = _purchaseReceiptQueryVersion;
    notifyListeners();
    try {
      final page = await _fetchPurchaseReceiptPage(
        limitStart: _purchaseReceipts.length,
      );
      if (version != _purchaseReceiptQueryVersion) return;
      final ids = _purchaseReceipts.map((e) => e.id).toSet();
      _purchaseReceipts = [
        ..._purchaseReceipts,
        ...page.where((e) => ids.add(e.id)),
      ];
      _hasMorePurchaseReceipts = page.isNotEmpty;
    } catch (err) {
      if (version != _purchaseReceiptQueryVersion) return;
      _purchaseReceiptsError = err.toString();
    } finally {
      if (version == _purchaseReceiptQueryVersion) {
        _isMorePurchaseReceiptsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMorePurchaseInvoices() async {
    if (_isPurchaseInvoicesLoading ||
        _isMorePurchaseInvoicesLoading ||
        !_hasMorePurchaseInvoices) {
      return;
    }
    _isMorePurchaseInvoicesLoading = true;
    final version = _purchaseInvoiceQueryVersion;
    notifyListeners();
    try {
      final page = await _fetchPurchaseInvoicePage(
        limitStart: _purchaseInvoices.length,
      );
      if (version != _purchaseInvoiceQueryVersion) return;
      final ids = _purchaseInvoices.map((e) => e.id).toSet();
      _purchaseInvoices = [
        ..._purchaseInvoices,
        ...page.where((e) => ids.add(e.id)),
      ];
      _hasMorePurchaseInvoices = page.isNotEmpty;
    } catch (err) {
      if (version != _purchaseInvoiceQueryVersion) return;
      _purchaseInvoicesError = err.toString();
    } finally {
      if (version == _purchaseInvoiceQueryVersion) {
        _isMorePurchaseInvoicesLoading = false;
        notifyListeners();
      }
    }
  }

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
          'from_warehouse',
          'to_warehouse',
        ],
        orderBy: 'posting_date desc',
        maxRows: _defaultFetchRowLimit,
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

  Future<void> refreshStockEntries() => fetchStockEntriesFromFrappe();

  Future<void> refreshStockReconciliations() async {
    final rows = await _fetchAllResourcePages(
      doctype: 'Stock Reconciliation',
      fields: const [
        'name',
        'company',
        'posting_date',
        'status',
        'docstatus',
        'difference_amount',
      ],
      orderBy: 'posting_date desc, name desc',
      maxRows: _defaultFetchRowLimit,
    );
    _stockReconciliations = rows
        .map(StockReconciliationSummary.fromJson)
        .toList();
    notifyListeners();
  }

  Future<void> fetchWarehousesFromFrappe({
    String? baseUrl,
    String? username,
    String? password,
  }) async {
    _frappeService.baseUrl = baseUrl ?? AppConfig.normalizedFrappeBaseUrl;

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
          maxRows: null,
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
          maxRows: null,
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

  int _warehouseDisplayPriority(String warehouseName) {
    final name = warehouseName.toLowerCase();
    if (name.contains('stores') || name.contains('store')) return 0;
    if (name.contains('inbound') || name.contains('receiving')) return 1;
    return 2;
  }

  int _compareWarehouseNames(String a, String b) {
    final priority = _warehouseDisplayPriority(
      a,
    ).compareTo(_warehouseDisplayPriority(b));
    if (priority != 0) return priority;
    return a.toLowerCase().compareTo(b.toLowerCase());
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

    areas.sort((a, b) => _compareWarehouseNames(a.title, b.title));
    return areas;
  }

  List<String> erpWarehouseNamesForCompany(String company) {
    if (_warehouses.isEmpty) return [];
    final names = _warehouses
        .where((w) => _warehouseBelongsToCompany(w, company))
        .map((w) => w.name)
        .toList();
    names.sort(_compareWarehouseNames);
    return names;
  }

  Future<void> fetchInventoryFromFrappe({
    String? baseUrl,
    String? username,
    String? password,
    List<List<dynamic>>? filters,
  }) async {
    _frappeService.baseUrl = baseUrl ?? AppConfig.normalizedFrappeBaseUrl;
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
          baseUrl: baseUrl ?? AppConfig.normalizedFrappeBaseUrl,
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
            'valuation_rate',
            'stock_value',
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
      final itemBuyingRates = await _fetchItemBuyingRates(
        items.map((i) => i.sku).where((s) => s.isNotEmpty).toSet(),
      );

      _inventory = items.map((inv) {
        final meta = itemMeta[inv.sku];

        var updated = inv;
        if (meta != null && meta.name.isNotEmpty && meta.name != inv.sku) {
          updated = updated.copyWith(name: meta.name);
        }
        if (meta != null && meta.reorderLevel > 0) {
          updated = updated.copyWith(minStockThreshold: meta.reorderLevel);
        }
        if (meta != null && meta.valuationRate > 0) {
          updated = updated.copyWith(unitValue: meta.valuationRate);
        }
        if (updated.unitValue <= 0) {
          final buyingRate = itemBuyingRates[inv.sku] ?? 0;
          if (buyingRate > 0) {
            updated = updated.copyWith(unitValue: buyingRate);
          }
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
    }
    unawaited(refreshAllSummaries(silent: true));
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
    unawaited(refreshAllSummaries(silent: true));
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
    unawaited(refreshAllSummaries(silent: true));
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
      maxRows: null,
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
        maxRows: null,
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
      maxRows: null,
    );

    final movements = data.map((e) => StockLedgerMovement.fromJson(e)).toList();
    return StockLedgerResult.fromMovements(movements);
  }

  Future<List<StockAgingItem>> fetchStockAging({int lookbackDays = 365}) async {
    await _frappeService.ensureLoggedIn();
    if (_inventory.isEmpty) await refreshInventory();
    final today = DateTime.now();
    final from = today.subtract(Duration(days: lookbackDays));
    final rows = await _fetchAllResourcePages(
      doctype: 'Stock Ledger Entry',
      fields: const [
        'name',
        'posting_date',
        'item_code',
        'warehouse',
        'actual_qty',
      ],
      filters: [
        ['posting_date', '>=', DateRangePresets.toFrappeDate(from)],
        ['actual_qty', '>', 0],
      ],
      orderBy: 'posting_date desc, posting_time desc',
      maxRows: 5000,
    );
    final latestIncoming = <String, DateTime>{};
    for (final row in rows) {
      final item = row['item_code']?.toString() ?? '';
      final warehouse = row['warehouse']?.toString() ?? '';
      final date = DateTime.tryParse(row['posting_date']?.toString() ?? '');
      if (item.isEmpty || warehouse.isEmpty || date == null) continue;
      latestIncoming.putIfAbsent('$item|$warehouse', () => date);
    }
    return [
      for (final item in _inventory)
        if (item.quantity > 0)
          StockAgingItem(
            itemCode: item.sku,
            itemName: item.name,
            warehouse: item.warehouseId,
            quantity: item.quantity,
            valuationRate: item.unitValue,
            lastIncomingDate: latestIncoming['${item.sku}|${item.warehouseId}'],
            ageDays: latestIncoming['${item.sku}|${item.warehouseId}'] == null
                ? lookbackDays + 1
                : today
                      .difference(
                        latestIncoming['${item.sku}|${item.warehouseId}']!,
                      )
                      .inDays,
          ),
    ];
  }

  Future<List<DeadStockItem>> fetchDeadStock({int lookbackDays = 365}) async {
    await _frappeService.ensureLoggedIn();
    if (_inventory.isEmpty) await refreshInventory();
    final today = DateTime.now();
    final from = today.subtract(Duration(days: lookbackDays));
    final rows = await _fetchAllResourcePages(
      doctype: 'Stock Ledger Entry',
      fields: const [
        'name',
        'posting_date',
        'item_code',
        'warehouse',
        'actual_qty',
      ],
      filters: [
        ['posting_date', '>=', DateRangePresets.toFrappeDate(from)],
      ],
      orderBy: 'posting_date desc, posting_time desc',
      maxRows: 5000,
    );
    final latestMovement = <String, DateTime>{};
    for (final row in rows) {
      final item = row['item_code']?.toString() ?? '';
      final warehouse = row['warehouse']?.toString() ?? '';
      final date = DateTime.tryParse(row['posting_date']?.toString() ?? '');
      if (item.isEmpty || warehouse.isEmpty || date == null) continue;
      latestMovement.putIfAbsent('$item|$warehouse', () => date);
    }
    return [
      for (final item in _inventory)
        if (item.quantity > 0)
          DeadStockItem(
            itemCode: item.sku,
            itemName: item.name,
            warehouse: item.warehouseId,
            quantity: item.quantity,
            valuationRate: item.unitValue,
            lastMovementDate: latestMovement['${item.sku}|${item.warehouseId}'],
            inactiveDays:
                latestMovement['${item.sku}|${item.warehouseId}'] == null
                ? lookbackDays + 1
                : today
                      .difference(
                        latestMovement['${item.sku}|${item.warehouseId}']!,
                      )
                      .inDays,
          ),
    ];
  }

  Future<List<StockMovementVelocityItem>> fetchStockMovementVelocity({
    int periodDays = 30,
  }) async {
    await _frappeService.ensureLoggedIn();
    if (_inventory.isEmpty) await refreshInventory();
    final from = DateTime.now().subtract(Duration(days: periodDays));
    final rows = await _fetchAllResourcePages(
      doctype: 'Stock Ledger Entry',
      fields: const ['name', 'item_code', 'warehouse', 'actual_qty'],
      filters: [
        ['posting_date', '>=', DateRangePresets.toFrappeDate(from)],
        ['actual_qty', '<', 0],
      ],
      orderBy: 'posting_date desc, posting_time desc',
      maxRows: 5000,
    );
    final outgoingQuantity = <String, double>{};
    final transactionCount = <String, int>{};
    for (final row in rows) {
      final item = row['item_code']?.toString() ?? '';
      final warehouse = row['warehouse']?.toString() ?? '';
      if (item.isEmpty || warehouse.isEmpty) continue;
      final key = '$item|$warehouse';
      outgoingQuantity[key] =
          (outgoingQuantity[key] ?? 0) +
          NumParse.asDouble(row['actual_qty']).abs();
      transactionCount[key] = (transactionCount[key] ?? 0) + 1;
    }
    return [
      for (final item in _inventory)
        if (item.quantity > 0)
          StockMovementVelocityItem(
            itemCode: item.sku,
            itemName: item.name,
            warehouse: item.warehouseId,
            currentQuantity: item.quantity,
            outgoingQuantity:
                outgoingQuantity['${item.sku}|${item.warehouseId}'] ?? 0,
            transactionCount:
                transactionCount['${item.sku}|${item.warehouseId}'] ?? 0,
          ),
    ];
  }

  Future<List<WarehouseBatchRecord>> fetchWarehouseBatches() async {
    await _frappeService.ensureLoggedIn();
    final rows = await _fetchAllResourcePages(
      doctype: 'Batch',
      fields: const [
        'name',
        'item',
        'manufacturing_date',
        'expiry_date',
        'disabled',
      ],
      orderBy: 'expiry_date asc, name asc',
      maxRows: 1000,
    );
    return rows.map(WarehouseBatchRecord.fromJson).toList();
  }

  Future<List<WarehouseSerialRecord>> fetchWarehouseSerialNumbers() async {
    await _frappeService.ensureLoggedIn();
    final rows = await _fetchAllResourcePages(
      doctype: 'Serial No',
      fields: const ['name', 'item_code', 'warehouse', 'status', 'batch_no'],
      orderBy: 'modified desc',
      maxRows: 1000,
    );
    return rows.map(WarehouseSerialRecord.fromJson).toList();
  }

  Future<List<QualityInspectionRecord>> fetchRejectedQualityInspections({
    int periodDays = 30,
  }) async {
    await _frappeService.ensureLoggedIn();
    final from = DateTime.now().subtract(Duration(days: periodDays));
    final rows = await _fetchAllResourcePages(
      doctype: 'Quality Inspection',
      fields: const [
        'name',
        'item_code',
        'item_name',
        'inspection_type',
        'reference_type',
        'reference_name',
        'inspected_by',
        'status',
        'remarks',
        'report_date',
        'docstatus',
      ],
      filters: [
        ['status', '=', 'Rejected'],
        ['report_date', '>=', DateRangePresets.toFrappeDate(from)],
      ],
      orderBy: 'report_date desc, modified desc',
      maxRows: 1000,
    );
    return rows.map(QualityInspectionRecord.fromJson).toList();
  }

  Future<List<QualityInspectionRecord>> fetchProductionQualityInspections({
    int periodDays = 30,
  }) async {
    await _frappeService.ensureLoggedIn();
    final from = DateTime.now().subtract(Duration(days: periodDays));
    final rows = await _fetchAllResourcePages(
      doctype: 'Quality Inspection',
      fields: const [
        'name',
        'item_code',
        'item_name',
        'inspection_type',
        'reference_type',
        'reference_name',
        'inspected_by',
        'status',
        'remarks',
        'report_date',
        'docstatus',
      ],
      filters: [
        ['inspection_type', '=', 'In Process'],
        ['report_date', '>=', DateRangePresets.toFrappeDate(from)],
      ],
      orderBy: 'report_date desc, modified desc',
      maxRows: 1000,
    );
    return rows.map(QualityInspectionRecord.fromJson).toList();
  }

  Future<List<QualityInspectionRecord>> fetchIncomingQualityInspections({
    int periodDays = 30,
  }) async {
    await _frappeService.ensureLoggedIn();
    final from = DateTime.now().subtract(Duration(days: periodDays));
    final rows = await _fetchAllResourcePages(
      doctype: 'Quality Inspection',
      fields: const [
        'name',
        'item_code',
        'item_name',
        'inspection_type',
        'reference_type',
        'reference_name',
        'inspected_by',
        'status',
        'remarks',
        'report_date',
        'docstatus',
      ],
      filters: [
        ['inspection_type', '=', 'Incoming'],
        ['report_date', '>=', DateRangePresets.toFrappeDate(from)],
      ],
      orderBy: 'report_date desc, modified desc',
      maxRows: 1000,
    );
    return rows.map(QualityInspectionRecord.fromJson).toList();
  }

  Future<List<QualityInspectionRecord>> fetchQualityInspections({
    int periodDays = 30,
  }) async {
    await _frappeService.ensureLoggedIn();
    final from = DateTime.now().subtract(Duration(days: periodDays));
    final rows = await _fetchAllResourcePages(
      doctype: 'Quality Inspection',
      fields: const [
        'name',
        'item_code',
        'item_name',
        'inspection_type',
        'reference_type',
        'reference_name',
        'inspected_by',
        'status',
        'remarks',
        'report_date',
        'docstatus',
      ],
      filters: [
        ['report_date', '>=', DateRangePresets.toFrappeDate(from)],
      ],
      orderBy: 'report_date desc, modified desc',
      maxRows: 1000,
    );
    return rows.map(QualityInspectionRecord.fromJson).toList();
  }

  Future<List<QualityInspectionRecord>> fetchQualityInspectionsForApproval({
    int periodDays = 30,
  }) async {
    await _frappeService.ensureLoggedIn();
    final from = DateTime.now().subtract(Duration(days: periodDays));
    final rows = await _fetchAllResourcePages(
      doctype: 'Quality Inspection',
      fields: const [
        'name',
        'item_code',
        'item_name',
        'inspection_type',
        'reference_type',
        'reference_name',
        'inspected_by',
        'status',
        'remarks',
        'report_date',
        'docstatus',
      ],
      filters: [
        ['docstatus', '=', 0],
        ['report_date', '>=', DateRangePresets.toFrappeDate(from)],
      ],
      orderBy: 'report_date desc, modified desc',
      maxRows: 1000,
    );
    return rows.map(QualityInspectionRecord.fromJson).toList();
  }

  Future<List<SalesOrderApproval>> fetchSalesOrderApprovals() async {
    await _frappeService.ensureLoggedIn();
    final rows = await _fetchAllResourcePages(
      doctype: 'Sales Order',
      fields: const [
        'name',
        'customer',
        'customer_name',
        'workflow_state',
        'status',
        'owner',
        'transaction_date',
        'grand_total',
        'docstatus',
      ],
      filters: [
        ['docstatus', '<', 2],
      ],
      orderBy: 'modified desc',
      maxRows: 200,
    );
    final approvals = <SalesOrderApproval>[];
    for (final row in rows) {
      try {
        final doc = await _frappeService.fetchDocument(
          'Sales Order',
          row['name']?.toString() ?? '',
        );
        final rawTransitions = await _frappeService.callMethod(
          'frappe.model.workflow.get_transitions',
          args: {'doc': doc},
        );
        final actions = rawTransitions is List
            ? rawTransitions
                  .whereType<Map>()
                  .map((transition) => transition['action']?.toString() ?? '')
                  .where((action) => action.isNotEmpty)
                  .toSet()
                  .toList()
            : <String>[];
        if (actions.isNotEmpty) {
          approvals.add(SalesOrderApproval.fromJson(row, actions: actions));
        }
      } catch (_) {
        // A document without an action for the current role is not a todo.
      }
    }
    if (_salesOrderApprovalTodoCount != approvals.length) {
      _salesOrderApprovalTodoCount = approvals.length;
      notifyListeners();
    }
    return approvals;
  }

  Future<List<SalesOrderApprovalHistory>>
  fetchSalesOrderApprovalHistory() async {
    await _frappeService.ensureLoggedIn();
    final rows = await _fetchAllResourcePages(
      doctype: 'Comment',
      fields: const [
        'name',
        'reference_name',
        'content',
        'comment_by',
        'owner',
        'creation',
      ],
      filters: [
        ['reference_doctype', '=', 'Sales Order'],
        ['content', 'like', '%via TMSX App%'],
      ],
      orderBy: 'creation desc',
      maxRows: 200,
    );
    return rows.map(SalesOrderApprovalHistory.fromJson).toList();
  }

  Future<Map<String, dynamic>> fetchSalesOrderApprovalDetail(String name) {
    return _frappeService.fetchDocument('Sales Order', name);
  }

  Future<void> applySalesOrderWorkflow({
    required SalesOrderApproval approval,
    required String action,
    String reason = '',
  }) async {
    await _frappeService.ensureLoggedIn();
    final normalizedAction = action.trim();
    final actionLower = normalizedAction.toLowerCase();
    final isReject =
        actionLower.contains('reject') ||
        actionLower.contains('tolak') ||
        actionLower.contains('decline');
    if (isReject && reason.trim().isEmpty) {
      throw Exception('Alasan reject wajib diisi.');
    }
    final doc = await _frappeService.fetchDocument(
      'Sales Order',
      approval.name,
    );
    await _frappeService.callMethod(
      'frappe.model.workflow.apply_workflow',
      args: {'doc': doc, 'action': normalizedAction},
    );
    final decision = isReject ? 'REJECT' : 'APPROVE';
    final content = [
      '$decision via TMSX App',
      'Action: $normalizedAction',
      if (reason.trim().isNotEmpty) 'Alasan: ${reason.trim()}',
    ].join('\n');
    await _frappeService.callMethod(
      'frappe.desk.form.utils.add_comment',
      args: {
        'reference_doctype': 'Sales Order',
        'reference_name': approval.name,
        'content': content,
        'comment_email': _currentUser ?? '',
        'comment_by': _currentUser ?? '',
      },
    );
    await Future.wait([
      refreshSalesOrders(),
      refreshNotifications(silent: true),
    ]);
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
    required String username,
    String? password,
    bool savePassword = true,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final shouldSavePassword =
        savePassword || _rememberDevice || password != null;
    final cfg = {
      'username': username,
      if (shouldSavePassword && password != null) 'password': password,
    };
    await sp.setString(_prefsFrappeConfigKey, jsonEncode(cfg));

    _frappeService.baseUrl = AppConfig.normalizedFrappeBaseUrl;
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
    final filters = <List<dynamic>>[
      ..._sellingPeriodFilters('transaction_date'),
      ...?_salesOrderFilters(_salesOrderStatus),
      ..._salesOwnerFilter,
    ];
    final data = await _fetchResourceWithFieldFallback(
      doctype: 'Sales Order',
      fields: const [
        'name',
        'owner',
        'customer',
        'customer_name',
        'grand_total',
        'status',
        'docstatus',
        'transaction_date',
        'delivery_date',
        'total_qty',
        'per_delivered',
        'per_billed',
      ],
      limit: _documentPageSize,
      limitStart: limitStart,
      orderBy: 'transaction_date desc, name desc',
      filters: filters.isEmpty ? null : filters,
      orFilters: _searchFilters(_salesOrderSearch, const [
        'name',
        'customer',
        'customer_name',
      ]),
    );

    var orders = data.map((item) => SalesOrder.fromJson(item)).toList();
    orders = await _attachSalesOrderItems(orders);
    return orders;
  }

  Future<List<DeliveryNote>> _fetchDeliveryNotePage({
    required int limitStart,
  }) async {
    final filters = <List<dynamic>>[
      ..._sellingPeriodFilters('posting_date'),
      ...?_statusFilters(_deliveryNoteStatus),
    ];
    final data = await _fetchResourceWithFieldFallback(
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
      limit: _documentPageSize,
      limitStart: limitStart,
      orderBy: 'posting_date desc, name desc',
      filters: filters,
      orFilters: _searchFilters(_deliveryNoteSearch, const [
        'name',
        'customer',
        'customer_name',
      ]),
    );
    return data.map(DeliveryNote.fromJson).toList();
  }

  Future<List<SalesInvoice>> _fetchSalesInvoicePage({
    required int limitStart,
  }) async {
    final filters = <List<dynamic>>[
      ..._sellingPeriodFilters('posting_date'),
      ...?_statusFilters(_salesInvoiceStatus),
      ..._salesOwnerFilter,
    ];
    final data = await _fetchResourceWithFieldFallback(
      doctype: 'Sales Invoice',
      fields: const [
        'name',
        'owner',
        'customer',
        'customer_name',
        'status',
        'docstatus',
        'posting_date',
        'grand_total',
        'outstanding_amount',
        'due_date',
      ],
      limit: _documentPageSize,
      limitStart: limitStart,
      orderBy: 'posting_date desc, name desc',
      filters: filters.isEmpty ? null : filters,
      orFilters: _searchFilters(_salesInvoiceSearch, const [
        'name',
        'customer',
        'customer_name',
      ]),
    );
    return data.map(SalesInvoice.fromJson).toList();
  }

  List<List<dynamic>>? _statusFilters(String? status) {
    if (status == null || status.isEmpty) return null;
    return [
      ['status', '=', status],
    ];
  }

  List<List<dynamic>> _sellingPeriodFilters(String dateField) {
    return [
      [dateField, '>=', DateRangePresets.toFrappeDate(sellingPeriodFrom)],
      [dateField, '<=', DateRangePresets.toFrappeDate(sellingPeriodTo)],
      ['docstatus', '!=', 2],
    ];
  }

  List<List<dynamic>> _buyingPeriodFilters(String dateField) {
    return [
      [dateField, '>=', DateRangePresets.toFrappeDate(buyingPeriodFrom)],
      [dateField, '<=', DateRangePresets.toFrappeDate(buyingPeriodTo)],
      ['docstatus', '!=', 2],
    ];
  }

  List<List<dynamic>>? _salesOrderFilters(String? status) {
    if (status != 'Overdue') return _statusFilters(status);
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return [
      ['delivery_date', '<', today],
      [
        'status',
        'not in',
        ['Draft', 'Completed', 'Closed', 'Cancelled'],
      ],
    ];
  }

  List<List<dynamic>>? _searchFilters(String search, List<String> fields) {
    final query = search.trim();
    if (query.isEmpty) return null;
    return fields
        .map<List<dynamic>>((field) => [field, 'like', '%$query%'])
        .toList();
  }

  Future<List<PurchaseOrder>> _fetchPurchaseOrderPage({
    required int limitStart,
  }) async {
    final filters = <List<dynamic>>[
      ..._buyingPeriodFilters('transaction_date'),
      ...?_purchaseOrderFilters(_purchaseOrderStatus),
    ];
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
      orderBy: 'modified desc, name desc',
      filters: filters,
      orFilters: _searchFilters(_purchaseOrderSearch, const [
        'name',
        'supplier',
        'supplier_name',
      ]),
    );

    var orders = data.map((item) => PurchaseOrder.fromJson(item)).toList();
    orders = await _attachPurchaseOrderItems(orders);
    return orders;
  }

  Future<List<PurchaseReceipt>> _fetchPurchaseReceiptPage({
    required int limitStart,
  }) async {
    final filters = <List<dynamic>>[
      ..._buyingPeriodFilters('posting_date'),
      ...?_statusFilters(_purchaseReceiptStatus),
    ];
    final data = await _fetchResourceWithFieldFallback(
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
      limit: _documentPageSize,
      limitStart: limitStart,
      orderBy: 'posting_date desc, name desc',
      filters: filters,
      orFilters: _searchFilters(_purchaseReceiptSearch, const [
        'name',
        'supplier',
        'supplier_name',
      ]),
    );
    return data.map(PurchaseReceipt.fromJson).toList();
  }

  Future<List<PurchaseInvoice>> _fetchPurchaseInvoicePage({
    required int limitStart,
  }) async {
    final filters = <List<dynamic>>[
      ..._buyingPeriodFilters('posting_date'),
      ...?_statusFilters(_purchaseInvoiceStatus),
    ];
    final data = await _fetchResourceWithFieldFallback(
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
      limit: _documentPageSize,
      limitStart: limitStart,
      orderBy: 'posting_date desc, name desc',
      filters: filters,
      orFilters: _searchFilters(_purchaseInvoiceSearch, const [
        'name',
        'supplier',
        'supplier_name',
      ]),
    );
    return data.map(PurchaseInvoice.fromJson).toList();
  }

  List<List<dynamic>>? _purchaseOrderFilters(String? status) {
    if (status != 'Delayed') return _statusFilters(status);
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return [
      ['schedule_date', '<', today],
      [
        'status',
        'not in',
        ['Draft', 'Completed', 'Closed', 'Cancelled'],
      ],
    ];
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
    required int? maxRows,
  }) async {
    return walkFrappePages(
      pageSize: _frappePageSize,
      maxRows: maxRows,
      fetchPage: (start, limit) => _fetchResourceWithFieldFallback(
        doctype: doctype,
        fields: fields,
        limit: limit,
        limitStart: start,
        orderBy: orderBy,
        filters: filters,
      ),
    );
  }

  static List<Map<String, dynamic>> _documentChildRows(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<Map<String, Map<String, dynamic>>> _fetchDocumentsInBatches(
    String doctype,
    Iterable<String> names, {
    int batchSize = 8,
  }) async {
    final uniqueNames = names.where((name) => name.isNotEmpty).toSet().toList();
    final documents = <String, Map<String, dynamic>>{};
    for (var start = 0; start < uniqueNames.length; start += batchSize) {
      final end = start + batchSize > uniqueNames.length
          ? uniqueNames.length
          : start + batchSize;
      final batch = uniqueNames.sublist(start, end);
      final results = await Future.wait(
        batch.map((name) async {
          try {
            return (
              name: name,
              document: await _frappeService.fetchDocument(doctype, name),
            );
          } catch (_) {
            return (name: name, document: null);
          }
        }),
      );
      for (final result in results) {
        final document = result.document;
        if (document != null) documents[result.name] = document;
      }
    }
    return documents;
  }

  Future<void> _forEachResourcePage({
    required String doctype,
    required List<String> fields,
    required void Function(Map<String, dynamic> row) onRow,
    String? orderBy,
    List<List<dynamic>>? filters,
  }) async {
    final progressBase = _summaryProcessedRows;
    await walkFrappePages(
      pageSize: _frappePageSize,
      onRow: onRow,
      onProgress: (processed) {
        _summaryProcessedRows = progressBase + processed;
        notifyListeners();
      },
      fetchPage: (start, limit) => _fetchResourceWithFieldFallback(
        doctype: doctype,
        fields: fields,
        limit: limit,
        limitStart: start,
        orderBy: orderBy ?? 'name asc',
        filters: filters,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchResourceWithFieldFallback({
    required String doctype,
    required List<String> fields,
    required int limit,
    int limitStart = 0,
    String? orderBy,
    List<List<dynamic>>? filters,
    List<List<dynamic>>? orFilters,
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
          orFilters: orFilters,
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

  Future<Map<String, double>> _fetchItemBuyingRates(
    Set<String> itemCodes,
  ) async {
    if (itemCodes.isEmpty) return {};

    final codes = itemCodes.toList();
    final rates = <String, double>{};

    for (var i = 0; i < codes.length; i += 80) {
      final chunk = codes.sublist(
        i,
        i + 80 > codes.length ? codes.length : i + 80,
      );

      try {
        final data = await _fetchResourceWithFieldFallback(
          doctype: 'Item Price',
          fields: const [
            'name',
            'item_code',
            'price_list',
            'price_list_rate',
            'currency',
          ],
          limit: chunk.length * 3,
          orderBy: 'valid_from desc, modified desc',
          filters: [
            ['item_code', 'in', chunk],
            ['buying', '=', 1],
            ['price_list_rate', '>', 0],
          ],
        );
        _addItemPriceRates(rates, data);
      } catch (_) {
        try {
          final data = await _fetchResourceWithFieldFallback(
            doctype: 'Item Price',
            fields: const ['name', 'item_code', 'price_list_rate'],
            limit: chunk.length * 3,
            orderBy: 'modified desc',
            filters: [
              ['item_code', 'in', chunk],
              ['price_list_rate', '>', 0],
            ],
          );
          _addItemPriceRates(rates, data);
        } catch (_) {}
      }
    }

    return rates;
  }

  void _addItemPriceRates(
    Map<String, double> rates,
    List<Map<String, dynamic>> rows,
  ) {
    for (final row in rows) {
      final code = row['item_code']?.toString() ?? '';
      final rate = NumParse.asDouble(row['price_list_rate']);
      if (code.isEmpty || rate <= 0) continue;
      rates.putIfAbsent(code, () => rate);
    }
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
