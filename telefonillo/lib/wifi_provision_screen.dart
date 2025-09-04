import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class WifiProvisionScreen extends StatefulWidget {
  // La IP de la placa en modo AP es fija
  final String serverIp;
  const WifiProvisionScreen({Key? key, this.serverIp = '192.168.4.1'}) : super(key: key);

  @override
  State<WifiProvisionScreen> createState() => _WifiProvisionScreenState();
}

class _WifiProvisionScreenState extends State<WifiProvisionScreen> {
  List<Map<String, dynamic>> networks = [];
  bool isLoading = false;
  String? errorMsg;
  String? selectedSsid;
  String password = '';
  String? provisionMsg;

  Future<void> scanNetworks() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
      networks = [];
      provisionMsg = null;
    });
    try {
      // Usar siempre la IP fija 192.168.4.1 para el provisionings
      final url = Uri.parse('http://192.168.4.1/scan');
      final response = await http.get(url).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> nets = data['networks'] ?? [];

        networks = nets.map((e) => Map<String, dynamic>.from(e)).toList();
        // Ordenar por RSSI
        networks.sort((a, b) => (b['rssi'] ?? -100).compareTo(a['rssi'] ?? -100));
        setState(() {});
      } else {
        setState(() { errorMsg = 'Error HTTP: ${response.statusCode}'; });
      }
    } catch (e) {
      setState(() { errorMsg = 'Error: $e'; });
    } finally {
      setState(() { isLoading = false; });
    }
  }

  Future<void> provisionWifi() async {
    if (selectedSsid == null) return;
    setState(() { isLoading = true; provisionMsg = null; });
    try {
      // Usar siempre la IP fija 192.168.4.1 para el provisioning
      final url = Uri.parse('http://192.168.4.1/config');
      final body = json.encode({ 'ssid': selectedSsid, 'password': password });
      final response = await http.post(url, body: body, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          setState(() { provisionMsg = '¡Aprovisionamiento exitoso!'; });
        } else {
          setState(() { provisionMsg = 'Fallo en el aprovisionamiento.'; });
        }
      } else {
        setState(() { provisionMsg = 'Error HTTP: ${response.statusCode}'; });
      }
    } catch (e) {
      setState(() { provisionMsg = 'Error: $e'; });
      
    } finally {
      setState(() { isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aprovisionamiento WiFi')),
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
                    'Aprovisionamiento WiFi',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '1. Conéctate a la WiFi de la placa (ej: ESP32-XXXX) desde los ajustes del móvil.\n'
                    '2. Pulsa el botón para escanear redes WiFi disponibles.\n'
                    '3. Selecciona la red y envía la contraseña para aprovisionar.',
                    style: TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.wifi),
                    onPressed: isLoading ? null : scanNetworks,
                    label: const Text('Escanear redes WiFi'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                  ),
                  if (isLoading) const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                  if (errorMsg != null) Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(errorMsg!, style: TextStyle(color: Colors.red)),
                  ),
                  if (networks.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        itemCount: networks.length,
                        itemBuilder: (context, i) {
                          final net = networks[i];
                          final ssid = net['ssid'] ?? 'Unknown';
                          final rssi = net['rssi'] ?? -100;
                          final security = net['security'] ?? 'Unknown';
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              title: Text(ssid),
                              subtitle: Text('Señal: $rssi dBm  Seguridad: $security'),
                              trailing: selectedSsid == ssid ? const Icon(Icons.check_circle, color: Colors.green) : null,
                              onTap: () {
                                setState(() { selectedSsid = ssid; password = ''; });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  if (selectedSsid != null) ...[
                    const SizedBox(height: 16),
                    Text('SSID seleccionado: $selectedSsid'),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Contraseña (vacío si es abierta)'),
                      onChanged: (v) => password = v,
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      onPressed: isLoading ? null : provisionWifi,
                      label: const Text('Aprovisionar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                  if (provisionMsg != null) Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(provisionMsg!, style: const TextStyle(fontWeight: FontWeight.bold)),
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
