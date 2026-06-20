import '../utils/num_parse.dart';

class DeliveryActivityLog {
  final String id;
  final String deliveryNote;
  final String customer;
  final String driver;
  final String activityStatus;
  final String notes;
  final String capturedAt;
  final String latitude;
  final String longitude;
  final double accuracy;

  const DeliveryActivityLog({
    required this.id,
    required this.deliveryNote,
    required this.customer,
    required this.driver,
    required this.activityStatus,
    required this.notes,
    required this.capturedAt,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  factory DeliveryActivityLog.fromJson(Map<String, dynamic> json) {
    return DeliveryActivityLog(
      id: json['name']?.toString() ?? '',
      deliveryNote: json['delivery_note']?.toString() ?? '',
      customer: json['customer']?.toString() ?? '',
      driver: json['driver']?.toString() ?? '',
      activityStatus: json['activity_status']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      capturedAt: json['captured_at']?.toString() ?? '',
      latitude: json['latitude']?.toString() ?? '',
      longitude: json['longitude']?.toString() ?? '',
      accuracy: NumParse.asDouble(json['accuracy']),
    );
  }
}
