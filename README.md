# Mesh Audio Network - ISO Bootable

## 📋 Resumen

Sistema de red mesh de audio distribuido arrancable desde USB usando NixOS. Cada nodo:
- Descubre automáticamente otros nodos en rango
- Se une a redes existentes o crea nuevas
- Comparte canciones en streaming
- Elige Master según recursos del sistema

## 📁 Estructura del Proyecto

```
network_iso_minimax/
├── PLAN.md                 # Plan de implementación
├── README.md               # Este archivo
├── flake.nix               # Configuración Flake
├── build_iso.sh            # Script para construir ISO
├── Dockerfile              # Dockerfile para build
├── nixos-config/           # Configuraciones NixOS
│   ├── configuration.nix
│   ├── hardware-configuration.nix
│   └── iso.nix
├── software/               # Software del sistema
│   ├── mesh-agent/         # Agente principal de red mesh
│   ├── monitor/            # Monitor TUI
│   └── api-server/         # API REST para control
└── songs/                  # 2000 canciones (80 nodos × 25)
    ├── all_songs/          # Todas las canciones
    ├── node_001/           # Canciones del nodo 1
    ├── node_002/           # Canciones del nodo 2
    └── ...
```

## 🔧 Requisitos para Build

### Opción 1: Linux con Nix
```bash
# Instalar Nix
curl -L https://nixos.org/nix/install | sh -s -- --daemon

# Agregar canal NixOS
nix-channel --add https://nixos.org/channels/nixos-24.05 nixos
nix-channel --update

# Construir ISO
chmod +x build_iso.sh
./build_iso.sh
```

### Opción 2: Docker
```bash
# Construir imagen Docker con NixOS
docker build -t mesh-iso-builder .
docker run -v $(pwd)/output:/output mesh-iso-builder
```

### Opción 3: VM NixOS
```bash
# Descargar NixOS live ISO
# https://nixos.org/download.html
# Boot desde ISO y ejecutar build_iso.sh
```

## 🚀 Construcción de la ISO

```bash
# Clonar o descargar este proyecto
cd network_iso_minimax

# Ejecutar script de build
chmod +x build_iso.sh
./build_iso.sh

# Salida: output/mesh-audio.iso
```

El proceso toma 30-60 minutos dependiendo del hardware.

## 💿 Instalación

```bash
# Flashear a USB (¡cuidado con el dispositivo!)
sudo dd if=output/mesh-audio.iso of=/dev/sdX bs=4M status=progress

# Reemplazar /dev/sdX con tu dispositivo USB
```

## 🎮 Uso

### Boot
1. Insertar USB en el dispositivo
2. Bootear desde USB ( configurar BIOS/UEFI)
3. El sistema arrancará automáticamente

### Credenciales por Defecto
- **Usuario**: `mesh` / **Contraseña**: `mesh123`
- **Root**: `root` / **Contraseña**: `root123`

### Comandos Disponibles

```bash
# Iniciar monitor TUI
mesh-monitor

# Ver estado de red
batctl n
batctl o

# Configurar WiFi mesh
iw dev wlan0 set type mesh
ip link set up dev wlan0
batctl meshif wlan0 join MESH-NETWORK

# API del nodo
curl http://localhost:8080/status

# Forzar canción específica (Master)
curl -X POST http://localhost:8080/api/master/song \
  -H "Content-Type: application/json" \
  -d '{"song_name": "Calm ambient synth"}'
```

## 📊 Monitoreo

El TUI muestra en tiempo real:

| Indicador | Descripción |
|-----------|--------------|
| TX Rate | Tasa de transmisión (Mbps) |
| Signal | Señal con nodos (dBm) |
| Modulation | QPSK, 16-QAM, 64-QAM, 256-QAM |
| Active Peers | Nodos visibles |
| Local Songs | Canciones del nodo |
| Streaming | Canción en stream |

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────┐
│              Red Mesh (batman-adv)           │
│                                              │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐  │
│  │ Node 1  │◄──►│ Node 2  │◄──►│ Node 3  │  │
│  │ Master  │    │ Slave   │    │ Slave   │  │
│  │ ★       │    │         │    │         │  │
│  └─────────┘    └─────────┘    └─────────┘  │
│      │              │              │        │
│      └──────────────┴──────────────┘        │
│                   │                         │
│              Icecast Stream                 │
└─────────────────────────────────────────────┘
```

## 🔄 Reconexión Automática

1. **Nodo detecta pérdida de conexión** → Espera 5s
2. **Escanea en busca de redes existentes** → Si no encuentra, crea nueva
3. **Anuncia presencia por broadcast** → Recibe peers
4. **Elección de Master** → Basada en recursos (CPU, RAM, uptime)

## 📝 API REST

### Endpoints

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/health` | Estado del servicio |
| GET | `/api/status` | Estado del nodo |
| GET | `/api/metrics` | Métricas de red |
| GET | `/api/peers` | Lista de peers |
| GET | `/api/songs` | Canciones locales |
| POST | `/api/master/song` | Seleccionar canción |
| GET | `/api/network` | Info de interfaces |

### Ejemplo

```bash
# Obtener métricas
curl http://localhost:8080/api/metrics

# Respuesta:
{
  "tx_rate_mbps": 54.2,
  "rx_rate_mbps": 45.1,
  "signal_dbm": -45,
  "modulation": "64-QAM",
  "connected": 3
}
```

## 🔒 Seguridad

- SSH habilitado con contraseña root
- Firewall abierto en puertos 22, 8000, 8080
- Usuarios con passwords iniciales (cambiar en producción)

## 📦 Contenido

- **Canciones**: 2000 archivos WAV generados
- **Nodos**: 80 directorios con 25 canciones cada uno
- **Software**: Go binaries para agent, monitor, API

## 🐛 Troubleshooting

```bash
# Ver logs del agente
journalctl -u mesh-agent -f

# Ver logs de API
journalctl -u mesh-api -f

# Reiniciar servicios
systemctl restart mesh-agent
systemctl restart mesh-api

# Ver interfaces mesh
batctl interfaces
iw dev

# Forzar re-elección de master
systemctl restart mesh-agent
```

## 📄 Licencia

Verificar licencias de canciones en `songs/metadata.json`

## 👥 Créditos

Desarrollado para proyecto de red mesh de audio distribuido.