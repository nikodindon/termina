# Termina OS

Boot directly into Hermès — your AI agent shell.

## What is it?

**Termina** is a minimal Linux OS that boots straight into Hermès as the primary shell. No desktop environment, no X — just a console and your AI companion. Inspired by the nostalgia of MS-DOS command lines, but powered by modern AI.

The goal: bring Hermès to bare metal. A laptop that boots into a conversation with your AI agent. Your music, your files, your workflow — all accessible through natural language.

## Features

- **Hermès as login shell** — replaces `/bin/bash` on tty1
- **Persistent session** — context maintained between commands
- **Fallback bash** — `Ctrl+Alt+F2` for a real shell when needed
- **Console music** — ncmpcpp + mpd for audio
- **Network wizard** — WiFi setup on first boot via nmtui
- **USB bootable** — persistent storage on any USB key

## Requirements

- USB key (8GB+ recommended)
- x86_64 hardware
- Wired or WiFi network for installation

## Build

```bash
# Full build
sudo ./build/build.sh

# The script will:
# 1. Bootstrap a minimal Debian
# 2. Install Hermès CLI
# 3. Configure networking (NetworkManager)
# 4. Add console tools (mpd, ncmpcpp, htop, tmux...)
# 5. Set up Hermès as default shell
# 6. Generate output/termina.img
```

## Write to USB

```bash
sudo dd if=output/termina.img of=/dev/sdX bs=4M status=progress
```

## Boot

1. Insert USB
2. Boot from USB (BIOS/UEFI selection)
3. First boot: follow the network wizard
4. Enjoy Termina

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Alt+F1` | Hermès (tty1) |
| `Ctrl+Alt+F2` | Bash fallback (tty2) |
| `:bash` | Open bash in tmux from Hermès |
| `:music` | Launch ncmpcpp |
| `exit` | Quit Hermès session |

## Project status

Architecture defined. Build scripts in progress. First boot on real hardware planned.

See [ARCHITECTURE.md](ARCHITECTURE.md) for full details.
