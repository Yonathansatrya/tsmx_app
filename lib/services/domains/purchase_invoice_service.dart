import '../../models/purchase_invoice.dart';
import '../frappe_service.dart';
import 'frappe_document_service.dart';

class PurchaseInvoiceService extends FrappeDocumentService<PurchaseInvoice> {
  PurchaseInvoiceService(FrappeService frappe)
    : super(
        frappe: frappe,
        doctype: 'Purchase Invoice',
        fromJson: PurchaseInvoice.fromJson,
      );
}
