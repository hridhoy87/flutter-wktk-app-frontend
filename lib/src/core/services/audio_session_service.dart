import 'package:audio_session/audio_session.dart';
import '../utils/logger.dart';

class AudioSessionService {
  static Future<void> initializeForPtt() async {
    try {
      final session = await AudioSession.instance;
      
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: 
            AVAudioSessionCategoryOptions.allowBluetooth | 
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
      ));

      // Removed session.setActive(true) from here. 
      // The AudioRepository will manage activation on-demand for PTT.
      L.success('Audio Session Configured (Idle State)');
    } catch (e) {
      L.error('Failed to initialize Audio Session', e);
    }
  }
}
