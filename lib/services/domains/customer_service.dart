import '../../models/sales_order_insight.dart';
import '../../models/sales_workspace.dart';
import '../../utils/num_parse.dart';
import '../frappe_service.dart';

class CustomerService {
  final FrappeService _frappe;

  CustomerService(this._frappe);

  Future<List<SalesCustomerOption>> fetchSalesCustomers({
    String? salesPerson,
  }) async {
    List<Map<String, dynamic>> assignedTeam = const [];
    if (salesPerson?.isNotEmpty == true) {
      assignedTeam = await _frappe.fetchResource(
        'Sales Team',
        fields: const [
          'parent',
          'parenttype',
          'sales_person',
          'allocated_percentage',
          'commission_rate',
        ],
        filters: [
          ['parenttype', '=', 'Customer'],
          ['sales_person', '=', salesPerson],
        ],
      );
    }
    final customerIds = assignedTeam
        .map((row) => row['parent']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    if (salesPerson?.isNotEmpty == true && customerIds.isEmpty) return const [];

    var teamRows = assignedTeam;
    if (customerIds.isNotEmpty) {
      teamRows = await _frappe.fetchResource(
        'Sales Team',
        fields: const [
          'parent',
          'parenttype',
          'sales_person',
          'allocated_percentage',
          'commission_rate',
        ],
        filters: [
          ['parenttype', '=', 'Customer'],
          ['parent', 'in', customerIds.toList()],
        ],
      );
    }
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
    final customers = rows
        .map(SalesCustomerOption.fromJson)
        .where((customer) => customer.id.isNotEmpty)
        .toList();
    if (salesPerson?.isNotEmpty != true) return customers;

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in teamRows) {
      final parent = row['parent']?.toString() ?? '';
      if (parent.isEmpty) continue;
      grouped.putIfAbsent(parent, () => []).add({
        'sales_person': row['sales_person'],
        'allocated_percentage':
            NumParse.asDouble(row['allocated_percentage']) > 0
            ? NumParse.asDouble(row['allocated_percentage'])
            : 100,
        if (row['commission_rate'] != null)
          'commission_rate': row['commission_rate'],
      });
    }
    return customers
        .map(
          (customer) => customer.copyWithSalesTeam(grouped[customer.id] ?? []),
        )
        .toList();
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

    return CustomerSalesInsight(
      creditLimit: creditLimit,
      outstanding: invoices.fold(
        0,
        (sum, row) => sum + NumParse.asDouble(row['outstanding_amount']),
      ),
      company: company ?? '',
      currency: companyCurrency,
      priceList: priceList,
      priceListCurrency: priceListCurrency,
    );
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
