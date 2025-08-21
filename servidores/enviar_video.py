import cv2
import socket

# Configuración
DEST_IP = '192.168.0.22'
DEST_PORT = 12345

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
cap = cv2.VideoCapture(0)

while True:
    ret, frame = cap.read()
    if not ret:
        break

    # Codifica el frame como JPEG
    _, jpeg = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 50])
    data = jpeg.tobytes()

    # Envía el frame (puede que necesites fragmentar si es muy grande)
    if len(data) < 65000:  # UDP limita a ~65KB
        sock.sendto(data, (DEST_IP, DEST_PORT))
    else:
        print("Frame demasiado grande para UDP, reduce resolución o calidad.")

    # Opcional: muestra el video localmente
    cv2.imshow('Enviando video', frame)
    if cv2.waitKey(1) == 27:  # ESC para salir
        break

cap.release()
sock.close()
cv2.destroyAllWindows()