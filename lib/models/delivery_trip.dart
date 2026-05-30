import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

class DeliveryTrip {
  final String id;
  final String reference;
  final String statusText;
  final int docStatus;
  final String date;
  final double totalDistance;

  DeliveryTrip({
    required this.id,
    required this.reference,
    required this.statusText,
    this.docStatus = 0,
    required this.date,
    required this.totalDistance,
  });

  factory DeliveryTrip.fromJson(Map<String, dynamic> json) {
    final docstatus = NumParse.asInt(json['docstatus']);
    final reference =
        json['vehicle']?.toString() ??
        json['trip_number']?.toString() ??
        json['route']?.toString() ??
        json['reference']?.toString() ??
        '';
    final date =
        json['posting_date']?.toString() ??
        json['departure_date']?.toString() ??
        json['modified']?.toString() ??
        json['creation']?.toString() ??
        '';
    final totalDistance = NumParse.asDouble(
      json['total_distance'] ??
          json['distance'] ??
          json['total_km'] ??
          json['km'] ??
          0,
    );

    return DeliveryTrip(
      id: json['name']?.toString() ?? 'UNKNOWN',
      reference: reference,
      statusText: normalizeStatusText(
        json['status']?.toString(),
        docstatus: docstatus,
      ),
      docStatus: docstatus,
      date: date,
      totalDistance: totalDistance,
    );
  }
}
