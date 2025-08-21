
import 'package:flutter/material.dart';
import 'video_receiver.dart';
import 'audio_sender.dart';

class VideoAudioScreen extends StatelessWidget {
	final String serverIp;
  const VideoAudioScreen({Key? key, required this.serverIp}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Video + Audio Bidireccional')),
			body: Column(
				children: [
					// Video en la parte superior (puerto 12346)
					Expanded(
						flex: 3,
						child: VideoReceiver(listenPort: 12346, serverIp: serverIp),
					),
					const Divider(),
					// Controles de audio en la parte inferior
					Expanded(
						flex: 2,
						child: AudioSender(serverIp: serverIp),
					),
				],
			),
		);
	}
}
