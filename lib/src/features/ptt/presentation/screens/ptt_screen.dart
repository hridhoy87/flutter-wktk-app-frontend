import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_links/app_links.dart';
import '../bloc/ptt_bloc.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../domain/entities/signaling_payload.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../admin/presentation/screens/admin_login.dart';
import '../../../presence/domain/repositories/presence_repository.dart';

class PttScreen extends StatefulWidget {
  const PttScreen({super.key});

  @override
  State<PttScreen> createState() => _PttScreenState();
}

class _PttScreenState extends State<PttScreen> {
  Map<String, String> _contactMap = {};
  final Set<String> _selectedUserIds = {};

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    if (await FlutterContacts.requestPermission()) {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final Map<String, String> newMap = {};
      for (var contact in contacts) {
        for (var phone in contact.phones) {
          String normalized = phone.number.replaceAll(RegExp(r'\D'), '');
          newMap[normalized] = contact.displayName;
        }
      }
      setState(() {
        _contactMap = newMap;
      });
    }
  }

  String _getDisplayName(String phone, List<Map<String, dynamic>> allUsers) {
    for (var user in allUsers) {
      if (user['phone'] == phone) {
        return user['legal_name'] ?? phone;
      }
    }
    String normalized = phone.replaceAll(RegExp(r'\D'), '');
    if (normalized.length >= 10) {
      String last10 = normalized.substring(normalized.length - 10);
      for (var key in _contactMap.keys) {
        if (key.endsWith(last10)) {
          return _contactMap[key]!;
        }
      }
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PttBloc, PttStateContainer>(
      listenWhen: (prev, curr) => 
          prev.pendingInvite != curr.pendingInvite || 
          prev.shareLink != curr.shareLink ||
          prev.showInvitePrompt != curr.showInvitePrompt,
      listener: (context, state) {
        if (state.pendingInvite != null) {
          _showInviteDialog(state.pendingInvite!);
        }
        if (state.shareLink != null) {
          Share.share(state.shareLink!);
        }
        if (state.showInvitePrompt && state.inviteShareText != null) {
          _showSmsInviteDialog(state.inviteShareText!, state.absentUserIds ?? [], state.allUsers);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        drawer: _buildDrawer(context),
        body: BlocBuilder<PttBloc, PttStateContainer>(
          builder: (context, state) {
            if (state.status == PttState.connecting) {
              return _buildLoadingState(context, state.activeGroupId);
            }
            if (state.errorMessage != null) {
              return _buildErrorState(context, state.errorMessage!);
            }

            return SafeArea(
              child: Column(
                children: [
                  _buildAppBar(context),
                  const Spacer(),
                  _buildStatusIndicator(state),
                  const Spacer(),
                  _buildPttButton(context, state),
                  const SizedBox(height: 60),
                  _buildBottomInfo(state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showInviteDialog(SignalingPayload invite) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Incoming Invite', style: TextStyle(color: Colors.white)),
        content: Text(
          '${invite.fromUserId} is inviting you to join private group: ${invite.channelName ?? "Private Call"}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<PttBloc>().add(PttInviteDeclined(invite));
              Navigator.pop(context);
            },
            child: const Text('DECLINE', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () {
              context.read<PttBloc>().add(PttInviteAccepted(invite));
              Navigator.pop(context);
            },
            child: const Text('ACCEPT', style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  void _showSmsInviteDialog(String text, List<String> absentIds, List<Map<String, dynamic>> allUsers) {
    final List<String> absentNames = absentIds.map((id) {
      final name = _getDisplayName(id, allUsers);
      return "$name ($id)";
    }).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Send Invitation?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Absent list:',
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              absentNames.join(', '),
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'did not join. Send invitation?:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                text,
                style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<PttBloc>().add(ClearInvitePrompt());
              Navigator.pop(context);
            },
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700)),
            onPressed: () async {
              context.read<PttBloc>().add(ClearInvitePrompt());
              Navigator.pop(context);
              await Clipboard.setData(ClipboardData(text: text));
              Share.share(text);
            },
            child: const Text('SEND', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, String? channelId) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFFFD700)),
          const SizedBox(height: 24),
          Text(
            channelId != null ? 'JOINING CHANNEL $channelId...' : 'CONNECTING...',
            style: const TextStyle(color: Colors.white70, letterSpacing: 1.5, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
            const SizedBox(height: 16),
            const Text('CONNECTION ERROR', style: TextStyle(color: Colors.redAccent, letterSpacing: 2, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.read<AuthBloc>().add(AppStarted()),
              child: const Text('RETRY'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return BlocBuilder<PttBloc, PttStateContainer>(
      builder: (context, state) {
        final currentChannel = state.availableChannels.firstWhere(
          (c) => c['id'].toString() == state.activeGroupId,
          orElse: () => {'name': 'Unknown'},
        );

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white54),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              GestureDetector(
                onTap: () => _showChannelSelector(context, state),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('TAP TO SWITCH CHANNEL', style: TextStyle(color: Colors.grey, letterSpacing: 2, fontSize: 10)),
                    Text(currentChannel['name'].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w300)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white54),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen())),
              )
            ],
          ),
        );
      },
    );
  }

  void _showChannelSelector(BuildContext context, PttStateContainer state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151515),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
                ),
                const Text('SELECT CHANNEL', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: state.availableChannels.length,
                    itemBuilder: (context, index) {
                      final ch = state.availableChannels[index];
                      final isSelected = ch['id'].toString() == state.activeGroupId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFFD700).withOpacity(0.1) : Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            ch['is_protected'] ? Icons.lock_outline : Icons.public_rounded,
                            size: 20,
                            color: isSelected ? const Color(0xFFFFD700) : Colors.white54,
                          ),
                        ),
                        title: Text(
                          ch['name'].toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFFFD700) : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            letterSpacing: 1,
                          ),
                        ),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFFFFD700), size: 20) : null,
                        onTap: () {
                          Navigator.pop(context);
                          if (!isSelected) {
                            _handleChannelSelection(ch);
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleChannelSelection(Map<String, dynamic> channel) async {
    final pttBloc = context.read<PttBloc>();
    final authRepo = context.read<AuthBloc>().authRepository;
    final channelId = channel['id'];

    if (channel['is_protected']) {
      final password = await _showPasswordDialog('Protected Channel', 'Enter channel password');
      if (password != null) {
        try {
          final success = await authRepo.verifyChannelPassword(channelId, password);
          if (success) {
            pttBloc.add(PttChannelChanged(channelId.toString(), password: password));
          } else {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Password')));
          }
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    } else {
      pttBloc.add(PttChannelChanged(channelId.toString()));
    }
  }

  Future<String?> _showPasswordDialog(String title, String hint) async {
    String? password;
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          autofocus: true,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white38)),
          onChanged: (value) => password = value,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, password), child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF151515),
      child: SafeArea(
        child: Column(
          children: [
            // User Profile Header
            BlocBuilder<PttBloc, PttStateContainer>(
              builder: (context, state) {
                final displayName = _getDisplayName(state.currentUserId ?? '', state.allUsers);
                return Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    border: const Border(bottom: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFFFD700).withOpacity(0.1),
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Color(0xFFFFD700), fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              state.currentUserId ?? '',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'ONLINE',
                                style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.only(top: 20.0, left: 20, right: 20, bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.contacts_outlined, color: Colors.white54, size: 18),
                  SizedBox(width: 12),
                  Text(
                    'CONTACTS',
                    style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<PttBloc, PttStateContainer>(
                builder: (context, state) {
                  final presence = state.presence;
                  final allUsers = state.allUsers;

                  if (allUsers.isEmpty) {
                    return const Center(child: Text('No users found', style: TextStyle(color: Colors.white38)));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: allUsers.length,
                    itemBuilder: (context, index) {
                      final user = allUsers[index];
                      final userId = user['phone'];
                      if (userId == state.currentUserId) return const SizedBox.shrink();

                      final status = presence[userId] ?? UserStatus.offline;
                      final displayName = _getDisplayName(userId, allUsers);
                      final isSelected = _selectedUserIds.contains(userId);

                      return Card(
                        color: isSelected ? const Color(0xFFFFD700).withOpacity(0.1) : const Color(0xFF1E1E1E),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isSelected ? const BorderSide(color: Color(0xFFFFD700), width: 1) : BorderSide.none,
                        ),
                        child: ListTile(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedUserIds.remove(userId);
                              } else {
                                _selectedUserIds.add(userId);
                              }
                            });
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.white10,
                                child: Text(
                                  displayName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Color(0xFFFFD700)),
                                ),
                              ),
                              Positioned(
                                right: 0, bottom: 0,
                                child: Container(
                                  width: 12, height: 12,
                                  decoration: BoxDecoration(
                                    color: status == UserStatus.online ? Colors.green : (status == UserStatus.busy ? Colors.orange : Colors.grey),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF1E1E1E), width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          title: Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                          subtitle: Text(userId, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: Checkbox(
                            value: isSelected,
                            activeColor: const Color(0xFFFFD700),
                            checkColor: Colors.black,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) _selectedUserIds.add(userId);
                                else _selectedUserIds.remove(userId);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_selectedUserIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _handleCreatePrivateGroup,
                    child: const Text('CREATE PRIVATE PTT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
              ),
            const Divider(color: Colors.white10),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => context.read<AuthBloc>().add(LogoutRequested()),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCreatePrivateGroup() async {
    final password = await _showPasswordDialog('Set Group Password', 'Optional: Leave empty for no password');
    
    String groupName = 'Private Call';
    // ignore: use_build_context_synchronously
    context.read<PttBloc>().add(PttInviteSent(
      _selectedUserIds.toList(),
      groupName,
      password,
    ));
    
    setState(() {
      _selectedUserIds.clear();
    });
    // ignore: use_build_context_synchronously
    Navigator.pop(context); // Close drawer
  }

  Widget _buildStatusIndicator(PttStateContainer state) {
    Color statusColor = Colors.white10;
    String label = 'STANDBY';
    if (state.status == PttState.talking) { statusColor = Colors.redAccent; label = 'TRANSMITTING'; }
    else if (state.status == PttState.receiving) { statusColor = Colors.greenAccent; label = 'RECEIVING'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(border: Border.all(color: statusColor), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
    );
  }

  Widget _buildPttButton(BuildContext context, PttStateContainer state) {
    final bool isTalking = state.status == PttState.talking;
    final bool isReceiving = state.status == PttState.receiving;
    
    Color accentColor = isTalking ? Colors.redAccent : (isReceiving ? Colors.greenAccent : const Color(0xFFFFD700));
    Color outerCircleColor = isTalking || isReceiving ? accentColor : Colors.white10;

    return GestureDetector(
      onTapDown: isReceiving ? null : (_) {
        if (state.activeGroupId != null) {
          HapticFeedback.mediumImpact();
          context.read<PttBloc>().add(PttStarted(state.activeGroupId!));
        }
      },
      onTapUp: (_) {
        if (isTalking) HapticFeedback.lightImpact();
        context.read<PttBloc>().add(PttStopped());
      },
      onTapCancel: () => context.read<PttBloc>().add(PttStopped()),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse Animation for "Talking"
          if (isTalking)
            _PttRipple(color: Colors.redAccent),
          
          // Receiving Visualization
          if (isReceiving)
             _PttRipple(color: Colors.greenAccent),

          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: isTalking ? 260 : 240, 
            height: isTalking ? 260 : 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: outerCircleColor, width: isTalking || isReceiving ? 4 : 2),
              boxShadow: [
                BoxShadow(
                  color: outerCircleColor.withOpacity(isTalking || isReceiving ? 0.3 : 0.05), 
                  blurRadius: isTalking ? 60 : 40, 
                  spreadRadius: isTalking ? 10 : 5
                )
              ],
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: isTalking ? 170 : 180, 
                height: isTalking ? 170 : 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, 
                  color: isTalking ? Colors.redAccent.withOpacity(0.1) : Colors.black,
                  border: isTalking ? Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1) : null,
                ),
                child: Icon(
                  isTalking || isReceiving ? Icons.mic : Icons.mic_none, 
                  size: isTalking ? 90 : 80, 
                  color: accentColor
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfo(PttStateContainer state) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 40.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi, size: 16, color: Colors.greenAccent),
          SizedBox(width: 8),
          Text('NETWORK READY', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
        ],
      ),
    );
  }
}

class _PttRipple extends StatefulWidget {
  final Color color;
  const _PttRipple({required this.color});

  @override
  State<_PttRipple> createState() => _PttRippleState();
}

class _PttRippleState extends State<_PttRipple> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            _buildCircle(1.0 + _controller.value * 0.5, 1.0 - _controller.value),
            _buildCircle(1.0 + (_controller.value + 0.5) % 1.0 * 0.5, 1.0 - (_controller.value + 0.5) % 1.0),
          ],
        );
      },
    );
  }

  Widget _buildCircle(double scale, double opacity) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: widget.color.withOpacity(opacity * 0.5), width: 2),
        ),
      ),
    );
  }
}
