import 'dart:convert';
import 'package:http/http.dart' as http;

class FrappeService {
  static const String defaultBaseUrl = 'http://apps.willshine.id:8014';

  String baseUrl;
  String? username;
  String? password;
  final Map<String, String> _cookies = {};

  FrappeService({this.baseUrl = defaultBaseUrl});

  bool get hasCredentials => username != null && password != null;

  Future<void> login(String username, String password) async {
    this.username = username;
    this.password = password;

    final uri = Uri.parse('$baseUrl/api/method/login');
    final response = await _post(
      uri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'usr': username, 'pwd': password},
    );

    if (response.statusCode != 200) {
      throw Exception('Frappe login failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['exc'] != null) {
      throw Exception('Frappe login failed: ${decoded['exc']}');
    }

    if (decoded is Map &&
        decoded['message']?.toString().toLowerCase().contains('invalid') ==
            true) {
      throw Exception('Frappe login failed: invalid username or password.');
    }

    if (_cookies.isEmpty) {
      throw Exception('Frappe login failed: no session cookie received.');
    }
  }

  Future<void> ensureLoggedIn() async {
    if (!hasCredentials) {
      throw Exception('Missing Frappe username or password.');
    }

    if (_cookies.isEmpty) {
      await login(username!, password!);
    }
  }

  Future<List<Map<String, dynamic>>> fetchResource(
    String doctype, {
    required List<String> fields,
    int limit = 50,
    String? orderBy,
    List<List<dynamic>>? filters,
  }) async {
    await ensureLoggedIn();

    final encodedDoctype = Uri.encodeComponent(doctype);
    final queryParameters = {
      'fields': jsonEncode(fields),
      'limit_page_length': limit.toString(),
      if (orderBy != null) 'order_by': orderBy,
      if (filters != null) 'filters': jsonEncode(filters),
    };

    final uri = Uri.parse(
      '$baseUrl/api/resource/$encodedDoctype',
    ).replace(queryParameters: queryParameters);

    final response = await _get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Frappe API error: ${response.statusCode} ${response.reasonPhrase}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['data'] is! List) {
      throw Exception('Invalid Frappe response for $doctype.');
    }

    return (decoded['data'] as List).map((item) {
      return item is Map<String, dynamic>
          ? item
          : Map<String, dynamic>.from(item as Map);
    }).toList();
  }

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = http.Client();
    try {
      final mergedHeaders = <String, String>{
        'Accept': 'application/json',
        if (headers != null) ...headers,
        if (_cookies.isNotEmpty) 'Cookie': _cookieHeader(),
      };
      final response = await client.post(
        uri,
        headers: mergedHeaders,
        body: body,
      );
      _updateCookies(response);
      return response;
    } finally {
      client.close();
    }
  }

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) async {
    final client = http.Client();
    try {
      final mergedHeaders = <String, String>{
        'Accept': 'application/json',
        if (headers != null) ...headers,
        if (_cookies.isNotEmpty) 'Cookie': _cookieHeader(),
      };
      final response = await client.get(uri, headers: mergedHeaders);
      _updateCookies(response);
      return response;
    } finally {
      client.close();
    }
  }

  String _cookieHeader() {
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  void _updateCookies(http.Response response) {
    final rawCookie = response.headers['set-cookie'];
    if (rawCookie == null || rawCookie.isEmpty) return;

    final parts = rawCookie.split(RegExp(r', (?=[^;]+=)'));
    for (final part in parts) {
      final cookie = part.split(';').first.trim();
      final separatorIndex = cookie.indexOf('=');
      if (separatorIndex <= 0) continue;
      final key = cookie.substring(0, separatorIndex).trim();
      final value = cookie.substring(separatorIndex + 1).trim();
      if (key.isNotEmpty) {
        _cookies[key] = value;
      }
    }
  }
}
