import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  final String baseUrl;
  static const String _tokenKey = 'auth_token';
  static const String _phoneKey = 'auth_phone';

  AuthRepository({required this.baseUrl});

  Future<String> login(String phone, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['access_token'];
      await _saveToken(token);
      await _savePhone(phone);
      return token;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Login failed');
    }
  }

  Future<void> register(String phone, String legalName, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone': phone,
        'legal_name': legalName,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Registration failed');
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> _savePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, phone);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_phoneKey);
  }

  Future<Map<String, dynamic>> getTurnCredentials() async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/turn-credentials'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch TURN credentials');
    }
  }

  Future<List<Map<String, dynamic>>> getOnlineUsers() async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/users/online'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch users');
    }
  }

  Future<List<Map<String, dynamic>>> getChannels() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/channels'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch channels');
  }

  Future<bool> verifyChannelPassword(int channelId, String password) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/channels/verify'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'channel_id': channelId, 'password': password}),
    );
    return response.statusCode == 200;
  }

  Future<void> updateChannelPassword(int channelId, String password) async {
    final token = await getToken();
    final response = await http.patch(
      Uri.parse('$baseUrl/channels/$channelId/password'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'password': password}),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to update password');
    }
  }

  Future<Map<String, dynamic>> createTempChannel({
    required String name,
    required List<String> allowedUserIds,
    String? password,
  }) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/channels/temp'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'is_protected': password != null && password.isNotEmpty,
        'password': password,
        'allowed_user_ids': allowedUserIds.join(','),
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to create temporary channel');
    }
  }

  Future<void> deleteChannel(int channelId) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl/channels/$channelId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200 && response.statusCode != 404) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to delete channel');
    }
  }
}
