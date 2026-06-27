import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../domain/repositories/presence_repository.dart';

class MqttPresenceRepositoryImpl implements PresenceRepository {
  final MqttServerClient client;
  final _statusController = StreamController<Map<String, UserStatus>>.broadcast();
  final Map<String, UserStatus> _currentPresence = {};

  MqttPresenceRepositoryImpl(String server, String clientId)
      : client = MqttServerClient(server, clientId);

  @override
  Stream<Map<String, UserStatus>> get groupPresenceStream => _statusController.stream;

  @override
  Future<void> connect({required String userId, required List<String> groupIds}) async {
    client.logging(on: false);
    client.setProtocolV311();
    client.keepAlivePeriod = 20;
    client.onDisconnected = _onDisconnected;

    // Configure Last Will and Testament (LWT)
    // This notifies others when this user disconnects ungracefully
    final connMessage = MqttConnectMessage()
        .withClientIdentifier(userId)
        .withWillTopic('presence/$userId')
        .withWillMessage(jsonEncode({'status': 'offline'}))
        .withWillRetain()
        .startClean();
    client.connectionMessage = connMessage;

    try {
      await client.connect();
      
      // Subscribe to presence topics for all allowed groups
      for (final groupId in groupIds) {
        client.subscribe('groups/$groupId/presence/#', MqttQos.atMostOnce);
      }

      // Listen for updates
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        
        _handlePresenceUpdate(c[0].topic, pt);
      });

      // Set initial status to online
      await updateStatus(UserStatus.online);
    } catch (e) {
      client.disconnect();
    }
  }

  void _handlePresenceUpdate(String topic, String payload) {
    try {
      final data = jsonDecode(payload);
      final userId = topic.split('/').last;
      final statusStr = data['status'] as String;
      
      UserStatus status;
      switch (statusStr) {
        case 'online': status = UserStatus.online; break;
        case 'busy': status = UserStatus.busy; break;
        default: status = UserStatus.offline;
      }

      _currentPresence[userId] = status;
      _statusController.add(Map.from(_currentPresence));
    } catch (_) {}
  }

  @override
  Future<void> updateStatus(UserStatus status) async {
    if (client.connectionStatus?.state != MqttConnectionState.connected) return;

    final userId = client.clientIdentifier;
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode({'status': status.name}));
    
    client.publishMessage(
      'presence/$userId',
      MqttQos.atMostOnce,
      builder.payload!,
      retain: true,
    );
  }

  @override
  Future<void> disconnect() async {
    await updateStatus(UserStatus.offline);
    client.disconnect();
  }

  void _onDisconnected() {
    // Handle reconnection logic or notify UI
  }
}
