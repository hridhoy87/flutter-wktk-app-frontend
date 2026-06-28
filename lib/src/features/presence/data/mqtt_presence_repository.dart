import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../domain/repositories/presence_repository.dart';
import '../../../core/utils/logger.dart';

class MqttPresenceRepositoryImpl implements PresenceRepository {
  final MqttServerClient client;
  final _statusController = StreamController<Map<String, UserStatus>>.broadcast();
  final Map<String, UserStatus> _currentPresence = {};
  List<String> _groupIds = [];
  String? _userId;
  bool _isListening = false;
  
  static const String topicPrefix = 'walkie_talkie_v3_99'; 

  MqttPresenceRepositoryImpl(String server, String clientId)
      : client = MqttServerClient(server, clientId);

  @override
  Stream<Map<String, UserStatus>> get groupPresenceStream => _statusController.stream;

  @override
  Future<void> connect({required String userId, required List<String> groupIds}) async {
    _groupIds = groupIds;
    _userId = userId;
    
    final state = client.connectionStatus?.state;
    
    if (state == MqttConnectionState.connected) {
      _onConnected();
      return;
    }
    
    if (state == MqttConnectionState.connecting) {
      L.info('MQTT: Already connecting, waiting...');
      return;
    }
    
    client.logging(on: false);
    client.setProtocolV311();
    client.keepAlivePeriod = 20;
    client.autoReconnect = true;
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(userId)
        .withWillTopic('$topicPrefix/groups/${groupIds.first}/presence/$userId')
        .withWillMessage(jsonEncode({'status': 'offline'}))
        .withWillRetain()
        .startClean();
    client.connectionMessage = connMessage;

    try {
      L.info('MQTT: Connecting to broker as $userId...');
      await client.connect();
    } catch (e) {
      if (e.toString().contains('connecting')) {
        L.warning('MQTT: Ignored connection attempt during "connecting" state');
      } else {
        L.error('MQTT Connection Failed', e);
      }
    }
  }

  void _onConnected() {
    L.success('MQTT: Connected and Authenticated');
    
    if (_userId != null && client.connectionStatus?.state == MqttConnectionState.connected) {
      _currentPresence.clear();

      for (final groupId in _groupIds) {
        final topic = '$topicPrefix/groups/$groupId/presence/#';
        client.subscribe(topic, MqttQos.atMostOnce);
        L.info('MQTT: Subscribed to $topic');
      }
      
      if (!_isListening && client.updates != null) {
        _isListening = true;
        client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
          final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
          final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
          _handlePresenceUpdate(c[0].topic, pt);
        });
      }

      updateStatus(UserStatus.online);
    }
  }

  void _handlePresenceUpdate(String topic, String payload) {
    try {
      if (!topic.contains('/presence/')) return;
      
      final data = jsonDecode(payload);
      final parts = topic.split('/');
      final userId = parts.last;
      
      // Ignore our own presence updates from the broker
      if (userId == _userId) return;

      final statusStr = data['status'] as String? ?? 'offline';
      
      UserStatus status;
      switch (statusStr) {
        case 'online': status = UserStatus.online; break;
        case 'busy': status = UserStatus.busy; break;
        default: status = UserStatus.offline;
      }

      if (_currentPresence[userId] != status) {
        L.info('User $userId is now $statusStr');
        _currentPresence[userId] = status;
        _statusController.add(Map.from(_currentPresence));
      }
    } catch (e) {
      // Quietly ignore malformed presence from other apps
    }
  }

  @override
  Future<void> updateStatus(UserStatus status) async {
    if (client.connectionStatus?.state != MqttConnectionState.connected) return;

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode({'status': status.name}));
    
    final payload = builder.payload!;
    for (final groupId in _groupIds) {
      final topic = '$topicPrefix/groups/$groupId/presence/$_userId';
      client.publishMessage(topic, MqttQos.atMostOnce, payload, retain: true);
    }
  }

  @override
  Future<void> disconnect() async {
    await updateStatus(UserStatus.offline);
    client.disconnect();
  }

  void _onDisconnected() {
    L.warning('MQTT: Connection Lost. Waiting for auto-reconnect...');
  }
}
