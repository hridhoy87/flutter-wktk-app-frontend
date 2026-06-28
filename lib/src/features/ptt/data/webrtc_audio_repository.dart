import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:audio_session/audio_session.dart';
import '../domain/repositories/audio_repository.dart';
import '../domain/entities/signaling_payload.dart';
import 'package:walkie_talkie/src/core/utils/logger.dart';

class WebRtcAudioRepositoryImpl implements AudioRepository {
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, List<RTCIceCandidate>> _remoteQueues = {};
  
  final Set<String> _activeTalkers = {};
  MediaStream? _localStream;
  String? _currentUserId;
  
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  void setUserId(String userId) => _currentUserId = userId;
  final _pttStateController = StreamController<PttState>.broadcast();
  final _signalingController = StreamController<SignalingPayload>.broadcast();

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  @override
  Stream<PttState> get pttStateStream => _pttStateController.stream;

  @override
  Stream<SignalingPayload> get signalingStream => _signalingController.stream;

  @override
  Future<void> initialize({required List<Map<String, dynamic>> iceServers}) async {
    L.webrtc('Initializing Mesh Audio Engine...');
    await _remoteRenderer.initialize();
    if (iceServers.isNotEmpty) _configuration['iceServers'] = iceServers;
    
    await _configureAudioSession(PttState.idle);
    _updateState(PttState.idle);
  }

  Future<void> _configureAudioSession(PttState state) async {
    final session = await AudioSession.instance;
    try {
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: 
            AVAudioSessionCategoryOptions.allowBluetooth | 
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ));
      await session.setActive(true);
      await Helper.setSpeakerphoneOn(true);
    } catch (e) {
      L.error('AudioSession Config Error', e);
    }
  }

  Future<void> _initLocalStream() async {
    if (_localStream != null) return;
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
    } catch (e) {
      L.error('Mic Acquisition Failed', e);
      rethrow;
    }
  }

  @override
  Future<void> startTransmission(String groupId) async {
    L.ptt('>>> PTT STARTING');
    await _initLocalStream();
    
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = true;
      
      // BROADCAST VOICE_START first.
      // This will trigger receivers to initiate negotiation back to us.
      _signalingController.add(SignalingPayload(
        type: SignalingType.offer,
        sdp: 'VOICE_START',
        fromUserId: _currentUserId ?? 'unknown',
        timestamp: DateTime.now(),
      ));

      // We do NOT initiate negotiation here anymore.
      // We wait for the receivers to send us an offer.
      // This prevents the "Double Offer" conflict.
    }

    _updateState(PttState.talking);
  }

  @override
  Future<void> stopTransmission() async {
    L.ptt('<<< PTT STOPPING');
    
    // 1. Notify others immediately via MQTT
    _signalingController.add(SignalingPayload(
      type: SignalingType.offer,
      sdp: 'VOICE_STOP',
      fromUserId: _currentUserId ?? 'unknown',
      timestamp: DateTime.now(),
    ));

    // 2. Physically close and clear all PeerConnections to cut the audio pipes
    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();
    _remoteQueues.clear();

    // 3. Completely kill the mic hardware
    if (_localStream != null) {
      _localStream!.getTracks().forEach((t) => t.stop());
      await _localStream!.dispose();
      _localStream = null;
    }

    // 4. Deactivate Audio Session to release the "Call Mode" in OS
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      L.error('Failed to deactivate audio session', e);
    }
    
    _updateState(_activeTalkers.isNotEmpty ? PttState.receiving : PttState.idle);
  }

  @override
  Future<void> handleIncomingSignaling(SignalingPayload payload) async {
    if (_currentUserId == payload.fromUserId) return;
    final peerId = payload.fromUserId;

    if (payload.sdp == 'VOICE_START') {
      _activeTalkers.add(peerId);
      if (_localStream == null) {
        await _configureAudioSession(PttState.receiving);
        _updateState(PttState.receiving);
      }
      
      // Small random delay (0-300ms) to prevent MQTT/WebRTC collision spikes
      await Future.delayed(Duration(milliseconds: 50 + (peerId.hashCode % 250)));
      
      // Receiver initiates connection back to the sender
      await _negotiate(peerId);
      return;
    }
    
    if (payload.sdp == 'VOICE_STOP') {
      L.ptt('Receiver: Stop signal from $peerId');
      _activeTalkers.remove(peerId);
      
      // Close the specific connection for this talker
      final pc = _peerConnections.remove(peerId);
      if (pc != null) {
        await pc.close();
      }

      if (_activeTalkers.isEmpty) {
        _remoteRenderer.srcObject = null;
        if (_localStream == null) {
          _updateState(PttState.idle);
          // Release session when fully idle
          try {
            final session = await AudioSession.instance;
            await session.setActive(false);
          } catch (_) {}
        }
      }
      return;
    }

    switch (payload.type) {
      case SignalingType.offer:
        await _handleOffer(peerId, payload.sdp!);
        break;
      case SignalingType.answer:
        await _handleAnswer(peerId, payload.sdp!);
        break;
      case SignalingType.iceCandidate:
        await _handleIceCandidate(peerId, payload.candidate!);
        break;
      default:
        break;
    }
  }

  Future<void> _negotiate(String peerId) async {
    final pc = await _getOrCreatePC(peerId);
    
    // Force the connection to expect audio
    RTCSessionDescription offer = await pc.createOffer({
      'mandatory': {'OfferToReceiveAudio': true},
      'optional': [],
    });
    await pc.setLocalDescription(offer);
    
    _signalingController.add(SignalingPayload(
      type: SignalingType.offer,
      sdp: offer.sdp,
      fromUserId: _currentUserId ?? 'unknown',
      toUserId: peerId,
      timestamp: DateTime.now(),
    ));
  }

  Future<RTCPeerConnection> _getOrCreatePC(String peerId) async {
    if (_peerConnections.containsKey(peerId)) {
      final pc = _peerConnections[peerId]!;
      // If we already have a connection but just started talking, make sure track is added
      if (_localStream != null) {
        final senders = await pc.getSenders();
        if (!senders.any((s) => s.track?.kind == 'audio')) {
          pc.addTrack(_localStream!.getAudioTracks().first, _localStream!);
        }
      }
      return pc;
    }

    L.webrtc('New connection for $peerId');
    final pc = await createPeerConnection(_configuration);
    
    pc.onIceConnectionState = (state) {
      L.webrtc('ICE Connection State for $peerId: $state');
    };

    pc.onIceCandidate = (candidate) {
      _signalingController.add(SignalingPayload(
        type: SignalingType.iceCandidate,
        candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
        fromUserId: _currentUserId ?? 'unknown',
        toUserId: peerId,
        timestamp: DateTime.now(),
      ));
    };

    pc.onTrack = (event) {
      if (event.track.kind == 'audio' && event.streams.isNotEmpty) {
        L.success('Track connected for $peerId. Stream ID: ${event.streams[0].id}');
        
        // Ensure the track is enabled
        event.track.enabled = true;
        
        _remoteRenderer.srcObject = event.streams[0];
        
        // Force audio routing to speaker again just in case
        Helper.setSpeakerphoneOn(true);
      }
    };

    if (_localStream != null) {
      final tracks = _localStream!.getAudioTracks();
      if (tracks.isNotEmpty) {
        final senders = await pc.getSenders();
        if (!senders.any((s) => s.track?.kind == 'audio')) {
          await pc.addTrack(tracks.first, _localStream!);
        }
      }
    }

    _peerConnections[peerId] = pc;
    return pc;
  }

  Future<void> _handleOffer(String peerId, String sdp) async {
    final pc = await _getOrCreatePC(peerId);
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    
    // If we are currently talking, we MUST ensure our track is included in the answer
    if (_localStream != null) {
       final senders = await pc.getSenders();
       if (!senders.any((s) => s.track?.kind == 'audio')) {
         pc.addTrack(_localStream!.getAudioTracks().first, _localStream!);
       }
    }

    if (_remoteQueues.containsKey(peerId)) {
      for (var c in _remoteQueues[peerId]!) await pc.addCandidate(c);
      _remoteQueues.remove(peerId);
    }

    RTCSessionDescription answer = await pc.createAnswer({
      'mandatory': {'OfferToReceiveAudio': true},
      'optional': [],
    });
    await pc.setLocalDescription(answer);

    _signalingController.add(SignalingPayload(
      type: SignalingType.answer,
      sdp: answer.sdp,
      fromUserId: _currentUserId ?? 'unknown',
      toUserId: peerId,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _handleAnswer(String peerId, String sdp) async {
    final pc = _peerConnections[peerId];
    if (pc == null) return;

    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));

    // DRAIN CANDIDATE QUEUE: Crucial fix for bidirectional connectivity
    if (_remoteQueues.containsKey(peerId)) {
      L.webrtc('Draining ${_remoteQueues[peerId]!.length} queued candidates for $peerId');
      for (var c in _remoteQueues[peerId]!) {
        await pc.addCandidate(c);
      }
      _remoteQueues.remove(peerId);
    }
  }

  Future<void> _handleIceCandidate(String peerId, Map<String, dynamic> data) async {
    final candidate = RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
    final pc = _peerConnections[peerId];
    
    if (pc != null && await pc.getRemoteDescription() != null) {
      await pc.addCandidate(candidate);
    } else {
      _remoteQueues.putIfAbsent(peerId, () => []).add(candidate);
    }
  }

  void _updateState(PttState state) {
    if (!_pttStateController.isClosed) _pttStateController.add(state);
  }

  @override
  Future<void> dispose() async {
    for (var pc in _peerConnections.values) await pc.close();
    _peerConnections.clear();
    await _localStream?.dispose();
    await _remoteRenderer.dispose();
    await _pttStateController.close();
    await _signalingController.close();
  }
  
  @override
  Future<void> joinStream(String streamId) async {}
}
