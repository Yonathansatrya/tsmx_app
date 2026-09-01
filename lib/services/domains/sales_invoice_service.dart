import '../../models/sales_invoice.dart';
import '../frappe_service.dart';
import 'frappe_document_service.dart';

class SalesInvoiceService extends FrappeDocumentService<SalesInvoice> {
  SalesInvoiceService(FrappeService frappe)
    : super(
        frappe: frappe,
        doctype: 'Sales Invoice',
        fromJson: SalesInvoice.fromJson,
      );
}
