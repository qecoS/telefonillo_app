import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioSender extends StatefulWidget {
  final String serverIp;
  const AudioSender({Key? key, required this.serverIp}) : super(key: key);
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
  late final String _serverIP;
  int _audioSeq = 0;
  @override
  void initState() {
    super.initState();
    _serverIP = widget.serverIp;
  }
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
          // Empaquetar audio con cabecera igual que el script Python
          final int packetType = 0; // AUDIO_PACKAGE
          final int timestamp = DateTime.now().millisecondsSinceEpoch;
          final int length = data.length;
          final header = BytesBuilder();
          header.add([packetType]); // uint8
          header.add(_intToBytes(_audioSeq, 4)); // uint32
          header.add(_intToBytes(timestamp, 8)); // uint64
          header.add(_intToBytes(length, 2)); // uint16
          final packet = Uint8List.fromList(header.toBytes() + data);
          _udpSocket!.send(packet, InternetAddress(_serverIP), _udpPort);
          _audioSeq++;
          print('Enviados ${data.length} bytes por UDP (con cabecera)');
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

  // Utilidad para convertir int a bytes little-endian
  List<int> _intToBytes(int value, int bytes) {
    final result = <int>[];
    for (int i = 0; i < bytes; i++) {
      result.add((value >> (8 * i)) & 0xFF);
    }
    return result;
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
    return Center(
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
    );
  }
}