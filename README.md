# tmsx_app

## Environment

Konfigurasi site ERPNext/Frappe dibaca dari `env.json`. File tersebut tidak
masuk Git; gunakan `env.example.json` sebagai template.

```powershell
flutter run --dart-define-from-file=env.json
flutter build apk --release --dart-define-from-file=env.json
flutter build appbundle --release --dart-define-from-file=env.json
```

`FRAPPE_BASE_URL` bukan secret karena nilainya tetap dibundel ke aplikasi.
Jangan simpan username, password, API key, atau API secret pada file env
frontend.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
