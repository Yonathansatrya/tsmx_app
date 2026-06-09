import 'dart:convert';

typedef FrappePageFetcher =
    Future<List<Map<String, dynamic>>> Function(int start, int limit);

Future<List<Map<String, dynamic>>> walkFrappePages({
  required FrappePageFetcher fetchPage,
  required int pageSize,
  int? maxRows,
  void Function(Map<String, dynamic> row)? onRow,
  void Function(int processed)? onProgress,
}) async {
  final rows = <Map<String, dynamic>>[];
  final seenNames = <String>{};
  final seenPages = <int>{};
  var start = 0;

  while (maxRows == null || rows.length < maxRows) {
    final remaining = maxRows == null ? pageSize : maxRows - rows.length;
    final requested = remaining < pageSize ? remaining : pageSize;
    final page = await fetchPage(start, requested);
    if (page.isEmpty) break;
    if (!seenPages.add(jsonEncode(page).hashCode)) break;

    var added = 0;
    for (final row in page) {
      final name = row['name']?.toString() ?? '';
      if (name.isNotEmpty && !seenNames.add(name)) continue;
      rows.add(row);
      onRow?.call(row);
      added++;
      if (maxRows != null && rows.length >= maxRows) break;
    }

    onProgress?.call(rows.length);
    if (added == 0) break;
    start += page.length;
    await Future<void>.delayed(Duration.zero);
  }

  return rows;
}
