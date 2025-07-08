import 'package:flutter/material.dart';
import 'audio_sender.dart'; 

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telefonillo Audio',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AudioSender(), // Aquí conectamos con tu código
    );
  }
}
