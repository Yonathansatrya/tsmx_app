import '../../models/sales_order_insight.dart';
import '../../models/sales_workspace.dart';
import '../../utils/num_parse.dart';
import '../frappe_service.dart';

class CustomerService {
  final FrappeService _frappe;

  CustomerService(this._frappe);

  Future<CustomerVisitLocation> fetchVisitLocation(String customer) async {
    final customerDoc = await _frappe.fetchDocument('Customer', customer);
    final addressId =
        customerDoc['customer_primary_address']?.toString().trim() ?? '';
    Map<String, dynamic> address = const {};
    if (addressId.isNotEmpty) {
      address = await _frappe.fetchDocument('Address', addressId);
    }
    final latitude = _coordinate(
      address['custom_latitude_text'],
      address['custom_visit_latitude'],
      address['custom_latitude'],
      address['latitude'],
      customerDoc['custom_latitude_text'],
      customerDoc['custom_visit_latitude'],
      customerDoc['custom_latitude'],
      customerDoc['latitude'],
    );
    final longitude = _coordinate(
      address['custom_longitude_text'],
      address['custom_visit_longitude'],
      address['custom_longitude'],
      address['longitude'],
      customerDoc['custom_longitude_text'],
      customerDoc['custom_visit_longitude'],
      customerDoc['custom_longitude'],
      customerDoc['longitude'],
    );
    if (addressId.isEmpty && latitude == 0 && longitude == 0) {
      throw Exception(
        'Customer belum memiliki Primary Address atau koordinat untuk validasi lokasi.',
      );
    }
    if (latitude == 0 && longitude == 0) {
      throw Exception(
        'Koordinat customer belum dikonfigurasi di Primary Address atau Customer.',
      );
    }
    if (latitude < -90 || latitude > 90) {
      throw Exception('Latitude Primary Address harus antara -90 dan 90.');
    }
    if (longitude < -180 || longitude > 180) {
      throw Exception('Longitude Primary Address harus antara -180 dan 180.');
    }
    return CustomerVisitLocation(
      addressId: addressId,
      displayAddress: address['display']?.toString().trim().isNotEmpty == true
          ? address['display'].toString()
          : address['address_title']?.toString().trim().isNotEmpty == true
          ? address['address_title'].toString()
          : customerDoc['customer_name']?.toString() ?? customer,
      latitude: latitude,
      longitude: longitude,
      geofenceRadius:
          NumParse.asDouble(
                address['custom_geofence_radius'] ??
                    customerDoc['custom_geofence_radius'],
              ) >
              0
          ? NumParse.asDouble(
              address['custom_geofence_radius'] ??
                  customerDoc['custom_geofence_radius'],
            )
          : 50,
    );
  }

  double _coordinate(
    dynamic first,
    dynamic second,
    dynamic third,
    dynamic fourth, [
    dynamic fifth,
    dynamic sixth,
    dynamic seventh,
    dynamic eighth,
  ]) {
    for (final value in [
      first,
      second,
      third,
      fourth,
      fifth,
      sixth,
      seventh,
      eighth,
    ]) {
      final text = value?.toString().trim() ?? '';
      if (text.isEmpty) continue;
      final parsed = double.tryParse(text.replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
    return 0;
  }

  Future<List<SalesCustomerOption>> fetchSalesCustomers({
    String? salesPerson,
  }) async {
    if (salesPerson?.trim().isNotEmpty == true) {
      final fromSalesTeamRows = await _fetchCustomersBySalesTeamRows(
        salesPerson!.trim(),
      );
      if (fromSalesTeamRows.isNotEmpty) return fromSalesTeamRows;
      final scoped = await _fetchCustomersByChildTableFilter(
        salesPerson.trim(),
      );
      if (scoped.isNotEmpty) return scoped;
      return _fetchCustomersByDetailSalesTeam(salesPerson.trim());
    }
    return _fetchPermittedCustomers();
  }

  Future<List<SalesCustomerOption>> _fetchCustomersBySalesTeamRows(
    String salesPerson,
  ) async {
    try {
      final rows = await _frappe.fetchResource(
        'Sales Team',
        fields: const [
          'parent',
          'sales_person',
          'allocated_percentage',
          'commission_rate',
        ],
        filters: [
          ['parenttype', '=', 'Customer'],
          ['sales_person', '=', salesPerson],
        ],
        orderBy: 'parent asc',
        limit: 2000,
      );
      final teamByCustomer = <String, List<Map<String, dynamic>>>{};
      for (final rawRow in rows) {
        final customer = rawRow['parent']?.toString().trim() ?? '';
        if (customer.isEmpty) continue;
        teamByCustomer.putIfAbsent(customer, () => []).add({
          'sales_person': salesPerson,
          'allocated_percentage':
              NumParse.asDouble(rawRow['allocated_percentage']) > 0
              ? NumParse.asDouble(rawRow['allocated_percentage'])
              : 100,
          if (rawRow['commission_rate'] != null)
            'commission_rate': rawRow['commission_rate'],
        });
      }
      if (teamByCustomer.isEmpty) return const [];

      final customers = await _fetchPermittedCustomers(
        customerIds: teamByCustomer.keys.toSet(),
      );
      return customers
          .map(
            (customer) => customer.copyWithSalesTeam(
              teamByCustomer[customer.id] ?? const [],
            ),
          )
          .where((customer) => customer.salesTeam.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<SalesCustomerOption>> _fetchCustomersByChildTableFilter(
    String salesPerson,
  ) async {
    try {
      final rows = await _frappe.fetchResource(
        'Customer',
        fields: const ['name', 'customer_name', 'primary_address'],
        filters: [
          ['Sales Team', 'sales_person', '=', salesPerson],
        ],
        orderBy: 'customer_name asc',
        limit: 500,
      );
      return rows
          .map(SalesCustomerOption.fromJson)
          .where((customer) => customer.id.isNotEmpty)
          .map(
            (customer) => customer.copyWithSalesTeam([
              {'sales_person': salesPerson, 'allocated_percentage': 100},
            ]),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<SalesCustomerOption>> _fetchPermittedCustomers({
    Set<String> customerIds = const {},
  }) async {
    final rows = await _frappe.fetchResource(
      'Customer',
      fields: const ['name', 'customer_name', 'primary_address'],
      filters: customerIds.isEmpty
          ? null
          : [
              ['name', 'in', customerIds.toList()],
            ],
      orderBy: 'customer_name asc',
    );
    return rows
        .map(SalesCustomerOption.fromJson)
        .where((customer) => customer.id.isNotEmpty)
        .toList();
  }

  Future<List<SalesCustomerOption>> _fetchCustomersByDetailSalesTeam(
    String salesPerson,
  ) async {
    final customers = await _fetchPermittedCustomers();
    final scoped = <SalesCustomerOption>[];
    for (final customer in customers) {
      try {
        final doc = await _frappe.fetchDocument('Customer', customer.id);
        final salesTeam = doc['sales_team'];
        if (salesTeam is! List) continue;
        final rows = <Map<String, dynamic>>[];
        for (final raw in salesTeam) {
          if (raw is! Map) continue;
          final row = Map<String, dynamic>.from(raw);
          if (row['sales_person']?.toString().trim() != salesPerson) continue;
          rows.add({
            'sales_person': row['sales_person'],
            'allocated_percentage':
                NumParse.asDouble(row['allocated_percentage']) > 0
                ? NumParse.asDouble(row['allocated_percentage'])
                : 100,
            if (row['commission_rate'] != null)
              'commission_rate': row['commission_rate'],
          });
        }
        if (rows.isNotEmpty) scoped.add(customer.copyWithSalesTeam(rows));
      } catch (_) {
        continue;
      }
    }
    return scoped;
  }

  Future<CustomerSalesInsight> fetchSalesInsight(
    String customer, {
    String? company,
  }) async {
    final customerDoc = await _frappe.fetchDocument('Customer', customer);
    final priceList = customerDoc['default_price_list']?.toString() ?? '';
    var companyCurrency = '';
    var priceListCurrency = '';
    if (company?.isNotEmpty == true) {
      try {
        final companyDoc = await _frappe.fetchDocument('Company', company!);
        companyCurrency =
            companyDoc['default_currency']?.toString() ??
            companyDoc['currency']?.toString() ??
            '';
      } catch (_) {}
    }
    if (priceList.isNotEmpty) {
      try {
        final doc = await _frappe.fetchDocument('Price List', priceList);
        priceListCurrency = doc['currency']?.toString() ?? '';
      } catch (_) {}
    }

    var creditLimit = 0.0;
    final creditLimits = customerDoc['credit_limits'];
    if (creditLimits is List) {
      for (final raw in creditLimits) {
        if (raw is! Map) continue;
        if (company?.isNotEmpty != true ||
            raw['company']?.toString() == company) {
          creditLimit += NumParse.asDouble(raw['credit_limit']);
        }
      }
    }
    final invoices = await _frappe.fetchResource(
      'Sales Invoice',
      fields: const ['name', 'outstanding_amount'],
      filters: [
        ['customer', '=', customer],
        if (company?.isNotEmpty == true) ['company', '=', company],
        ['docstatus', '=', 1],
        ['outstanding_amount', '>', 0],
      ],
    );
    final depositBalance = await _fetchCustomerDepositBalance(
      customer,
      company: company,
    );

    return CustomerSalesInsight(
      creditLimit: creditLimit,
      outstanding: invoices.fold(
        0,
        (sum, row) => sum + NumParse.asDouble(row['outstanding_amount']),
      ),
      depositBalance: depositBalance,
      company: company ?? '',
      currency: companyCurrency,
      priceList: priceList,
      priceListCurrency: priceListCurrency,
    );
  }

  Future<double> _fetchCustomerDepositBalance(
    String customer, {
    String? company,
  }) async {
    try {
      final response = await _frappe.callMethod(
        'frappe.desk.query_report.run',
        args: {
          'report_name': 'Accounts Receivable',
          'filters': {
            'report_date': DateTime.now().toIso8601String().split('T').first,
            'ageing_based_on': 'Due Date',
            'range1': 30,
            'range2': 60,
            'range3': 90,
            'range4': 120,
            'customer': customer,
            if (company?.trim().isNotEmpty == true) 'company': company!.trim(),
          },
          'ignore_prepared_report': true,
          'are_default_filters': false,
        },
      );
      final report = _queryReportPayload(response);
      final columns = _queryReportColumns(report?['columns']);
      final rows = _queryReportRows(report?['result'] ?? report?['data']);
      var total = 0.0;
      for (final row in rows) {
        final mapped = _queryReportRowMap(row, columns);
        if (_isQueryReportTotalRow(mapped)) continue;
        final rowCustomer = _firstText(mapped, const [
          'customer',
          'party',
          'customer_name',
          'Customer',
          'Party',
        ]);
        if (rowCustomer.isNotEmpty &&
            rowCustomer != customer &&
            !rowCustomer.toLowerCase().contains(customer.toLowerCase())) {
          continue;
        }
        final outstanding = _firstNumber(mapped, const [
          'outstanding',
          'outstanding_amount',
          'Outstanding Amount',
          'Outstanding',
        ]);
        if (outstanding < 0) total += outstanding.abs();
      }
      return total;
    } catch (_) {
      return _fetchCustomerNegativeInvoiceBalance(customer, company: company);
    }
  }

  Future<double> _fetchCustomerNegativeInvoiceBalance(
    String customer, {
    String? company,
  }) async {
    try {
      final invoices = await _frappe.fetchResource(
        'Sales Invoice',
        fields: const ['name', 'outstanding_amount'],
        filters: [
          ['customer', '=', customer],
          if (company?.trim().isNotEmpty == true) ['company', '=', company],
          ['docstatus', '=', 1],
          ['outstanding_amount', '<', 0],
        ],
      );
      return invoices.fold<double>(
        0,
        (sum, row) => sum + NumParse.asDouble(row['outstanding_amount']).abs(),
      );
    } catch (_) {
      return 0;
    }
  }

  Map<String, dynamic>? _queryReportPayload(dynamic response) {
    if (response is! Map) return null;
    final map = Map<String, dynamic>.from(response);
    final message = map['message'];
    if (message is Map) return Map<String, dynamic>.from(message);
    return map;
  }

  List<Map<String, dynamic>> _queryReportColumns(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((column) {
      if (column is String) return {'label': column, 'fieldname': column};
      if (column is Map) return Map<String, dynamic>.from(column);
      return <String, dynamic>{};
    }).toList();
  }

  List<dynamic> _queryReportRows(dynamic raw) => raw is List ? raw : const [];

  Map<String, dynamic> _queryReportRowMap(
    dynamic row,
    List<Map<String, dynamic>> columns,
  ) {
    if (row is Map<String, dynamic>) return row;
    if (row is Map) return Map<String, dynamic>.from(row);
    if (row is! List) return const {};
    final mapped = <String, dynamic>{};
    for (var i = 0; i < row.length && i < columns.length; i++) {
      final fieldname =
          columns[i]['fieldname']?.toString() ??
          columns[i]['field']?.toString() ??
          columns[i]['label']?.toString() ??
          '';
      final label = columns[i]['label']?.toString() ?? '';
      if (fieldname.isNotEmpty) mapped[fieldname] = row[i];
      if (label.isNotEmpty) mapped[label] = row[i];
    }
    return mapped;
  }

  bool _isQueryReportTotalRow(Map<String, dynamic> row) {
    return row.values.any((value) {
      final text = value?.toString().trim().toLowerCase() ?? '';
      return text == 'total' || text == 'grand total';
    });
  }

  String _firstText(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }

  double _firstNumber(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      if (!row.containsKey(key)) continue;
      final value = NumParse.asDouble(row[key]);
      if (value != 0) return value;
    }
    return 0;
  }

  Future<List<CustomerPurchaseHistory>> fetchPurchaseHistory({
    required String customer,
    required String doctype,
    String? company,
    int offset = 0,
    int limit = 20,
  }) async {
    final isInvoice = doctype == 'Sales Invoice';
    final rows = await _frappe.fetchResource(
      doctype,
      fields: [
        'name',
        isInvoice ? 'posting_date' : 'transaction_date',
        'status',
        'grand_total',
        'total_qty',
        if (isInvoice) 'outstanding_amount',
      ],
      filters: [
        ['customer', '=', customer],
        if (company?.isNotEmpty == true) ['company', '=', company],
      ],
      orderBy:
          '${isInvoice ? 'posting_date' : 'transaction_date'} desc, name desc',
      limitStart: offset,
      limit: limit,
    );
    return rows
        .map(
          (row) => CustomerPurchaseHistory(
            id: row['name']?.toString() ?? '',
            doctype: doctype,
            date:
                row[isInvoice ? 'posting_date' : 'transaction_date']
                    ?.toString() ??
                '',
            status: row['status']?.toString() ?? '',
            total: NumParse.asDouble(row['grand_total']),
            outstanding: NumParse.asDouble(row['outstanding_amount']),
            itemsCount: NumParse.asInt(row['total_qty']),
          ),
        )
        .where((row) => row.id.isNotEmpty)
        .toList();
  }
}
