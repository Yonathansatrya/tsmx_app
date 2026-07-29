class FrappeSitePreset {
  final String code;
  final String name;
  final String baseUrl;

  const FrappeSitePreset({
    required this.code,
    required this.name,
    required this.baseUrl,
  });
}

class AppConfig {
  const AppConfig._();

  static const String defaultAppName = 'TMSX Hub';
  static const String defaultAppTagline = 'Mobile ERP';

  static const String frappeBaseUrl = String.fromEnvironment(
    'FRAPPE_BASE_URL',
    defaultValue: '',
  );

  static String get normalizedFrappeBaseUrl {
    final value = frappeBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (value.isEmpty) {
      throw StateError(
        'FRAPPE_BASE_URL belum dikonfigurasi. '
        'Jalankan Flutter dengan --dart-define-from-file=env.json.',
      );
    }
    return value;
  }

  static String get optionalFrappeBaseUrl =>
      frappeBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  static const localFrappeSites = [
    FrappeSitePreset(
      code: 'TABI',
      name: 'Tabi',
      baseUrl: 'https://tabi.willshine.id',
    ),
    FrappeSitePreset(
      code: 'ATIS',
      name: 'ATIS',
      baseUrl: 'https://atis.willshine.id',
    ),
    FrappeSitePreset(
      code: 'PAJAK',
      name: 'Pajak',
      baseUrl: 'https://pajak.willshine.id',
    ),
    FrappeSitePreset(
      code: 'PLANTATION',
      name: 'Plantation',
      baseUrl: 'https://plantation.willshine.id',
    ),
    FrappeSitePreset(
      code: 'TMSX',
      name: 'TMSX',
      baseUrl: 'https://jakarta.willshine.id',
    ),
    FrappeSitePreset(
      code: 'SMS',
      name: 'SABANG MAKMUR SENTOSA',
      baseUrl: 'https://sms.willshine.id',
    ),
    FrappeSitePreset(
      code: 'GREENHOUSE',
      name: 'Greenhouse Cisauk',
      baseUrl: 'https://ghcisauk.willshine.id',
    ),
    FrappeSitePreset(
      code: 'LAHATTS',
      name: 'Lahat Tani Sejahtera',
      baseUrl: 'https://lahattanisejahtera.willshine.id',
    ),
    FrappeSitePreset(
      code: 'HOLTI',
      name: 'Holti',
      baseUrl: 'https://holti.willshine.id',
    ),
    FrappeSitePreset(
      code: 'EXAMPLE',
      name: 'Example Site',
      baseUrl: 'http://172.30.218.103:8000',
    ),
  ];
}
