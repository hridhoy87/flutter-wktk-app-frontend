class SdpUtils {
  /// Modifies the SDP string to force Opus codec and limit bitrate.
  /// Standard voice PTT is optimal at 16-24 kbps.
  static String optimizeForVoice(String sdp, {int bitrate = 20}) {
    List<String> lines = sdp.split('\r\n');
    int? opusIndex;

    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('a=rtpmap') && lines[i].contains('opus/48000')) {
        // Find the payload type for opus
        RegExp exp = RegExp(r'a=rtpmap:(\d+) opus/48000');
        Match? match = exp.firstMatch(lines[i]);
        if (match != null) {
          opusIndex = int.parse(match.group(1)!);
        }
      }
    }

    if (opusIndex != null) {
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].contains('a=fmtp:$opusIndex')) {
          // Set maxaveragebitrate for Opus
          lines[i] = '${lines[i]};maxaveragebitrate=${bitrate * 1000};stereo=0;sprop-stereo=0;useinbandfec=1';
        }
      }
    }

    return lines.join('\r\n');
  }
}
