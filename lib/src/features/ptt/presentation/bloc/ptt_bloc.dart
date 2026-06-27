import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../../presence/domain/repositories/presence_repository.dart';

// Events
abstract class PttEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class PttStarted extends PttEvent {
  final String groupId;
  PttStarted(this.groupId);
}

class PttStopped extends PttEvent {}

class _PttStateChanged extends PttEvent {
  final PttState state;
  _PttStateChanged(this.state);
}

class _IncomingSignaling extends PttEvent {
  final SignalingPayload payload;
  _IncomingSignaling(this.payload);
  @override
  List<Object?> get props => [payload];
}

// States
class PttStateContainer extends Equatable {
  final PttState status;
  final String? activeGroupId;
  final String? errorMessage;

  const PttStateContainer({
    this.status = PttState.idle,
    this.activeGroupId,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [status, activeGroupId, errorMessage];
}

// BLoC
import '../../domain/repositories/signaling_repository.dart';
import '../../domain/entities/signaling_payload.dart';

class PttBloc extends Bloc<PttEvent, PttStateContainer> {
  final AudioRepository audioRepository;
  final PresenceRepository presenceRepository;
  final SignalingRepository signalingRepository;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _signalingSubscription;

  PttBloc({
    required this.audioRepository,
    required this.presenceRepository,
    required this.signalingRepository,
  }) : super(const PttStateContainer()) {
    on<PttStarted>(_onPttStarted);
    on<PttStopped>(_onPttStopped);
    on<_PttStateChanged>(_onStateChanged);
    on<_IncomingSignaling>(_onIncomingSignaling);

    _audioSubscription = audioRepository.pttStateStream.listen((state) {
      add(_PttStateChanged(state));
    });

    _signalingSubscription = signalingRepository.signalingStream.listen((payload) {
      add(_IncomingSignaling(payload));
    });
  }

  // New Event for Signaling
  Future<void> _onIncomingSignaling(_IncomingSignaling event, Emitter<PttStateContainer> emit) async {
    final payload = event.payload;
    
    if (payload.type == SignalingType.offer) {
      // Transition to receiving state
      await audioRepository.joinStream(payload.fromUserId);
      // Process SDP Answer logic here via repository
    }
  }

  Future<void> _onPttStarted(PttStarted event, Emitter<PttStateContainer> emit) async {
    try {
      await presenceRepository.updateStatus(UserStatus.busy);
      await audioRepository.startTransmission(event.groupId);
      emit(PttStateContainer(status: PttState.talking, activeGroupId: event.groupId));
    } catch (e) {
      emit(PttStateContainer(status: PttState.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onPttStopped(PttStopped event, Emitter<PttStateContainer> emit) async {
    await audioRepository.stopTransmission();
    await presenceRepository.updateStatus(UserStatus.online);
    emit(const PttStateContainer(status: PttState.idle));
  }

  void _onStateChanged(_PttStateChanged event, Emitter<PttStateContainer> emit) {
    emit(PttStateContainer(status: event.state, activeGroupId: state.activeGroupId));
  }

  @override
  Future<void> close() {
    _audioSubscription?.cancel();
    return super.close();
  }
}
