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
      Uri.parse('$baseUrl/token'),
      body: {
        'username': phone,
        'password': password,
      },
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
      headers: {'Authorization': 'Bearer $_adminToken'},
    );

    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    } else {
      throw Exception('Failed to fetch pending users');
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
}
