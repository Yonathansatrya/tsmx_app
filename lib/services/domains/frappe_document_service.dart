import '../frappe_service.dart';

typedef FrappeDocumentParser<T> = T Function(Map<String, dynamic> json);

class FrappeDocumentService<T> {
  final FrappeService frappe;
  final String doctype;
  final FrappeDocumentParser<T> fromJson;

  const FrappeDocumentService({
    required this.frappe,
    required this.doctype,
    required this.fromJson,
  });

  Future<T> load(String name) async {
    final doc = await frappe.fetchDocument(doctype, name);
    return fromJson(doc);
  }

  Future<T> create(Map<String, dynamic> payload) async {
    final doc = await frappe.createDocument(doctype, payload);
    return fromJson(doc);
  }

  Future<T> update(String name, Map<String, dynamic> updates) async {
    await frappe.updateDocument(doctype, name, updates);
    return load(name);
  }

  Future<void> delete(String name) {
    return frappe.deleteDocument(doctype, name);
  }
}
