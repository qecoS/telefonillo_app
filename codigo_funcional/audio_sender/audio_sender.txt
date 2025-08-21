import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioSender extends StatefulWidget {
  const AudioSender({super.key});

  @override
  State<AudioSender> createState() => _AudioSenderState();
}

class _AudioSenderState extends State<AudioSender> {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  RawDatagramSocket? _udpSocket;
  Socket? _tcpSocket; 
  StreamController<Uint8List>? _audioStreamController;
  bool _isCallActive = false;
  bool _isTCPConnected = false;

  // Configuración de red
  final String _serverIP = '10.136.144.190';
  final int _tcpPort = 12345;
  final int _udpPort = 12345;

  Future<void> _connectTCP() async {
    try {
      await Permission.microphone.request(); // Solicitar permiso primero
      _tcpSocket = await Socket.connect(_serverIP, _tcpPort, timeout: const Duration(seconds: 3));
      _tcpSocket?.listen(
        (data) => print('Datos TCP recibidos: $data'),
        onError: (error) => _showError("Error TCP: $error"),
        onDone: () => print('Conexión TCP cerrada'),
      );
      setState(() => _isTCPConnected = true);
    } catch (e) {
      _showError("Error TCP: ${e.toString()}");
    }
  }

  Future<void> _startCall() async {
    if (!_isTCPConnected) {
      _showError("Primero conéctate por TCP");
      return;
    }

    try {
      // 1. Enviar señal de inicio
      _tcpSocket?.add(Uint8List.fromList([0]));
      await _tcpSocket?.flush();

      // 2. Configurar UDP
      await _initUDP();

      // 3. Iniciar transmisión de audio
      _audioStreamController = StreamController<Uint8List>();
      _audioStreamController!.stream.listen((data) {
        if (_udpSocket != null) {
          _udpSocket!.send(data, InternetAddress(_serverIP), _udpPort);
          print('Enviados ${data.length} bytes por UDP');
        }
      });

      await _recorder.openRecorder(); // Asegurar que el recorder esté abierto
      await _recorder.startRecorder(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 8000,
        toStream: _audioStreamController!.sink,
      );

      await _player.openPlayer(); // Asegurar que el player esté abierto
      await _player.startPlayer(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 8000,
      );

      setState(() => _isCallActive = true);
    } catch (e) {
      _showError("Error UDP: ${e.toString()}");
    }
  }

  Future<void> _endCall() async {
    try {
      // 1. Enviar señal de fin
      _tcpSocket?.add(Uint8List.fromList([1]));
      await _tcpSocket?.flush();

      // 2. Detener transmisión
      await _recorder.stopRecorder();
      await _player.stopPlayer();
      await _audioStreamController?.close();
      _udpSocket?.close();

      setState(() => _isCallActive = false);
    } catch (e) {
      print("Error al finalizar: $e");
    }
  }

  Future<void> _initUDP() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _udpPort);
      _udpSocket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket?.receive();
          if (datagram != null) {
            _player.feedUint8FromStream(datagram.data);
          }
        }
      });
    } catch (e) {
      _showError("Error UDP: ${e.toString()}");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message))
    );
  }

  @override
  void dispose() {
    _endCall();
    _tcpSocket?.close();
    _recorder.closeRecorder();
    _player.closePlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Control de Llamada')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isTCPConnected ? null : _connectTCP,
              child: Text(_isTCPConnected ? "Conectado TCP" : "Conectar TCP"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isTCPConnected && !_isCallActive ? _startCall : null,
              child: const Text("Iniciar Llamada"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isCallActive ? _endCall : null,
              child: const Text("Finalizar Llamada"),
            ),
            if (_isCallActive)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text("Llamada en curso...", style: TextStyle(color: Colors.green)),
              ),
          ],
        ),
      ),
    );
  }
}