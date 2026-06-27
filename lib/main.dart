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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Request Microphone permissions on startup
  await [
    Permission.microphone,
    Permission.notification,
  ].request();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize Repositories
  final audioRepo = WebRtcAudioRepositoryImpl();
  final presenceRepo = MqttPresenceRepositoryImpl('broker.hivemq.com', 'client_id_123');
  final signalingRepo = MqttSignalingRepositoryImpl(presenceRepo.client);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: audioRepo),
        RepositoryProvider.value(value: presenceRepo),
        RepositoryProvider.value(value: signalingRepo),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => PttBloc(
              audioRepository: audioRepo,
              presenceRepository: presenceRepo,
              signalingRepository: signalingRepo,
            ),
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
        fontFamily: 'Roboto', // Or a more premium font if added to assets
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD700),
          brightness: Brightness.dark,
          primary: const Color(0xFFFFD700),
          secondary: const Color(0xFF2ECC71),
        ),
        useMaterial3: true,
      ),
      // For demonstration, start with PTT Screen. In production, check auth state.
      home: const PttScreen(),
    );
  }
}
