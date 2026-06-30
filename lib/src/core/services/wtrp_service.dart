import 'package:flutter/services.dart';
import 'dart:async';

enum WtrpEvent { pressed, released }

class WtrpService {
  static const _eventChannel = EventChannel('com.example.walkie_talkie/wtrp_events');
  static const _methodChannel = MethodChannel('com.example.walkie_talkie/wtrp_methods');

  Stream<WtrpEvent>? _eventStream;

  Stream<WtrpEvent> get events {
    _eventStream ??= _eventChannel.receiveBroadcastStream().map((dynamic event) {
      if (event == 'pressed') return WtrpEvent.pressed;
      return WtrpEvent.released;
    });
    return _eventStream!;
  }

  Future<String?> getProtocolVersion() async {
    try {
      return await _methodChannel.invokeMethod<String>('getProtocolVersion');
    } catch (e) {
      return null;
    }
  }

  Future<void> startScanning() async {
    await _methodChannel.invokeMethod('startScanning');
  }

  Future<void> stopScanning() async {
    await _methodChannel.invokeMethod('stopScanning');
  }
}
