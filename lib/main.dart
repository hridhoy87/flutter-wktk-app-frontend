import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'src/features/ptt/presentation/screens/ptt_screen.dart';
import 'src/features/ptt/presentation/bloc/ptt_bloc.dart';
import 'src/features/ptt/data/webrtc_audio_repository.dart';
import 'src/features/presence/data/mqtt_presence_repository.dart';
import 'src/features/ptt/data/mqtt_signaling_repository.dart';
import 'src/features/auth/presentation/screens/login_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';

import 'src/core/services/audio_session_service.dart';
import 'src/core/services/background_service.dart';

import 'src/features/admin/domain/admin_repository_interface.dart';
import 'src/features/admin/data/admin_repository.dart';
import 'src/features/admin/presentation/bloc/admin_bloc.dart';

import 'src/features/auth/data/auth_repository.dart';
import 'src/features/auth/presentation/bloc/auth_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Request permissions on startup
  await [
    Permission.microphone,
    Permission.notification,
  ].request();

  await AudioSessionService.initializeForPtt();
  await BackgroundService.initialize();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  const String backendUrl = 'https://flutter-wktk-app-backend.vercel.app';

  // Initialize Repositories
  final authRepo = AuthRepository(baseUrl: backendUrl);
  final audioRepo = WebRtcAudioRepositoryImpl();
  
  // Generate a random stable ID for this device session
  final String randomSessionId = Random().nextInt(1000000).toString();
  final presenceRepo = MqttPresenceRepositoryImpl('broker.hivemq.com', 'user_$randomSessionId');
  final signalingRepo = MqttSignalingRepositoryImpl(presenceRepo.client);
  final adminRepo = AdminRepositoryImpl(baseUrl: backendUrl);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepo),
        RepositoryProvider.value(value: audioRepo),
        RepositoryProvider.value(value: presenceRepo),
        RepositoryProvider.value(value: signalingRepo),
        RepositoryProvider<IAdminRepository>.value(value: adminRepo),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(authRepository: authRepo)..add(AppStarted()),
          ),
          BlocProvider(
            create: (context) => PttBloc(
              audioRepository: audioRepo,
              presenceRepository: presenceRepo,
              signalingRepository: signalingRepo,
              authRepository: authRepo,
            ),
          ),
          BlocProvider(
            create: (context) => AdminBloc(adminRepo),
          ),
        ],
        child: const WalkieTalkieApp(),
      ),
    ),
  );
}

class WalkieTalkieApp extends StatelessWidget {
  const WalkieTalkieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PTT Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F),
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD700),
          brightness: Brightness.dark,
          primary: const Color(0xFFFFD700),
          secondary: const Color(0xFF2ECC71),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          context.read<PttBloc>().add(
            PttInitializeRequested(state.phone, 'alpha_group'),
          );
        }
      },
      builder: (context, state) {
        if (state is Authenticated) {
          return const PttScreen();
        }
        if (state is Unauthenticated || state is AuthError) {
          return const LoginScreen();
        }
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFFFFD700)),
          ),
        );
      },
    );
  }
}
