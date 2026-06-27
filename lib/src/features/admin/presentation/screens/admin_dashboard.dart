import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/admin_bloc.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('ADMIN CONSOLE', style: TextStyle(letterSpacing: 4, fontSize: 14)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AdminBloc>().add(FetchPendingUsers()),
          ),
        ],
      ),
      body: BlocBuilder<AdminBloc, AdminState>(
        builder: (context, state) {
          if (state is AdminLoading) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)));
          }
          if (state is PendingUsersLoaded) {
            if (state.users.isEmpty) {
              return const Center(child: Text('NO PENDING APPROVALS', style: TextStyle(color: Colors.white24, letterSpacing: 2)));
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 800) {
                  return _buildWebTable(context, state.users);
                }
                return _buildMobileList(context, state.users);
              },
            );
          }
          return const Center(child: Text('ERROR LOADING DATA', style: TextStyle(color: Colors.redAccent)));
        },
      ),
    );
  }

  Widget _buildWebTable(BuildContext context, List<Map<String, dynamic>> users) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: SingleChildScrollView(
        child: DataTable(
          headingTextStyle: const TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
          dataTextStyle: const TextStyle(color: Colors.white70),
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('LEGAL NAME')),
            DataColumn(label: Text('PHONE')),
            DataColumn(label: Text('ACTIONS')),
          ],
          rows: users.map((user) => DataRow(cells: [
            DataCell(Text(user['id'].toString())),
            DataCell(Text(user['legal_name'])),
            DataCell(Text(user['phone'])),
            DataCell(Row(
              children: [
                TextButton(
                  onPressed: () => context.read<AdminBloc>().add(ApproveUserRequested(user['id'])),
                  child: const Text('APPROVE', style: TextStyle(color: Colors.greenAccent)),
                ),
                TextButton(
                  onPressed: () => context.read<AdminBloc>().add(RejectUserRequested(user['id'])),
                  child: const Text('REJECT', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            )),
          ])).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileList(BuildContext context, List<Map<String, dynamic>> users) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.white10),
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
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
        );
      },
    );
  }
}
