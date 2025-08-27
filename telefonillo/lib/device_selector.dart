import 'package:flutter/material.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'dart:io';
import 'menu_screen.dart';
import 'wifi_provision_screen.dart';

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
            connectionStatus = 'Conectado a TelRem en \\${socket.remoteAddress.address}:\\${socket.remotePort}';
          });
          // Navegar automáticamente al menú principal y pasar el socket
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MenuScreen(serverIp: record.address.address, tcpSocket: socket),
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
        title: const Text('Buscar ESP'),
      ),
      body: Container(
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
                    'Buscando ESP-32',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_isScanning)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )
                  else ...[
                    if (telremIp == null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            onPressed: _resolveTelremHost,
                            label: const Text('Reintentar búsqueda'),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.wifi),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WifiProvisionScreen(),
                                ),
                              ).then((_) {
                                // Al volver del aprovisionamiento, intentar discovery de nuevo
                                _resolveTelremHost();
                              });
                            },
                            label: const Text('Aprovisionar WiFi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Text(connectionStatus, style: const TextStyle(fontSize: 16)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
