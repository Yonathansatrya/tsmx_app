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

class CustomerVisitLocation {
  final String addressId;
  final String displayAddress;
  final double latitude;
  final double longitude;
  final double geofenceRadius;

  const CustomerVisitLocation({
    required this.addressId,
    required this.displayAddress,
    required this.latitude,
    required this.longitude,
    this.geofenceRadius = 50,
  });

  bool get isConfigured => latitude != 0 || longitude != 0;
}

class SalesTrackingPoint {
  final String id;
  final String salesVisit;
  final String salesPerson;
  final String customer;
  final DateTime? capturedAt;
  final double latitude;
  final double longitude;
  final double accuracy;

  const SalesTrackingPoint({
    required this.id,
    required this.salesVisit,
    required this.salesPerson,
    required this.customer,
    required this.capturedAt,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  factory SalesTrackingPoint.fromJson(Map<String, dynamic> json) {
    return SalesTrackingPoint(
      id: json['name']?.toString() ?? '',
      salesVisit: json['sales_visit']?.toString() ?? '',
      salesPerson: json['sales_person']?.toString() ?? '',
      customer: json['customer']?.toString() ?? '',
      capturedAt: DateTime.tryParse(json['captured_at']?.toString() ?? ''),
      latitude: NumParse.asDouble(json['latitude']),
      longitude: NumParse.asDouble(json['longitude']),
      accuracy: NumParse.asDouble(json['accuracy']),
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

class CollectionPayment {
  final String id;
  final String customer;
  final String customerName;
  final String postingDate;
  final double amount;
  final String referenceNo;
  final String remarks;
  final List<CollectionPaymentReference> references;

  const CollectionPayment({
    required this.id,
    required this.customer,
    required this.customerName,
    required this.postingDate,
    required this.amount,
    this.referenceNo = '',
    this.remarks = '',
    this.references = const [],
  });

  factory CollectionPayment.fromJson(Map<String, dynamic> json) {
    final customer = json['party']?.toString() ?? '';
    return CollectionPayment(
      id: json['name']?.toString() ?? '',
      customer: customer,
      customerName: json['party_name']?.toString() ?? customer,
      postingDate: json['posting_date']?.toString() ?? '',
      amount: NumParse.asDouble(json['received_amount'] ?? json['paid_amount']),
      referenceNo: json['reference_no']?.toString() ?? '',
      remarks: json['remarks']?.toString() ?? '',
    );
  }

  CollectionPayment copyWithReferences(
    List<CollectionPaymentReference> references,
  ) {
    return CollectionPayment(
      id: id,
      customer: customer,
      customerName: customerName,
      postingDate: postingDate,
      amount: amount,
      referenceNo: referenceNo,
      remarks: remarks,
      references: references,
    );
  }
}

class CollectionPaymentReference {
  final String doctype;
  final String documentName;
  final double allocatedAmount;

  const CollectionPaymentReference({
    required this.doctype,
    required this.documentName,
    required this.allocatedAmount,
  });

  factory CollectionPaymentReference.fromJson(Map<String, dynamic> json) {
    return CollectionPaymentReference(
      doctype: json['reference_doctype']?.toString() ?? '',
      documentName: json['reference_name']?.toString() ?? '',
      allocatedAmount: NumParse.asDouble(json['allocated_amount']),
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
  final String journeyStartTime;
  final String address;
  final double targetLatitude;
  final double targetLongitude;
  final double checkInLatitude;
  final double checkInLongitude;
  final double checkOutLatitude;
  final double checkOutLongitude;
  final double checkInDistance;
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
    this.journeyStartTime = '',
    this.address = '',
    this.targetLatitude = 0,
    this.targetLongitude = 0,
    this.checkInLatitude = 0,
    this.checkInLongitude = 0,
    this.checkOutLatitude = 0,
    this.checkOutLongitude = 0,
    this.checkInDistance = 0,
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
      journeyStartTime: json['journey_start_time']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      targetLatitude: NumParse.asDouble(json['target_latitude']),
      targetLongitude: NumParse.asDouble(json['target_longitude']),
      checkInLatitude: NumParse.asDouble(json['check_in_latitude']),
      checkInLongitude: NumParse.asDouble(json['check_in_longitude']),
      checkOutLatitude: NumParse.asDouble(json['check_out_latitude']),
      checkOutLongitude: NumParse.asDouble(json['check_out_longitude']),
      checkInDistance: NumParse.asDouble(json['check_in_distance']),
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
