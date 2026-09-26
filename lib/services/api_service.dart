import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static const String keyToken = 'auth_token';
  static const String keyPendingMeeting = 'pending_meeting_uuid';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyToken);
  }

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyToken, token);
  }

  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyToken);
  }

  static Future<String?> getPendingMeetingUuid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyPendingMeeting);
  }

  static Future<void> setPendingMeetingUuid(String uuid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyPendingMeeting, uuid);
  }

  static Future<void> removePendingMeetingUuid() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyPendingMeeting);
  }

  static Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (requireAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Future<Map<String, dynamic>> get(String endpoint, {bool requireAuth = true}) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);

    try {
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));
      return _processResponse(response);
    } catch (e) {
      return {'status': 'error', 'message': 'Network connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body, {bool requireAuth = true}) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);

    try {
      final response = await http.post(url, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 8));
      return _processResponse(response);
    } catch (e) {
      return {'status': 'error', 'message': 'Network connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> delete(String endpoint, {bool requireAuth = true}) async {
    final baseUrl = await ApiConfig.getBaseUrl();
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders(requireAuth: requireAuth);

    try {
      final response = await http.delete(url, headers: headers).timeout(const Duration(seconds: 8));
      return _processResponse(response);
    } catch (e) {
      return {'status': 'error', 'message': 'Network connection error: $e'};
    }
  }

  static Map<String, dynamic> _processResponse(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return json;
        } else if (response.statusCode == 202) {
          // Accepted / Pending approval
          return json;
        } else {
          return {
            'status': 'error',
            'code': json['code'] ?? 'HTTP_${response.statusCode}',
            'message': json['message'] ?? (json['errors'] != null ? _flattenErrors(json['errors']) : 'Request failed'),
            'data': json['data'],
          };
        }
      }
      return {'status': 'error', 'message': 'Unexpected server response.'};
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Failed to parse response: ${response.body}',
      };
    }
  }

  static String _flattenErrors(dynamic errors) {
    if (errors is Map) {
      List<String> messages = [];
      errors.forEach((key, value) {
        if (value is List) {
          messages.addAll(value.map((e) => e.toString()));
        } else {
          messages.add(value.toString());
        }
      });
      return messages.join('\n');
    }
    return errors.toString();
  }
}
