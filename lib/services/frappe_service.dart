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

  Future<Map<String, dynamic>> createDocument(
    String doctype,
    Map<String, dynamic> data,
  ) async {
    await ensureLoggedIn();

    final encodedDoctype = Uri.encodeComponent(doctype);
    final uri = Uri.parse('$baseUrl/api/resource/$encodedDoctype');

    final response = await _post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(_extractFrappeError(decoded, response.statusCode));
    }

    if (decoded is! Map || decoded['data'] is! Map) {
      throw Exception('Invalid create response for $doctype.');
    }

    final payload = decoded['data'];
    return payload is Map<String, dynamic>
        ? payload
        : Map<String, dynamic>.from(payload as Map);
  }

  Future<void> updateDocument(
    String doctype,
    String name,
    Map<String, dynamic> data,
  ) async {
    await ensureLoggedIn();

    final encodedDoctype = Uri.encodeComponent(doctype);
    final encodedName = Uri.encodeComponent(name);
    final uri = Uri.parse(
      '$baseUrl/api/resource/$encodedDoctype/$encodedName',
    );

    final response = await _put(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(_extractFrappeError(decoded, response.statusCode));
    }
  }

  Future<dynamic> callMethod(
    String method, {
    Map<String, dynamic>? args,
  }) async {
    await ensureLoggedIn();

    final uri = Uri.parse('$baseUrl/api/method/$method');
    final response = await _post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(args ?? {}),
    );
    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(_extractFrappeError(decoded, response.statusCode));
    }

    if (decoded is Map && decoded['exc'] != null) {
      throw Exception(decoded['exc'].toString());
    }

    if (decoded is Map) {
      return decoded['message'];
    }
    return decoded;
  }

  Future<Map<String, dynamic>> submitDocument(
    String doctype,
    String name,
  ) async {
    final doc = await fetchDocument(doctype, name);
    final result = await callMethod(
      'frappe.client.submit',
      args: {'doc': doc},
    );
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    return fetchDocument(doctype, name);
  }

  Future<Map<String, dynamic>> cancelDocument(
    String doctype,
    String name,
  ) async {
    final doc = await fetchDocument(doctype, name);
    final result = await callMethod(
      'frappe.client.cancel',
      args: {'doc': doc},
    );
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    return fetchDocument(doctype, name);
  }

  Future<void> deleteDocument(String doctype, String name) async {
    await ensureLoggedIn();

    final encodedDoctype = Uri.encodeComponent(doctype);
    final encodedName = Uri.encodeComponent(name);
    final uri = Uri.parse('$baseUrl/api/resource/$encodedDoctype/$encodedName');

    final response = await _delete(uri);
    final decoded = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode != 200 && response.statusCode != 202) {
      throw Exception(_extractFrappeError(decoded, response.statusCode));
    }
  }

  Future<http.Response> _put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.putUrl(uri);
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
        request.write(body.toString());
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      _updateCookiesFromHeaders(response.headers);
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(',');
      });
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

  Future<http.Response> _delete(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.deleteUrl(uri);
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

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      _updateCookiesFromHeaders(response.headers);
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values.join(',');
      });
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
