#!/bin/bash
#===============================================
# Termina — Script 05: Fallback bash (tty2)
#===============================================
set -e

export DEBIAN_FRONTEND=noninteractive

echo "[Fallback] Configuration du tty2 bash..."

# Configuration de agetty pour tty2 (fallback bash)
mkdir -p /etc/systemd/system/getty@tty2.service.d/
cat > /etc/systemd/system/getty@tty2.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I 38400 linux
TTYVTDisallocate=no
EOF

# Le tty2 ouvre directement root sans mot de passe (USB local, pas de risque)
# Pour plus de sécurité, remplacer --autologin root par --autologin username

echo "[Fallback] Configuration du tty3 (optionnel, pour plus de ttys)..."
mkdir -p /etc/systemd/system/getty@tty3.service.d/
cat > /etc/systemd/system/getty@tty3.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I 38400 linux
TTYVTDisallocate=no
EOF

echo "[Fallback] Configuration du login classique..."
# Shell de fallback dans /etc/shells
if ! grep -q "/bin/bash" /etc/shells; then
    echo "/bin/bash" >> /etc/shells
fi

# Message du jour (MOTD)
cat > /etc/motd << 'EOF'
===============================================
  Bienvenue sur Termina OS
===============================================

  TTY1 → Hermès (agent IA)
  TTY2 → Bash root
  TTY3 → Bash root

  Commandes utiles :
    :music    → Lance ncmpcpp (musique)
    :bash     → Ouvre bash dans tmux
    exit      → Quitte Hermès

  Réseau :
    nmtui     → Menu NetworkManager
    wifi-detect → Détecte les réseaux WiFi

  Musique :
    music     → Lance ncmpcpp
    mpc play/pause/stop → Contrôle rapide

===============================================
EOF

echo "[Fallback] Touches magiques systemd..."
# Permettre Ctrl+Alt+Del
ln -sf /lib/systemd/system.ctrl-alt-del.target /etc/systemd/system/ctrl-alt-del.target

echo "[Fallback] TTYs supplémentaires..."
cat >> /etc/default/console-setup << 'EOF'
# Activer plus de TTYs
ACTIVATE_5_TTYS=yes
EOF

echo "[Fallback] Configuration de sudo pour tty local..."
# Permettre sudo sans mot de passe sur ttys locaux (sécurité USB)
cat >> /etc/sudoers << 'EOF'
# sudo sans mot de passe sur console locale (Termina USB)
%sudo ALL=(ALL) NOPASSWD: ALL
Defaults !requiretty
EOF

echo "[Fallback] Message au login root (tty2)..."
cat > /root/.bashrc << 'EOF'
# Bashrc root pour Termina
PS1='\[\033[01;31m\]\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]# '

# Welcome message
echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║   Termina OS — Bash Root Fallback        ║"
echo "  ║                                          ║"
echo "  ║   TTY1 = Hermès                          ║"
echo "  ║   Ctrl+Alt+F1 = Hermès                   ║"
echo "  ║   Ctrl+Alt+F2 = Ce terminal (root)       ║"
echo "  ║                                          ║"
echo "  ║   Tapez 'exithermes' pour revenir        ║"
echo "  ║   à Hermès ou 'exit' pour rester         ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""
EOF

echo "[Fallback] Script pour revenir à Hermès..."
cat > /usr/local/bin/exithermes << 'SCRIPT'
#!/bin/bash
# Quitte le bash et revient à Hermès sur tty1
echo "Retour à Hermès sur TTY1..."
sleep 1
chvt 1
SCRIPT
chmod +x /usr/local/bin/exithermes

echo "[Fallback] Alias dans /root/.bashrc pour方便..."
cat >> /root/.bashrc << 'EOF'

# Aliases utiles
alias ll='ls -la'
alias c='clear'
alias hermes='chvt 1'
alias music='ncmpcpp'
alias wifi='nmtui'
alias ipa='ip addr'
EOF

echo "[Fallback] Terminé !"
EOF
