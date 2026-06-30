import 'dart:io';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/ptt/presentation/bloc/ptt_bloc.dart';
import '../../features/ptt/domain/repositories/audio_repository.dart';
import '../utils/logger.dart';

class WatchBridgeService {
  static final WatchBridgeService _instance = WatchBridgeService._internal();
  factory WatchBridgeService() => _instance;
  WatchBridgeService._internal();

  HttpServer? _server;
  PttBloc? _pttBloc;
  PttState _currentState = PttState.idle;

  void initialize(PttBloc bloc) async {
    _pttBloc = bloc;
    try {
      // Changed to 8081 and listening on all interfaces
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8081);
      L.success('WATCH BRIDGE: Active on http://0.0.0.0:8081');
      
      _server!.listen((HttpRequest request) async {
        final response = request.response;
        
        // Handle CORS/Headers
        response.headers.add('Access-Control-Allow-Origin', '*');
        
        if (request.uri.path == '/state') {
          response.headers.contentType = ContentType.json;
          response.write(jsonEncode({'status': _currentState.name}));
        } 
        else if (request.uri.path == '/ptt/on') {
          L.warning('WATCH COMMAND: START TRANSMIT');
          _pttBloc?.add(PttStarted(_pttBloc?.state.activeGroupId ?? '1'));
          response.write('OK');
        } 
        else if (request.uri.path == '/ptt/off') {
          L.success('WATCH COMMAND: STOP TRANSMIT');
          _pttBloc?.add(PttStopped());
          response.write('OK');
        }
        
        await response.close();
      });
    } catch (e) {
      L.error('WATCH BRIDGE FATAL ERROR: $e');
    }
  }

  void updateState(PttState state) {
    _currentState = state;
  }
}
