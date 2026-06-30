import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final http.Client _client = http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final mergedHeaders = {..._headers, ...?headers};
    return await _client.get(url, headers: mergedHeaders);
  }

  Future<http.Response> post(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final mergedHeaders = {..._headers, ...?headers};
    return await _client.post(url,
        headers: mergedHeaders, body: body, encoding: encoding);
  }

  http.MultipartRequest createMultipartRequest(String method, Uri url) {
    final request = http.MultipartRequest(method, url);
    request.headers.addAll(_headers);
    return request;
  }
}
