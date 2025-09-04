import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'sync_state.dart';

class AudioSender extends StatefulWidget {
  final String serverIp;
  final Socket? tcpSocket;
  const AudioSender({Key? key, required this.serverIp, this.tcpSocket}) : super(key: key);
  @override
  State<AudioSender> createState() => _AudioSenderState();
}

class _AudioSenderState extends State<AudioSender> {
  // Buffer para paquetes de audio recibidos
  final List<Uint8List> _audioBuffer = [];
  Timer? _audioPlayTimer;
  static const int audioPlayIntervalMs = 40;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  RawDatagramSocket? _udpSocket;
  Socket? _tcpSocket;
  StreamController<Uint8List>? _audioStreamController;
  bool _isCallActive = false;
  bool _isTCPConnected = true;

  // Configuración de red
  late final String _serverIP;
  int _audioSeq = 0;
  @override
  void initState() {
    super.initState();
    _serverIP = widget.serverIp;
    _tcpSocket = widget.tcpSocket;
  }
  final int _udpPort = 12345;


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

          final int packetType = 0;
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
        }
      });

      await _recorder.openRecorder();
      await _recorder.startRecorder(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 8000,
        toStream: _audioStreamController!.sink,
        bufferSize: 324,
      );

      await _player.openPlayer(); // Asegurar que el player esté abierto
      await _player.startPlayerFromStream(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 8000,
        bufferSize: 324,
        interleaved: false,
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
      _showError("Error al finalizar: $e");
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
        // Escuchar eventos de socket UDP
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket?.receive();
          // Procesar datagramas recibidos
          if (datagram != null) {
            final audioData = _parseAudioPacket(datagram.data);
            // Procesar audioData
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
        if (_audioBuffer.isNotEmpty && _player.uint8ListSink != null) {
          // Reproducir todos los paquetes en orden de llegada
          while (_audioBuffer.isNotEmpty) {
            final toPlay = _audioBuffer.removeAt(0);
            _player.uint8ListSink!.add(toPlay);
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

  Uint8List? _parseAudioPacket(Uint8List packet) {
    try {
      // Estructura de encabezado (15 bytes totales):
      // - packetType: 1 byte (uint8)
      // - audioSeq: 4 bytes (uint32)
      // - timestamp: 8 bytes (uint64) 
      // - length: 2 bytes (uint16)
      // - audioData: remaining bytes
      
      if (packet.length < 15) {
        print('Packet too small: ${packet.length} bytes');
        return null;
      }

      // Extraer campos de encabezado
      final packetType = packet[0];
      final timestamp = _bytesToInt(packet.sublist(5, 13));
      // Guardar timestamp global para sincronización AV
      lastAudioTimestamp = timestamp;
      final length = _bytesToInt(packet.sublist(13, 15));
      // Validar paquete
      if (packetType != 0) {
        return null;
      }
      if (packet.length < 15 + length) {
        return null;
      }
      // Extraer datos de audio (omitir encabezado de 15 bytes)
      final audioData = packet.sublist(15, 15 + length);
      return audioData;
      
    } 
    catch (e) {
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

  // Utilidad para convertir int a bytes (little-endian)
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFe0eafc), Color(0xFFcfdef3)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Controles de llamada",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.call, size: 28),
                      label: const Text("Llamar"),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: !_isCallActive ? _startCallAndSendTCP : null,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.call_end, size: 28),
                      label: const Text("Colgar"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: _isCallActive ? _endCallAndSendTCP : null,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.door_front_door, size: 28),
                  label: const Text("Abrir puerta"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  onPressed: _sendOpenCommand,
                ),
                if (_isCallActive)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text(
                      "Llamada en curso...",
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}