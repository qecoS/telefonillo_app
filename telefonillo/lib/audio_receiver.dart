import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';

class AudioReceiver {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  RawDatagramSocket? _socket;
  StreamController<Uint8List>? _streamController;

  final int listenPort = 50006; // Puerto donde escucha el móvil

  Future<void> start() async {
    await _player.openPlayer();
    _streamController = StreamController<Uint8List>();

    await _player.startPlayerFromStream(
      //fromStream: _streamController!.stream,
      codec: Codec.pcm16,
      interleaved: true,
      numChannels: 1,
      sampleRate: 16000,
      bufferSize: 3200,
    );


    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, listenPort);
    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram != null) {
          _streamController?.add(datagram.data);
        }
      }
    });
  }

  Future<void> stop() async {
    await _player.stopPlayer();
    _streamController?.close();
    _streamController = null;
    _socket?.close();
    _socket = null;
  }

  void dispose() {
    _player.closePlayer();
    _socket?.close();
    _streamController?.close();
  }
}