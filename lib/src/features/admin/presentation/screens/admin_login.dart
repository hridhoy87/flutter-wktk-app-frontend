import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/admin_bloc.dart';
import 'admin_dashboard.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      resizeToAvoidBottomInset: false,
      body: BlocListener<AdminBloc, AdminState>(
        listener: (context, state) {
          if (state is AdminAuthenticated) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashboard()),
            );
          }
          if (state is AdminError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
            );
          }
        },
        child: SingleChildScrollView(
          child: Container(
            height: MediaQuery.of(context).size.height,
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'IDENTITY\nVERIFY',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w100,
                    letterSpacing: 8,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Confirm credentials to access settings or admin console.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _phoneController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'ADMIN PHONE',
                    hintStyle: TextStyle(color: Colors.white24, letterSpacing: 2),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'PASSCODE',
                    hintStyle: TextStyle(color: Colors.white24, letterSpacing: 2),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                  ),
                ),
                const SizedBox(height: 60),
                BlocBuilder<AdminBloc, AdminState>(
                  builder: (context, state) {
                    return SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        ),
                        onPressed: state is AdminLoading 
                          ? null 
                          : () {
                              context.read<AdminBloc>().add(
                                AdminLoginRequested(_phoneController.text, _passwordController.text),
                              );
                            },
                        child: state is AdminLoading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text('AUTHORIZE', style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
