# TMSX Mobile

Frappe backend package for the TMSX Flutter mobile app.

## Install on a bench

```bash
bench get-app tmsx_mobile /path/to/frappe_apps/tmsx_mobile
bench --site your-site install-app tmsx_mobile
bench --site your-site migrate
bench restart
```


## untuk yang sudah terlanjur install mobile nya
``` Bash bench --site dev.local migrate
bench --site dev.local execute tmsx_mobile.setup.setup_mobile_roles
bench --site dev.local execute tmsx_mobile.setup.setup_mobile_settings
bench --site dev.local execute tmsx_mobile.setup.setup_mobile_workspace
bench --site dev.local clear-cache
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

## Installed configuration

The app installs these TMSX doctypes:

- `TMSX Mobile Settings`
- `TMSX Mobile Role Module`
- `Sales Visit`
- `Sales Visit Competitor`
- `Sales Visit Potential Order`
- `Sales Tracking Point`
- `Delivery Tracking Point`
- `Delivery Activity Log`

The sales and delivery tracking doctypes are intentionally custom because
ERPNext does not provide a mobile GPS point log that matches this app's sales
visit and delivery driver workflow.

During install, the app also creates missing mobile roles using the
`User/Admin/Manager` naming pattern, for example `Sales User`, `Sales Admin`,
`Sales Manager`, `Purchase User`, `Purchase Admin`, `Warehouse User`,
`Warehouse Admin`, `Logistics User`, `Logistics Admin`, `Finance User`, and
`Finance Admin`. Existing ERPNext roles such as `Sales User`, `Purchase User`,
`Stock User`, and `System Manager` are reused when they already exist.

Default mobile role matrix:

| Role | Mobile modules |
| --- | --- |
| Sales User | Sales |
| Sales Manager / Sales Admin | Sales, Collection, Approval |
| Collection User | Collection |
| Collection Manager / Collection Admin | Collection, Approval |
| Purchase User | Purchase |
| Purchase Manager / Purchase Admin | Purchase, Approval |
| Warehouse User | Stock, Warehouse |
| Warehouse Manager / Warehouse Admin | Stock, Warehouse, Approval |
| Quality Control User | Stock, Warehouse, Quality Control |
| Quality Control Manager / Quality Control Admin | Stock, Warehouse, Quality Control, Approval |
| Logistics User / Driver | Logistics |
| Logistics Manager / Logistics Admin | Logistics, Approval |
| Finance User | Finance |
| Finance Manager / Finance Admin | Finance, Approval |
| Accounting User | Accounting |
| Accounting Manager / Accounting Admin | Accounting, Approval |
| Plantation Supervisor | Plantation |
| Plantation Manager / Plantation Admin | Plantation, Approval |
