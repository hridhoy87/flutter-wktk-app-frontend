import 'dart:async';

enum UserStatus { online, offline, busy }

abstract class PresenceRepository {
  /// Stream of status updates for users in the current active group.
  /// Key: UserId, Value: UserStatus
  Stream<Map<String, UserStatus>> get groupPresenceStream;

  /// Connect to the MQTT broker with Last Will and Testament (LWT)
  /// for ungraceful disconnect detection.
  Future<void> connect({
    required String userId,
    required List<String> groupIds,
  });

  /// Update the current user's online status
  Future<void> updateStatus(UserStatus status);

  /// Gracefully disconnect from the presence service
  Future<void> disconnect();
}
