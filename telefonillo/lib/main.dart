import 'package:flutter/material.dart';
import 'audio_sender.dart';
import 'audio_receiver.dart';

void main() {
  runApp(const TelefonilloApp());
}

class TelefonilloApp extends StatelessWidget {
  const TelefonilloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telefonillo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const AudioCallScreen(),
    );
  }
}

class AudioCallScreen extends StatefulWidget {
  const AudioCallScreen({super.key});

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  final AudioSender _sender = AudioSender();
  final AudioReceiver _receiver = AudioReceiver();
  bool isCommunicating = false;

  Future<void> _startCommunication() async {
    await _sender.start();
    await _receiver.start();
    setState(() => isCommunicating = true);
  }

  Future<void> _stopCommunication() async {
    await _sender.stop();
    await _receiver.stop();
    setState(() => isCommunicating = false);
  }

  @override
  void dispose() {
    _sender.dispose();
    _receiver.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Telefonillo - Comunicación')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isCommunicating ? null : _startCommunication,
              child: const Text('📞 Contestar'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isCommunicating ? _stopCommunication : null,
              child: const Text('❌ Colgar'),
            ),
          ],
        ),
      ),
    );
  }
}