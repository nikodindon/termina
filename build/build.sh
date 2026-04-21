#!/bin/bash
#===============================================
# Termina Build Orchestrator
#===============================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/output"
CONF_DIR="$PROJECT_ROOT/conf"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[BUILD]${NC} $1"; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Vérifications pré-requis
check_requirements() {
    log "Vérification des pré-requis..."
    
    if [[ $EUID -ne 0 ]]; then
        error "Ce script doit être exécuté en tant que root (sudo)."
    fi
    
    local missing=()
    for cmd in debootstrap chroot tar gzip; do
        if ! command -v $cmd &> /dev/null; then
            missing+=($cmd)
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Commandes manquantes : ${missing[*]}. Installez-les avec apt."
    fi
    
    success "Pré-requis OK"
}

# Création du rootfstar
create_rootfs() {
    local target="$OUTPUT_DIR/termina-rootfs.tar.gz"
    
    if [[ -f "$target" ]]; then
        info "Rootfs déjà présent : $target"
        read -p "Voulez-vous le.regénérer ? [o/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Oo]$ ]]; then
            info "Utilisation du rootfs existant."
            return 0
        fi
        rm -f "$target"
    fi
    
    log "Création du rootfs Debian minimal..."
    mkdir -p "$OUTPUT_DIR"
    
    debootstrap --arch amd64 --variant minbase stable "$OUTPUT_DIR/rootfs" http://deb.debian.org/debian/
    
    log "Compression en tarball..."
    tar -czf "$target" -C "$OUTPUT_DIR/rootfs" .
    rm -rf "$OUTPUT_DIR/rootfs"
    
    success "Rootfs créé : $target"
}

# Exécution d'un script dans le chroot
run_in_chroot() {
    local script="$1"
    local rootfs="$OUTPUT_DIR/rootfs"
    local script_name=$(basename "$script")
    
    log "Exécution de $script_name dans le chroot..."
    
    # Copie le script dans le rootfs
    cp "$script" "$rootfs/tmp/$script_name"
    chmod +x "$rootfs/tmp/$script_name"
    
    # Bind mounts nécessaires
    mount -t proc proc "$rootfs/proc"
    mount -t sysfs sys "$rootfs/sys"
    mount -t devpts devpts "$rootfs/dev/pts" 2>/dev/null || true
    
    # Exécution dans le chroot
    chroot "$rootfs" /tmp/"$script_name"
    local exit_code=$?
    
    # Cleanup
    umount "$rootfs/proc" "$rootfs/sys" "$rootfs/dev/pts" 2>/dev/null || true
    rm -f "$rootfs/tmp/$script_name"
    
    if [[ $exit_code -ne 0 ]]; then
        error "Échec de $script_name (exit code: $exit_code)"
    fi
    
    success "$script_name terminé"
}

# Application des configs
apply_configs() {
    log "Application des fichiers de configuration..."
    
    local rootfs="$OUTPUT_DIR/rootfs"
    local conf_etc="$CONF_DIR/etc"
    
    # passwd
    if [[ -f "$conf_etc/passwd" ]]; then
        cp "$conf_etc/passwd" "$rootfs/etc/passwd"
    fi
    
    # sudoers
    if [[ -f "$conf_etc/sudoers" ]]; then
        cp "$conf_etc/sudoers" "$rootfs/etc/sudoers"
    fi
    
    # systemd services
    if [[ -d "$conf_etc/systemd/system" ]]; then
        cp "$conf_etc/systemd/system/"* "$rootfs/etc/systemd/system/" 2>/dev/null || true
    fi
    
    success "Configs appliquées"
}

# Génération de l'image finale
generate_image() {
    log "Génération de l'image USB..."
    
    local rootfs="$OUTPUT_DIR/termina-rootfs.tar.gz"
    local image="$OUTPUT_DIR/termina.img"
    local size_gb=8
    
    if [[ ! -f "$rootfs" ]]; then
        error "Rootfs non trouvé : $rootfs"
    fi
    
    # Size estimate (rootfs + 30% overhead)
    local rootfs_size=$(stat -c%s "$rootfs")
    local size_bytes=$((rootfs_size * 130 / 100 + 1 * 1024 * 1024 * 1024))
    local size_mb=$((size_bytes / 1024 / 1024))
    
    info "Création d'une image de ${size_mb}MB..."
    
    # Create sparse image
    truncate -s ${size_mb}M "$image"
    
    # Partitionner avec fdisk (EFI + Linux)
    # Setup loopback
    local loop_dev=$(losetup -f --show "$image")
    info "Loopback: $loop_dev"
    
    # Partition table
    cat << EOF | sfdisk "$loop_dev" 
1M,128M,ef
128M,,83
EOF

    losetup -d "$loop_dev"
    loop_dev=$(losetup -f --show "$image")
    
    # Format partitions
    info "Formatage des partitions..."
    mkfs.vfat -F 32 "${loop_dev}p1" -n "BOOT"
    mkfs.ext4 "${loop_dev}p2" -L "TERMINA" -E lazy_itable_init=0,lazy_journal_init=0
    
    # Mount
    local mnt_boot=$(mktemp -d)
    local mnt_root=$(mktemp -d)
    mount "${loop_dev}p1" "$mnt_boot"
    mount "${loop_dev}p2" "$mnt_root"
    
    # Install GRUB
    info "Installation de GRUB..."
    mkdir -p "$mnt_boot/grub"
    tar -xzf "$rootfs" -C "$mnt_root"
    
    grub-install --target=x86_64-efi --boot-directory="$mnt_boot" --efi-directory="$mnt_boot" --removable "$image" 2>/dev/null || \
    grub-install --target=i386-pc --boot-directory="$mnt_boot" "${loop_dev}"
    
    # Unmount
    umount "$mnt_boot" "$mnt_root"
    losetup -d "$loop_dev"
    rmdir "$mnt_boot" "$mnt_root"
    
    success "Image créée : $image"
    info "Pour écrire sur USB: sudo dd if=$image of=/dev/sdX bs=4M status=progress"
}

# Menu interactif
show_menu() {
    echo
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}  Termina Build Menu${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo
    echo "  1. Build complet (tous les scripts)"
    echo "  2. Build rootfs seulement"
    echo "  3. Exécuter script 01-base.sh (base Debian)"
    echo "  4. Exécuter script 02-hermes.sh (Hermès)"
    echo "  5. Exécuter script 03-network.sh (Réseau)"
    echo "  6. Exécuter script 04-console-tools.sh (Outils)"
    echo "  7. Appliquer les configs"
    echo "  8. Générer l'image"
    echo "  0. Quitter"
    echo
}

# Build complet
build_all() {
    log "=== Build complet Termina ==="
    check_requirements
    create_rootfs
    
    run_in_chroot "$SCRIPT_DIR/02-hermes.sh"
    run_in_chroot "$SCRIPT_DIR/03-network.sh"
    run_in_chroot "$SCRIPT_DIR/04-console-tools.sh"
    
    apply_configs
    generate_image
    
    success "=== Build Termina terminé ! ==="
}

# Main
main() {
    mkdir -p "$OUTPUT_DIR"
    
    if [[ $# -eq 0 ]]; then
        show_menu
        read -p "Votre choix: " choice
        case $choice in
            1) build_all ;;
            2) check_requirements; create_rootfs ;;
            3) check_requirements; create_rootfs; run_in_chroot "$SCRIPT_DIR/01-base.sh" ;;
            4) run_in_chroot "$SCRIPT_DIR/02-hermes.sh" ;;
            5) run_in_chroot "$SCRIPT_DIR/03-network.sh" ;;
            6) run_in_chroot "$SCRIPT_DIR/04-console-tools.sh" ;;
            7) apply_configs ;;
            8) generate_image ;;
            0) exit 0 ;;
            *) error "Option invalide" ;;
        esac
    else
        case "$1" in
            full) build_all ;;
            rootfs) check_requirements; create_rootfs ;;
            image) generate_image ;;
            *) error "Usage: $0 [full|rootfs|image]" ;;
        esac
    fi
}

main "$@"
