import 'dart:convert';

enum SignalingType { offer, answer, iceCandidate }

class SignalingPayload {
  final SignalingType type;
  final String? sdp;
  final Map<String, dynamic>? candidate;
  final String fromUserId;
  final DateTime timestamp;

  SignalingPayload({
    required this.type,
    this.sdp,
    this.candidate,
    required this.fromUserId,
    required this.timestamp,
  });

  bool get isExpired => 
      DateTime.now().difference(timestamp).inMilliseconds > 2500;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'sdp': sdp,
    'candidate': candidate,
    'fromUserId': fromUserId,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SignalingPayload.fromJson(Map<String, dynamic> json) => SignalingPayload(
    type: SignalingType.values.byName(json['type']),
    sdp: json['sdp'],
    candidate: json['candidate'],
    fromUserId: json['fromUserId'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}
