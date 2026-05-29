class WarehouseMapper {
  static String toAreaId(String rawWarehouse, {Map<String, String>? overrides}) {
    if (rawWarehouse.isEmpty) return '';

    if (overrides != null) {
      if (overrides.containsKey(rawWarehouse)) {
        return overrides[rawWarehouse]!;
      }
      final lowKey = rawWarehouse.toLowerCase();
      if (overrides.containsKey(lowKey)) {
        return overrides[lowKey]!;
      }
    }

    final w = rawWarehouse.toLowerCase();

    if (w.contains('curug')) {
      return 'curug_stores';
    }

    if (w.contains('medan') || w.contains('sumatra')) {
      if (w.contains('stores')) return 'medan_stores';
      return 'medan_stores';
    }

    if (w.contains('jakarta') ||
        w.contains('jkt') ||
        w.contains('distribution hub') ||
        w.endsWith(' - jakarta')) {
      if (w.contains('inbound') || w.contains('masuk')) {
        return 'jakarta_inbound';
      }
      if (w.contains('ripen') ||
          w.contains('matang') ||
          w.contains('pematang')) {
        return 'jakarta_ripening';
      }
      if (w.contains('stores') || w.contains('siap jual')) {
        return 'jakarta_stores';
      }
    }

    return w
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static String hubFilterPrefix(String hubId) {
    switch (hubId) {
      case 'curug':
        return '%Curug%';
      case 'medan':
        return '%Medan%';
      case 'jakarta':
      default:
        return '%Jakarta%';
    }
  }

  static String hubIdFromWarehouse(String rawWarehouse) {
    final w = rawWarehouse.toLowerCase();
    if (w.contains('curug')) return 'curug';
    if (w.contains('medan') || w.contains('sumatra')) return 'medan';
    if (w.contains('jakarta') ||
        w.contains('jkt') ||
        w.contains('distribution hub')) {
      return 'jakarta';
    }
    return '';
  }

  static bool warehouseMatchesHub(String warehouseName, String hubId) {
    if (hubId.isEmpty) return true;
    if (warehouseName == hubId) return true;
    final mapped = hubIdFromWarehouse(warehouseName);
    if (mapped.isNotEmpty) return mapped == hubId;
    return warehouseName.toLowerCase().contains(
      hubFilterPrefix(hubId).toLowerCase(),
    );
  }

  static String hubDisplayName(String hubId) {
    switch (hubId) {
      case 'jakarta':
        return 'Jakarta Distribution Hub';
      case 'curug':
        return 'Curug Hub';
      case 'medan':
        return 'Medan Hub';
      default:
        return hubId;
    }
  }
}
