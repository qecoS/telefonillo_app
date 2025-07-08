import socket
import pyaudio

# Configura el audio
CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000

# Configura el socket
UDP_IP = '192.168.0.24'  # IP del móvil
UDP_PORT = 50006

# Inicializa PyAudio
p = pyaudio.PyAudio()
stream = p.open(format=FORMAT,
                channels=CHANNELS,
                rate=RATE,
                input=True,
                frames_per_buffer=CHUNK)

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

print("🎤 Enviando audio al móvil...")

try:
    while True:
        data = stream.read(CHUNK, exception_on_overflow=False)
        sock.sendto(data, (UDP_IP, UDP_PORT))
except KeyboardInterrupt:
    print("🛑 Finalizado.")
finally:
    stream.stop_stream()
    stream.close()
    p.terminate()
    sock.close()
