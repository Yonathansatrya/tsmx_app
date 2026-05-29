import '../utils/frappe_status.dart';
import '../utils/num_parse.dart';

class MaterialRequest {
  final String id;
  final String materialRequestType;
  final String statusText;
  final int docStatus;
  final String date;
  final int itemsCount;

  MaterialRequest({
    required this.id,
    required this.materialRequestType,
    required this.statusText,
    this.docStatus = 0,
    required this.date,
    required this.itemsCount,
  });

  factory MaterialRequest.fromJson(Map<String, dynamic> json) {
    final docstatus = NumParse.asInt(json['docstatus']);
    return MaterialRequest(
      id: json['name']?.toString() ?? 'UNKNOWN',
      materialRequestType: json['material_request_type']?.toString() ?? '',
      statusText: normalizeStatusText(
        json['status']?.toString(),
        docstatus: docstatus,
      ),
      docStatus: docstatus,
      date: json['transaction_date']?.toString() ?? '',
      itemsCount: NumParse.asInt(json['total_qty']),
    );
  }
}
