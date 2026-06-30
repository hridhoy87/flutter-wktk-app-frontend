import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../../presence/domain/repositories/presence_repository.dart';
import '../../domain/repositories/signaling_repository.dart';
import '../../domain/entities/signaling_payload.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/webrtc_audio_repository.dart';
import 'package:walkie_talkie/src/core/utils/logger.dart';
import '../../../../core/services/wtrp_service.dart';
import '../../../../core/services/watch_bridge_service.dart';

abstract class PttEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class PttStarted extends PttEvent {
  final String groupId;
  PttStarted(this.groupId);
}

class PttStopped extends PttEvent {}

class PttReset extends PttEvent {}

class PttChannelChanged extends PttEvent {
  final String channelId;
  final String? password;
  PttChannelChanged(this.channelId, {this.password});
}

class PttDeepLinkReceived extends PttEvent {
  final String channelId;
  final String? password;
  PttDeepLinkReceived(this.channelId, {this.password});
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

class _CheckInvitePresence extends PttEvent {}

class ClearInvitePrompt extends PttEvent {}

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
  final String? inviteShareText; 
  final bool showInvitePrompt;
  final List<String>? pendingInviteTargets;
  final List<String>? absentUserIds;

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
    this.inviteShareText,
    this.showInvitePrompt = false,
    this.pendingInviteTargets,
    this.absentUserIds,
  });

  @override
  List<Object?> get props => [
    status, activeGroupId, errorMessage, presence, allUsers, 
    availableChannels, currentUserId, pendingInvite, shareLink,
    inviteShareText, showInvitePrompt, pendingInviteTargets, absentUserIds
  ];

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
    String? inviteShareText,
    bool? showInvitePrompt,
    List<String>? pendingInviteTargets,
    List<String>? absentUserIds,
    bool clearInvitePrompt = false,
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
      inviteShareText: inviteShareText ?? this.inviteShareText,
      showInvitePrompt: clearInvitePrompt ? false : (showInvitePrompt ?? this.showInvitePrompt),
      pendingInviteTargets: pendingInviteTargets ?? this.pendingInviteTargets,
      absentUserIds: clearInvitePrompt ? null : (absentUserIds ?? this.absentUserIds),
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
  StreamSubscription? _wtrpSubscription;
  
  Map<String, UserStatus> _currentPresence = {};
  String? _currentUserId;
  String? _pendingChannelId;
  String? _pendingPassword;

  PttBloc({
    required this.audioRepository,
    required this.presenceRepository,
    required this.signalingRepository,
    required this.authRepository,
  }) : super(const PttStateContainer()) {
    on<PttInitializeRequested>(_onInitialize);
    on<PttStarted>(_onPttStarted);
    on<PttStopped>(_onPttStopped);
    on<PttReset>(_onPttReset);
    on<PttChannelChanged>(_onChannelChanged);
    on<PttDeepLinkReceived>(_onDeepLinkReceived);
    on<_PttStateChanged>(_onStateChanged);
    on<_IncomingSignaling>(_onIncomingSignaling);
    on<_PresenceUpdated>(_onPresenceUpdated);
    on<LoadOnlineUsersRequested>(_onLoadOnlineUsers);
    on<PttInviteSent>(_onInviteSent);
    on<PttInviteAccepted>(_onInviteAccepted);
    on<PttInviteDeclined>(_onInviteDeclined);
    on<_CheckInvitePresence>(_onCheckInvitePresence);
    on<ClearInvitePrompt>(_onClearInvitePrompt);

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
      
      // If a specific target is set, send only to them (Point-to-Point)
      if (payload.toUserId != null) {
        signalingRepository.sendSignaling(payload.toUserId!, payload);
      } else {
        // Broadcast to everyone in the channel (Control messages like VOICE_START/STOP)
        signalingRepository.sendBroadcast(payload);
      }
    });

    _wtrpSubscription = WtrpService().events.listen((event) {
      if (state.activeGroupId == null) return;
      if (event == WtrpEvent.pressed) {
        add(PttStarted(state.activeGroupId!));
      } else {
        add(PttStopped());
      }
    });
  }

  Future<void> _onInitialize(PttInitializeRequested event, Emitter<PttStateContainer> emit) async {
    emit(state.copyWith(status: PttState.connecting, currentUserId: event.userId));
    try {
      _currentUserId = event.userId;
      
      final users = await authRepository.getOnlineUsers();
      final rawChannels = await authRepository.getChannels();
      
      // Sort channels: Global first, then chronologically/by ID
      final List<Map<String, dynamic>> channels = List.from(rawChannels);
      channels.sort((a, b) {
        if (a['name'].toString().toLowerCase() == 'global') return -1;
        if (b['name'].toString().toLowerCase() == 'global') return 1;
        return a['id'].toString().compareTo(b['id'].toString());
      });

      // 1. Check for Pending Deep Link
      // 2. Otherwise use Global if it exists
      // 3. Fallback to event.groupId
      String initialGroupId = event.groupId;
      String? initialPassword;

      if (_pendingChannelId != null) {
        initialGroupId = _pendingChannelId!;
        initialPassword = _pendingPassword;
        _pendingChannelId = null;
        _pendingPassword = null;
        L.info('Deep Link: Joining pending channel $initialGroupId');
      } else {
        final globalChannel = channels.firstWhere(
          (c) => c['name'].toString().toLowerCase() == 'global',
          orElse: () => {},
        );
        if (globalChannel.isNotEmpty) {
          initialGroupId = globalChannel['id'].toString();
        }
      }

      emit(state.copyWith(
        allUsers: users, 
        availableChannels: channels,
        activeGroupId: initialGroupId,
      ));

      if (audioRepository is WebRtcAudioRepositoryImpl) {
        (audioRepository as WebRtcAudioRepositoryImpl).setUserId(event.userId);
      }
      
      await presenceRepository.connect(userId: event.userId, groupIds: [initialGroupId]);
      await signalingRepository.init(initialGroupId, event.userId);
      
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
      
      // Start scanning for watch after successful initialization and permissions
      WtrpService().startScanning();

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

  Future<void> _onPttReset(PttReset event, Emitter<PttStateContainer> emit) async {
    L.warning('PTT BLOC: Resetting for logout...');
    _currentUserId = null;
    _pendingChannelId = null;
    _pendingPassword = null;
    try {
      await audioRepository.stopTransmission();
      await presenceRepository.disconnect();
      await signalingRepository.disconnect();
    } catch (e) {
      L.error('Error during PTT reset', e);
    }
    emit(const PttStateContainer());
  }

  Future<void> _onChannelChanged(PttChannelChanged event, Emitter<PttStateContainer> emit) async {
    final oldChannelId = state.activeGroupId;
    if (event.channelId == oldChannelId) return;
    
    // LAST PERSON OUT LOGIC
    if (oldChannelId != null) {
      final oldChannel = state.availableChannels.firstWhere(
        (c) => c['id'].toString() == oldChannelId,
        orElse: () => {},
      );

      // If leaving a temporary channel and NO ONE ELSE is online
      if (oldChannel['is_temporary'] == true && _currentPresence.isEmpty) {
        try {
          L.info('Last person out of channel $oldChannelId. Deleting...');
          await authRepository.deleteChannel(int.parse(oldChannelId));
        } catch (e) {
          L.error('Failed to cleanup empty channel', e);
        }
      }
    }

    emit(state.copyWith(status: PttState.connecting, activeGroupId: event.channelId, presence: {}));
    
    try {
      await presenceRepository.connect(userId: _currentUserId!, groupIds: [event.channelId]);
      await signalingRepository.init(event.channelId, _currentUserId!);
      
      // Update channels list and sort
      final rawChannels = await authRepository.getChannels();
      final List<Map<String, dynamic>> channels = List.from(rawChannels);
      channels.sort((a, b) {
        if (a['name'].toString().toLowerCase() == 'global') return -1;
        if (b['name'].toString().toLowerCase() == 'global') return 1;
        return a['id'].toString().compareTo(b['id'].toString());
      });

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
      }

      // Automatically join the created channel
      add(PttChannelChanged(channelId, password: event.password));

      // START 10 SECOND MONITORING
      final deepLink = 'walkietalkie://join?channel_id=$channelId${event.password != null ? '&pwd=${event.password}' : ''}';
      final shareText = '$initiatorName is requesting for your presence in Wakli Talkie app. Use this link to join directly his private call $deepLink';
      
      emit(state.copyWith(
        pendingInviteTargets: event.targetUserIds,
        inviteShareText: shareText,
      ));

      Future.delayed(const Duration(seconds: 10)).then((_) {
        if (!isClosed) add(_CheckInvitePresence());
      });
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to create group: $e'));
    }
  }

  void _onCheckInvitePresence(_CheckInvitePresence event, Emitter<PttStateContainer> emit) {
    if (state.pendingInviteTargets == null || state.inviteShareText == null) return;

    final List<String> absentIds = [];
    for (var targetId in state.pendingInviteTargets!) {
      if (!state.presence.containsKey(targetId)) {
        absentIds.add(targetId);
      }
    }

    if (absentIds.isNotEmpty) {
      L.warning('Invite Timeout: ${absentIds.length} users did not join within 10s.');
      emit(state.copyWith(
        showInvitePrompt: true, 
        absentUserIds: absentIds
      ));
    } else {
      L.success('Invite Success: Everyone joined within 10s');
      emit(state.copyWith(pendingInviteTargets: null, inviteShareText: null));
    }
  }

  void _onClearInvitePrompt(ClearInvitePrompt event, Emitter<PttStateContainer> emit) {
    emit(state.copyWith(clearInvitePrompt: true));
  }

  Future<void> _onInviteAccepted(PttInviteAccepted event, Emitter<PttStateContainer> emit) async {
    emit(state.copyWith(clearInvite: true));
    
    // FETCH CHANNELS AGAIN before switching, so the new private channel 
    // actually exists in the local 'availableChannels' list.
    try {
      final channels = await authRepository.getChannels();
      emit(state.copyWith(availableChannels: channels));
    } catch (e) {
      L.error('Failed to refresh channels after invite', e);
    }

    add(PttChannelChanged(event.invite.groupId!, password: event.invite.password));
  }

  void _onInviteDeclined(PttInviteDeclined event, Emitter<PttStateContainer> emit) {
    emit(state.copyWith(clearInvite: true));
  }

  void _onDeepLinkReceived(PttDeepLinkReceived event, Emitter<PttStateContainer> emit) {
    L.info('PTT BLOC: Deep Link Received - Channel ${event.channelId}');
    if (_currentUserId != null) {
      // User is already logged in, switch channel immediately
      add(PttChannelChanged(event.channelId, password: event.password));
    } else {
      // User is logged out, store for after login
      _pendingChannelId = event.channelId;
      _pendingPassword = event.password;
      L.info('PTT BLOC: Stored pending deep link for login');
    }
  }

  void _onStateChanged(_PttStateChanged event, Emitter<PttStateContainer> emit) {
    emit(state.copyWith(status: event.state));
    _updateBackgroundNotification(event.state);
    WatchBridgeService().updateState(event.state);
  }

  void _updateBackgroundNotification(PttState pttState) {
    String title = 'PTT READY';
    String content = 'Monitoring for incoming voice...';
    int? color;

    if (pttState == PttState.receiving) {
      title = 'PTT INACTIVE';
      content = 'Receiving Voice';
      color = 0xFFFF0000; // Red
      L.error('NOTIFICATION SYNC: [RED] PTT INACTIVE - Receiving Voice');
    } else if (pttState == PttState.talking) {
      title = 'PTT IN USE';
      content = 'Transmitting Voice';
      color = 0xFFFFD700; // Gold / Yellowish
      L.warning('NOTIFICATION SYNC: [YELLOW] PTT IN USE - Transmitting Voice');
    } else {
      L.success('NOTIFICATION SYNC: [GREEN] PTT READY - Standby');
    }

    FlutterBackgroundService().invoke('updateNotification', {
      'title': title,
      'content': content,
      'color': color,
    });
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
    _wtrpSubscription?.cancel();
    return super.close();
  }
}
