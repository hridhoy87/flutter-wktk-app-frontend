import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../domain/repositories/signaling_repository.dart';
import '../domain/entities/signaling_payload.dart';

class MqttSignalingRepositoryImpl implements SignalingRepository {
  final MqttServerClient client;
  final _controller = StreamController<SignalingPayload>.broadcast();
  late String _channelId;
  late String _currentUserId;

  MqttSignalingRepositoryImpl(this.client);

  @override
  Stream<SignalingPayload> get signalingStream => _controller.stream;

  @override
  Future<void> init(String channelId, String userId) async {
    _channelId = channelId;
    _currentUserId = userId;
    
    // Topic: channels/{channelId}/users/{currentUserId}/signaling
    final topic = 'channels/$_channelId/users/$_currentUserId/signaling';
    client.subscribe(topic, MqttQos.atLeastOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      
      final data = SignalingPayload.fromJson(jsonDecode(payload));
      
      // Validation: Drop stale payloads to prevent "lag loops"
      if (!data.isExpired) {
        _controller.add(data);
      }
    });
  }

  @override
  Future<void> sendSignaling(String targetUserId, SignalingPayload payload) async {
    final topic = 'channels/$_channelId/users/$targetUserId/signaling';
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload.toJson()));
    
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
