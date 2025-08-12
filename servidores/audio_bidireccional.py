import socket
import pyaudio
import threading

# Configuración del audio
CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000

# Configuración del socket UDP
UDP_IP = "0.0.0.0"
UDP_PORT_RECEIVE = 50006  # Recibe audio del móvil
UDP_PORT_SEND = 50007     # Envía audio al móvil

# Inicializa PyAudio
p = pyaudio.PyAudio()
stream_output = p.open(format=FORMAT,
                       channels=CHANNELS,
                       rate=RATE,
                       output=True,
                       frames_per_buffer=CHUNK)

stream_input = p.open(format=FORMAT,
                      channels=CHANNELS,
                      rate=RATE,
                      input=True,
                      frames_per_buffer=CHUNK)

# Configura sockets UDP
sock_receive = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock_receive.bind((UDP_IP, UDP_PORT_RECEIVE))

sock_send = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
mobile_ip = "172.20.10.3"  # Cambia por la IP del móvil

def receive_audio():
    print("🎧 Escuchando audio del móvil...")
    try:
        while True:
            data, addr = sock_receive.recvfrom(2048)
            stream_output.write(data)
    except KeyboardInterrupt:
        print("\n🔇 Recepción detenida.")

def send_audio():
    print("🎤 Enviando audio al móvil... (Presiona Ctrl+C para detener)")
    try:
        while True:
            data = stream_input.read(CHUNK, exception_on_overflow=False)
            sock_send.sendto(data, (mobile_ip, UDP_PORT_SEND))
    except KeyboardInterrupt:
        print("\n🔇 Envío detenido.")

# Inicia hilos para enviar/recibir
thread_receive = threading.Thread(target=receive_audio)
thread_send = threading.Thread(target=send_audio)

thread_receive.start()
thread_send.start()

try:
    thread_receive.join()
    thread_send.join()
except KeyboardInterrupt:
    print("\n🔇 Servidor detenido.")
finally:
    stream_output.stop_stream()
    stream_input.stop_stream()
    stream_output.close()
    stream_input.close()
    p.terminate()
    sock_receive.close()
    sock_send.close()