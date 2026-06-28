import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/admin_repository_interface.dart';

// Events
abstract class AdminEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AdminLoginRequested extends AdminEvent {
  final String phone;
  final String password;
  AdminLoginRequested(this.phone, this.password);
}

class FetchPendingUsers extends AdminEvent {}

class ApproveUserRequested extends AdminEvent {
  final int userId;
  ApproveUserRequested(this.userId);
}

class RejectUserRequested extends AdminEvent {
  final int userId;
  RejectUserRequested(this.userId);
}

class UpdateProfileRequested extends AdminEvent {
  final String? legalName;
  final String? password;
  UpdateProfileRequested({this.legalName, this.password});
}

class FetchChannelsRequested extends AdminEvent {}

class UpdateChannelPasswordRequested extends AdminEvent {
  final int channelId;
  final String password;
  UpdateChannelPasswordRequested(this.channelId, this.password);
}

// States
abstract class AdminState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {}
class AdminLoading extends AdminState {}
class AdminAuthenticated extends AdminState {
  final Map<String, dynamic>? userProfile;
  final List<Map<String, dynamic>> channels;
  AdminAuthenticated({this.userProfile, this.channels = const []});
  @override
  List<Object?> get props => [userProfile, channels];
}

class ProfileUpdated extends AdminState {
  final Map<String, dynamic> userProfile;
  final List<Map<String, dynamic>> channels;
  ProfileUpdated(this.userProfile, {this.channels = const []});
  @override
  List<Object?> get props => [userProfile, channels];
}

class PendingUsersLoaded extends AdminState {
  final List<Map<String, dynamic>> users;
  final Map<String, dynamic>? userProfile;
  final List<Map<String, dynamic>> channels;
  PendingUsersLoaded(this.users, {this.userProfile, this.channels = const []});
  @override
  List<Object?> get props => [users, userProfile, channels];
}
class AdminError extends AdminState {
  final String message;
  AdminError(this.message);
}

// BLoC
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final IAdminRepository repository;

  AdminBloc(this.repository) : super(AdminInitial()) {
    on<AdminLoginRequested>((event, emit) async {
      emit(AdminLoading());
      try {
        await repository.login(event.phone, event.password);
        final profile = await repository.getOwnProfile();
        final channels = await repository.getChannels();
        emit(AdminAuthenticated(userProfile: profile, channels: channels));
        if (profile['is_admin'] == true) {
          add(FetchPendingUsers());
        }
      } catch (e) {
        emit(AdminError(e.toString()));
      }
    });

    on<FetchPendingUsers>((event, emit) async {
      final currentState = state;
      Map<String, dynamic>? profile;
      List<Map<String, dynamic>> channels = [];
      if (currentState is AdminAuthenticated) {
        profile = currentState.userProfile;
        channels = currentState.channels;
      }
      if (currentState is PendingUsersLoaded) {
        profile = currentState.userProfile;
        channels = currentState.channels;
      }

      emit(AdminLoading());
      try {
        final users = await repository.getPendingUsers();
        emit(PendingUsersLoaded(users, userProfile: profile, channels: channels));
      } catch (e) {
        emit(AdminError(e.toString()));
      }
    });

    on<UpdateProfileRequested>((event, emit) async {
      final currentState = state;
      List<Map<String, dynamic>> channels = [];
      if (currentState is AdminAuthenticated) channels = currentState.channels;
      if (currentState is PendingUsersLoaded) channels = currentState.channels;

      emit(AdminLoading());
      try {
        final updatedUser = await repository.updateProfile(
          legalName: event.legalName,
          password: event.password,
        );
        emit(ProfileUpdated(updatedUser, channels: channels));
        emit(AdminAuthenticated(userProfile: updatedUser, channels: channels));
        if (updatedUser['is_admin'] == true) {
          add(FetchPendingUsers());
        }
      } catch (e) {
        emit(AdminError(e.toString()));
      }
    });

    on<FetchChannelsRequested>((event, emit) async {
      final currentState = state;
      Map<String, dynamic>? profile;
      if (currentState is AdminAuthenticated) profile = currentState.userProfile;
      if (currentState is PendingUsersLoaded) profile = currentState.userProfile;

      try {
        final channels = await repository.getChannels();
        if (currentState is PendingUsersLoaded) {
          emit(PendingUsersLoaded(currentState.users, userProfile: profile, channels: channels));
        } else {
          emit(AdminAuthenticated(userProfile: profile, channels: channels));
        }
      } catch (e) {
        emit(AdminError(e.toString()));
      }
    });

    on<UpdateChannelPasswordRequested>((event, emit) async {
      emit(AdminLoading());
      try {
        await repository.updateChannelPassword(event.channelId, event.password);
        add(FetchChannelsRequested());
      } catch (e) {
        emit(AdminError(e.toString()));
      }
    });

    on<ApproveUserRequested>((event, emit) async {
      try {
        await repository.approveUser(event.userId);
        add(FetchPendingUsers());
      } catch (e) {
        emit(AdminError(e.toString()));
      }
    });

    on<RejectUserRequested>((event, emit) async {
      try {
        await repository.rejectUser(event.userId);
        add(FetchPendingUsers());
      } catch (e) {
        emit(AdminError(e.toString()));
      }
    });
  }
}
