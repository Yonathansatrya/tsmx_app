import 'domains/auth_service.dart';
import 'domains/customer_service.dart';
import 'domains/purchase_invoice_service.dart';
import 'domains/purchase_order_service.dart';
import 'domains/sales_invoice_service.dart';
import 'domains/sales_order_service.dart';
import 'frappe_service.dart';

class ErpServices {
  final FrappeService frappe;

  late final AuthService auth = AuthService(frappe);
  late final CustomerService customer = CustomerService(frappe);
  late final SalesOrderService salesOrder = SalesOrderService(frappe);
  late final PurchaseOrderService purchaseOrder = PurchaseOrderService(frappe);
  late final SalesInvoiceService salesInvoice = SalesInvoiceService(frappe);
  late final PurchaseInvoiceService purchaseInvoice = PurchaseInvoiceService(
    frappe,
  );

  ErpServices({FrappeService? frappe}) : frappe = frappe ?? FrappeService();
}
