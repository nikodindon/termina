#!/bin/bash
#===============================================
# Termina — Script 03: Réseau (NetworkManager)
#===============================================
set -e

export DEBIAN_FRONTEND=noninteractive

echo "[Network] Installation de NetworkManager..."
apt update
apt install -y \
    network-manager \
    network-manager-gnome \
    iproute2 \
    iputils-ping \
    dnsutils \
    net-tools \
    isc-dhcp-client

echo "[Network] Configuration de NetworkManager..."
# Activer NetworkManager pour gérer tous les interfaces
cat > /etc/NetworkManager/NetworkManager.conf << 'EOF'
[main]
plugins=ifupdown,keyfile
dns=default

[ifupdown]
managed=true

[device]
wifi.scan-rand-mac-address=no
EOF

# Activer le service
systemctl enable NetworkManager
systemctl enable wpa_supplicant

echo "[Network] Configuration wpa_supplicant pour WiFi..."
cat > /etc/wpa_supplicant.conf << 'EOF'
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=FR
EOF

# Interface WiFi par défaut
cat > /etc/wpa_supplicant/wpa_supplicant.conf << 'EOF'
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=FR
EOF

echo "[Network] Configuration DNS..."
cat > /etc/resolv.conf << 'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF

echo "[Network] Outils réseau additionnels..."
apt install -y \
    traceroute \
    mtr \
    nmap \
    telnet \
    ftp \
    rsync \
    openssh-client

echo "[Network] Script de détection WiFi..."
cat > /usr/local/bin/wifi-detect << 'SCRIPT'
#!/bin/bash
# Détection et connexion WiFi rapide
set -e

echo "=== Détection WiFi ==="
ip link set up wlan0 2>/dev/null || true
iw dev wlan0 scan 2>/dev/null | grep -E "^BSS|SSID:" | head -20

echo ""
echo "Réseaux disponibles :"
nmcli device wifi list | head -15
SCRIPT
chmod +x /usr/local/bin/wifi-detect

echo "[Network] Configuration du firewall (ufw)..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw --force enable

echo "[Network] IP forwarding pour partage internet (optionnel)..."
cat >> /etc/sysctl.conf << 'EOF'
# IP forwarding pour partage de connexion
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF

echo "[Network] Terminé !"
