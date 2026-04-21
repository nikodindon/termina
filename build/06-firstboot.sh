#!/bin/bash
#===============================================
# Termina — Script 06: Wizard Premier Boot
#===============================================
set -e

# Ce script est appelé par firstboot.service au premier démarrage
# Il vérifie si c'est le premier boot et lance le wizard

FIRSTBOOT_FLAG="/etc/hermes/.firstboot_done"
LOG_FILE="/var/log/firstboot.log"

log() {
    echo "[$(date)] $1" >> "$LOG_FILE"
    echo "$1"
}

# Vérifie si premier boot
if [[ -f "$FIRSTBOOT_FLAG" ]]; then
    log "Premier boot déjà effectué. Sortie."
    exit 0
fi

log "=== Premier boot — Wizard Termina ==="

# Démarre NetworkManager si pas déjà fait
systemctl start NetworkManager 2>/dev/null || true
sleep 2

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║         Termina — Configuration               ║"
echo "║         Première installation                 ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# 1. Configuration réseau
echo "[1/4] Configuration du réseau"
echo "----------------------------------------"
echo "Cartes réseau détectées :"
ip -br link show | grep -v "lo" || echo "  Aucune interface détectée"
echo ""

read -p "Voulez-vous configurer le WiFi maintenant ? [o/N] : " configure_wifi

if [[ "$configure_wifi" =~ ^[Oo]$ ]]; then
    echo ""
    echo "Démarrage de nmtui pour configurer le WiFi..."
    echo "Dans le menu :"
    echo "  1. Sélectionner 'Activer une connexion'"
    echo "  2. Choisir votre réseau WiFi"
    echo "  3. Entrer votre passphrase"
    echo "  4. Quitter avec Echap"
    echo ""
    sleep 2
    nmtui || true
fi

# Test de connexion
echo ""
echo "Test de connexion..."
if ping -c 1 8.8.8.8 &>/dev/null; then
    echo "  ✓ Connexion internet OK"
else
    echo "  ⚠ Pas de connexion internet. Vérifiez votre câble ou WiFi."
fi

# 2. Création de l'utilisateur
echo ""
echo "[2/4] Configuration de l'utilisateur"
echo "----------------------------------------"
read -p "Nom d'utilisateur [terminas] : " username
username=${username:-termina}

# Vérifie que l'utilisateur n'existe pas
if id "$username" &>/dev/null; then
    echo "  L'utilisateur $username existe déjà."
else
    echo "Création de l'utilisateur $username..."
    useradd -m -s /bin/bash -G sudo,audio,video,bluetooth,netdev "$username"
    echo "  Utilisateur créé."
fi

# 3. Configuration du hostname
echo ""
echo "[3/4] Nom de la machine"
echo "----------------------------------------"
read -p "Hostname [termina] : " hostname
hostname=${hostname:-termina}
echo "$hostname" > /etc/hostname
sed -i "s/127.0.1.1.*/127.0.1.1       $hostname/" /etc/hosts
echo "  Hostname configuré : $hostname"

# 4. Fuseau horaire
echo ""
echo "[4/4] Fuseau horaire"
echo "----------------------------------------"
read -p "Fuseau horaire [Europe/Paris] : " timezone
timezone=${timezone:-Europe/Paris}
ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime 2>/dev/null || true
dpkg-reconfigure -f noninteractive tzdata 2>/dev/null || true
echo "  Fuseau horaire : $timezone"

# Message de fin
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║         Configuration terminée !             ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo " Resume :"
echo "    - Utilisateur : $username"
echo "    - Machine     : $hostname"
echo "    - Réseau      : WiFi configuré"
echo ""
echo "  Prochaines étapes :"
echo "    - Tapez 'hermes' pour démarrer Hermès"
echo "    - Tapez ':music' dans Hermès pour la musique"
echo "    - Tapez 'sudo nmtui' pour gérer le WiFi"
echo ""
echo "  La machine va redémarrer dans 10 secondes..."
echo "  Ctrl+C pour annuler le redémarrage."
echo ""

# Marque le premier boot comme fait
touch "$FIRSTBOOT_FLAG"
log "Premier boot terminé avec succès."

# Countdown et reboot
countdown=10
while [[ $countdown -gt 0 ]]; do
    echo -ne "\r  Redémarrage dans $countdown s... (Ctrl+C pour annuler) "
    sleep 1
    ((countdown--))
done
echo ""
log "Redémarrage..."
reboot
