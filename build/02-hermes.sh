#!/bin/bash
#===============================================
# Termina — Script 02: Installation Hermès
#===============================================
set -e

export DEBIAN_FRONTEND=noninteractive

echo "[Hermes] Mise à jour des paquets..."
apt update
apt upgrade -y

echo "[Hermes] Installation des dépendances Python..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    git \
    curl \
    build-essential \
    libffi-dev \
    libssl-dev

echo "[Hermes] Création de l'environnement virtuel..."
mkdir -p /opt/hermes
python3 -m venv /opt/hermes/venv
/opt/hermes/venv/bin/pip install --upgrade pip

echo "[Hermes] Installation d'Hermès CLI..."
# Installation depuis le repo local ou GitHub
if [[ -d "/tmp/hermes-cli" ]]; then
    cd /tmp/hermes-cli
    /opt/hermes/venv/bin/pip install -e .
else
    # Installation depuis PyPI (si disponible) ou GitHub
    /opt/hermes/venv/bin/pip install hermes-cli || \
    /opt/hermes/venv/bin/pip install git+https://github.com/nikodindon/hermes-lite.git
fi

echo "[Hermes] Configuration du shell Hermès..."
# Symbole du shell Hermès
echo 'export HERMES_SHELL=1' >> /etc/environment

# Script de démarrage Hermès
cat > /usr/local/bin/hermes-shell << 'SHELL'
#!/bin/bash
# Démarrage d'Hermès comme shell interactif

# Export pour que Hermès sache qu'il tourne comme shell
export HERMES_SHELL=1
export TERM=xterm-256color

# Démarrage de tmux (session persistante)
if [[ -z "$TMUX" ]]; then
    # Première connexion — crée ou rattache une session tmux
    exec tmux new-session -A -s hermes /opt/hermes/venv/bin/hermes run
else
    # Déjà dans tmux — lance Hermès directement
    exec /opt/hermes/venv/bin/hermes run
fi
SHELL
chmod +x /usr/local/bin/hermes-shell

echo "[Hermes] Installation de tmux..."
apt install -y tmux

echo "[Hermes] Configuration tmux..."
cat > /etc/hermes/tmux.conf << 'EOF'
# tmux config pour Termina
set -g default-terminal "xterm-256color"
set -g history-limit 50000
set -g mouse off
set -g base-index 1
set -g pane-base-index 1

# Barres de statut
set -g status-bg black
set -g status-fg white
set -g status-left "#[fg=cyan]Hermes#[fg=white] | "
set -g status-right "#[fg=cyan]%H:%M"

# Mode vi
set -g mode-keys vi
bind-key -T copy-mode-vi v send-keys -X begin-selection
bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
EOF

echo "[Hermes] Service systemd pour Hermès daemon..."
cat > /etc/systemd/system/terminad.service << 'EOF'
[Unit]
Description=Termina Hermès Daemon
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/opt/hermes/venv/bin/hermes run --daemon
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "[Hermes] Terminé !"
