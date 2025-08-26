TFG Telefonillo - Parte de la APP

Autores: Dorzhi Aylagas y Sergio Cuenca

Estructura del repositorio

telefonillo_app/
├── codigo_funcional/
│   ├── TCP.txt
│   ├── mDNS/
│   └── audio_sender/
│       ├── audio_main.txt
│       └── audio_sender.txt
├── servidores/
│   ├── audio_bidireccional.py
│   ├── enviar_video.py
│   ├── enviar_videoAudio.py
│   ├── mDNS.py
│   ├── mdns_telrem_sim.py
│   ├── recibir_audio.py
│   └── servidor_tcp.py
├── telefonillo/
│   ├── analysis_options.yaml
│   ├── pubspec.lock
│   ├── pubspec.yaml
│   ├── README.md
│   ├── telefonillo.iml
│   ├── android/
│   │   ├── build.gradle.kts
│   │   ├── gradle.properties
│   │   ├── gradlew
│   │   ├── gradlew.bat
│   │   ├── local.properties
│   │   ├── settings.gradle.kts
│   │   └── app/
│   │       ├── build.gradle.kts
│   │       └── src/
│   ├── build/
│   ├── ios/
│   ├── lib/
│   │   ├── audio_sender.dart
│   │   ├── device_selector.dart
│   │   ├── main.dart
│   │   ├── menu_screen.dart
│   │   ├── sync_state.dart
│   │   ├── video_audio.dart
│   │   ├── video_receiver.dart
│   │   └── wifi_provision_screen.dart
│   ├── linux/
│   ├── macos/
│   ├── test/
│   │   └── widget_test.dart
│   ├── web/
│   │   ├── favicon.png
│   │   ├── icons/
│   │   ├── index.html
│   │   └── manifest.json
│   └── windows/
└── ...


Descripción de carpetas y archivos principales

codigo_funcional/: Ejemplos y pruebas de lógica de comunicación (TCP, mDNS, audio) en scripts y pseudocódigo.

servidores/: Scripts Python para simular o implementar el servidor (ESP32).
    audio_bidireccional.py: Servidor de audio bidireccional.
    enviar_video.py, enviar_videoAudio.py: Scripts para enviar vídeo y audio.
    mDNS.py, mdns_telrem_sim.py: Simulación y pruebas de mDNS.
    recibir_audio.py: Recepción de audio.
    servidor_tcp.py: Servidor TCP principal.

telefonillo/: Proyecto Flutter principal de la app.
    lib/: Código fuente Dart de la app.
        main.dart: Punto de entrada de la app.
        device_selector.dart: Descubrimiento de dispositivos por mDNS.
        menu_screen.dart: Menú principal de la app.
        audio_sender.dart: Lógica de envío y recepción de audio.
        video_audio.dart: Integración de audio y vídeo.
        video_receiver.dart: Recepción y reconstrucción de vídeo.
        wifi_provision_screen.dart: Pantalla de aprovisionamiento WiFi.
        sync_state.dart: Sincronización global AV.
    android/, ios/, linux/, macos/, windows/: Carpetas de plataforma para compilación nativa.
    web/: Recursos y configuración para la versión web.
    test/: Tests automáticos de la app.
    pubspec.yaml: Configuración de dependencias Flutter.