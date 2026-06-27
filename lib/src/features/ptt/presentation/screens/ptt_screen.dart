import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ptt_bloc.dart';
import '../../domain/repositories/audio_repository.dart';

class PttScreen extends StatelessWidget {
  const PttScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: BlocBuilder<PttBloc, PttStateContainer>(
        builder: (context, state) {
          final bool isTransmitting = state.status == PttState.talking;
          final bool isReceiving = state.status == PttState.receiving;
          
          return SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                const Spacer(),
                _buildStatusIndicator(state),
                const Spacer(),
                _buildPttButton(context, state),
                const SizedBox(height: 60),
                _buildBottomInfo(state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OPS CHANNEL', style: TextStyle(color: Colors.grey, letterSpacing: 2, fontSize: 12)),
              Text('SQUAD ALPHA', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w300)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white54),
            onPressed: () {},
          )
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(PttStateContainer state) {
    Color statusColor = Colors.white10;
    String label = 'STANDBY';
    
    if (state.status == PttState.talking) {
      statusColor = Colors.redAccent;
      label = 'TRANSMITTING';
    } else if (state.status == PttState.receiving) {
      statusColor = Colors.greenAccent;
      label = 'RECEIVING';
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: statusColor),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ),
      ],
    );
  }

  Widget _buildPttButton(BuildContext context, PttStateContainer state) {
    final bool isTalking = state.status == PttState.talking;
    
    return GestureDetector(
      onTapDown: (_) => context.read<PttBloc>().add(PttStarted('alpha_group')),
      onTapUp: (_) => context.read<PttBloc>().add(PttStopped()),
      onTapCancel: () => context.read<PttBloc>().add(PttStopped()),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isTalking ? Colors.redAccent.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isTalking ? Colors.redAccent : Colors.white10,
            width: 2,
          ),
          boxShadow: isTalking ? [
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.2),
              blurRadius: 40,
              spreadRadius: 5,
            )
          ] : [],
        ),
        child: Center(
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                colors: isTalking 
                  ? [const Color(0xFF300000), const Color(0xFF100000)]
                  : [const Color(0xFF1A1A1A), const Color(0xFF000000)],
              ),
            ),
            child: Icon(
              isTalking ? Icons.mic : Icons.mic_none,
              size: 80,
              color: isTalking ? Colors.redAccent : const Color(0xFFFFD700),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInfo(PttStateContainer state) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 40.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi, size: 16, color: Colors.greenAccent),
          SizedBox(width: 8),
          Text('LTE CONNECTED', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
        ],
      ),
    );
  }
}
