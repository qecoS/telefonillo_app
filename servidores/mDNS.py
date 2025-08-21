from zeroconf import Zeroconf, ServiceInfo
import socket

# Configuración del servicio
service_type = "_telefonillo._tcp.local."
service_name = "TelefonilloServidor._telefonillo._tcp.local."
port = 12345  # Puerto del servicio
desc = {'info': 'Servidor Telefonillo'}

# Obtiene la IP local
hostname = socket.gethostname()
ip_address = socket.gethostbyname(hostname)

info = ServiceInfo(
    type_=service_type,
    name=service_name,
    addresses=[socket.inet_aton(ip_address)],
    port=port,
    properties=desc,
    server=hostname + ".local."
)

zeroconf = Zeroconf()
print(f"Registrando servicio mDNS en {ip_address}:{port}...")
zeroconf.register_service(info)

try:
    input("Presiona Enter para salir...\n")
finally:
    zeroconf.unregister_service(info)
    zeroconf.close()