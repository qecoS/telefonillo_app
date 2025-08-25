import 'package:flutter/material.dart';
import 'video_audio.dart';
import 'wifi_provision_screen.dart';

class MenuScreen extends StatelessWidget {
  final String serverIp;
  const MenuScreen({Key? key, required this.serverIp}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menú principal')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Dispositivo encontrado: $serverIp', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoAudioScreen(serverIp: serverIp),
                  ),
                );
              },
              child: const Text('Llamada'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WifiProvisionScreen(serverIp: serverIp),
                  ),
                );
              },
              child: const Text('Aprovisionamiento WiFi'),
            ),
          ],
        ),
      ),
    );
  }
}
