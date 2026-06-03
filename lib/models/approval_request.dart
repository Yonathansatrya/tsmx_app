class ApprovalRequest {
  final String id;
  final String documentType;
  final String documentName;
  final String workflowState;
  final String status;
  final String action;
  final String assignedUser;
  final DateTime? modifiedAt;

  const ApprovalRequest({
    required this.id,
    required this.documentType,
    required this.documentName,
    required this.workflowState,
    required this.status,
    required this.action,
    required this.assignedUser,
    this.modifiedAt,
  });

  factory ApprovalRequest.fromWorkflowAction(Map<String, dynamic> json) {
    return ApprovalRequest(
      id: json['name']?.toString() ?? '',
      documentType:
          json['reference_doctype']?.toString() ??
          json['document_type']?.toString() ??
          '',
      documentName:
          json['reference_name']?.toString() ??
          json['document_name']?.toString() ??
          '',
      workflowState:
          json['workflow_state']?.toString() ?? json['state']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Open',
      action: json['action']?.toString() ?? '',
      assignedUser: json['user']?.toString() ?? '',
      modifiedAt: _parseDate(json['modified'] ?? json['creation']),
    );
  }

  bool get hasDocument => documentType.isNotEmpty && documentName.isNotEmpty;

  String get timeLabel {
    final value = modifiedAt;
    if (value == null) return '';

    final local = value.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }
}
