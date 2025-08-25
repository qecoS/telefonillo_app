import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sync_state.dart';

class AudioSender extends StatefulWidget {
  final String serverIp;
  const AudioSender({Key? key, required this.serverIp}) : super(key: key);
  @override
  State<AudioSender> createState() => _AudioSenderState();
}

class _AudioSenderState extends State<AudioSender> {
  // Buffer para paquetes de audio recibidos
  final List<Uint8List> _audioBuffer = [];
  Timer? _audioPlayTimer;
  static const int audioPlayIntervalMs = 40;
  // ...existing code...
  // Usa la variable global lastAudioTimestamp de sync_state.dart
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

  Future<void> _startCallAndSendTCP() async {
    if (!_isTCPConnected) {
      _showError("Primero conéctate por TCP");
      return;
    }

    try {
      // 1. Enviar señal de inicio (0) por TCP y flush
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
        bufferSize: 324,
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

  Future<void> _endCallAndSendTCP() async {
    try {
      // 1. Enviar señal de fin (1) por TCP y flush
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

  Future<void> _sendOpenCommand() async {
    try {
      // Enviar '7' por TCP y flush
      _tcpSocket?.add(Uint8List.fromList([7]));
      await _tcpSocket?.flush();
      _showError("Comando 'abrir' enviado");
    } catch (e) {
      _showError("Error al enviar 'abrir': $e");
    }
  }

  

  Future<void> _initUDP() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _udpPort);
      _udpSocket?.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket?.receive();
          if (datagram != null) {
            final audioData = _parseAudioPacket(datagram.data);
            if (audioData != null) {
              // Añadir al buffer
              _audioBuffer.add(audioData);
              // Limitar tamaño del buffer para evitar acumulación excesiva
              if (_audioBuffer.length > 10) {
                _audioBuffer.removeRange(0, _audioBuffer.length - 10);
              }
            }
          }
        }
      });
      // Iniciar temporizador para reproducir audio cada 20ms
  _audioPlayTimer = Timer.periodic(Duration(milliseconds: audioPlayIntervalMs), (timer) {
        if (_audioBuffer.isNotEmpty) {
          // Reproducir el paquete más reciente y vaciar el buffer
          final toPlay = _audioBuffer.removeLast();
          _audioBuffer.clear();
          _player.feedUint8FromStream(toPlay);
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

  Uint8List? _parseAudioPacket(Uint8List packet) {
    try {
      // Header structure (15 bytes total):
      // - packetType: 1 byte (uint8)
      // - audioSeq: 4 bytes (uint32)
      // - timestamp: 8 bytes (uint64) 
      // - length: 2 bytes (uint16)
      // - audioData: remaining bytes
      
      if (packet.length < 15) {
        print('Packet too small: ${packet.length} bytes');
        return null;
      }
      
      // Extract header fields
      final packetType = packet[0];
      final audioSeq = _bytesToInt(packet.sublist(1, 5));
  final timestamp = _bytesToInt(packet.sublist(5, 13));
  // Guardar timestamp global para sincronización AV
  lastAudioTimestamp = timestamp;
      final length = _bytesToInt(packet.sublist(13, 15));
      
      // Validate packet
      if (packetType != 0) {
        print('Invalid packet type: $packetType');
        return null;
      }
      
      if (packet.length < 15 + length) {
        print('Packet length mismatch. Expected: ${15 + length}, Got: ${packet.length}');
        return null;
      }
      
      // Extract audio data (skip 15-byte header)
      final audioData = packet.sublist(15, 15 + length);
      
      print('Received audio packet - Seq: $audioSeq, Length: $length bytes');
      return audioData;
      
    } 
    catch (e) {
      print('Error parsing packet: $e');
      return null;
    }
  }

  // Utilidad para convertir bytes a int (little-endian)
  int _bytesToInt(Uint8List bytes) {
    int result = 0;
    for (int i = 0; i < bytes.length; i++) {
      result |= bytes[i] << (8 * i);
    }
    return result;
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
  _endCallAndSendTCP();
  _audioPlayTimer?.cancel();
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
            onPressed: _isTCPConnected && !_isCallActive ? _startCallAndSendTCP : null,
            child: const Text("Iniciar Llamada"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isCallActive ? _endCallAndSendTCP : null,
            child: const Text("Finalizar Llamada"),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isTCPConnected ? _sendOpenCommand : null,
            child: const Text("Abrir"),
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