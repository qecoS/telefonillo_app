import 'package:flutter/material.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'dart:io';
import 'video_audio.dart';

void main() => runApp(const MDNSDiscoveryApp());

class MDNSDiscoveryApp extends StatelessWidget {
  const MDNSDiscoveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mDNS Discovery',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DiscoveryScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class DiscoveredDevice {
  final String name;
  final String? ip;
  final int? port;

  DiscoveredDevice(this.name, this.ip, this.port);
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  String? telremIp;
  String connectionStatus = '';
  bool _isScanning = false;
  MDnsClient? _mdnsClient;

  Future<void> _resolveTelremHost() async {
    setState(() {
      _isScanning = true;
      telremIp = null;
      connectionStatus = '';
    });
    final MDnsClient client = MDnsClient();
    _mdnsClient = client;
    await client.start();
    bool found = false;
    try {
      await for (IPAddressResourceRecord record in client.lookup<IPAddressResourceRecord>(
          ResourceRecordQuery.addressIPv4('telrem.local'))) {
        found = true;
        setState(() {
          telremIp = record.address.address;
          connectionStatus = 'IP encontrada: ${record.address.address}';
        });
        // Intentar conectar automáticamente por TCP
        try {
          final socket = await Socket.connect(record.address, 12345, timeout: const Duration(seconds: 3));
          setState(() {
            connectionStatus = 'Conectado a TelRem en ${socket.remoteAddress.address}:${socket.remotePort}';
          });
          socket.destroy();
          // Navegar automáticamente a la pantalla de video/audio
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => VideoAudioScreen(serverIp: record.address.address),
              ),
            );
          }
        } catch (e) {
          setState(() {
            connectionStatus = 'No se pudo conectar a TelRem: $e';
          });
        }
        break; // Solo el primer resultado
      }
      if (!found) {
        setState(() {
          connectionStatus = 'No se encontró telrem.local en la red.';
        });
      }
    } catch (e) {
      setState(() {
        connectionStatus = 'Error: $e';
      });
    } finally {
      client.stop();
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _stopDiscovery() async {
    _mdnsClient?.stop();
    _mdnsClient = null;
  }

  @override
  void dispose() {
    _stopDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar TelRem por mDNS'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Buscando IP de telrem.local y conectando por TCP al puerto 12345.'),
          ),
          if (_isScanning)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (telremIp == null)
                      ElevatedButton(
                        onPressed: _resolveTelremHost,
                        child: const Text('Reintentar búsqueda'),
                      ),
                    const SizedBox(height: 16),
                    Text(connectionStatus, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
