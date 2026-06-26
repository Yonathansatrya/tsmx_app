# TMSX Mobile

Frappe backend package for the TMSX Flutter mobile app.

## Install on a bench

```bash
bench get-app tmsx_mobile /path/to/frappe_apps/tmsx_mobile
bench --site your-site install-app tmsx_mobile
bench --site your-site migrate
bench restart
```

## Main API

```text
/api/method/tmsx_mobile.api.auth.get_mobile_boot
```

The Flutter app uses this endpoint after login to read the active user, roles,
default company, allowed companies, warehouse scope, and enabled mobile modules.

If this package is not installed on a site, the Flutter app falls back to
standard ERPNext APIs.

## Mobile boot contract

`get_mobile_boot` should return this minimum shape:

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

Use **TMSX Mobile Settings** in each Frappe site to configure app name,
default modules, role-to-module mapping, company scope, and warehouse scope.
The Flutter app treats `modules`, `menus`, `companies`, and `warehouses` from
this API as the official runtime configuration for that active site.
