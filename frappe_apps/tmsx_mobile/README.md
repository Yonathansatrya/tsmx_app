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
