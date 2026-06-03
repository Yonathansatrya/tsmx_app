enum NotificationType { action, warning, info }

class AppNotification {
  final String id;
  final String title;
  final String description;
  final NotificationType type;
  final String timeString;
  final bool isRead;
  final String? documentType;
  final String? documentName;
  final String source;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.timeString,
    this.isRead = false,
    this.documentType,
    this.documentName,
    this.source = 'frappe',
    this.createdAt,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      description: description,
      type: type,
      timeString: timeString,
      isRead: isRead ?? this.isRead,
      documentType: documentType,
      documentName: documentName,
      source: source,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromNotificationLog(Map<String, dynamic> json) {
    final typeRaw =
        json['type']?.toString() ?? json['notification_type']?.toString() ?? '';

    return AppNotification(
      id: json['name']?.toString() ?? '',
      title: json['subject']?.toString().trim().isNotEmpty == true
          ? json['subject'].toString()
          : _defaultTitle(json),
      description: _plainText(
        json['email_content']?.toString() ?? json['message']?.toString() ?? '',
      ),
      type: _mapType(typeRaw, json),
      timeString: _formatTime(json['modified'] ?? json['creation']),
      isRead: json['read'] == 1 || json['read'] == true,
      documentType: json['document_type']?.toString(),
      documentName: json['document_name']?.toString(),
      source: 'notification_log',
      createdAt: _parseDateTime(json['modified'] ?? json['creation']),
    );
  }

  factory AppNotification.fromActivityLog(Map<String, dynamic> json) {
    final operation = json['operation']?.toString() ?? 'Update';
    final doctype = json['reference_doctype']?.toString() ?? 'Document';
    final docname = json['reference_name']?.toString() ?? '';

    return AppNotification(
      id: 'activity-${json['name'] ?? '$doctype-$docname-${json['creation']}'}',
      title: json['subject']?.toString().trim().isNotEmpty == true
          ? json['subject'].toString()
          : '$operation · $doctype',
      description: _plainText(
        json['content']?.toString() ??
            (docname.isNotEmpty ? '$doctype $docname' : doctype),
      ),
      type: _mapActivityType(operation),
      timeString: _formatTime(json['modified'] ?? json['creation']),
      isRead: false,
      documentType: doctype.isNotEmpty ? doctype : null,
      documentName: docname.isNotEmpty ? docname : null,
      source: 'activity_log',
      createdAt: _parseDateTime(json['modified'] ?? json['creation']),
    );
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  static NotificationType _mapType(String typeRaw, Map<String, dynamic> json) {
    final t = typeRaw.toLowerCase();
    if (t.contains('alert') ||
        t.contains('warning') ||
        t.contains('error') ||
        t.contains('delete')) {
      return NotificationType.warning;
    }
    if (t.contains('assignment') ||
        t.contains('action') ||
        t.contains('task')) {
      return NotificationType.action;
    }

    final subject = '${json['subject'] ?? ''} ${json['email_content'] ?? ''}'
        .toLowerCase();
    if (subject.contains('deleted') ||
        subject.contains('cancelled') ||
        subject.contains('removed')) {
      return NotificationType.warning;
    }

    return NotificationType.info;
  }

  static NotificationType _mapActivityType(String operation) {
    final op = operation.toLowerCase();
    if (op.contains('delet') || op.contains('cancel')) {
      return NotificationType.warning;
    }
    if (op.contains('submit') || op.contains('approve')) {
      return NotificationType.action;
    }
    return NotificationType.info;
  }

  static String _defaultTitle(Map<String, dynamic> json) {
    final doctype = json['document_type']?.toString();
    final docname = json['document_name']?.toString();
    if (doctype != null && doctype.isNotEmpty) {
      return docname != null && docname.isNotEmpty
          ? '$doctype · $docname'
          : doctype;
    }
    return 'ERP Notification';
  }

  static String _plainText(String raw) {
    if (raw.isEmpty) return '';
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _formatTime(dynamic raw) {
    if (raw == null) return '';
    final text = raw.toString().trim();
    if (text.isEmpty) return '';

    final dt = DateTime.tryParse(text);
    if (dt == null) return text;

    final local = dt.toLocal();
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
}
