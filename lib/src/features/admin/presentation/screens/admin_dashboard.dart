import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/admin_bloc.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  void _showProfileEditDialog(BuildContext context, Map<String, dynamic> profile) {
    _nameController.text = profile['legal_name'] ?? '';
    _passwordController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('EDIT PROFILE', style: TextStyle(color: Colors.white, letterSpacing: 2)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'LEGAL NAME',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'NEW PASSWORD (LEAVE BLANK TO KEEP)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
            onPressed: () {
              context.read<AdminBloc>().add(UpdateProfileRequested(
                    legalName: _nameController.text,
                    password: _passwordController.text.isEmpty ? null : _passwordController.text,
                  ));
              Navigator.pop(context);
            },
            child: const Text('UPDATE', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminBloc, AdminState>(
      builder: (context, state) {
        Map<String, dynamic>? profile;
        List<Map<String, dynamic>> channels = [];
        
        if (state is AdminAuthenticated) {
          profile = state.userProfile;
          channels = state.channels;
        } else if (state is PendingUsersLoaded) {
          profile = state.userProfile;
          channels = state.channels;
        } else if (state is ProfileUpdated) {
          profile = state.userProfile;
          channels = state.channels;
        }

        final bool isAdmin = profile?['is_admin'] == true;

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          appBar: AppBar(
            title: Text(isAdmin ? 'ADMIN CONSOLE' : 'USER SETTINGS',
                style: const TextStyle(letterSpacing: 4, fontSize: 14)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              if (profile != null)
                IconButton(
                  icon: const Icon(Icons.person_outline, color: Color(0xFFFFD700)),
                  onPressed: () => _showProfileEditDialog(context, profile!),
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  if (isAdmin) context.read<AdminBloc>().add(FetchPendingUsers());
                  context.read<AdminBloc>().add(FetchChannelsRequested());
                },
              ),
            ],
          ),
          body: _buildBody(context, state, isAdmin, profile, channels),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AdminState state, bool isAdmin, Map<String, dynamic>? profile, List<Map<String, dynamic>> channels) {
    if (state is AdminLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
    }

    if (state is AdminError) {
      return Center(child: Text(state.message, style: const TextStyle(color: Colors.redAccent)));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!isAdmin) _buildUserProfile(profile),
        if (isAdmin && state is PendingUsersLoaded) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text('PENDING APPROVALS', style: TextStyle(color: Color(0xFFFFD700), letterSpacing: 2, fontWeight: FontWeight.bold)),
          ),
          ...state.users.map((user) => ListTile(
            title: Text(user['legal_name'], style: const TextStyle(color: Colors.white)),
            subtitle: Text(user['phone'], style: const TextStyle(color: Colors.white38)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                  onPressed: () => context.read<AdminBloc>().add(ApproveUserRequested(user['id'])),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => context.read<AdminBloc>().add(RejectUserRequested(user['id'])),
                ),
              ],
            ),
          )),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Text('CHANNEL MANAGEMENT', style: TextStyle(color: Color(0xFFFFD700), letterSpacing: 2, fontWeight: FontWeight.bold)),
        ),
        ...channels.where((ch) => ch['is_protected'] || ch['id'] == 0).map((ch) {
          final bool canManage = ch['admin_id'] == profile?['id'] || ch['admin_id'] == null || isAdmin;
          return ListTile(
            title: Text(ch['name'], style: const TextStyle(color: Colors.white)),
            subtitle: Text(ch['is_protected'] ? 'Protected' : 'Public', style: const TextStyle(color: Colors.white38)),
            trailing: canManage && ch['is_protected']
                ? ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
                    onPressed: () => _showChannelPasswordDialog(context, ch),
                    child: const Text('SET PASSWORD', style: TextStyle(color: Colors.black, fontSize: 10)),
                  )
                : null,
          );
        }),
      ],
    );
  }

  Widget _buildUserProfile(Map<String, dynamic>? profile) {
    return Column(
      children: [
        const Icon(Icons.verified_user_outlined, color: Colors.greenAccent, size: 64),
        const SizedBox(height: 16),
        Text(profile?['legal_name'] ?? 'USER', style: const TextStyle(color: Colors.white, fontSize: 24)),
        Text(profile?['phone'] ?? '', style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 32),
      ],
    );
  }

  void _showChannelPasswordDialog(BuildContext context, Map<String, dynamic> channel) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('PASSWORD FOR ${channel['name']}', style: const TextStyle(color: Colors.white, fontSize: 14)),
        content: TextField(
          controller: controller,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Enter new password', hintStyle: TextStyle(color: Colors.white38)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              context.read<AdminBloc>().add(UpdateChannelPasswordRequested(channel['id'], controller.text));
              Navigator.pop(context);
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }
}
