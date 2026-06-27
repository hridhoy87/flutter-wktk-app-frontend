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

// States
abstract class AdminState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AdminInitial extends AdminState {}
class AdminLoading extends AdminState {}
class AdminAuthenticated extends AdminState {}
class PendingUsersLoaded extends AdminState {
  final List<Map<String, dynamic>> users;
  PendingUsersLoaded(this.users);
  @override
  List<Object?> get props => [users];
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
        emit(AdminAuthenticated());
        add(FetchPendingUsers());
      } catch (e) {
        emit(AdminError(e.toString()));
      }
    });

    on<FetchPendingUsers>((event, emit) async {
      emit(AdminLoading());
      try {
        final users = await repository.getPendingUsers();
        emit(PendingUsersLoaded(users));
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
