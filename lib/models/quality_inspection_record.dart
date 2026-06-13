class QualityInspectionRecord {
  final String name;
  final String itemCode;
  final String itemName;
  final String inspectionType;
  final String referenceType;
  final String referenceName;
  final String inspectedBy;
  final String status;
  final String remarks;
  final DateTime? reportDate;

  const QualityInspectionRecord({
    required this.name,
    required this.itemCode,
    required this.itemName,
    required this.inspectionType,
    required this.referenceType,
    required this.referenceName,
    required this.inspectedBy,
    required this.status,
    required this.remarks,
    required this.reportDate,
  });

  factory QualityInspectionRecord.fromJson(Map<String, dynamic> json) =>
      QualityInspectionRecord(
        name: json['name']?.toString() ?? '',
        itemCode: json['item_code']?.toString() ?? '',
        itemName: json['item_name']?.toString() ?? '',
        inspectionType: json['inspection_type']?.toString() ?? '',
        referenceType: json['reference_type']?.toString() ?? '',
        referenceName: json['reference_name']?.toString() ?? '',
        inspectedBy: json['inspected_by']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        remarks: json['remarks']?.toString() ?? '',
        reportDate: DateTime.tryParse(json['report_date']?.toString() ?? ''),
      );
}
