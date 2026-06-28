abstract class IAdminRepository {
  Future<String> login(String agentId, String passcode);
  Future<List<Map<String, dynamic>>> getPendingUsers();
  Future<void> approveUser(int userId);
  Future<void> rejectUser(int userId);
  Future<Map<String, dynamic>> updateProfile({String? legalName, String? password});
  Future<Map<String, dynamic>> getOwnProfile();
  Future<List<Map<String, dynamic>>> getChannels();
  Future<void> updateChannelPassword(int channelId, String password);
}
