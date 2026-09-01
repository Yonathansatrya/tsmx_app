import '../../models/sales_order.dart';
import '../frappe_service.dart';
import 'frappe_document_service.dart';

class SalesOrderService extends FrappeDocumentService<SalesOrder> {
  SalesOrderService(FrappeService frappe)
    : super(
        frappe: frappe,
        doctype: 'Sales Order',
        fromJson: SalesOrder.fromJson,
      );

  Future<void> uploadAttachment(String orderId, String filePath) async {
    await frappe.uploadFile(
      filePath: filePath,
      doctype: doctype,
      documentName: orderId,
    );
  }
}
