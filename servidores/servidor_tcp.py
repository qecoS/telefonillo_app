import socket

HOST = '0.0.0.0'
PORT = 12345

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.bind((HOST, PORT))
    s.listen(1)
    print(f"Esperando conexión en {HOST}:{PORT}...")

    conn, addr = s.accept()
    with conn:
        print(f"Conectado por {addr}")
        conn.sendall(b"TIMBRE\n")
        while True:
            data = conn.recv(1024)
            if not data:
                print("🔌 Conexión cerrada por el cliente.")
                break
            print("📩 Recibido desde la app:", repr(data))
