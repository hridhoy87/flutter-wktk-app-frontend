import '../../auth/domain/entities/user_entity.dart'; // Assuming a common user entity

abstract class IAdminRepository {
  Future<String> login(String agentId, String passcode);
  Future<List<Map<String, dynamic>>> getPendingUsers();
  Future<void> approveUser(int userId);
  Future<void> rejectUser(int userId);
}
