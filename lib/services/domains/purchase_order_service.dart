import '../../models/purchase_order.dart';
import '../frappe_service.dart';
import 'frappe_document_service.dart';

class PurchaseOrderService extends FrappeDocumentService<PurchaseOrder> {
  PurchaseOrderService(FrappeService frappe)
    : super(
        frappe: frappe,
        doctype: 'Purchase Order',
        fromJson: PurchaseOrder.fromJson,
      );
}
