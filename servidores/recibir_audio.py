import socket
import pyaudio

# Configuración del audio
CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000

# Configuración del socket UDP
UDP_IP = "0.0.0.0"
UDP_PORT = 50005

# Inicializa PyAudio
p = pyaudio.PyAudio()
stream = p.open(format=FORMAT,
                channels=CHANNELS,
                rate=RATE,
                output=True,
                frames_per_buffer=CHUNK)

# Configura y abre el socket UDP
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.bind((UDP_IP, UDP_PORT))
print(f"🎧 Escuchando audio UDP en {UDP_PORT}...")

try:
    while True:
        data, addr = sock.recvfrom(2048)
        stream.write(data)
except KeyboardInterrupt:
    print("\n🔇 Finalizado por el usuario.")
finally:
    stream.stop_stream()
    stream.close()
    p.terminate()
    sock.close()
