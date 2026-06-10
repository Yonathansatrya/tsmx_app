import '../../models/purchase_invoice.dart';
import '../frappe_service.dart';

class PurchaseInvoiceService {
  final FrappeService _frappe;

  PurchaseInvoiceService(this._frappe);

  Future<PurchaseInvoice> load(String invoiceId) async {
    final doc = await _frappe.fetchDocument('Purchase Invoice', invoiceId);
    return PurchaseInvoice.fromJson(doc);
  }

  Future<PurchaseInvoice> create(Map<String, dynamic> payload) async {
    final doc = await _frappe.createDocument('Purchase Invoice', payload);
    return PurchaseInvoice.fromJson(doc);
  }
}
