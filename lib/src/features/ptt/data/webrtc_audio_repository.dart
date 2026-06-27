import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../domain/repositories/audio_repository.dart';

class WebRtcAudioRepositoryImpl implements AudioRepository {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final _pttStateController = StreamController<PttState>.broadcast();
  PttState _currentState = PttState.idle;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  @override
  Stream<PttState> get pttStateStream => _pttStateController.stream;

  @override
  Future<void> initialize({required List<Map<String, dynamic>> iceServers}) async {
    if (iceServers.isNotEmpty) {
      _configuration['iceServers'] = iceServers;
    }
    _updateState(PttState.idle);
  }

  @override
  Future<void> startTransmission(String groupId) async {
    try {
      _updateState(PttState.connecting);
      
      final Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': false,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      _peerConnection = await createPeerConnection(_configuration);
      
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // In a real PTT app, you'd send the offer to your Signaling Server here
      // For this implementation, we simulate the 'talking' state
      _updateState(PttState.talking);
      
    } catch (e) {
      _updateState(PttState.error);
      rethrow;
    }
  }

  @override
  Future<void> stopTransmission() async {
    await _cleanupConnection();
    _updateState(PttState.idle);
  }

  @override
  Future<void> joinStream(String streamId) async {
    _updateState(PttState.receiving);
    // Logic to handle incoming offer and set remote description
  }

  Future<void> _cleanupConnection() async {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    
    await _peerConnection?.close();
    _peerConnection = null;
  }

  void _updateState(PttState state) {
    _currentState = state;
    _pttStateController.add(state);
  }

  @override
  Future<void> dispose() async {
    await _cleanupConnection();
    await _pttStateController.close();
  }
}
