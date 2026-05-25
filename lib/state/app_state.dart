import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sales_order.dart';
import '../models/purchase_order.dart';
import '../models/inventory_item.dart';
import '../models/action_item.dart';
import '../services/frappe_service.dart';
import '../utils/warehouse_mapper.dart';

class AppState with ChangeNotifier {
  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  String? _currentUser;
  String? get currentUser => _currentUser;

  bool _rememberDevice = false;
  bool get rememberDevice => _rememberDevice;

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
  // static const String _prefsFrappeCookiesKey = 'frappe_cookies';
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

      final data = await _fetchResourceWithFieldFallback(
        doctype: 'Purchase Order',
        fields: const [
          'name',
          'supplier',
          'supplier_name',
          'status',
          'transaction_date',
          'schedule_date',
          'total_qty',
          'grand_total',
          'creation',
        ],
        limit: limit,
        orderBy: 'modified desc',
      );

      _purchaseOrders = data.map((item) {
        return PurchaseOrder.fromJson(item);
      }).toList();

      _purchaseOrdersError = null;
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

      List<Map<String, dynamic>> data;
      try {
        data = await _fetchResourceWithFieldFallback(
          doctype: 'Bin',
          fields: const ['item_code', 'warehouse', 'actual_qty'],
          limit: limit,
          filters: filters,
        );
      } catch (_) {
        data = await _fetchResourceWithFieldFallback(
          doctype: 'Bin',
          fields: const ['item_code', 'warehouse', 'actual_qty'],
          limit: limit,
        );
      }

      final hubPrefix = filters != null && filters.isNotEmpty
          ? (filters.first.length > 2 ? filters.first[2].toString() : '')
          : '';

      final List<InventoryItem> items = [];
      for (final rawItem in data) {
        final rawWarehouse =
            rawItem['warehouse']?.toString() ??
            rawItem['warehouse_id']?.toString() ??
            '';

        if (hubPrefix.isNotEmpty &&
            !rawWarehouse.toLowerCase().contains(
              hubPrefix.replaceAll('%', '').toLowerCase(),
            )) {
          continue;
        }

        final inv = InventoryItem.fromJson(rawItem);
        final normalized = _mapWarehouseId(rawWarehouse);
        items.add(inv.copyWith(warehouseId: normalized));
      }
      _inventory = items;
      _inventoryError = null;
    } catch (err) {
      _inventoryError = err.toString();
    } finally {
      _isInventoryLoading = false;
      notifyListeners();
    }
  }

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

  Future<void> refreshInventoryForWarehouse(String hubId) =>
      fetchInventoryFromFrappe(
        filters: [
          ['warehouse', 'like', '${WarehouseMapper.hubFilterPrefix(hubId)}%'],
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
    return WarehouseMapper.toAreaId(raw, overrides: _warehouseMappings);
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

  Future<List<Map<String, dynamic>>> _fetchResourceWithFieldFallback({
    required String doctype,
    required List<String> fields,
    required int limit,
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
}
