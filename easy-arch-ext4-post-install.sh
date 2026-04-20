#!/usr/bin/env bash
# =============================================================================
#  post-install.sh — wretchedghost's Arch Linux post-install setup
#  Run this as your normal user (with sudo access) AFTER easy-arch-ext4.sh
# =============================================================================
set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
die()     { echo -e "${RED}${BOLD}[ERROR]${RESET} $*" >&2; exit 1; }

# ── Sanity checks ─────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] && die "Do NOT run as root. Run as your regular user."
command -v pacman &>/dev/null || die "pacman not found — is this Arch Linux?"

DOTFILES_REPO="https://github.com/wretchedghost/dotfiles"
USERNAME="$(whoami)"

# =============================================================================
#  SECTION 1 — System update
# =============================================================================
section_update() {
    info "Updating system..."
    sudo pacman -Syu --noconfirm
    success "System up to date."
}

# =============================================================================
#  SECTION 2 — Install yay (AUR helper)
# =============================================================================
section_yay() {
    if command -v yay &>/dev/null; then
        success "yay already installed — skipping."
        return
    fi
    info "Installing yay..."
    sudo pacman -S --needed --noconfirm git base-devel
    local tmpdir
    tmpdir=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    (cd "$tmpdir/yay" && makepkg -si --noconfirm)
    rm -rf "$tmpdir"
    success "yay installed."
}

# =============================================================================
#  SECTION 3 — Pacman packages
# =============================================================================
PACMAN_PKGS=(
    # --- i3 core ---
    i3-wm
    i3blocks
    i3lock
    i3status

    # --- Display / compositor ---
    xorg-server
    xorg-xinit
    xorg-xrandr
    xorg-xset
    xorg-xrdb
    xf86-input-libinput
    picom
    feh
    redshift
    lightdm
    lightdm-slick-greeter

    # --- Terminal & shell ---
    rxvt-unicode
    urxvt-perls
    tmux
    bash-completion

    # --- Editors ---
    vim

    # --- Launcher / notifications ---
    rofi
    dunst

    # --- Fonts ---
    ttf-font-awesome
    ttf-dejavu
    noto-fonts
    noto-fonts-emoji

    # --- File managers ---
    thunar
    pcmanfm

    # --- Browser ---
    firefox

    # --- Media / screenshots ---
    scrot
    vlc
    feh

    # --- System info / eye candy ---
    neofetch
    conky

    # --- Networking ---
    networkmanager
    network-manager-applet
    networkmanager-openvpn
    tailscale

    # --- Office ---
    libreoffice-fresh

    # --- Calculator / calendar ---
    galculator
    gsimplecal

    # --- Volume ---
    volumeicon
    alsa-utils
    pulseaudio
    pulseaudio-alsa
    pavucontrol

    # --- Misc utilities ---
    perl-json
    git
    wget
    curl
    unzip
    zip
    htop
    lxappearance
    python
    python-pip
)

section_pacman() {
    info "Installing pacman packages..."
    sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
    success "Pacman packages installed."
}

# =============================================================================
#  SECTION 4 — AUR packages
# =============================================================================
AUR_PKGS=(
    vimix-icon-theme
    vimix-gtk-themes
    vimix-cursors
    i3-resurrect
    ttf-monoid
)

section_aur() {
    info "Installing AUR packages..."
    yay -S --needed --noconfirm "${AUR_PKGS[@]}"
    success "AUR packages installed."
}

# =============================================================================
#  SECTION 5 — Touchpad configuration (libinput)
# =============================================================================
TOUCHPAD_CONF="/etc/X11/xorg.conf.d/90-touchpad.conf"

section_touchpad() {
    info "Configuring touchpad (libinput)..."
    sudo mkdir -p /etc/X11/xorg.conf.d

    sudo tee "$TOUCHPAD_CONF" > /dev/null <<'EOF'
Section "InputClass"
        Identifier      "touchpad"
        MatchIsTouchpad "on"
        Driver          "libinput"
        Option "Tapping"           "on"
        Option "NaturalScrolling"  "true"
        Option "TappingButtonMap"  "lrm"
        Option "DisableWhileTyping" "on"
        Option "ClickMethod"       "clickfinger"
        Option "ScrollMethod"      "twofinger"
        Option "AccelProfile"      "adaptive"
EndSection
EOF

    success "Touchpad config written to $TOUCHPAD_CONF"
    info "Options enabled: tap-to-click, natural scroll, lrm 3-finger map,"
    info "  disable-while-typing, clickfinger, two-finger scroll, adaptive accel."
}

# =============================================================================
#  SECTION 6 — Laptop lid → i3lock suspend service
# =============================================================================
SUSPEND_SERVICE="/etc/systemd/system/suspend@${USERNAME}.service"

section_lid_lock() {
    info "Setting up lid-close i3lock suspend service..."
    sudo tee "$SUSPEND_SERVICE" > /dev/null <<EOF
[Unit]
Description=User suspend actions — i3lock on lid close
Before=sleep.target

[Service]
User=${USERNAME}
Type=forking
Environment=DISPLAY=:0
ExecStartPre=/usr/bin/sleep 1
ExecStart=/home/${USERNAME}/.config/i3/scripts/lock_and_blur.sh

[Install]
WantedBy=sleep.target
EOF

    sudo systemctl enable "suspend@${USERNAME}.service"
    success "suspend@${USERNAME}.service enabled."
    warn "Make sure ~/.config/i3/scripts/lock_and_blur.sh exists and is chmod +x."
}

# =============================================================================
#  SECTION 7 — Enable key systemd services
# =============================================================================
section_services() {
    info "Enabling systemd services..."

    local services=(
        NetworkManager
        lightdm
        tailscaled
    )

    for svc in "${services[@]}"; do
        if systemctl list-unit-files --type=service | grep -q "^${svc}.service"; then
            sudo systemctl enable "$svc"
            success "Enabled: $svc"
        else
            warn "Service not found, skipping: $svc"
        fi
    done
}

# =============================================================================
#  SECTION 8 — Clone dotfiles and symlink
# =============================================================================
section_dotfiles() {
    info "Cloning dotfiles from $DOTFILES_REPO ..."
    local dotdir="$HOME/.dotfiles"

    if [[ -d "$dotdir" ]]; then
        warn "~/.dotfiles already exists — pulling latest instead."
        git -C "$dotdir" pull
    else
        git clone "$DOTFILES_REPO" "$dotdir"
    fi

    info "Symlinking dotfiles..."

    # Map: source (relative to $dotdir) -> destination
    declare -A LINKS=(
        [".bashrc"]="$HOME/.bashrc"
        [".vimrc"]="$HOME/.vimrc"
        [".Xresources"]="$HOME/.Xresources"
        [".xinitrc"]="$HOME/.xinitrc"
        [".tmux.conf"]="$HOME/.tmux.conf"
        [".fehbg"]="$HOME/.fehbg"
        [".screenlayout"]="$HOME/.screenlayout"
        [".vim"]="$HOME/.vim"
        [".config"]="$HOME/.config"
    )

    for src in "${!LINKS[@]}"; do
        local dst="${LINKS[$src]}"
        local full_src="$dotdir/$src"

        if [[ ! -e "$full_src" ]]; then
            warn "Source not found, skipping: $full_src"
            continue
        fi

        # Back up existing file/dir if it's not already a symlink to our dotfiles
        if [[ -e "$dst" && ! -L "$dst" ]]; then
            warn "Backing up existing $dst → ${dst}.bak"
            mv "$dst" "${dst}.bak"
        fi

        ln -sfn "$full_src" "$dst"
        success "Linked: $dst → $full_src"
    done

    # Reload Xresources if possible
    if command -v xrdb &>/dev/null && [[ -f "$HOME/.Xresources" ]]; then
        xrdb -merge "$HOME/.Xresources" 2>/dev/null || true
    fi

    # Copy lightdm config
    if [[ -d "$dotdir/lightdm" ]]; then
        info "Copying lightdm config..."
        sudo rm -rf /etc/lightdm
        sudo cp -R "$dotdir/lightdm" /etc/lightdm
        success "lightdm config installed."
    fi

    # Copy wallpaper
    if [[ -f "$dotdir/background.jpg" ]]; then
        sudo cp "$dotdir/background.jpg" /usr/share/pixmaps/background.jpg
        success "Wallpaper copied to /usr/share/pixmaps/background.jpg"
    fi

    # Libreoffice desktop entry
    if [[ -f "$dotdir/libreoffice-writer.desktop" ]]; then
        mkdir -p "$HOME/.local/share/applications"
        cp "$dotdir/libreoffice-writer.desktop" "$HOME/.local/share/applications/"
        success "LibreOffice Writer desktop entry installed."
    fi

    # i3-resurrect (pip fallback if AUR failed)
    if ! command -v i3-resurrect &>/dev/null; then
        info "Installing i3-resurrect via pip..."
        pip install i3-resurrect --break-system-packages
    fi

    success "Dotfiles setup complete."
}

# =============================================================================
#  SECTION 9 — User systemd timers/services from dotfiles
# =============================================================================
section_user_services() {
    info "Enabling user systemd units..."

    local user_systemd="$HOME/.config/systemd/user"

    if systemctl --user list-unit-files 2>/dev/null | grep -q "wallpaper.timer"; then
        systemctl --user enable --now wallpaper.timer
        success "wallpaper.timer enabled."
    else
        warn "wallpaper.timer not found in $user_systemd — skipping."
    fi

    if systemctl --user list-unit-files 2>/dev/null | grep -q "i3-workspace-save.service"; then
        systemctl --user enable i3-workspace-save.service
        success "i3-workspace-save.service enabled."
    else
        warn "i3-workspace-save.service not found — skipping."
    fi
}

# =============================================================================
#  SECTION 10 — Neofetch Xsession chmod fix
# =============================================================================
section_xsession_fix() {
    if [[ -f /etc/lightdm/Xsession ]]; then
        sudo chmod +x /etc/lightdm/Xsession
        success "chmod +x /etc/lightdm/Xsession"
    fi
}

# =============================================================================
#  MAIN — interactive menu
# =============================================================================
print_banner() {
    echo -e "${CYAN}${BOLD}"
    cat <<'BANNER'
  ____           _     ___           _        _ _
 |  _ \ ___  __| |_  |_ _|_ __  ___| |_ __ _| | |
 | |_) / _ \/ _` | |  | || '_ \/ __| __/ _` | | |
 |  __/ (_) \__,_|_|  | || | | \__ \ || (_| | | |
 |_|   \___/\____|_| |___|_| |_|___/\__\__,_|_|_|
  wretchedghost — Arch i3 post-install setup
BANNER
    echo -e "${RESET}"
}

run_all() {
    section_update
    section_yay
    section_pacman
    section_aur
    section_touchpad
    section_lid_lock
    section_services
    section_dotfiles
    section_user_services
    section_xsession_fix

    echo ""
    success "════════════════════════════════════════"
    success " All done! Reboot to start LightDM/i3."
    success "════════════════════════════════════════"
    echo ""
    warn "Post-reboot reminders:"
    echo "  1. Update weather city in ~/.config/i3/i3blocks/i3blocks → [rofi-wttr] → Location"
    echo "  2. Confirm ~/.config/i3/scripts/lock_and_blur.sh is executable"
    echo "  3. Enable wallpaper rotation: systemctl --user enable --now wallpaper.timer"
    echo "  4. Add noatime to SSD partitions in /etc/fstab if on an SSD"
    echo ""
}

print_banner

echo -e "${BOLD}Select an option:${RESET}"
echo "  1) Run everything (recommended for fresh install)"
echo "  2) System update only"
echo "  3) Install yay only"
echo "  4) Install pacman packages only"
echo "  5) Install AUR packages only"
echo "  6) Configure touchpad only"
echo "  7) Setup lid-lock service only"
echo "  8) Enable systemd services only"
echo "  9) Clone & symlink dotfiles only"
echo "  0) Exit"
echo ""
read -rp "Choice [0-9]: " CHOICE

case "$CHOICE" in
    1) run_all ;;
    2) section_update ;;
    3) section_yay ;;
    4) section_pacman ;;
    5) section_aur ;;
    6) section_touchpad ;;
    7) section_lid_lock ;;
    8) section_services ;;
    9) section_dotfiles ;;
    0) echo "Bye."; exit 0 ;;
    *) die "Invalid choice." ;;
esac
