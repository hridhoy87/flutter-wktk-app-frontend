import 'dart:async';
import '../entities/signaling_payload.dart';

enum PttState { 
  idle,       // App is ready but not transmitting or receiving
  connecting, // WebRTC handshake in progress
  talking,    // Local user is pushing to talk
  receiving,  // Remote user is talking
  error       // Something went wrong with the stream
}

abstract class AudioRepository {
  /// Stream of the current PTT state to drive the UI
  Stream<PttState> get pttStateStream;

  /// Stream of signaling payloads (Offers, ICE Candidates) to be sent to peers
  Stream<SignalingPayload> get signalingStream;

  /// Initialize WebRTC configurations (ICE Servers, etc.)
  Future<void> initialize({
    required List<Map<String, dynamic>> iceServers,
  });

  /// Open audio channel and start transmitting to the target group
  Future<void> startTransmission(String groupId);

  /// Close transmission channel
  Future<void> stopTransmission();

  /// Handle incoming signaling message from a peer
  Future<void> handleIncomingSignaling(SignalingPayload payload);

  /// Cleanup resources
  Future<void> dispose();
}
