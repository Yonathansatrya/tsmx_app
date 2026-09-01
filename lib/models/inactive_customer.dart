import '../utils/num_parse.dart';

class InactiveCustomer {
  final String documentType;
  final String customer;
  final String customerName;
  final String customerGroup;
  final String territory;
  final String lastOrder;
  final String lastOrderDate;
  final int daysSinceLastOrder;
  final double totalOrderValue;

  const InactiveCustomer({
    required this.documentType,
    required this.customer,
    required this.customerName,
    required this.customerGroup,
    required this.territory,
    required this.lastOrder,
    required this.lastOrderDate,
    required this.daysSinceLastOrder,
    required this.totalOrderValue,
  });

  factory InactiveCustomer.fromReportRow(
    Map<String, dynamic> row, {
    required String documentType,
  }) {
    String text(List<String> keys) {
      for (final key in keys) {
        final value =
            row[key] ?? row[_snakeToTitle(key)] ?? row[key.toUpperCase()];
        final trimmed = value?.toString().trim() ?? '';
        if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'null') {
          return trimmed;
        }
      }
      return '';
    }

    final customer = text(['customer', 'Customer', 'name']);
    return InactiveCustomer(
      documentType: documentType,
      customer: customer,
      customerName: text(['customer_name', 'Customer Name', 'customer']),
      customerGroup: text(['customer_group', 'Customer Group']),
      territory: text(['territory', 'Territory']),
      lastOrder: text([
        'last_order',
        'last_sales_order',
        'sales_order',
        'Last Order',
        'Last Sales Order',
      ]),
      lastOrderDate: text([
        'last_order_date',
        'last_sales_order_date',
        'transaction_date',
        'Last Order Date',
      ]),
      daysSinceLastOrder: NumParse.asDouble(
        row['days_since_last_order'] ??
            row['Days Since Last Order'] ??
            row['days'] ??
            row['Days'],
      ).round(),
      totalOrderValue: NumParse.asDouble(
        row['total_order_value'] ??
            row['Total Order Value'] ??
            row['grand_total'] ??
            row['Grand Total'],
      ),
    );
  }

  bool get hasLastOrder => lastOrder.isNotEmpty || lastOrderDate.isNotEmpty;

  String get displayName {
    if (customerName.isNotEmpty) return customerName;
    if (customer.isNotEmpty) return customer;
    return 'Customer';
  }
}

String _snakeToTitle(String value) {
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
