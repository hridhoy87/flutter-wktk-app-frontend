import 'package:equatable/equatable.dart';

class TalkGroup extends Equatable {
  final String id;
  final String name;
  final List<String> authorizedUsers;

  const TalkGroup({
    required this.id,
    required this.name,
    required this.authorizedUsers,
  });

  @override
  List<Object?> get props => [id, name, authorizedUsers];
}
