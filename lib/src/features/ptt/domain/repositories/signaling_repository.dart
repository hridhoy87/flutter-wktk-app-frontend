import '../entities/signaling_payload.dart';

abstract class SignalingRepository {
  Stream<SignalingPayload> get signalingStream;
  
  Future<void> init(String channelId, String userId);
  
  Future<void> sendSignaling(String targetUserId, SignalingPayload payload);

  Future<void> sendBroadcast(SignalingPayload payload);

  Future<void> sendInvite(String targetUserId, SignalingPayload payload);
  
  Future<void> disconnect();
  
  Future<void> dispose();
}
