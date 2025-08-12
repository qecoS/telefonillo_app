import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';

class AudioReceiver {
  final int listenPort;

  late FlutterSoundPlayer _player;
  late RawDatagramSocket _socket;
  late StreamController<Uint8List> _audioStreamController;
  late StreamSink<Uint8List> _uint8ListSink;

  AudioReceiver(this.listenPort) {
    _player = FlutterSoundPlayer();
    _audioStreamController = StreamController<Uint8List>();
    _uint8ListSink = _audioStreamController.sink;
  }

  Future<void> init() async {
    // Abrimos el reproductor
    await _player.openPlayer();

    // Empezamos a reproducir desde stream
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      interleaved: true,
      numChannels: 1,
      sampleRate: 16000,
      bufferSize: 4096,
    );

    // Escuchamos el stream para alimentar el player
    _audioStreamController.stream.listen((buffer) {
      _player.feedFromStream(buffer);
    });

    // Abrimos socket UDP para recibir
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, listenPort);
    print("🎧 Escuchando en el puerto $listenPort...");
  }

  Future<void> startReceiving() async {
    _socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket.receive();
        if (datagram != null) {
          _uint8ListSink.add(datagram.data);
        }
      }
    });
  }

  Future<void> stopReceiving() async {
    await _player.stopPlayer();
    await _player.closePlayer();

    await _audioStreamController.close();
    _socket.close();
  }

  Future<void> dispose() async {
    await stopReceiving();
  }
}
