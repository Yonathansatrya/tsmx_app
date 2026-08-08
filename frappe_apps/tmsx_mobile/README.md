# TMSX Mobile

Frappe backend package untuk aplikasi Flutter TMSX Hub. App ini dipasang ke
setiap site ERPNext yang ingin dipakai dari mobile.

> Catatan multi-site: install dan migrate harus dijalankan per site. Setting,
> role, permission, dan data master tetap mengikuti site ERPNext aktif.

## Prasyarat

- Frappe Bench dengan Frappe/ERPNext v15 atau v16.
  Package ini mendeklarasikan dependency `frappe >=15.0.0` dan
  `erpnext >=15.0.0`, jadi tidak dikunci hanya untuk v15.
- Akses terminal ke server bench.
- App folder ini tersedia di server:
  `frappe_apps/tmsx_mobile`
- User bench punya akses menjalankan `bench`.

## Install Baru Ke Site ERPNext

Jalankan dari server ERPNext/Frappe:

```bash
cd /path/to/frappe-bench
bench get-app /path/to/tmsx_app/frappe_apps/tmsx_mobile
bench --site nama-site install-app tmsx_mobile
bench --site nama-site migrate
bench --site nama-site clear-cache
bench --site nama-site clear-website-cache
bench restart
```

Contoh:

```bash
cd ~/frappe-bench
bench get-app /home/frappe/tmsx_app/frappe_apps/tmsx_mobile
bench --site jakarta.willshine.id install-app tmsx_mobile
bench --site jakarta.willshine.id migrate
bench --site jakarta.willshine.id clear-cache
bench --site jakarta.willshine.id clear-website-cache
bench restart
```

Kalau app sudah berada di folder `apps/tmsx_mobile`, cukup install ke site:

```bash
cd /path/to/frappe-bench
bench --site nama-site install-app tmsx_mobile
bench --site nama-site migrate
bench --site nama-site clear-cache
bench restart
```

## Update Site Yang Sudah Terpasang

Jika app sudah pernah dipasang dan ada perubahan DocType/permission/setup:

```bash
cd /path/to/frappe-bench
bench --site nama-site migrate
bench --site nama-site execute tmsx_mobile.setup.after_install
bench --site nama-site clear-cache
bench --site nama-site clear-website-cache  
bench restart
```

`after_install` aman dijalankan ulang karena setup dibuat idempotent:
role/permission/custom field yang sudah ada akan diperbarui, bukan diduplikasi.

## Validasi Setelah Install

Pastikan app terpasang:

```bash
bench --site nama-site list-apps
```

Pastikan setup bisa dijalankan tanpa error:

```bash
bench --site nama-site execute tmsx_mobile.setup.after_install
```

Lalu cek di Desk ERPNext:

- DocType `TMSX Mobile Settings` ada.
- DocType `NOO Request` ada.
- DocType `Promo Request` dan `Promo Request Item` ada.
- DocType `Sales Visit` punya field `Employee Checkin IN` dan
  `Employee Checkin OUT`.
- DocType SPG ada: `SPG Schedule`, `SPG Visit`,
  `SPG Daily Activity`, dan `SPG Daily Report`.
- Field custom `Sales Order.noted` ada.

## Setup Wajib Di ERPNext Setelah Install

1. Buka `TMSX Mobile Settings`.
2. Atur app name, default modules, company scope, dan warehouse scope.
3. Atur `TMSX Mobile Role Module` untuk menentukan menu mobile per role.
4. Buka Role Permission Manager, pastikan role yang dipakai user punya akses
   ke DocType yang diperlukan.
5. Untuk user Sales/SPG/Driver, isi relasi `Employee.user_id` dengan email
   login user.
6. Untuk SPG, buat `SPG Schedule` aktif:
   - `start_date` dan `end_date` sesuai periode aktif.
   - `table_bffa` berisi customer yang boleh dikunjungi.
   - `table_cylv` berisi employee SPG yang ditugaskan.
7. Untuk item yang boleh dijual, centang `Allow Sales` / `is_sales_item` di
   master Item.
8. Jika fitur lokasi dipakai, isi latitude/longitude/radius pada Customer atau
   Address sesuai field yang dibuat setup.

## Permission Minimum Per Fitur

Permission tetap dikendalikan dari ERPNext Role Permission Manager.

Sales / Sales User:

- `Sales Order`, `Sales Invoice`, `Delivery Note`
- `Customer`, `Customer Group`, `Item`, `Item Price`, `UOM`
- `Sales Person`, `Address`, `File`
- `Sales Visit`, `Employee Checkin`
- `NOO Request`
- `Promo Request`, `Promo Request Item`

SPG:

- `SPG Schedule`, `SPG Schedule Customer`, `SPG Schedule Employee`
- `SPG Visit`
- `SPG Daily Activity`, `SPG Daily Activity Photo`
- `SPG Daily Report`, `SPG Daily Report Item`
- `Customer`, `Employee`, `Item`, `UOM`, `File`, `Employee Checkin`

Role admin/developer:

- Tambahkan role `System Manager`, `Developer`, atau role admin internal.
- Jalankan ulang:

```bash
bench --site nama-site execute tmsx_mobile.setup.after_install
bench --site nama-site clear-cache
```

## Main API

```text
/api/method/tmsx_mobile.api.auth.get_mobile_boot
```

Flutter app memakai endpoint ini setelah login untuk membaca user aktif, roles,
default company, allowed companies, warehouse scope, dan menu mobile aktif.

Jika app ini belum dipasang pada suatu site, Flutter app masih bisa fallback ke
API standar ERPNext, tetapi menu custom seperti NOO, Promo, Visit, dan SPG tidak
akan lengkap.

## Mobile Boot Contract

`get_mobile_boot` minimal mengembalikan bentuk seperti ini:

```json
{
  "app": {
    "name": "TMSX Hub",
    "tagline": "Mobile ERP"
  },
  "role": "Sales",
  "roles": ["Sales User"],
  "default_company": "Company A",
  "companies": ["Company A"],
  "warehouses": ["Stores - A"],
  "modules": ["dashboard", "sales"],
  "menus": [
    {
      "module": "dashboard",
      "label": "Beranda",
      "icon": "dashboard",
      "order": 10
    },
    {
      "module": "sales",
      "label": "Sales",
      "icon": "point_of_sale",
      "order": 20
    }
  ]
}
```

## Installed Configuration

DocType yang dibawa atau disiapkan app:

- `TMSX Mobile Settings`
- `TMSX Mobile Role Module`
- `Sales Visit`
- `Sales Visit Competitor`
- `Sales Visit Potential Order`
- `NOO Request`
- `Promo Request`
- `Promo Request Item`
- `SPG Schedule`
- `SPG Schedule Customer`
- `SPG Schedule Employee`
- `SPG Visit`
- `SPG Daily Activity`
- `SPG Daily Activity Photo`
- `SPG Daily Report`
- `SPG Daily Report Item`
- `Delivery Tracking Point`
- `Delivery Activity Log`

Custom field yang dibuat setup:

- `Sales Order.noted`
- Field lokasi/radius pada `Customer` dan `Address` untuk validasi kunjungan.

Hook app:

- `before_install = tmsx_mobile.setup.setup_mobile_roles`
- `after_install = tmsx_mobile.setup.after_install`
- `after_migrate = tmsx_mobile.setup.after_install`

Artinya setiap `bench migrate` juga menjalankan sinkronisasi setup mobile.

## Troubleshooting

Jika DocType custom tidak muncul:

```bash
bench --site nama-site migrate
bench --site nama-site execute tmsx_mobile.setup.after_install
bench --site nama-site clear-cache
bench restart
```

Jika mobile mendapat error permission:

- Pastikan role user benar di User / Role Profile.
- Pastikan role tersebut punya `Read` dan `Select` untuk DocType yang dibaca.
- Pastikan punya `Create` dan `Write` untuk halaman create/edit.
- Jalankan ulang setup dan clear cache:

```bash
bench --site nama-site execute tmsx_mobile.setup.after_install
bench --site nama-site clear-cache
```

Jika user SPG tidak melihat customer schedule:

- Pastikan `Employee.user_id` sama dengan email login user.
- Pastikan `SPG Schedule` aktif pada tanggal hari ini.
- Pastikan employee user ada di `table_cylv`.
- Pastikan customer yang boleh dikunjungi ada di `table_bffa`.

Jika item tidak muncul di search Sales Order/SPG:

- Pastikan Item aktif.
- Pastikan field `is_sales_item` / `Allow Sales` aktif.
- Pastikan user punya `Read` dan `Select` ke `Item` dan `UOM`.
