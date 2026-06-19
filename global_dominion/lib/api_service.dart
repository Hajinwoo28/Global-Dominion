import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  String? _cookie;

  static const Duration _timeout = Duration(seconds: 10);

  ApiService({required this.baseUrl});

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_cookie != null) {
      headers['cookie'] = _cookie!;
    }
    return headers;
  }

  void _updateCookie(http.Response response) {
    String? rawCookie = response.headers['set-cookie'];
    if (rawCookie != null) {
      int index = rawCookie.indexOf(';');
      _cookie = (index == -1) ? rawCookie : rawCookie.substring(0, index);
    }
  }

  Future<bool> login(String identifier, String password) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'identifier': identifier, 'password': password}),
        )
        .timeout(_timeout);

    if (response.statusCode == 302 || response.statusCode == 200) {
      _updateCookie(response);
      return true;
    }
    return false;
  }

  Future<bool> register(
    String username,
    String email,
    String password,
    String confirmPassword,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/register'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'username': username,
            'email': email,
            'password': password,
            'confirm_password': confirmPassword,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 302 || response.statusCode == 200) {
      _updateCookie(response);
      return true;
    }
    return false;
  }

  Future<bool> setCountry(String country) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/country_selection'),
          headers: _headers,
          body: json.encode({'country': country}),
        )
        .timeout(_timeout);

    if (response.statusCode == 302 || response.statusCode == 200) {
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> getState() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/state'), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load state: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> attack(int territoryId, {String? spell}) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/attack'),
          headers: _headers,
          body: json.encode({'territory_id': territoryId, 'spell': spell}),
        )
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Attack failed: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> recruitUnit(
    String unitType,
    int quantity,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/recruit_unit'),
          headers: _headers,
          body: json.encode({'unit_type': unitType, 'quantity': quantity}),
        )
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Recruitment failed: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> evolveUnit(String unitType) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/evolve_unit'),
          headers: _headers,
          body: json.encode({'unit_type': unitType}),
        )
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Evolution failed: ${response.statusCode}');
    }
  }
}
