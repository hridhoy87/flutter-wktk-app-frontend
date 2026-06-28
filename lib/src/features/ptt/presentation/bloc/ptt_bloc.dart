import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../../presence/domain/repositories/presence_repository.dart';
import '../../domain/repositories/signaling_repository.dart';
import '../../domain/entities/signaling_payload.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/webrtc_audio_repository.dart';
import 'package:walkie_talkie/src/core/utils/logger.dart';

abstract class PttEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class PttStarted extends PttEvent {
  final String groupId;
  PttStarted(this.groupId);
}

class PttStopped extends PttEvent {}

class PttChannelChanged extends PttEvent {
  final String channelId;
  final String? password;
  PttChannelChanged(this.channelId, {this.password});
}

class PttInitializeRequested extends PttEvent {
  final String userId;
  final String groupId;
  PttInitializeRequested(this.userId, this.groupId);
}

class PttInviteSent extends PttEvent {
  final List<String> targetUserIds;
  final String channelName;
  final String? password;
  PttInviteSent(this.targetUserIds, this.channelName, this.password);
}

class PttInviteAccepted extends PttEvent {
  final SignalingPayload invite;
  PttInviteAccepted(this.invite);
}

class PttInviteDeclined extends PttEvent {
  final SignalingPayload invite;
  PttInviteDeclined(this.invite);
}

class _PttStateChanged extends PttEvent {
  final PttState state;
  _PttStateChanged(this.state);
}

class _IncomingSignaling extends PttEvent {
  final SignalingPayload payload;
  _IncomingSignaling(this.payload);
}

class _PresenceUpdated extends PttEvent {
  final Map<String, UserStatus> presence;
  _PresenceUpdated(this.presence);
}

class LoadOnlineUsersRequested extends PttEvent {}

class PttStateContainer extends Equatable {
  final PttState status;
  final String? activeGroupId;
  final String? errorMessage;
  final Map<String, UserStatus> presence;
  final List<Map<String, dynamic>> allUsers;
  final List<Map<String, dynamic>> availableChannels;
  final String? currentUserId;
  final SignalingPayload? pendingInvite;
  final String? shareLink; // To trigger share sheet in UI

  const PttStateContainer({
    this.status = PttState.idle,
    this.activeGroupId,
    this.errorMessage,
    this.presence = const {},
    this.allUsers = const [],
    this.availableChannels = const [],
    this.currentUserId,
    this.pendingInvite,
    this.shareLink,
  });

  @override
  List<Object?> get props => [status, activeGroupId, errorMessage, presence, allUsers, availableChannels, currentUserId, pendingInvite, shareLink];

  PttStateContainer copyWith({
    PttState? status,
    String? activeGroupId,
    String? errorMessage,
    Map<String, UserStatus>? presence,
    List<Map<String, dynamic>>? allUsers,
    List<Map<String, dynamic>>? availableChannels,
    String? currentUserId,
    SignalingPayload? pendingInvite,
    bool clearInvite = false,
    String? shareLink,
    bool clearShareLink = false,
  }) {
    return PttStateContainer(
      status: status ?? this.status,
      activeGroupId: activeGroupId ?? this.activeGroupId,
      errorMessage: errorMessage ?? this.errorMessage,
      presence: presence ?? this.presence,
      allUsers: allUsers ?? this.allUsers,
      availableChannels: availableChannels ?? this.availableChannels,
      currentUserId: currentUserId ?? this.currentUserId,
      pendingInvite: clearInvite ? null : (pendingInvite ?? this.pendingInvite),
      shareLink: clearShareLink ? null : (shareLink ?? this.shareLink),
    );
  }
}

class PttBloc extends Bloc<PttEvent, PttStateContainer> {
  final AudioRepository audioRepository;
  final PresenceRepository presenceRepository;
  final SignalingRepository signalingRepository;
  final AuthRepository authRepository;
  
  StreamSubscription? _audioSubscription;
  StreamSubscription? _audioSignalingSubscription;
  StreamSubscription? _signalingSubscription;
  StreamSubscription? _presenceSubscription;
  
  Map<String, UserStatus> _currentPresence = {};
  String? _currentUserId;

  PttBloc({
    required this.audioRepository,
    required this.presenceRepository,
    required this.signalingRepository,
    required this.authRepository,
  }) : super(const PttStateContainer()) {
    on<PttInitializeRequested>(_onInitialize);
    on<PttStarted>(_onPttStarted);
    on<PttStopped>(_onPttStopped);
    on<PttChannelChanged>(_onChannelChanged);
    on<_PttStateChanged>(_onStateChanged);
    on<_IncomingSignaling>(_onIncomingSignaling);
    on<_PresenceUpdated>(_onPresenceUpdated);
    on<LoadOnlineUsersRequested>(_onLoadOnlineUsers);
    on<PttInviteSent>(_onInviteSent);
    on<PttInviteAccepted>(_onInviteAccepted);
    on<PttInviteDeclined>(_onInviteDeclined);

    _audioSubscription = audioRepository.pttStateStream.listen((state) {
      add(_PttStateChanged(state));
    });

    _signalingSubscription = signalingRepository.signalingStream.listen((payload) {
      add(_IncomingSignaling(payload));
    });

    _presenceSubscription = presenceRepository.groupPresenceStream.listen((presence) {
      add(_PresenceUpdated(presence));
    });
    
    _audioSignalingSubscription = audioRepository.signalingStream.listen((payload) {
      if (_currentUserId == null) return;
      for (final targetId in _currentPresence.keys) {
        if (targetId != _currentUserId) {
          signalingRepository.sendSignaling(targetId, payload);
        }
      }
    });
  }

  Future<void> _onInitialize(PttInitializeRequested event, Emitter<PttStateContainer> emit) async {
    emit(state.copyWith(status: PttState.connecting, currentUserId: event.userId, activeGroupId: event.groupId));
    try {
      _currentUserId = event.userId;
      
      final users = await authRepository.getOnlineUsers();
      final channels = await authRepository.getChannels();
      emit(state.copyWith(allUsers: users, availableChannels: channels));

      if (audioRepository is WebRtcAudioRepositoryImpl) {
        (audioRepository as WebRtcAudioRepositoryImpl).setUserId(event.userId);
      }
      await presenceRepository.connect(userId: event.userId, groupIds: [event.groupId]);
      await signalingRepository.init(event.groupId, event.userId);
      
      List<Map<String, dynamic>> iceServers = [{'urls': 'stun:stun.l.google.com:19302'}];
      try {
        final creds = await authRepository.getTurnCredentials();
        if (creds['uris'] != null) {
          iceServers = (creds['uris'] as List).map((uri) => {
            'urls': uri, 'username': creds['username'], 'credential': creds['password'],
          }).toList();
        }
      } catch (_) {}
      
      await audioRepository.initialize(iceServers: iceServers);
      emit(state.copyWith(status: PttState.idle));
    } catch (e) {
      emit(state.copyWith(status: PttState.error, errorMessage: e.toString()));
    }
  }

  void _onPresenceUpdated(_PresenceUpdated event, Emitter<PttStateContainer> emit) {
    _currentPresence = event.presence;
    emit(state.copyWith(presence: event.presence));
  }

  Future<void> _onIncomingSignaling(_IncomingSignaling event, Emitter<PttStateContainer> emit) async {
    if (event.payload.type == SignalingType.invite) {
      emit(state.copyWith(pendingInvite: event.payload));
    } else {
      await audioRepository.handleIncomingSignaling(event.payload);
    }
  }

  Future<void> _onPttStarted(PttStarted event, Emitter<PttStateContainer> emit) async {
    try {
      await presenceRepository.updateStatus(UserStatus.busy);
      await audioRepository.startTransmission(event.groupId);
    } catch (e) {
      emit(state.copyWith(status: PttState.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onPttStopped(PttStopped event, Emitter<PttStateContainer> emit) async {
    await audioRepository.stopTransmission();
    await presenceRepository.updateStatus(UserStatus.online);
  }

  Future<void> _onChannelChanged(PttChannelChanged event, Emitter<PttStateContainer> emit) async {
    if (event.channelId == state.activeGroupId) return;
    
    emit(state.copyWith(status: PttState.connecting, activeGroupId: event.channelId, presence: {}));
    
    try {
      await presenceRepository.connect(userId: _currentUserId!, groupIds: [event.channelId]);
      await signalingRepository.init(event.channelId, _currentUserId!);
      
      // Update channels list to include the new temp channel
      final channels = await authRepository.getChannels();
      emit(state.copyWith(availableChannels: channels, status: PttState.idle));
    } catch (e) {
      emit(state.copyWith(status: PttState.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onInviteSent(PttInviteSent event, Emitter<PttStateContainer> emit) async {
    try {
      final channel = await authRepository.createTempChannel(
        name: event.channelName,
        allowedUserIds: event.targetUserIds,
        password: event.password,
      );

      final channelId = channel['id'].toString();
      final String? initiatorName = state.allUsers.firstWhere((u) => u['phone'] == _currentUserId)['legal_name'];

      final invitePayload = SignalingPayload(
        type: SignalingType.invite,
        fromUserId: _currentUserId!,
        timestamp: DateTime.now(),
        groupId: channelId,
        password: event.password,
        channelName: event.channelName,
        isCustom: true,
      );

      bool hasOffline = false;
      for (var targetId in event.targetUserIds) {
        // Always send MQTT invite so they see it in-app if they are online or log in soon
        await signalingRepository.sendInvite(targetId, invitePayload);
        
        if (!_currentPresence.containsKey(targetId)) {
          hasOffline = true;
        }
      }

      if (hasOffline) {
        final deepLink = 'walkietalkie://join?channel_id=$channelId${event.password != null ? '&pwd=${event.password}' : ''}';
        final shareText = '$initiatorName is inviting you to join a ptt group call. Click to join: \n$deepLink';
        emit(state.copyWith(shareLink: shareText));
        emit(state.copyWith(clearShareLink: true)); // Reset immediately after UI would have consumed it
      }

      // Automatically join the created channel
      add(PttChannelChanged(channelId, password: event.password));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to create group: $e'));
    }
  }

  void _onInviteAccepted(PttInviteAccepted event, Emitter<PttStateContainer> emit) {
    emit(state.copyWith(clearInvite: true));
    add(PttChannelChanged(event.invite.groupId!, password: event.invite.password));
  }

  void _onInviteDeclined(PttInviteDeclined event, Emitter<PttStateContainer> emit) {
    emit(state.copyWith(clearInvite: true));
  }

  void _onStateChanged(_PttStateChanged event, Emitter<PttStateContainer> emit) {
    emit(state.copyWith(status: event.state));
  }

  Future<void> _onLoadOnlineUsers(LoadOnlineUsersRequested event, Emitter<PttStateContainer> emit) async {
    try {
      final users = await authRepository.getOnlineUsers();
      emit(state.copyWith(allUsers: users));
    } catch (_) {}
  }

  @override
  Future<void> close() {
    _audioSubscription?.cancel();
    _audioSignalingSubscription?.cancel();
    _signalingSubscription?.cancel();
    _presenceSubscription?.cancel();
    return super.close();
  }
}
