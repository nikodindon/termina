# Termina — OS

## Résumé

**Termina** est un OS Linux minimal qui boot directement dans Hermès comme shell principal. Inspiré du terminal, nostalgique console MS-DOS, mais avec la puissance d'un agent IA conversationnel persistent. V1 cible : clé USB bootable (persistant), test multi-machines, usage console pure.

---

## 1. Principes de design

- **Hermès comme shell par défaut** — remplac `/bin/bash` dans `/etc/passwd`
- **Session persistente** — contexte Hermès conservé entre les commandes
- **Console-first** — pas de X/Wayland en v1, solutions console avant tout
- **Mono-compte + sudo** — un seul utilisateur, `sudo` pour les privileges
- **Boot sur clé USB** — persistant via partition ext4 sur la clé
- **Debian stable** — debootstrap, base fiable, apt fonctionnel
- **Fallback bash** — `Ctrl+Alt+F2` ouvre un vrai bash dans un tty séparé

---

## 2. Architecture générale

```
┌─────────────────────────────────────────────────────┐
│                      BIOS/UEFI                      │
└──────────────────────┬──────────────────────────────┘
                       │ Boot USB
        ┌──────────────▼──────────────┐
        │        Kernel Linux         │
        │      (via Syslinux/GRUB)    │
        └──────────────┬──────────────┘
                       │ pivot_root
        ┌──────────────▼──────────────┐
        │     Debian base (debootstrap)│
        │                              │
        │  ┌─────────────────────────┐ │
        │  │  systemd (PID 1)        │ │
        │  └────────────┬────────────┘ │
        │               │              │
        │  ┌────────────▼────────────┐ │
        │  │  getty@tty1             │ │
        │  │  (login shell = hermes) │ │
        │  └────────────┬────────────┘ │
        │               │              │
        │  ┌────────────▼────────────┐ │
        │  │  Hermès Agent           │ │
        │  │  (contexte persistant)  │ │
        │  └─────────────────────────┘ │
        │                              │
        │  ┌─────────────────────────┐ │
        │  │  getty@tty2             │ │
        │  │  (fallback /bin/bash)   │ │
        │  └─────────────────────────┘ │
        │                              │
        └──────────────────────────────┘
```

---

## 3. Structure du projet

```
termina/
├── ARCHITECTURE.md              ← ce fichier
├── README.md
│
├── build/                       # Scripts de construction
│   ├── 01-base.sh               # debootstrap Debian minimal
│   ├── 02-hermes.sh              # Installation Hermès + Python
│   ├── 03-network.sh             # NetworkManager + nmtui + wpa_supplicant
│   ├── 04-console-tools.sh       # ncmpcpp, mpd, git, htop, tmux, neomutt...
│   ├── 05-shell-fallback.sh      # Config tty2 bash + Ctrl+Alt+F2
│   ├── 06-firstboot.sh           # Script wizard premier boot
│   └── build.sh                  # Orchestrateur ( builds dans l'ordre )
│
├── conf/
│   ├── etc/
│   │   ├── passwd                # hermes comme shell par défaut
│   │   ├── sudoers
│   │   └── systemd/
│   │       ├── firstboot.service
│   │       └── terminad.service  # Service Hermès persistant
│   └── root/
│       └── .bashrc               # Fallback bash minimal
│
├── packages/                     # Patches et configs custom
│   ├── hermes-cli/               # Clone Hermes CLI ici
│   └── dotfiles/
│       └── .hermes/
│
└── output/                      # Artifacts de build
    ├── termina.img               # Image clé USB
    └── termina-rootfs.tar.gz     # Rootfs pour install
```

---

## 4. Stack applicatif

### Outils console essentiels

| Paquet | Description |
|--------|-------------|
| `tmux` | Multiplexeur terminal, sessions persistantes |
| `htop` | Moniteur système |
| `git` | Gestion de version |
| `curl`, `wget` | Clients HTTP |
| `vim` / `nano` | Éditeurs |
| `rsync` | Sync fichiers |
| `openssh-client` | SSH |
| `bluez` + `blueman` | Bluetooth (si dispo) |

### Musique (audio pure)

| Paquet | Description |
|--------|-------------|
| `mpd` | Music Player Daemon |
| `ncmpcpp` | Client ncurses pour mpd, visualizeur ASCII |
| `mpc` | Contrôle en ligne de commande |

### Réseau

| Paquet | Description |
|--------|-------------|
| `network-manager` | Gestionnaire réseau |
| `nmtui` | UI curses NetworkManager |
| `wpasupplicant` | WiFi WPA/WPA2 |
| `iproute2` | IP routing |
| `dnsutils` | dig, nslookup |

### Développement / IA

| Paquet | Description |
|--------|-------------|
| `python3` | Python (pour Hermès) |
| `python3-pip` | pip |
| `python3-venv` | Environnements virtuels |
| `ollama` | LLM local (optionnel, selon hardware) |

---

## 5. Boot et initialisation

### Sequence de boot

```
1. BIOS/UEFI → USB → SYSLINUX/GRUB
2. Kernel Linux chargé en mémoire
3. initramfs → pivot_root vers Debian sur USB
4. systemd (PID 1)
5. firstboot.service (si premier boot) → wizard réseau + user
6. terminad.service → Démarre Hermès daemon
7. getty@tty1 → spawn hermes comme login shell
```

### Premier boot — Wizard réseau

Au premier démarrage sur une machine, le wizard apparaît sur tty1 :

```
===============================================
  Termina — Configuration initiale
============================================

  Bienvenue ! Configurons le réseau ensemble.

  Cartes réseau détectées :
  1. eth0 — Ethernet (câblé)
  2. wlan0 — WiFi

  Voulez-vous configurer le WiFi maintenant ? [o/N]
```

Utilisation de **nmtui** (NetworkManager) pour :
- Détection des réseaux WiFi disponibles
- Sélection du réseau + saisie passphrase
- Sauvegarde et connexion automatique

### Persistance des configurations

- `/etc/NetworkManager/` → config réseau
- `/home/` → partition persistance (ext4 sur USB)
- `/etc/hermes/` → config Hermès

---

## 6. Session Hermès

### Comment ça marche

Hermès tourne comme **login shell** sur tty1. L'utilisateur interagit directement avec l'agent.

Pour persister le contexte entre commandes :
- Hermès maintient un état en mémoire (fichier JSON ou SQLite)
- Pas de "pipe" — chaque commande est une turns dans la même session
- Historique des commands conservée dans `~/.hermes/history/`

### Commandes specials

| Commande | Action |
|----------|--------|
| `:bash` | Ouvre un vrai bash dans tmux (session parallèle) |
| `:music` | Lance ncmpcpp |
| `:detach` | Détache tmux, retour à Hermès |
| `exit` | Quitte Hermès (等同 logout) |

### Fallback bash

À tout moment :
- **Ctrl+Alt+F2** → tty2 avec bash classique
- **Ctrl+Alt+F1** → retour à Hermès sur tty1

---

## 7. Musique — ncmpcpp + mpd

### Installation

```bash
apt install mpd ncmpcpp
```

### Configuration mpd

```bash
# ~/.config/mpd/mpd.conf
music_directory "~/music"
playlist_directory "~/playlists"
db_file "~/data/mpd.db"
audio_output {
    type "alsa"
    name "Default"
}
```

### Contrôles ncmpcpp

| Touche | Action |
|--------|--------|
| `1` | Affichage console |
| `2` | Affichage bibliothèque |
| `3` | Playlist |
| `Enter` | Jouer |
| `Space` | Pause |
| `s` | Stop |
| `←` `→` | Navigation |
| `q` | Quitter |

---

## 8. USB persistant

### Stratégie partitionnement

```
/dev/sdX1  bootable  ext4  /boot/grub  ~256MB
/dev/sdX2             ext4  /           ~4GB
/dev/sdX3             ext4  /home        ~8GB (optionnel, reste de la clé)
```

Ou pour une clé simple (test) :

```
/dev/sdX1  bootable  ext4  /  tout sur une partition
```

### Outils de build

- `debootstrap` — installe Debian
- `chroot` — pour installer dans le rootfs
- `squashfs` — compression filesystem (optionnel)
- `dd` —写入 USB

### Commandes build

```bash
# Build complet
sudo ./build/build.sh

# Build incremental (après modifications)
sudo ./build/02-hermes.sh
sudo ./build/03-network.sh
```

---

## 9. Sécurité

- **sudo** — utilisateur normal peut sudo
- **SSH** — serveur SSH optionnel, clé publique
- **Firewall** — nftables ou iptables simple
- **Pas de root login SSH** — interdit par défaut

---

## 10. TODO / Prochaines étapes

- [ ] Init repo GitHub
- [ ] Script 01-base.sh (debootstrap)
- [ ] Script 02-hermes.sh (install Hermès CLI)
- [ ] Script 03-network.sh (NetworkManager)
- [ ] Script 04-console-tools.sh (mpd, ncmpcpp, etc.)
- [ ] Script 05-shell-fallback.sh (tty2 bash)
- [ ] Script 06-firstboot.sh (wizard réseau)
- [ ] Script build.sh orchestateur
- [ ] Test boot sur clé USB
- [ ] README complet

---

## 11. Licence

MIT / Apache 2.0 — au choix.
