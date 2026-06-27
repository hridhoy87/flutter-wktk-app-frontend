import 'package:audio_session/audio_session.dart';

class AudioSessionService {
  static Future<void> initializeForPtt() async {
    final session = await AudioSession.instance;
    
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions: 
          AVAudioSessionCategoryOptions.allowBluetooth | 
          AVAudioSessionCategoryOptions.defaultToSpeaker,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
      androidAudioStreamType: AndroidAudioStreamType.voiceCommunication,
    ));

    // Activates the session hardware
    await session.setActive(true);
  }
}
