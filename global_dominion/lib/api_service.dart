import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;
  String? _cookie;

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
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      body: {
        'identifier': identifier,
        'password': password,
      },
    );

    if (response.statusCode == 302 || response.statusCode == 200) {
      _updateCookie(response);
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> getState() async {
    final response = await http.get(Uri.parse('$baseUrl/api/state'), headers: _headers);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load state: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> attack(int territoryId, {String? spell}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/attack'),
      headers: _headers,
      body: json.encode({
        'territory_id': territoryId,
        'spell': spell,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Attack failed: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> recruitUnit(String unitType, int quantity) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/recruit_unit'),
      headers: _headers,
      body: json.encode({
        'unit_type': unitType,
        'quantity': quantity,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Recruitment failed: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> evolveUnit(String unitType) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/evolve_unit'),
      headers: _headers,
      body: json.encode({
        'unit_type': unitType,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Evolution failed: ${response.statusCode}');
    }
  }
}
