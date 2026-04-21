#!/bin/bash
#===============================================
# Termina — Script 01: Base Debian
#===============================================
set -e

export DEBIAN_FRONTEND=noninteractive

echo "[Base] Configuration du hostname..."
echo "termina" > /etc/hostname
cat > /etc/hosts << 'EOF'
127.0.0.1 localhost
127.0.1.1 termina
EOF

echo "[Base] Configuration du fuseau horaire..."
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

echo "[Base] Configuration du clavier..."
cat > /etc/default/keyboard << 'EOF'
XKBMODEL=pc105
XKBLAYOUT=fr
XKBVARIANT=latin9
XKBOPTIONS=terminate:ctrl_alt_bksp
EOF
dpkg-reconfigure -f noninteractive keyboard-configuration 2>/dev/null || true

echo "[Base] Mise à jour des paquets..."
apt update
apt upgrade -y

echo "[Base] Installation des utilitaires de base..."
apt install -y \
    sudo \
    locales \
    bash-completion \
    ufw \
    curl \
    wget \
    vim \
    nano \
    git \
    less \
    jq \
    bc \
    dc \
    screen \
    htop \
    tree

echo "[Base] Configuration de sudo..."
echo "%sudo ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

echo "[Base] Génération des locales FR..."
sed -i '/fr_FR.UTF-8/s/^# //' /etc/locale.gen
locale-gen
update-locale LANG=fr_FR.UTF-8

echo "[Base] Configuration du réseau..."
cat > /etc/network/interfaces << 'EOF'
# Loopback
auto lo
iface lo inet loopback

# DHCP par défaut (NetworkManager prendra le relais)
auto eth0
iface eth0 inet dhcp
EOF

echo "[Base] Activation de NTP..."
apt install -y ntp ntpdate
systemctl enable ntp 2>/dev/null || true

echo "[Base] Installation de systemd réseau..."
apt install -y ifupdown
systemctl enable networking 2>/dev/null || true

echo "[Base] Configuration des partitions fstab..."
# UUID sera différent sur chaque machine, on utilise des labels
cat >> /etc/fstab << 'EOF'
# Label-based mounts pour USB persistant
LABEL=TERMINA / ext4 defaults,errors=remount-ro 0 1
LABEL=BOOT /boot vfat defaults 0 2
tmpfs /tmp tmpfs defaults 0 0
tmpfs /var/log tmpfs defaults 0 0
tmpfs /var/cache tmpfs defaults 0 0
EOF

echo "[Base] Nettoyage..."
apt autoremove -y
apt autoclean

echo "[Base] Terminé !"
