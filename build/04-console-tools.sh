#!/bin/bash
#===============================================
# Termina — Script 04: Outils console + Musique
#===============================================
set -e

export DEBIAN_FRONTEND=noninteractive

echo "[Tools] Installation des outils console..."

apt update
apt install -y \
    tmux \
    htop \
    vim \
    nano \
    git \
    curl \
    wget \
    rsync \
    ssh \
    scp \
    zip \
    unzip \
    tar \
    gzip \
    bzip2 \
    xz-utils \
    p7zip-full \
    tree \
    jq \
    bc \
    dc \
    screen \
    w3m \
    links \
    lynx \
    irssi \
    weechat-curses \
    mutt \
    neomutt \
    mailutils \
    calcurse \
    newsboat \
    w3m-img

echo "[Tools] Installation des outils réseau..."
apt install -y \
    nmap \
    mtr \
    iproute2 \
    net-tools \
    traceroute \
    dnsutils \
    iputils-ping \
    whois

echo "[Tools] Installation des outils système..."
apt install -y \
    strace \
    lsof \
    ltrace \
    dmidecode \
    pciutils \
    usbutils \
    hdparm \
    smartmontools \
    lm-sensors \
    fancontrol

echo "[Tools] Installation de audio player (mpd + ncmpcpp)..."
apt install -y \
    mpd \
    ncmpcpp \
    mpc \
    alsa-utils \
    sox \
    ffmpeg \
    mpeg123

# Configuration mpd
mkdir -p /etc/hermes/mpd
cat > /etc/hermes/mpd/mpd.conf << 'EOF'
# Configuration mpd pour Termina

music_directory "~/music"
playlist_directory "~/playlists"
db_file "~/data/mpd/mpd.db"
log_file "~/data/mpd/mpd.log"
pid_file "~/data/mpd/mpd.pid"
state_file "~/data/mpd/state"

bind_to_address "127.0.0.1"
port "6600"

audio_output {
    type "alsa"
    name "Default ALSA"
    device "default"
    mixer_type "software"
}

audio_output {
    type "fifo"
    name "Visualiseur"
    path "/tmp/mpd.fifo"
    format "44100:16:2"
}

filesystem_charset "UTF-8"
id3v1_encoding "UTF-8"
EOF

# Configuration ncmpcpp
mkdir -p /etc/hermes/ncmpcpp
cat > /etc/hermes/ncmpcpp/config << 'EOF'
# Configuration ncmpcpp pour Termina

ncmpcpp_directory = ~/data/ncmpcpp
lyrics_directory = ~/lyrics

mpd_host = "127.0.0.1"
mpd_port = "6600"
mpd_connection_timeout = "5"
mpd_music_dir = "~/music"
mpd_crossfade_time = "2"

visualizer_fifo_path = "/tmp/mpd.fifo"
visualizer_in_stereo = "yes"
visualizer_sync_interval = "30"
visualizer_output_name = "Visualizer"

now_playing_prefix = "$b$8»$a "
now_playing_suffix = "$b$8«"
song_list_format = "$4%n $b$1│$9 %a - %t$r$3(%D)$r"
song_status_format = "$b$1%a - %t$r$3(%l)$r"
song_library_format = "{{%n - }%t}|{$f(%a)$r}"
alternative_header_first_line_format = "$b$1%a - %t$r"
alternative_header_second_line_format = "$b$9%l$9"

playlist_display_mode = "columns"
browser_display_mode = "columns"
search_engine_display_mode = "columns"
playlist_editor_display_mode = "columns"

discard_colors_if_item_is_selected = "yes"
show_hidden_files_in_browser = "no"
display_bitrate = "no"
display_volume_level = "yes"
display_remaining_time = "no"

header_visibility = "yes"
statusbar_visibility = "yes"
titles_visibility = "yes"
headphones_visibility = "no"

enable_window_border = "no"
centered_cursor = "yes"

colors_enabled = "yes"
empty_tag_color = "cyan"
header_window_color = "white"
volume_color = "cyan"
state_line_color = "white"
state_flags_color = "cyan"
progressbar_color = "cyan"
progressbar_elapsed_color = "white"
statusbar_color = "cyan"
alternative_ui_color_separator = "cyan"

main_window_color = "green:red"
column_window_color = "cyan"
bright_box_item_color = "white"
selected_item_color = "cyan"
selected_item_attributes = "bold"
now_playing_item_color = "cyan"
now_playing_item_attributes = "bold"
visible_items_in_main_window_color = "white"
visible_items_in_other_windows_color = "cyan"
box_item_color = "cyan"

browser_sort_mode = "type"
sort_by_mtime_in_browser = "yes"
playlist_shorten_total_times = "no"
playlist_separate_albums = "no"
display_urls_instead_of_paths = "no"

execute_on_song_change = ""
execute_on_playlist_change = ""
execute_on_stored_playlist_change = ""

clock_display_seconds = "no"
display SBC bitrate = "no"
歌词目录 = "~/lyrics"
EOF

# Script de démarrage musique
cat > /usr/local/bin/music << 'SCRIPT'
#!/bin/bash
# Lance ncmpcpp pour contrôler la musique
# Usage: music

# Démarre mpd si pas déjà lancé
if ! pgrep -x mpd > /dev/null; then
    echo "[Music] Démarrage de mpd..."
    mkdir -p ~/music ~/playlists ~/data/mpd ~/data/ncmpcpp ~/lyrics
    mpd /etc/hermes/mpd/mpd.conf
fi

# Lance ncmpcpp
exec ncmpcpp
SCRIPT
chmod +x /usr/local/bin/music

echo "[Tools] Installation des outils dev..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    git \
    build-essential \
    make \
    gcc \
    pkg-config \
    libffi-dev \
    libssl-dev

echo "[Tools] Installation de tools supplémentaires..."
apt install -y \
    man-db \
    man-pages \
    info \
    diffutils

echo "[Tools] Alias utiles pour bash fallback..."
cat > /etc/hermes/bash_aliases << 'EOF'
# Aliases pour le bash fallback
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias cls='clear'
alias c='clear'
alias h='history'
alias j='jobs'
alias、音乐='ncmpcpp play'
alias mus='ncmpcpp'
alias wifi='nmtui'
alias ipa='ip addr'
alias psg='ps aux | grep'
alias untar='tar -xvf'
EOF

cat >> /etc/skel/.bashrc << 'EOF'

# Aliases Termina
alias ll='ls -la'
alias la='ls -A'
alias cls='clear'
alias c='clear'
alias h='history'
alias music='ncmpcpp'
alias wifi='nmtui'
alias ipa='ip addr'
alias psg='ps aux | grep'
EOF

echo "[Tools] Terminé !"
