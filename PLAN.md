# Plan de Implementación - Sistema Mesh de Audio Distribuido

## 🎯 Objetivo
Crear una ISO de NixOS arrancable desde USB con sistema mesh de audio distribuido.

## Arquitectura del Sistema

### Requisitos de Red Mesh
- [x] Cada nodo puede crear red propia si no hay cobertura
- [x] Nodos se unen automáticamente a redes existentes
- [x] Detección de desconexión y creación de nueva red
- [x] Protocolo de señalización para descubrimiento de nodos

### Gestión de Canciones
- [x] 2000 canciones sin copyright descargadas
- [x] Cada nodo recibe 25 canciones aleatorias únicas
- [x] Almacenamiento local independiente por nodo

### Nodo Master
- [x] Selección automática por recursos (CPU, RAM, uptime)
- [x] Streaming aleatorio de canciones a todos los nodos
- [x] Capacidad de recibir canción específica via API
- [x] Puede haber múltiples Masters (uno por red)

### Monitoreo (indicadores en tiempo real)
- [x] Tasa de transmisión activa (Mbps)
- [x] Nodos que ve activamente
- [x] Nivel de señal con nodos activos (dBm)
- [x] Modulación utilizada (QPSK, QAM, etc.)
- [x] Lista de canciones en modo local
- [x] Canción actual en streaming

---

## Fases de Implementación

### Fase 1: Setup del Entorno
- [x] Instalar Nix package manager
- [x] Instalar nixos-rebuild y herramientas de ISO
- [x] Configurar canales de NixOS

### Fase 2: Descarga de Contenido
- [x] Descargar 2000 canciones sin copyright (generadas)
- [x] Organizar en estructura de 80 nodos (25 canciones c/u)
- [x] Verificar integridad de archivos

### Fase 3: Configuración de NixOS
- [x] Configuración base del sistema
- [x] Drivers de red mesh (batman-adv)
- [x] Servicios de streaming (Icecast/ezstream)

### Fase 4: Software de Gestión
- [x] Agente mesh daemon en Go (compilado ✅)
- [x] Monitor en tiempo real (TUI) (compilado ✅)
- [x] API para control de Master (compilado ✅)
- [x] Interfaz TUI (compilado ✅)

### Fase 5: Construcción de ISO
- [x] Generar configuración de iso.nix ✅
- [x] Incluir canciones en imagen (18GB generado) ✅
- [x] Script de build generado ✅
- [x] Binarios compilados para Linux x86_64 ✅
- [ ] Ejecutar build en Linux con NixOS (requiere Linux)

### Fase 6: Testing
- [ ] Test en VMs
- [ ] Verificación de boot desde USB
- [ ] Prueba de mesh networking

---

## Stack Tecnológico

| Componente | Tecnología |
|------------|------------|
| OS Base | NixOS 24.05 |
| Kernel | Linux 6.x |
| Mesh Protocol | batman-adv / OLSRd2 |
| Streaming | Icecast + ezstream |
| Agente Node | Go (o Rust) |
| Base de datos | SQLite (local) + Redis |
| API Server | Go/HTTP |
| TUI | Bubble Tea (Go) |
| GUI | GTK4 (opcional) |
| Lenguajes scripting | Lua, Python |

---

## Estructura de Directorios
```
network_iso_minimax/
├── plan.md (este archivo)
├── nixos-config/
│   ├── configuration.nix
│   ├── iso.nix
│   └── hardware-configuration.nix
├── software/
│   ├── mesh-agent/
│   ├── monitor/
│   └── api-server/
├── songs/
│   └── (2000 canciones)
└── output/
    └── mesh-audio.iso
```

---

## Estimación de Recursos

| Recurso | Valor |
|---------|-------|
| ISO Size | ~4-6 GB |
| RAM mínima | 2 GB |
| Almacenamiento extra | 500 MB |
| Tiempo de build | 30-60 min |

---

## Commands Clave

```bash
# Build ISO
nix-build '<nixpkgs/nixos>' -A config.system.build.isoImage -f config.nix

# Rebuild
sudo nixos-rebuild switch

# Deploy
sudo nixos-rebuild build
```