import 'package:flutter/foundation.dart';

class L {
  static const String reset = '\x1B[0m';
  static const String red = '\x1B[31m';
  static const String green = '\x1B[32m';
  static const String yellow = '\x1B[33m';
  static const String blue = '\x1B[34m';
  static const String cyan = '\x1B[36m';
  static const String magenta = '\x1B[35m';

  static void info(String message) {
    if (kDebugMode) {
      print('$blue[INFO] $message$reset');
    }
  }

  static void success(String message) {
    if (kDebugMode) {
      print('$green[SUCCESS] $message$reset');
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      print('$yellow[WARNING] $message$reset');
    }
  }

  static void error(String message, [dynamic error, StackTrace? stack]) {
    if (kDebugMode) {
      print('$red[ERROR] $message$reset');
      if (error != null) print('$red$error$reset');
      if (stack != null) print('$red$stack$reset');
    }
  }

  static void ptt(String message) {
    if (kDebugMode) {
      print('$magenta[PTT] $message$reset');
    }
  }

  static void webrtc(String message) {
    if (kDebugMode) {
      print('$cyan[WebRTC] $message$reset');
    }
  }
}
