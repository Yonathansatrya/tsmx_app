import '../models/mobile_boot.dart';
import '../config/mobile_role_registry.dart';

export '../config/mobile_role_registry.dart' show MobileModule, MobileRole;

class MobileAccess {
  final String role;
  final MobileBoot? boot;

  const MobileAccess({required this.role, this.boot});

  bool get hasBoot => boot != null;
  String get normalizedRole => MobileRoleRegistry.normalizeRoleProfile(role);

  bool get isAdministrator => normalizedRole == MobileRole.administrator;
  bool get isDeveloper => normalizedRole == MobileRole.developer;
  bool get isCompanyAdministrator =>
      normalizedRole == MobileRole.companyAdministrator;
  bool get isDirector => normalizedRole == MobileRole.director;
  bool get isSalesUser => normalizedRole == MobileRole.sales;
  bool get isSalesManager => normalizedRole == MobileRole.salesManager;
  bool get isSalesArea => isSalesUser || isSalesManager;
  bool get isCollectionUser => normalizedRole == MobileRole.collection;
  bool get isPurchaseUser => normalizedRole == MobileRole.purchase;
  bool get isPurchaseManager => normalizedRole == MobileRole.purchaseManager;
  bool get isPurchaseArea => isPurchaseUser || isPurchaseManager;
  bool get isWarehouse => normalizedRole == MobileRole.warehouse;
  bool get isQualityControl => normalizedRole == MobileRole.qualityControl;
  bool get isLogistics => normalizedRole == MobileRole.logistics;
  bool get isDriver => normalizedRole == MobileRole.driver;
  bool get isFinance => normalizedRole == MobileRole.finance;
  bool get isAccounting => normalizedRole == MobileRole.accounting;
  bool get isPlantationSupervisor =>
      normalizedRole == MobileRole.plantationSupervisor;
  bool get shouldScopeSalesData => isSalesUser;

  bool canUse(String module) {
    final normalized = module.trim().toLowerCase();
    if (MobileRoleRegistry.isFullAccessRole(normalizedRole)) {
      return MobileRoleRegistry.modulesForRole(normalizedRole).contains(
        normalized,
      );
    }

    final bootModules = boot?.modules ?? const <String>{};
    if (boot != null && bootModules.isNotEmpty) {
      return bootModules.contains(normalized);
    }

    return MobileRoleRegistry.modulesForRole(normalizedRole).contains(
      normalized,
    );
  }

  Set<String> get enabledModules {
    if (MobileRoleRegistry.isFullAccessRole(normalizedRole)) {
      return MobileRoleRegistry.modulesForRole(normalizedRole);
    }

    final bootModules = boot?.modules ?? const <String>{};
    if (boot != null && bootModules.isNotEmpty) return bootModules;

    return MobileRoleRegistry.modulesForRole(normalizedRole);
  }
}
