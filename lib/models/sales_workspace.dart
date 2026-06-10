import '../utils/num_parse.dart';

class SalesCustomerOption {
  final String id;
  final String name;
  final String address;
  final List<Map<String, dynamic>> salesTeam;

  const SalesCustomerOption({
    required this.id,
    required this.name,
    this.address = '',
    this.salesTeam = const [],
  });

  factory SalesCustomerOption.fromJson(Map<String, dynamic> json) {
    final id = json['name']?.toString() ?? '';
    return SalesCustomerOption(
      id: id,
      name: json['customer_name']?.toString() ?? id,
      address: json['primary_address']?.toString() ?? '',
      salesTeam: const [],
    );
  }

  SalesCustomerOption copyWithSalesTeam(List<Map<String, dynamic>> rows) {
    return SalesCustomerOption(
      id: id,
      name: name,
      address: address,
      salesTeam: rows,
    );
  }
}

class PromiseToPay {
  final String id;
  final String customer;
  final String salesPerson;
  final String salesInvoice;
  final double amount;
  final String promiseDate;
  final String notes;
  final String status;

  const PromiseToPay({
    required this.id,
    required this.customer,
    required this.salesPerson,
    this.salesInvoice = '',
    required this.amount,
    required this.promiseDate,
    this.notes = '',
    this.status = 'Pending',
  });

  factory PromiseToPay.fromJson(Map<String, dynamic> json) {
    return PromiseToPay(
      id: json['name']?.toString() ?? '',
      customer: json['customer']?.toString() ?? '',
      salesPerson: json['sales_person']?.toString() ?? '',
      salesInvoice: json['sales_invoice']?.toString() ?? '',
      amount: NumParse.asDouble(json['amount']),
      promiseDate: json['promise_date']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
    );
  }
}

class CollectionRanking {
  final String salesPerson;
  final double amount;
  final int rank;

  const CollectionRanking({
    required this.salesPerson,
    required this.amount,
    required this.rank,
  });

  factory CollectionRanking.fromJson(Map<String, dynamic> json) {
    return CollectionRanking(
      salesPerson:
          json['owner']?.toString() ??
          json['sales_person']?.toString() ??
          json['name']?.toString() ??
          'Unknown',
      amount: NumParse.asDouble(
        json['amount'] ?? json['collected_amount'] ?? json['total'],
      ),
      rank: NumParse.asInt(json['rank']),
    );
  }
}

class SalesVisit {
  final String id;
  final String customer;
  final String salesPerson;
  final String checkInTime;
  final String checkOutTime;
  final String status;
  final String notes;
  final List<Map<String, dynamic>> competitors;
  final List<Map<String, dynamic>> potentialOrders;

  const SalesVisit({
    required this.id,
    required this.customer,
    required this.salesPerson,
    required this.checkInTime,
    this.checkOutTime = '',
    this.status = 'Checked In',
    this.notes = '',
    this.competitors = const [],
    this.potentialOrders = const [],
  });

  factory SalesVisit.fromJson(Map<String, dynamic> json) {
    return SalesVisit(
      id: json['name']?.toString() ?? '',
      customer: json['customer']?.toString() ?? '',
      salesPerson: json['sales_person']?.toString() ?? '',
      checkInTime: json['check_in_time']?.toString() ?? '',
      checkOutTime: json['check_out_time']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Checked In',
      notes: json['notes']?.toString() ?? '',
      competitors: _mapRows(json['competitors']),
      potentialOrders: _mapRows(json['potential_orders']),
    );
  }

  static List<Map<String, dynamic>> _mapRows(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
}
