import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final int id;
  final String phone;
  final String legalName;
  final bool isApproved;
  final bool isAdmin;

  const UserEntity({
    required this.id,
    required this.phone,
    required this.legalName,
    required this.isApproved,
    required this.isAdmin,
  });

  @override
  List<Object?> get props => [id, phone, legalName, isApproved, isAdmin];
}
