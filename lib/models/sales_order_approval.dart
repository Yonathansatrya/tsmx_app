import '../utils/num_parse.dart';

class SalesOrderApproval {
  final String name;
  final String customer;
  final String customerName;
  final String workflowState;
  final String status;
  final String owner;
  final String transactionDate;
  final double grandTotal;
  final int docStatus;
  final List<String> actions;

  const SalesOrderApproval({
    required this.name,
    required this.customer,
    required this.customerName,
    required this.workflowState,
    required this.status,
    required this.owner,
    required this.transactionDate,
    required this.grandTotal,
    required this.docStatus,
    required this.actions,
  });

  factory SalesOrderApproval.fromJson(
    Map<String, dynamic> json, {
    required List<String> actions,
  }) => SalesOrderApproval(
    name: json['name']?.toString() ?? '',
    customer: json['customer']?.toString() ?? '',
    customerName:
        json['customer_name']?.toString() ?? json['customer']?.toString() ?? '',
    workflowState: json['workflow_state']?.toString() ?? '',
    status: json['status']?.toString() ?? '',
    owner: json['owner']?.toString() ?? '',
    transactionDate: json['transaction_date']?.toString() ?? '',
    grandTotal: NumParse.asDouble(json['grand_total']),
    docStatus: NumParse.asInt(json['docstatus']),
    actions: actions,
  );
}

class SalesOrderApprovalHistory {
  final String id;
  final String doctype;
  final String salesOrder;
  final String content;
  final String actor;
  final String createdAt;

  const SalesOrderApprovalHistory({
    required this.id,
    this.doctype = 'Sales Order',
    required this.salesOrder,
    required this.content,
    required this.actor,
    required this.createdAt,
  });

  factory SalesOrderApprovalHistory.fromJson(Map<String, dynamic> json) =>
      SalesOrderApprovalHistory(
        id: json['name']?.toString() ?? '',
        doctype: json['reference_doctype']?.toString() ?? 'Sales Order',
        salesOrder: json['reference_name']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        actor:
            json['comment_by']?.toString() ?? json['owner']?.toString() ?? '',
        createdAt: json['creation']?.toString() ?? '',
      );
}
