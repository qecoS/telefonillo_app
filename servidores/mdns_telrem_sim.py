# Simulador mDNS para telrem.local usando zeroconf
# Ejecuta este script en tu PC para anunciar 'telrem.local' en la red local

from zeroconf import Zeroconf, ServiceInfo
import socket
import sys

# Obtiene la IP local automáticamente
hostname = socket.gethostname()
local_ip = socket.gethostbyname(hostname)

# Permite pasar la IP manualmente como argumento
if len(sys.argv) > 1:
    local_ip = sys.argv[1]

print(f"Anunciando telrem.local -> {local_ip}")

info = ServiceInfo(
    type_="_telrem._tcp.local.",
    name="TelRem-Control._telrem._tcp.local.",
    addresses=[socket.inet_aton(local_ip)],
    port=12345,
    properties={
        "version": "1.0",
        "device": "esp32-audio",
        "type": "control",
        "protocol": "tcp"
    },
    server="telrem.local."
)

zeroconf = Zeroconf()
try:
    zeroconf.register_service(info)
    print("Servicio mDNS registrado. Pulsa Ctrl+C para salir.")
    import time
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("\nCerrando servicio mDNS...")
    zeroconf.unregister_service(info)
    zeroconf.close()
