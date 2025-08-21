import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class VideoReceiver extends StatefulWidget {
  final int listenPort;
  final String serverIp;
  const VideoReceiver({Key? key, required this.listenPort, required this.serverIp}) : super(key: key);

  @override
  State<VideoReceiver> createState() => _VideoReceiverState();
}
class _VideoReceiverState extends State<VideoReceiver> {
  RawDatagramSocket? _videoSocket;
  final ValueNotifier<Uint8List?> _lastFrameNotifier = ValueNotifier(null);

  // Para reconstrucción de frames
  final Map<int, Map<int, Uint8List>> _videoFrames = {}; // frame_id -> {packet_seq: data}
  final Map<int, int> _totalPackets = {}; // frame_id -> total_packets

  @override
  void initState() {
    super.initState();
    _initVideoSocket();
  }

  Future<void> _initVideoSocket() async {
    _videoSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, widget.listenPort);
    _videoSocket?.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _videoSocket?.receive();
        if (datagram != null) {
          _processVideoPacket(datagram.data);
        }
      }
    });
  }

  // Cabecera: <BIQHHH> = 1+4+8+2+2+2 = 19 bytes
  void _processVideoPacket(Uint8List data) {
    if (data.length < 19) return;
    final packetType = data[0];
    if (packetType != 1) return; // 1 = VIDEO_PACKAGE
    final frameId = _bytesToInt(data.sublist(1, 5));
    // timestamp (8 bytes) no usado aquí
    final length = _bytesToInt(data.sublist(13, 15));
    final packetSeq = _bytesToInt(data.sublist(15, 17));
    final totalPackets = _bytesToInt(data.sublist(17, 19));
    final payload = data.sublist(19, 19 + length);

    _videoFrames.putIfAbsent(frameId, () => {});
    _videoFrames[frameId]![packetSeq] = payload;
    _totalPackets[frameId] = totalPackets;

    // Si ya tenemos todos los fragmentos, ensamblar y mostrar
    if (_videoFrames[frameId]!.length == totalPackets) {
      final frameData = <int>[];
      for (int i = 0; i < totalPackets; i++) {
        frameData.addAll(_videoFrames[frameId]![i]!);
      }
      _lastFrameNotifier.value = Uint8List.fromList(frameData);
      _videoFrames.remove(frameId);
      _totalPackets.remove(frameId);
    }
  }

  int _bytesToInt(List<int> bytes) {
    int result = 0;
    for (int i = 0; i < bytes.length; i++) {
      result |= (bytes[i] & 0xFF) << (8 * i);
    }
    return result;
  }

  @override
  void dispose() {
    _videoSocket?.close();
    _lastFrameNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ValueListenableBuilder<Uint8List?>(
        valueListenable: _lastFrameNotifier,
        builder: (context, frame, _) {
          return frame != null
              ? Image.memory(frame, gaplessPlayback: true)
              : const Text('Esperando video...');
        },
      ),
    );
  }
}