import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/admin_repository_interface.dart';

class AdminRepositoryImpl implements IAdminRepository {
  final String baseUrl;
  String? _adminToken;

  AdminRepositoryImpl({required this.baseUrl});

  @override
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
      _adminToken = data['access_token'];
      return _adminToken!;
    } else {
      throw Exception('Admin Login Failed: ${response.body}');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/pending-users'),
      headers: {
        'Authorization': 'Bearer $_adminToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to fetch pending users');
    }
  }

  @override
  Future<void> approveUser(int userId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/admin/approve-user/$userId'),
      headers: {'Authorization': 'Bearer $_adminToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to approve user');
    }
  }

  @override
  Future<void> rejectUser(int userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/admin/reject-user/$userId'),
      headers: {'Authorization': 'Bearer $_adminToken'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to reject user');
    }
  }

  @override
  Future<Map<String, dynamic>> updateProfile({String? legalName, String? password}) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/users/me'),
      headers: {
        'Authorization': 'Bearer $_adminToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (legalName != null) 'legal_name': legalName,
        if (password != null) 'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Update profile failed');
    }
  }

  @override
  Future<Map<String, dynamic>> getOwnProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/home'),
      headers: {
        'Authorization': 'Bearer $_adminToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to fetch profile');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getChannels() async {
    final response = await http.get(
      Uri.parse('$baseUrl/channels'),
      headers: {'Authorization': 'Bearer $_adminToken'},
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw Exception('Failed to fetch channels');
  }

  @override
  Future<void> updateChannelPassword(int channelId, String password) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/channels/$channelId/password'),
      headers: {
        'Authorization': 'Bearer $_adminToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'password': password}),
    );
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Failed to update channel password');
    }
  }
}
