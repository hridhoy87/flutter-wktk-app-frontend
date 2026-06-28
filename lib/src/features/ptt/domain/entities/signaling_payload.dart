enum SignalingType { offer, answer, iceCandidate, invite, accept, decline }

class SignalingPayload {
  final SignalingType type;
  final String? sdp;
  final Map<String, dynamic>? candidate;
  final String fromUserId;
  final DateTime timestamp;
  final String? groupId;
  final String? password;
  final bool isCustom;
  final String? channelName;

  SignalingPayload({
    required this.type,
    this.sdp,
    this.candidate,
    required this.fromUserId,
    required this.timestamp,
    this.groupId,
    this.password,
    this.isCustom = false,
    this.channelName,
  });

  bool get isExpired => 
      DateTime.now().difference(timestamp).inSeconds.abs() > 30; // Increased for invites

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'sdp': sdp,
    'candidate': candidate,
    'fromUserId': fromUserId,
    'timestamp': timestamp.toIso8601String(),
    'groupId': groupId,
    'password': password,
    'isCustom': isCustom,
    'channelName': channelName,
  };

  factory SignalingPayload.fromJson(Map<String, dynamic> json) {
    return SignalingPayload(
      type: SignalingType.values.byName(json['type'] ?? 'offer'),
      sdp: json['sdp'],
      candidate: json['candidate'],
      fromUserId: json['fromUserId'] ?? 'unknown',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
      groupId: json['groupId'],
      password: json['password'],
      isCustom: json['isCustom'] ?? false,
      channelName: json['channelName'],
    );
  }
}
