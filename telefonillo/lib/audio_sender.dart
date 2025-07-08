import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioSender {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  RawDatagramSocket? _socket;
  StreamController<Uint8List>? _audioStreamController;

  final String serverIP = '192.168.0.21'; // IP del portátil
  final int serverPort = 50005;

  Future<void> start() async {
    await Permission.microphone.request();
    await _recorder.openRecorder();
    _audioStreamController = StreamController<Uint8List>();
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

    _audioStreamController!.stream.listen((data) {
      _socket?.send(data, InternetAddress(serverIP), serverPort);
    });

    await _recorder.startRecorder(
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
      toStream: _audioStreamController!.sink,
    );
  }

  Future<void> stop() async {
    await _recorder.stopRecorder();
    await _audioStreamController?.close();
    _audioStreamController = null;
    _socket?.close();
  }

  void dispose() {
    _recorder.closeRecorder();
    _socket?.close();
    _audioStreamController?.close();
  }
}