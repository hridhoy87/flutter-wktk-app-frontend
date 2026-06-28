import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../domain/repositories/signaling_repository.dart';
import '../domain/entities/signaling_payload.dart';
import 'package:walkie_talkie/src/core/utils/logger.dart';

class MqttSignalingRepositoryImpl implements SignalingRepository {
  final MqttServerClient client;
  final _controller = StreamController<SignalingPayload>.broadcast();
  String? _channelId;
  late String _currentUserId;
  bool _isListening = false;
  
  static const String topicPrefix = 'walkie_talkie_v3_99';

  MqttSignalingRepositoryImpl(this.client);

  @override
  Stream<SignalingPayload> get signalingStream => _controller.stream;

  @override
  Future<void> init(String channelId, String userId) async {
    // Unsubscribe from previous channel if any
    if (this._channelId != null) {
      final oldTopic = '$topicPrefix/channels/$_channelId/users/$_currentUserId/signaling';
      client.unsubscribe(oldTopic);
    }

    _channelId = channelId;
    _currentUserId = userId;
    
    final sigTopic = '$topicPrefix/channels/$_channelId/users/$_currentUserId/signaling';
    final broadcastTopic = '$topicPrefix/channels/$_channelId/broadcast';
    final inviteTopic = '$topicPrefix/users/$_currentUserId/invites';
    
    client.subscribe(sigTopic, MqttQos.atLeastOnce);
    client.subscribe(broadcastTopic, MqttQos.atLeastOnce);
    client.subscribe(inviteTopic, MqttQos.atLeastOnce);
    
    L.info('MQTT: Subscribed to signaling ($sigTopic), broadcast ($broadcastTopic) and invites ($inviteTopic)');
    
    // Only set up listener once
    if (_isListening) return;
    _isListening = true;

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final String receivedTopic = c[0].topic;
      final bool isSignaling = receivedTopic.contains('/signaling');
      final bool isBroadcast = receivedTopic.contains('/broadcast');
      final bool isInvite = receivedTopic.contains('/invites');
      
      if (!isSignaling && !isInvite && !isBroadcast) return;
      
      // If it's signaling, it MUST be for us. If it's broadcast, it's for everyone in the channel.
      if (isSignaling && !receivedTopic.contains(_currentUserId)) return;

      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      
      try {
        final data = SignalingPayload.fromJson(jsonDecode(payload));
        if (data.fromUserId != _currentUserId && !data.isExpired) {
          _controller.add(data);
        }
      } catch (e) {
        // Ignore noise from public broker
      }
    });
  }

  @override
  Future<void> sendSignaling(String targetUserId, SignalingPayload payload) async {
    if (client.connectionStatus?.state != MqttConnectionState.connected) return;

    final topic = '$topicPrefix/channels/$_channelId/users/$targetUserId/signaling';
    _publish(topic, payload, qos: MqttQos.atLeastOnce); // Use QoS 1 for reliable handshake
  }

  @override
  Future<void> sendBroadcast(SignalingPayload payload) async {
    if (client.connectionStatus?.state != MqttConnectionState.connected) return;

    final topic = '$topicPrefix/channels/$_channelId/broadcast';
    _publish(topic, payload, qos: MqttQos.atLeastOnce);
  }

  @override
  Future<void> sendInvite(String targetUserId, SignalingPayload payload) async {
    if (client.connectionStatus?.state != MqttConnectionState.connected) return;

    final topic = '$topicPrefix/users/$targetUserId/invites';
    _publish(topic, payload);
  }

  void _publish(String topic, SignalingPayload payload, {MqttQos qos = MqttQos.atMostOnce}) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload.toJson()));
    client.publishMessage(topic, qos, builder.payload!);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
