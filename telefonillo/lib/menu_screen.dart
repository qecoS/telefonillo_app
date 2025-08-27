import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'video_audio.dart';

class MenuScreen extends StatelessWidget {
  final String serverIp;
  final Socket? tcpSocket;
  const MenuScreen({Key? key, required this.serverIp, this.tcpSocket}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menú principal')),
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
                    "Menú principal",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text('Dispositivo encontrado: $serverIp', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.call, size: 28),
                    label: const Text("Llamada"),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoAudioScreen(serverIp: serverIp, tcpSocket: tcpSocket),
                        ),
                      );
                    },
                  ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.door_front_door, size: 28),
                      label: const Text("Abrir puerta"),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      onPressed: () async {
                        // Enviar comando de abrir puerta por TCP
                        if (tcpSocket != null) {
                          try {
                            tcpSocket?.add(Uint8List.fromList([7]));
                            await tcpSocket!.flush();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Comando de abrir puerta enviado')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error al abrir puerta: $e')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No hay conexión TCP activa')),
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
