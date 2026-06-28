import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:audio_session/audio_session.dart';
import '../domain/repositories/audio_repository.dart';
import '../domain/entities/signaling_payload.dart';
import 'package:walkie_talkie/src/core/utils/logger.dart';

class WebRtcAudioRepositoryImpl implements AudioRepository {
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, List<RTCIceCandidate>> _remoteQueues = {};
  
  // Track who is currently talking to manage UI state
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
    // We no longer init local stream here to keep the mic free.
    _updateState(PttState.idle);
  }

  Future<void> _initLocalStream() async {
    if (_localStream != null) return;
    try {
      L.webrtc('Acquiring Microphone...');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          'latency': 0,
        },
        'video': false,
      });
      L.success('Microphone acquired');
    } catch (e) {
      L.error('Mic Init Failed', e);
    }
  }

  @override
  Future<void> startTransmission(String groupId) async {
    L.ptt('>>> TALKING...');
    _updateState(PttState.talking);
    
    // Feature 2: Acquire mic on-demand
    await _initLocalStream();
    
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = true;
      
      // Update existing peer connections with the new track
      for (var pc in _peerConnections.values) {
        final senders = await pc.getSenders();
        final audioSender = senders.where((s) => s.track?.kind == 'audio').firstOrNull;
        if (audioSender != null) {
          await audioSender.replaceTrack(audioTrack);
        } else {
          await pc.addTrack(audioTrack, _localStream!);
        }
      }
    }

    _signalingController.add(SignalingPayload(
      type: SignalingType.offer,
      sdp: 'VOICE_START',
      fromUserId: _currentUserId ?? 'unknown',
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<void> stopTransmission() async {
    L.ptt('<<< SILENT');
    
    // 1. Detach track from WebRTC senders
    for (var pc in _peerConnections.values) {
      final senders = await pc.getSenders();
      for (var sender in senders) {
        if (sender.track?.kind == 'audio') {
          await sender.replaceTrack(null);
        }
      }
    }

    // 2. Stop and dispose local tracks (existing logic)
    if (_localStream != null) {
      _localStream!.getTracks().forEach((t) => t.stop());
      await _localStream!.dispose();
      _localStream = null;
    }
    
    // 3. Force Android OS to release the VoIP call state
    final session = await AudioSession.instance;
    await session.setActive(false);
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionMode: AVAudioSessionMode.defaultMode, 
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music, // Resets Android to Normal mode
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    ));
    
    _signalingController.add(SignalingPayload(
      type: SignalingType.offer,
      sdp: 'VOICE_STOP',
      fromUserId: _currentUserId ?? 'unknown',
      timestamp: DateTime.now(),
    ));

    if (_activeTalkers.isNotEmpty) {
      _updateState(PttState.receiving);
    } else {
      _updateState(PttState.idle);
    }
  }

  @override
  Future<void> handleIncomingSignaling(SignalingPayload payload) async {
    if (_currentUserId == payload.fromUserId) return;
    final peerId = payload.fromUserId;

    if (payload.sdp == 'VOICE_START') {
      L.ptt('Incoming voice from $peerId');
      _activeTalkers.add(peerId);
      _updateState(PttState.receiving);
      await _negotiate(peerId);
      return;
    }
    
    if (payload.sdp == 'VOICE_STOP') {
      L.info('User $peerId stopped talking');
      _activeTalkers.remove(peerId);
      
      // Only go back to idle if NO ONE else is talking
      if (_activeTalkers.isEmpty) {
        _updateState(PttState.idle);
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
    }
  }

  Future<void> _negotiate(String peerId) async {
    final pc = await _getOrCreatePC(peerId);
    RTCSessionDescription offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    
    _signalingController.add(SignalingPayload(
      type: SignalingType.offer,
      sdp: offer.sdp,
      fromUserId: _currentUserId ?? 'unknown',
      timestamp: DateTime.now(),
    ));
  }

  Future<RTCPeerConnection> _getOrCreatePC(String peerId) async {
    if (_peerConnections.containsKey(peerId)) return _peerConnections[peerId]!;

    L.webrtc('Creating Mesh Peer for $peerId');
    final pc = await createPeerConnection(_configuration);
    
    pc.onIceConnectionState = (state) => L.webrtc('[$peerId] ICE: ${state.name}');
    
    pc.onIceCandidate = (candidate) {
      _signalingController.add(SignalingPayload(
        type: SignalingType.iceCandidate,
        candidate: {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
        fromUserId: _currentUserId ?? 'unknown',
        timestamp: DateTime.now(),
      ));
    };

    pc.onTrack = (event) {
      if (event.track.kind == 'audio' && event.streams.isNotEmpty) {
        L.success('Mesh Audio Pipe Active for $peerId');
        _remoteRenderer.srcObject = event.streams[0];
        Helper.setSpeakerphoneOn(true);
      }
    };

    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) => pc.addTrack(track, _localStream!));
    }

    _peerConnections[peerId] = pc;
    return pc;
  }

  Future<void> _handleOffer(String peerId, String sdp) async {
    final pc = await _getOrCreatePC(peerId);
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    
    if (_remoteQueues.containsKey(peerId)) {
      for (var c in _remoteQueues[peerId]!) {
        await pc.addCandidate(c);
      }
      _remoteQueues.remove(peerId);
    }

    RTCSessionDescription answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    _signalingController.add(SignalingPayload(
      type: SignalingType.answer,
      sdp: answer.sdp,
      fromUserId: _currentUserId ?? 'unknown',
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _handleAnswer(String peerId, String sdp) async {
    final pc = _peerConnections[peerId];
    if (pc != null) {
      await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
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
