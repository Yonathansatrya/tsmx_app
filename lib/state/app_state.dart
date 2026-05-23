import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sales_order.dart';
import '../models/purchase_order.dart';
import '../models/inventory_item.dart';
import '../models/action_item.dart';
import '../services/frappe_service.dart';

class AppState with ChangeNotifier {
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  String? _currentUser;
  String? get currentUser => _currentUser;

  bool _rememberDevice = false;
  bool get rememberDevice => _rememberDevice;

  String _optimizationStepMessage = '';
  String get optimizationStepMessage => _optimizationStepMessage;

  String _selectedWarehouseId = 'jakarta';
  String get selectedWarehouseId => _selectedWarehouseId;

  List<SalesOrder> _salesOrders = [];
  List<PurchaseOrder> _purchaseOrders = [];
  List<InventoryItem> _inventory = [];
  List<ActionItem> _actionRequired = [];

  List<SalesOrder> get salesOrders => _salesOrders;
  List<PurchaseOrder> get purchaseOrders => _purchaseOrders;
  List<InventoryItem> get inventory => _inventory;
  List<ActionItem> get actionRequired => _actionRequired;

  bool _isSalesOrdersLoading = false;
  bool get isSalesOrdersLoading => _isSalesOrdersLoading;

  String? _salesOrdersError;
  String? get salesOrdersError => _salesOrdersError;

  bool _isPurchaseOrdersLoading = false;
  bool get isPurchaseOrdersLoading => _isPurchaseOrdersLoading;

  String? _purchaseOrdersError;
  String? get purchaseOrdersError => _purchaseOrdersError;

  bool _isInventoryLoading = false;
  bool get isInventoryLoading => _isInventoryLoading;

  String? _inventoryError;
  String? get inventoryError => _inventoryError;

  static const String _defaultFrappeBaseUrl = 'http://apps.willshine.id:8014';
  static const String _prefsFrappeConfigKey = 'frappe_config';
  static const String _prefsFrappeCookiesKey = 'frappe_cookies';
  static const String _prefsWarehouseMapKey = 'warehouse_mappings';

  Map<String, String> _warehouseMappings = {};
  final FrappeService _frappeService = FrappeService();

  Future<void> _loadPersistedWarehouseMappings() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_prefsWarehouseMapKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _warehouseMappings = decoded.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
  }

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

  Timer? _fleetTimer;

  AppState() {
    _loadInitialMockData();
    () async {
      await _loadPersistedWarehouseMappings();
      await _restoreFrappeConfig();
      await _fetchInitialFromFrappe();
    }();
  }

  void setRememberDevice(bool value) {
    _rememberDevice = value;
    notifyListeners();
  }

  void selectWarehouse(String warehouseId) {
    _selectedWarehouseId = warehouseId;
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
      notifyListeners();
      return true;
    } catch (_) {
      _isAuthenticated = false;
      _currentUser = null;
      notifyListeners();
      return false;
    }
  }

  void loginWithBadge(String badgeId, String employeeName) {
    _isAuthenticated = true;
    _currentUser = employeeName;
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    _currentUser = null;
    notifyListeners();
  }

  Future<void> fetchSalesOrdersFromFrappe({
    String baseUrl = _defaultFrappeBaseUrl,
    String? username,
    String? password,
    int limit = 50,
  }) async {
    _isSalesOrdersLoading = true;
    _salesOrdersError = null;
    notifyListeners();

    try {
      _frappeService.baseUrl = baseUrl;
      if (username != null && password != null) {
        await _frappeService.login(username, password);
      } else {
        await _frappeService.ensureLoggedIn();
      }

      final data = await _frappeService.fetchResource(
        'Sales Order',
        fields: [
          'name',
          'customer',
          'customer_name',
          'grand_total',
          'status',
          'transaction_date',
          'total_qty',
        ],
        limit: limit,
        orderBy: 'transaction_date desc',
      );

      _salesOrders = data.map((item) => SalesOrder.fromJson(item)).toList();
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
    int limit = 50,
  }) async {
    _frappeService.baseUrl = baseUrl;
    _isPurchaseOrdersLoading = true;
    _purchaseOrdersError = null;
    notifyListeners();

    try {
      if (username != null && password != null) {
        await _frappeService.login(username, password);
      } else {
        await _frappeService.ensureLoggedIn();
      }

      final data = await _frappeService.fetchResource(
        'Purchase Order',
        fields: [
          'name',
          'supplier',
          'supplier_name',
          'status',
          'expected_delivery_date',
          'total_qty',
          'rounded_total',
        ],
        limit: limit,
        orderBy: 'creation desc',
      );

      _purchaseOrders = data
          .map((item) => PurchaseOrder.fromJson(item))
          .toList();
    } catch (err) {
      _purchaseOrdersError = err.toString();
    } finally {
      _isPurchaseOrdersLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchInventoryFromFrappe({
    String baseUrl = _defaultFrappeBaseUrl,
    String? username,
    String? password,
    int limit = 1000,
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

      final data = await _frappeService.fetchResource(
        'Bin',
        fields: ['item_code', 'item_name', 'warehouse', 'actual_qty'],
        limit: limit,
        filters: filters,
      );

      final List<InventoryItem> items = [];
      for (final rawItem in data) {
        final inv = InventoryItem.fromJson(rawItem);
        final rawWarehouse =
            rawItem['warehouse']?.toString() ??
            rawItem['warehouse_id']?.toString() ??
            '';
        final normalized = _mapWarehouseId(rawWarehouse);
        items.add(inv.copyWith(warehouseId: normalized));
      }
      _inventory = items;
      notifyListeners();
    } catch (err) {
      _inventoryError = err.toString();
    } finally {
      _isInventoryLoading = false;
      notifyListeners();
    }
  }

  // Fetch initial data from Frappe (fire-and-forget on init)
  Future<void> _fetchInitialFromFrappe() async {
    try {
      final cfg = await _loadFrappeConfig();
      if (cfg == null || !cfg.containsKey('username')) return;

      await fetchSalesOrdersFromFrappe(
        baseUrl: cfg['baseUrl'] ?? _defaultFrappeBaseUrl,
        username: cfg['username'],
        password: cfg['password'],
      );
      await fetchPurchaseOrdersFromFrappe(
        baseUrl: cfg['baseUrl'] ?? _defaultFrappeBaseUrl,
        username: cfg['username'],
        password: cfg['password'],
      );
      await fetchInventoryFromFrappe(
        baseUrl: cfg['baseUrl'] ?? _defaultFrappeBaseUrl,
        username: cfg['username'],
        password: cfg['password'],
      );
    } catch (_) {
      // ignore errors during init
    }
  }

  Future<void> refreshSalesOrders() => fetchSalesOrdersFromFrappe();
  Future<void> refreshPurchaseOrders() => fetchPurchaseOrdersFromFrappe();
  Future<void> refreshInventory() => fetchInventoryFromFrappe();

  Future<void> refreshInventoryForWarehouse(String warehousePrefix) =>
      fetchInventoryFromFrappe(
        filters: [
          ['Bin', 'warehouse', 'like', '$warehousePrefix%'],
        ],
      );

  Future<void> saveFrappeConfig({
    required String baseUrl,
    required String username,
    String? password,
    bool savePassword = false,
  }) async {
    final sp = await SharedPreferences.getInstance();
    final cfg = {
      'baseUrl': baseUrl,
      'username': username,
      if (savePassword && password != null) 'password': password,
    };
    await sp.setString(_prefsFrappeConfigKey, jsonEncode(cfg));

    _frappeService.baseUrl = baseUrl;
    _frappeService.username = username;
    if (savePassword && password != null) {
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

  String _mapWarehouseId(String raw) {
    if (raw.isEmpty) return '';
    if (_warehouseMappings.containsKey(raw)) return _warehouseMappings[raw]!;
    final low = raw.toLowerCase();
    if (_warehouseMappings.containsKey(low)) return _warehouseMappings[low]!;
    return low
        .replaceAll(RegExp(r"[^a-z0-9_]"), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }

  // Add Purchase Order Action
  void addPurchaseOrder({
    required String vendor,
    required int itemsCount,
    required double totalValue,
    required String eta,
  }) {
    final nextId = 'PO-${10000 + _purchaseOrders.length + 1}';
    final newOrder = PurchaseOrder(
      id: nextId,
      vendor: vendor,
      status: PurchaseOrderStatus.pendingApproval,
      eta: eta,
      itemsCount: itemsCount,
      totalValue: totalValue,
    );
    _purchaseOrders.insert(0, newOrder);

    // Also add to Action Required
    _actionRequired.insert(
      0,
      ActionItem(
        id: 'ACT-${5000 + _actionRequired.length + 1}',
        title: 'Approve $nextId',
        description:
            'New Purchase Order created for $vendor requires authorization.',
        type: ActionType.action,
        timeString: 'Just now',
      ),
    );
    notifyListeners();
  }

  void approvePurchaseOrder(String poId) {
    final idx = _purchaseOrders.indexWhere((p) => p.id == poId);
    if (idx != -1) {
      _purchaseOrders[idx] = _purchaseOrders[idx].copyWith(
        status: PurchaseOrderStatus.inTransit,
      );
      // Remove corresponding action
      _actionRequired.removeWhere((a) => a.title.contains(poId));
      notifyListeners();
    }
  }

  void dismissActionItem(String actionId) {
    _actionRequired.removeWhere((a) => a.id == actionId);
    notifyListeners();
  }

  @override
  void dispose() {
    _fleetTimer?.cancel();
    super.dispose();
  }

  // Pre-load data helper
  void _loadInitialMockData() {
    _salesOrders = [
      SalesOrder(
        id: 'SO-1001',
        customer: 'PT. Alpha',
        value: 12500000,
        status: SalesOrderStatus.pending,
        date: '2026-05-10',
        itemsCount: 3,
      ),
      SalesOrder(
        id: 'SO-1002',
        customer: 'CV. Beta',
        value: 2450000,
        status: SalesOrderStatus.shipped,
        date: '2026-05-11',
        itemsCount: 2,
      ),
      SalesOrder(
        id: 'SO-1003',
        customer: 'PT. Gamma',
        value: 980000,
        status: SalesOrderStatus.delivered,
        date: '2026-05-09',
        itemsCount: 1,
      ),
      SalesOrder(
        id: 'SO-1004',
        customer: 'UD. Delta',
        value: 4500000,
        status: SalesOrderStatus.pending,
        date: '2026-05-12',
        itemsCount: 4,
      ),
      SalesOrder(
        id: 'SO-1005',
        customer: 'PT. Epsilon',
        value: 15300000,
        status: SalesOrderStatus.to_bill,
        date: '2026-05-08',
        itemsCount: 6,
      ),
      SalesOrder(
        id: 'SO-1006',
        customer: 'PT. Zeta',
        value: 2100000,
        status: SalesOrderStatus.draft,
        date: '2026-05-07',
        itemsCount: 2,
      ),
      SalesOrder(
        id: 'SO-1007',
        customer: 'CV. Eta',
        value: 670000,
        status: SalesOrderStatus.completed,
        date: '2026-05-06',
        itemsCount: 1,
      ),
      SalesOrder(
        id: 'SO-1008',
        customer: 'PT. Theta',
        value: 3050000,
        status: SalesOrderStatus.shipped,
        date: '2026-05-05',
        itemsCount: 3,
      ),
    ];

    _purchaseOrders = [
      PurchaseOrder(
        id: 'PO-90214',
        vendor: 'Steel Alloys Corp',
        status: PurchaseOrderStatus.pendingApproval,
        eta: '2026-05-24',
        itemsCount: 50,
        totalValue: 120000000,
      ),
      PurchaseOrder(
        id: 'PO-90215',
        vendor: 'Sinotech Electronics',
        status: PurchaseOrderStatus.inTransit,
        eta: '2026-05-23',
        itemsCount: 200,
        totalValue: 340000000,
      ),
      PurchaseOrder(
        id: 'PO-90216',
        vendor: 'Paper Products Ltd',
        status: PurchaseOrderStatus.delayed,
        eta: '2026-05-22',
        itemsCount: 1500,
        totalValue: 45000000,
      ),
      PurchaseOrder(
        id: 'PO-90217',
        vendor: 'Global Logistics Parts',
        status: PurchaseOrderStatus.completed,
        eta: '2026-05-20',
        itemsCount: 35,
        totalValue: 18500000,
      ),
      PurchaseOrder(
        id: 'PO-90218',
        vendor: 'Nippon Polymers',
        status: PurchaseOrderStatus.inTransit,
        eta: '2026-05-26',
        itemsCount: 80,
        totalValue: 92000000,
      ),
      PurchaseOrder(
        id: 'PO-90219',
        vendor: 'TexChem Indonesia',
        status: PurchaseOrderStatus.completed,
        eta: '2026-05-18',
        itemsCount: 120,
        totalValue: 63000000,
      ),
    ];

    _inventory = [
      InventoryItem(
        sku: 'BRG-001',
        name: 'Pisang Cavendish Incoming',
        warehouseId: 'jakarta_inbound',
        quantity: 420,
        minStockThreshold: 100,
        status: StockStatus.inStock,
      ),

      InventoryItem(
        sku: 'BRG-002',
        name: 'Jeruk Mandarin Incoming',
        warehouseId: 'jakarta_inbound',
        quantity: 210,
        minStockThreshold: 80,
        status: StockStatus.inStock,
      ),

      InventoryItem(
        sku: 'BRG-003',
        name: 'Apel Fuji Incoming',
        warehouseId: 'jakarta_inbound',
        quantity: 65,
        minStockThreshold: 70,
        status: StockStatus.lowStock,
      ),

      InventoryItem(
        sku: 'RIP-001',
        name: 'Pisang Cavendish Ripening',
        warehouseId: 'jakarta_ripening',
        quantity: 180,
        minStockThreshold: 90,
        status: StockStatus.inStock,
      ),

      InventoryItem(
        sku: 'RIP-002',
        name: 'Pisang Barangan Ripening',
        warehouseId: 'jakarta_ripening',
        quantity: 55,
        minStockThreshold: 60,
        status: StockStatus.lowStock,
      ),

      InventoryItem(
        sku: 'RIP-003',
        name: 'Alpukat Hass Ripening',
        warehouseId: 'jakarta_ripening',
        quantity: 18,
        minStockThreshold: 40,
        status: StockStatus.urgent,
      ),

      InventoryItem(
        sku: 'STR-001',
        name: 'Pisang Cavendish Ready Sell',
        warehouseId: 'jakarta_stores',
        quantity: 320,
        minStockThreshold: 120,
        status: StockStatus.inStock,
      ),

      InventoryItem(
        sku: 'STR-002',
        name: 'Jeruk Mandarin Ready Sell',
        warehouseId: 'jakarta_stores',
        quantity: 95,
        minStockThreshold: 100,
        status: StockStatus.lowStock,
      ),

      InventoryItem(
        sku: 'STR-003',
        name: 'Anggur Shine Muscat',
        warehouseId: 'jakarta_stores',
        quantity: 22,
        minStockThreshold: 50,
        status: StockStatus.urgent,
      ),

      InventoryItem(
        sku: 'CUR-001',
        name: 'Melon Premium',
        warehouseId: 'curug_stores',
        quantity: 120,
        minStockThreshold: 60,
        status: StockStatus.inStock,
      ),

      InventoryItem(
        sku: 'CUR-002',
        name: 'Semangka Merah',
        warehouseId: 'curug_stores',
        quantity: 35,
        minStockThreshold: 50,
        status: StockStatus.lowStock,
      ),

      InventoryItem(
        sku: 'MDN-001',
        name: 'Pisang Barangan Medan',
        warehouseId: 'medan_stores',
        quantity: 260,
        minStockThreshold: 100,
        status: StockStatus.inStock,
      ),

      InventoryItem(
        sku: 'MDN-002',
        name: 'Durian Kupas Frozen',
        warehouseId: 'medan_stores',
        quantity: 15,
        minStockThreshold: 40,
        status: StockStatus.urgent,
      ),
    ];

    _actionRequired = [
      ActionItem(
        id: 'ACT-5001',
        title: 'Approve PO-90214',
        description:
            'Steel Alloys Corp invoice exceeds standard limit, needs manager sign-off.',
        type: ActionType.action,
        timeString: '2h ago',
      ),
      ActionItem(
        id: 'ACT-5002',
        title: 'Low Stock: TSX-801 (Surabaya)',
        description:
            'Stock level is at 12 units (Threshold: 35). Restock immediately.',
        type: ActionType.warning,
        timeString: '3h ago',
      ),
      ActionItem(
        id: 'ACT-5003',
        title: 'Delayed Shipment Alert',
        description:
            'Purchase Order PO-90216 is delayed at Belawan port due to custom clearance.',
        type: ActionType.warning,
        timeString: '5h ago',
      ),
      ActionItem(
        id: 'ACT-5004',
        title: 'Biometric System Update',
        description:
            'Employee badge authentication system underwent standard maintenance.',
        type: ActionType.info,
        timeString: '1d ago',
      ),
    ];
  }
}
