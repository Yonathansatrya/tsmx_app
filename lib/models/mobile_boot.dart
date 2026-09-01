import '../config/mobile_role_registry.dart';

class MobileBoot {
  final String user;
  final String fullName;
  final String appName;
  final String appTagline;
  final String roleProfile;
  final List<String> roles;
  final String defaultCompany;
  final List<String> companies;
  final List<String> warehouses;
  final Set<String> modules;
  final List<MobileBootMenuItem> menus;
  final Map<String, dynamic> raw;

  const MobileBoot({
    this.user = '',
    this.fullName = '',
    this.appName = MobileRoleRegistry.defaultAppName,
    this.appTagline = MobileRoleRegistry.defaultAppTagline,
    this.roleProfile = '',
    this.roles = const [],
    this.defaultCompany = '',
    this.companies = const [],
    this.warehouses = const [],
    this.modules = const {},
    this.menus = const [],
    this.raw = const {},
  });

  factory MobileBoot.fromJson(Map<String, dynamic> json) {
    final permissions = _asMap(json['permissions']);
    final app = _asMap(json['app']);
    final rawModules = json['modules'] ?? json['enabled_modules'];
    final parsedMenus = _asMenuList(json['menus'] ?? json['menu_items']);
    final parsedModules = _asStringList(
      rawModules,
    ).map((module) => module.toLowerCase()).toSet();
    final rawCompanies =
        json['companies'] ??
        json['allowed_companies'] ??
        permissions['companies'];
    final rawWarehouses =
        json['warehouses'] ??
        json['allowed_warehouses'] ??
        permissions['warehouses'];

    return MobileBoot(
      user: _clean(json['user']),
      fullName: _clean(json['full_name'] ?? json['fullName']),
      appName: _clean(
        app['name'] ?? json['app_name'] ?? json['appName'],
      ).ifEmpty(MobileRoleRegistry.defaultAppName),
      appTagline: _clean(
        app['tagline'] ?? json['app_tagline'] ?? json['appTagline'],
      ).ifEmpty(MobileRoleRegistry.defaultAppTagline),
      roleProfile: _clean(
        json['role_profile_name'] ??
            json['role_profile'] ??
            json['roleProfile'] ??
            json['role'] ??
            json['user_role'] ??
            json['userRole'],
      ),
      roles: _asStringList(json['roles']),
      defaultCompany: _clean(
        json['default_company'] ??
            json['defaultCompany'] ??
            permissions['default_company'],
      ),
      companies: _asStringList(rawCompanies),
      warehouses: _asStringList(rawWarehouses),
      modules: parsedModules.isNotEmpty
          ? parsedModules
          : parsedMenus.map((menu) => menu.module).toSet(),
      menus: parsedMenus,
      raw: Map<String, dynamic>.from(json),
    );
  }

  bool hasModule(String module) {
    if (modules.isEmpty) return false;
    return modules.contains(module.trim().toLowerCase());
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static List<String> _asStringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) {
          if (item is Map) return _clean(item['name'] ?? item['role']);
          return _clean(item);
        })
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  static List<MobileBootMenuItem> _asMenuList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (item) =>
              MobileBootMenuItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .where((item) => item.module.isNotEmpty)
        .toList();
  }

  static String _clean(Object? value) {
    final cleaned = value?.toString().trim() ?? '';
    final lower = cleaned.toLowerCase();
    if (lower == 'null' || lower == 'none' || lower == 'undefined') return '';
    return cleaned;
  }
}

class MobileBootMenuItem {
  final String module;
  final String label;
  final String icon;
  final int order;

  const MobileBootMenuItem({
    this.module = '',
    this.label = '',
    this.icon = '',
    this.order = 0,
  });

  factory MobileBootMenuItem.fromJson(Map<String, dynamic> json) {
    return MobileBootMenuItem(
      module: MobileBoot._clean(json['module'] ?? json['key']).toLowerCase(),
      label: MobileBoot._clean(json['label'] ?? json['title']),
      icon: MobileBoot._clean(json['icon']),
      order: int.tryParse(json['order']?.toString() ?? '') ?? 0,
    );
  }
}

extension _NonEmptyString on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
