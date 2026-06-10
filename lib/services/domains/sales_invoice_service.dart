import '../../models/sales_invoice.dart';
import '../frappe_service.dart';

class SalesInvoiceService {
  final FrappeService _frappe;

  SalesInvoiceService(this._frappe);

  Future<SalesInvoice> load(String invoiceId) async {
    final doc = await _frappe.fetchDocument('Sales Invoice', invoiceId);
    return SalesInvoice.fromJson(doc);
  }
}
