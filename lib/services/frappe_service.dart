import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class FrappeService {
  static const String defaultBaseUrl = 'http://apps.willshine.id:8014';

  static const int maxPageLength = 10000;

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
    int limit = maxPageLength,
    int limitStart = 0,
    String? orderBy,
    List<List<dynamic>>? filters,
  }) async {
    await ensureLoggedIn();

    final encodedDoctype = Uri.encodeComponent(doctype);
    final queryParameters = {
      'fields': jsonEncode(fields),
      'limit_page_length': limit.toString(),
      if (limitStart > 0) 'limit_start': limitStart.toString(),
      if (orderBy != null) 'order_by': orderBy,
      if (filters != null) 'filters': jsonEncode(filters),
    };

    final uri = Uri.parse(
      '$baseUrl/api/resource/$encodedDoctype',
    ).replace(queryParameters: queryParameters);

    final response = await _get(uri);
    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(_extractFrappeError(decoded, response.statusCode));
    }

    if (decoded is! Map || decoded['data'] is! List) {
      throw Exception('Invalid Frappe response for $doctype.');
    }

    return (decoded['data'] as List).map((item) {
      return item is Map<String, dynamic>
          ? item
          : Map<String, dynamic>.from(item as Map);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchAllResources(
    String doctype, {
    required List<String> fields,
    int pageSize = maxPageLength,
    String? orderBy,
    List<List<dynamic>>? filters,
  }) async {
    final all = <Map<String, dynamic>>[];
    var start = 0;

    while (true) {
      final page = await fetchResource(
        doctype,
        fields: fields,
        limit: pageSize,
        limitStart: start,
        orderBy: orderBy,
        filters: filters,
      );
      all.addAll(page);
      if (page.length < pageSize) break;
      start += pageSize;
    }

    return all;
  }

  /// Fetches a single document including child tables (e.g. Sales Order items).
  Future<Map<String, dynamic>> fetchDocument(
    String doctype,
    String name,
  ) async {
    await ensureLoggedIn();

    final encodedDoctype = Uri.encodeComponent(doctype);
    final encodedName = Uri.encodeComponent(name);
    final uri = Uri.parse('$baseUrl/api/resource/$encodedDoctype/$encodedName');

    final response = await _get(uri);
    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(_extractFrappeError(decoded, response.statusCode));
    }

    if (decoded is! Map || decoded['data'] is! Map) {
      throw Exception('Invalid Frappe document response for $doctype/$name.');
    }

    final data = decoded['data'];
    return data is Map<String, dynamic>
        ? data
        : Map<String, dynamic>.from(data as Map);
  }

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.postUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (headers != null) {
        headers.forEach((key, value) {
          if (key.toLowerCase() == HttpHeaders.expectHeader.toLowerCase()) {
            return;
          }
          request.headers.set(key, value);
        });
      }
      if (_cookies.isNotEmpty) {
        request.headers.set(HttpHeaders.cookieHeader, _cookieHeader());
      }
      request.headers.removeAll(HttpHeaders.expectHeader);

      if (body != null) {
        if (body is Map<String, String>) {
          request.headers.set(
            HttpHeaders.contentTypeHeader,
            'application/x-www-form-urlencoded',
          );
          request.write(Uri(queryParameters: body).query);
        } else {
          request.write(body.toString());
        }
      }

      // capture headers actually sent for debugging
      final sentRequestHeaders = <String, String>{};
      request.headers.forEach((name, values) {
        sentRequestHeaders[name] = values.join(',');
      });

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      _updateCookiesFromHeaders(response.headers);
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(',');
      });
      if (response.statusCode >= 400) {
        print('FrappeService POST error for ${uri.toString()}');
        print('Sent request headers: $sentRequestHeaders');
        print('Response status: ${response.statusCode}');
        print('Response headers: $responseHeaders');
        print('Response body: $responseBody');
      }
      return http.Response(
        responseBody,
        response.statusCode,
        headers: responseHeaders,
        reasonPhrase: response.reasonPhrase,
      );
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (headers != null) {
        headers.forEach((key, value) {
          if (key.toLowerCase() == HttpHeaders.expectHeader.toLowerCase()) {
            return;
          }
          request.headers.set(key, value);
        });
      }
      if (_cookies.isNotEmpty) {
        request.headers.set(HttpHeaders.cookieHeader, _cookieHeader());
      }
      request.headers.removeAll(HttpHeaders.expectHeader);

      // capture headers actually sent for debugging
      final sentRequestHeaders = <String, String>{};
      request.headers.forEach((name, values) {
        sentRequestHeaders[name] = values.join(',');
      });

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      _updateCookiesFromHeaders(response.headers);
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(',');
      });
      if (response.statusCode >= 400) {
        print('FrappeService GET error for ${uri.toString()}');
        print('Sent request headers: $sentRequestHeaders');
        print('Response status: ${response.statusCode}');
        print('Response headers: $responseHeaders');
        print('Response body: $responseBody');
      }
      return http.Response(
        responseBody,
        response.statusCode,
        headers: responseHeaders,
        reasonPhrase: response.reasonPhrase,
      );
    } finally {
      httpClient.close(force: true);
    }
  }

  void _updateCookiesFromHeaders(HttpHeaders headers) {
    headers.forEach((name, values) {
      if (name.toLowerCase() != 'set-cookie') return;
      for (final rawCookie in values) {
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
    });
  }

  String _cookieHeader() {
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  static String _extractFrappeError(dynamic decoded, int statusCode) {
    if (decoded is Map) {
      final exception = decoded['exception']?.toString();
      if (exception != null && exception.isNotEmpty) {
        return exception;
      }

      final exc = decoded['exc']?.toString();
      if (exc != null && exc.isNotEmpty) {
        return exc;
      }

      final message = decoded['message'];
      if (message != null) {
        return message.toString();
      }

      final serverMessages = decoded['_server_messages']?.toString();
      if (serverMessages != null && serverMessages.isNotEmpty) {
        return serverMessages;
      }
    }

    return 'Frappe API error: $statusCode';
  }
}
