# State and Service Architecture

## Tujuan

- `FrappeService` hanya menangani HTTP, cookie, dan session.
- `ErpServices` membuat semua service domain memakai satu session Frappe.
- Service domain menangani query, payload, dan parsing satu domain.
- State domain menangani loading, error, pagination, cache UI, dan refresh.
- `AppState` sementara menjadi facade kompatibilitas selama migrasi layar.

## Struktur Saat Ini

```text
lib/
  services/
    frappe_service.dart
    erp_services.dart
    domains/
      auth_service.dart
      customer_service.dart
      sales_order_service.dart
      sales_invoice_service.dart
      purchase_order_service.dart
      purchase_invoice_service.dart
  state/
    app_state.dart
```

Semua domain service menerima `FrappeService` yang sama melalui `ErpServices`.
Jangan membuat `FrappeService()` baru di service atau screen karena itu membuat
session dan cookie terpisah.

## Batas Tanggung Jawab

### FrappeService

- login dan memastikan session aktif
- request REST resource dan method whitelisted
- upload file
- operasi dokumen generik

### Domain Service

- menentukan DocType dan filter domain
- membangun payload domain
- parsing response menjadi model

### Domain State

Target migrasi berikutnya:

```text
state/
  auth_state.dart
  sales_order_state.dart
  sales_invoice_state.dart
  purchase_order_state.dart
  purchase_invoice_state.dart
  inventory_state.dart
  notification_state.dart
```

Jangan menambahkan fitur domain baru ke `AppState`. Tambahkan ke service dan
state domain terkait, lalu pindahkan pemakai facade secara bertahap.
