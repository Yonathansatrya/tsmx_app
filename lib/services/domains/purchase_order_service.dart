import '../../models/purchase_order.dart';
import '../frappe_service.dart';

class PurchaseOrderService {
  final FrappeService _frappe;

  PurchaseOrderService(this._frappe);

  Future<PurchaseOrder> load(String orderId) async {
    final doc = await _frappe.fetchDocument('Purchase Order', orderId);
    return PurchaseOrder.fromJson(doc);
  }

  Future<PurchaseOrder> create(Map<String, dynamic> payload) async {
    final doc = await _frappe.createDocument('Purchase Order', payload);
    return PurchaseOrder.fromJson(doc);
  }

  Future<PurchaseOrder> update(
    String orderId,
    Map<String, dynamic> updates,
  ) async {
    await _frappe.updateDocument('Purchase Order', orderId, updates);
    return load(orderId);
  }

  Future<void> delete(String orderId) {
    return _frappe.deleteDocument('Purchase Order', orderId);
  }
}
