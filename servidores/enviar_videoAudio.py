import socket
import cv2
import sounddevice as sd
import numpy as np
import threading

# Configuración
PC_IP = '192.168.1.106'            # Escucha en todas las interfaces
TCP_PORT = 12345             # Puerto TCP para confirmación
AUDIO_UDP_PORT = 12345       # Puerto UDP para audio
VIDEO_UDP_PORT = 12346       # Puerto UDP para video

# --- Servidor TCP para handshake ---
tcp_server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
tcp_server.bind((PC_IP, TCP_PORT))
tcp_server.listen(1)
print(f"Esperando conexión TCP de la app en el puerto {TCP_PORT}...")
conn, addr = tcp_server.accept()
print(f"Conexión TCP establecida desde {addr}")

# Espera señal de inicio (byte 0)
data = conn.recv(1)
if data == b'\x00':
    print("Confirmación recibida, iniciando transmisión UDP.")
else:
    print("No se recibió confirmación de inicio.")
    conn.close()
    tcp_server.close()
    exit(1)

# Obtén la IP de la app (cliente TCP)
APP_IP = addr[0]

# --- UDP sockets ---
audio_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
video_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

# --- Audio (envío) ---
def send_audio():
    def callback(indata, frames, time, status):
        audio_sock.sendto(indata.tobytes(), (APP_IP, AUDIO_UDP_PORT))
    with sd.InputStream(samplerate=8000, channels=1, dtype='int16', callback=callback, blocksize=1024):
        print("Enviando audio... (Ctrl+C para parar)")
        while True:
            sd.sleep(1000)

# --- Video (envío) ---
def send_video():
    cap = cv2.VideoCapture(0)
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        _, jpeg = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 50])
        data = jpeg.tobytes()
        if len(data) < 65000:
            video_sock.sendto(data, (APP_IP, VIDEO_UDP_PORT))
        cv2.imshow('Enviando video', frame)
        if cv2.waitKey(1) == 27:
            break
    cap.release()
    cv2.destroyAllWindows()

# --- Lanzar ambos en paralelo ---
audio_thread = threading.Thread(target=send_audio, daemon=True)
video_thread = threading.Thread(target=send_video, daemon=True)
audio_thread.start()
video_thread.start()

try:
    audio_thread.join()
    video_thread.join()
except KeyboardInterrupt:
    print("Cerrando...")
    conn.close()
    tcp_server.close()
    audio_sock.close()
    video_sock.close()