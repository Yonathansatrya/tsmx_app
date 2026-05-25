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

    if (w.contains('medan')) {
      return 'medan_stores';
    }

    if (w.contains('jakarta') ||
        w.contains('jkt') ||
        w.contains('distribution hub')) {
      if (w.contains('inbound') || w.contains('masuk')) {
        return 'jakarta_inbound';
      }
      if (w.contains('ripen') ||
          w.contains('matang') ||
          w.contains('pematang')) {
        return 'jakarta_ripening';
      }
      if (w.contains('store') || w.contains('siap jual')) {
        return 'jakarta_stores';
      }
      return 'jakarta_stores';
    }

    return w
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static String hubFilterPrefix(String hubId) {
    switch (hubId) {
      case 'curug':
        return 'Curug';
      case 'medan':
        return 'Medan';
      case 'jakarta':
      default:
        return 'Jakarta';
    }
  }
}
