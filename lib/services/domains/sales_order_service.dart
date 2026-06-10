import '../../models/sales_order.dart';
import '../frappe_service.dart';

class SalesOrderService {
  final FrappeService _frappe;

  SalesOrderService(this._frappe);

  Future<SalesOrder> load(String orderId) async {
    final doc = await _frappe.fetchDocument('Sales Order', orderId);
    return SalesOrder.fromJson(doc);
  }

  Future<SalesOrder> create(Map<String, dynamic> payload) async {
    final doc = await _frappe.createDocument('Sales Order', payload);
    return SalesOrder.fromJson(doc);
  }

  Future<SalesOrder> update(
    String orderId,
    Map<String, dynamic> updates,
  ) async {
    await _frappe.updateDocument('Sales Order', orderId, updates);
    return load(orderId);
  }

  Future<void> delete(String orderId) {
    return _frappe.deleteDocument('Sales Order', orderId);
  }

  Future<void> uploadAttachment(String orderId, String filePath) async {
    await _frappe.uploadFile(
      filePath: filePath,
      doctype: 'Sales Order',
      documentName: orderId,
    );
  }
}
