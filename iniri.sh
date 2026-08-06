#!/bin/bash
#==============================================================================
# Arch Linux Niri Gaming Setup v3.0
#==============================================================================

set -o pipefail

#==============================================================================
# CONFIGURATION
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$HOME/niri-setup-$(date +%Y%m%d-%H%M%S).log"
ERROR_LOG="$HOME/niri-setup-errors-$(date +%Y%m%d-%H%M%S).log"
SUCCESS=0
FAILS=0
FAILED_ITEMS=()

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

#==============================================================================
# FUNCTIONS
#==============================================================================

header() {
    echo -e "\n${BLUE}═══ ${CYAN}$1 ${BLUE}═══${NC}\n"
}

step() {
    echo -ne "${YELLOW}[$1/$TOTAL_STEPS]${NC} ${CYAN}$2${NC}... "
}

ok() {
    echo -e "${GREEN}✓${NC}"
    ((SUCCESS++))
}

fail() {
    echo -e "${RED}✗${NC}"
    ((FAILS++))
    FAILED_ITEMS+=("$1")
    echo "[ERROR] $1" >> "$ERROR_LOG"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

install_pkg() {
    local pkg="$1"
    if pacman -Q "$pkg" &>/dev/null; then
        return 0
    else
        sudo pacman -S --noconfirm --needed "$pkg" >> "$LOG_FILE" 2>&1
        return $?
    fi
}

install_aur() {
    local pkg="$1"
    if pacman -Q "$pkg" &>/dev/null; then
        return 0
    else
        yay -S --noconfirm --needed "$pkg" >> "$LOG_FILE" 2>&1
        return $?
    fi
}

#==============================================================================
# START
#==============================================================================

clear
echo -e "${GREEN}"
echo "╔══════════════════════════════════════╗"
echo "║  Arch Linux Niri Gaming Setup v3.0  ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

# Root check
[ "$EUID" -eq 0 ] && echo -e "${RED}Run as normal user${NC}" && exit 1

# Log files
echo "Installation started: $(date)" > "$LOG_FILE"
echo "Error log: $(date)" > "$ERROR_LOG"

#==============================================================================
# 1. YAY
#==============================================================================
TOTAL_STEPS=12
CURRENT=1

header "AUR HELPER"

step "$CURRENT" "Installing yay"
if command -v yay &>/dev/null; then
    ok
else
    sudo pacman -S --noconfirm --needed base-devel git >> "$LOG_FILE" 2>&1
    rm -rf /tmp/yay 2>/dev/null
    git clone https://aur.archlinux.org/yay.git /tmp/yay >> "$LOG_FILE" 2>&1
    cd /tmp/yay && makepkg -si --noconfirm >> "$LOG_FILE" 2>&1 && cd ~
    command -v yay &>/dev/null && ok || fail "yay installation"
fi

#==============================================================================
# 2. MULTILIB
#==============================================================================
((CURRENT++))

step "$CURRENT" "Enabling multilib"
if grep -q "^#\[multilib\]" /etc/pacman.conf; then
    sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
    sudo pacman -Syu --noconfirm >> "$LOG_FILE" 2>&1 && ok || fail "multilib"
else
    ok
fi

#==============================================================================
# 3. PACKAGES
#==============================================================================
((CURRENT++))

header "INSTALLING PACKAGES"

step "$CURRENT" "Core packages"
PACKAGES=(
    # Wayland/compositor
    niri waybar swaybg swaylock
    # Terminal/launcher
    kitty fuzzel
    # File manager
    nemo nemo-fileroller
    # Audio/video
    playerctl
    # Power
    power-profiles-daemon
    # Portals
    xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
    # Screenshots
    grim slurp wl-clipboard
    # Fonts
    noto-fonts noto-fonts-emoji ttf-jetbrains-mono
    # Wayland QT
    qt5-wayland qt6-wayland
    # Tools
    fastfetch git curl wget imagemagick jq
    # Theming
    gtk3 gtk4 gtk-engine-murrine gnome-themes-extra
    qt5ct qt6ct kvantum kvantum-qt5 papirus-icon-theme
    # Dev
    neovim
)

for pkg in "${PACKAGES[@]}"; do
    install_pkg "$pkg"
done
ok

#==============================================================================
# 4. GPU + GAMING
#==============================================================================
((CURRENT++))

step "$CURRENT" "AMD drivers + Gaming"
PACKAGES=(
    # AMD GPU
    mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon
    vulkan-icd-loader lib32-vulkan-icd-loader amd-ucode
    libva-mesa-driver lib32-libva-mesa-driver
    # Gaming
    steam mangohud lib32-mangohud gamemode lib32-gamemode gamescope
    lutris wine-staging winetricks
    # Steam dependencies
    giflib lib32-giflib libpng lib32-libpng
    libldap lib32-libldap gnutls lib32-gnutls
    mpg123 lib32-mpg123 openal lib32-openal
    v4l-utils lib32-v4l-utils libpulse lib32-libpulse
    alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib
    libjpeg-turbo lib32-libjpeg-turbo
    libxcomposite lib32-libxcomposite
    libxinerama lib32-libxinerama
    ncurses lib32-ncurses
    opencl-icd-loader lib32-opencl-icd-loader
    libxslt lib32-libxslt gperftools
    lib32-systemd lib32-libgcrypt
)

for pkg in "${PACKAGES[@]}"; do
    install_pkg "$pkg"
done
ok

#==============================================================================
# 5. AUR PACKAGES
#==============================================================================
((CURRENT++))

step "$CURRENT" "AUR packages"
AUR_PKGS=(librewolf-bin bibata-cursor-theme)
OFFICIAL_PKGS=(matugen obs-studio v4l2loopback-dkms)

for pkg in "${AUR_PKGS[@]}"; do
    install_aur "$pkg"
done

for pkg in "${OFFICIAL_PKGS[@]}"; do
    install_pkg "$pkg"
done
ok

#==============================================================================
# 6. CONFIGURATIONS
#==============================================================================
((CURRENT++))

header "CONFIGURING SYSTEM"

step "$CURRENT" "Configuration files"
mkdir -p ~/.config/{niri/scripts,waybar,kitty,nvim,matugen,qt5ct,qt6ct,Kvantum,gtk-3.0,gtk-4.0,fastfetch,environment.d,wallpaper}
mkdir -p ~/Pictures/{Wallpapers,Screenshots}
mkdir -p ~/.local/share/applications
ok

#==============================================================================
# 7. CURSOR + GTK
#==============================================================================
((CURRENT++))

step "$CURRENT" "Cursor and GTK theme"
sudo mkdir -p /usr/share/icons/default/
echo "[Icon Theme]
Inherits=Bibata-Modern-Classic" | sudo tee /usr/share/icons/default/index.theme > /dev/null

cat > ~/.config/gtk-3.0/settings.ini << EOF
[Settings]
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 10
gtk-application-prefer-dark-theme=true
EOF
ok

#==============================================================================
# 8. WALLPAPERS
#==============================================================================
((CURRENT++))

step "$CURRENT" "Wallpapers"
if [ -d "$SCRIPT_DIR/Wallpapers" ] && [ -n "$(ls -A "$SCRIPT_DIR/Wallpapers" 2>/dev/null)" ]; then
    cp -r "$SCRIPT_DIR/Wallpapers"/* ~/Pictures/Wallpapers/ 2>/dev/null
else
    for color in "#1a1b26" "#2d1b69" "#1b4332" "#312244"; do
        convert -size 1920x1080 xc:"$color" ~/Pictures/Wallpapers/wp_${color//\#/}.jpg 2>/dev/null
    done
    convert -size 1920x1080 gradient:'#1a1b26'-'#2d1b69' ~/Pictures/Wallpapers/purple.jpg 2>/dev/null
fi

# Set initial wallpaper
FIRST_WP=$(ls ~/Pictures/Wallpapers/*.jpg 2>/dev/null | head -1)
[ -n "$FIRST_WP" ] && cp "$FIRST_WP" ~/.config/wallpaper/current.jpg
ok

#==============================================================================
# 9. MATUGEN + SCRIPTS
#==============================================================================
((CURRENT++))

step "$CURRENT" "Matugen theming"

# Config
cat > ~/.config/matugen/config.toml << EOF
[general]
color_space = "lab"
saturate = 1.0
brightness = 1.0
[contrast]
dark = 0.0
light = 0.0
[colors]
primary = "blue"
EOF

# Reload script
cat > ~/.config/matugen/reload-all.sh << 'SCRIPT'
#!/bin/bash
WP="$HOME/.config/wallpaper/current.jpg"
[ ! -f "$WP" ] && exit 0

matugen image "$WP" --format kitty > ~/.config/kitty/colors.conf
matugen image "$WP" --format env > ~/.config/matugen/colors.sh
matugen image "$WP" --format nvim > ~/.config/nvim/colors.vim
matugen image "$WP" --format css > ~/.config/waybar/colors.css

source ~/.config/matugen/colors.sh 2>/dev/null
cat > ~/.config/gtk-3.0/gtk.css << EOFG
@define-color theme_bg_color ${surface:-#1a1b26};
@define-color theme_fg_color ${on_surface:-#c0caf5};
@define-color theme_selected_bg_color ${primary:-#7aa2f7};
window { background-color: @theme_bg_color; color: @theme_fg_color; }
button { background-color: @theme_selected_bg_color; border-radius: 4px; padding: 4px 12px; }
EOFG
cp ~/.config/gtk-3.0/gtk.css ~/.config/gtk-4.0/gtk.css 2>/dev/null

mkdir -p ~/.config/Kvantum/Matugen
cat > ~/.config/Kvantum/Matugen/Matugen.kvconfig << EOFK
[General]
author=Matugen
opacity=100
[%General]
base_color=${surface:-#1a1b26}
bg_color=${surface:-#1a1b26}
fg_color=${on_surface:-#c0caf5}
link_color=${primary:-#7aa2f7}
EOFK

pkill -USR1 kitty 2>/dev/null
pkill -USR2 waybar 2>/dev/null
exit 0
SCRIPT
chmod +x ~/.config/matugen/reload-all.sh

# Wallpaper changer
cat > ~/.config/niri/scripts/change-wallpaper.sh << 'SCRIPT'
#!/bin/bash
DIR="$HOME/Pictures/Wallpapers"
WPS=($(find "$DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" \)))
[ ${#WPS[@]} -eq 0 ] && exit 0
RWP="${WPS[RANDOM % ${#WPS[@]}]}"
cp "$RWP" ~/.config/wallpaper/current.jpg
pkill swaybg 2>/dev/null
swaybg -i "$RWP" -m fill &
~/.config/matugen/reload-all.sh &
exit 0
SCRIPT
chmod +x ~/.config/niri/scripts/change-wallpaper.sh

# Qt configs
cat > ~/.config/qt5ct/qt5ct.conf << EOF
[Appearance]
icon_theme=Papirus-Dark
standard_dialogs=gtk3
style=kvantum
EOF
cp ~/.config/qt5ct/qt5ct.conf ~/.config/qt6ct/qt6ct.conf

# Generate initial colors
~/.config/matugen/reload-all.sh >> "$LOG_FILE" 2>&1 &
ok

#==============================================================================
# 10. KITTY + NEOVIM
#==============================================================================
((CURRENT++))

step "$CURRENT" "Kitty and Neovim"

# Kitty
cat > ~/.config/kitty/kitty.conf << 'EOF'
include colors.conf
font_family JetBrains Mono
font_size 11.0
window_padding_width 10
hide_window_decorations yes
cursor_shape beam
shell zsh
scrollback_lines 10000
detect_urls yes
map ctrl+c copy_to_clipboard
map ctrl+v paste_from_clipboard
map ctrl+shift+n new_os_window
EOF

# Neovim
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim 2>/dev/null

cat > ~/.config/nvim/init.vim << 'EOF'
if filereadable(expand('~/.config/nvim/colors.vim'))
    source ~/.config/nvim/colors.vim
endif
call plug#begin('~/.local/share/nvim/plugged')
Plug 'nvim-lualine/lualine.nvim'
Plug 'preservim/nerdtree'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'neoclide/coc.nvim', {'branch': 'release'}
call plug#end()
set number relativenumber
set mouse=a
set clipboard=unnamedplus
set termguicolors
set tabstop=4 shiftwidth=4 expandtab
let mapleader = " "
nnoremap <leader>n :NERDTreeToggle<CR>
lua << LUA
require'nvim-treesitter.configs'.setup { highlight = { enable = true } }
require('lualine').setup { options = { theme = 'auto' } }
LUA
EOF
ok

#==============================================================================
# 11. NIRI + WAYBAR
#==============================================================================
((CURRENT++))

step "$CURRENT" "Niri and Waybar"

[ -f ~/.config/niri/config.kdl ] && cp ~/.config/niri/config.kdl ~/.config/niri/config.kdl.backup

# Niri
cat > ~/.config/niri/config.kdl << 'EOF'
spawn-at-startup "sh" "-c" "systemctl --user import-environment && systemctl --user restart pipewire.service pipewire-pulse.service wireplumber.service 2>/dev/null || true"
spawn-at-startup "xwayland-satellite"
spawn-at-startup "waybar"
spawn-at-startup "power-profiles-daemon"
spawn-at-startup "sh" "-c" "[ -f ~/.config/wallpaper/current.jpg ] && swaybg -i ~/.config/wallpaper/current.jpg -m fill &"

hotkey-overlay { skip-at-startup }

input {
    focus-follows-mouse
    keyboard { xkb { layout "us,br" } }
    mouse { accel-profile "flat"; accel-speed 0.0 }
    trackpoint { accel-profile "flat" }
}

output "DP-3" { mode "1920x1080@319.976"; scale 1; position x=0 y=0 }
output "HDMI-A-1" { mode "1920x1080@60.000"; scale 1; position x=1920 y=0 }

layout {
    gaps 10
    center-focused-column "never"
    preset-column-widths { proportion 0.33333; proportion 0.5; proportion 0.66667 }
    default-column-width { proportion 0.5 }
    focus-ring { width 4 }
    border { width 2 }
    shadow { softness 30; spread 5; offset x=0 y=5; color "#0007" }
    tab-indicator {}
    insert-hint {}
    struts {}
}

recent-windows { highlight {} }
include "colors.kdl"
screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"
animations {}
prefer-no-csd

window-rule { match app-id=r#"firefox$"# title="^Picture-in-Picture$"; open-floating true }
window-rule { match app-id=r#"^gamescope$"#; open-fullscreen true; open-floating false }
window-rule { match app-id=r#"^cs2$"#; open-fullscreen true }
window-rule { match title=r#"^Counter-Strike 2$"#; open-fullscreen true }
window-rule { match app-id=r#"^steam$"#; open-floating true }

binds {
    Print { screenshot; }
    Ctrl+Print { screenshot-screen; }
    Alt+Print { screenshot-window; }
    Mod+F1 { switch-layout "next"; }
    Mod+Shift+Slash { show-hotkey-overlay; }
    
    Mod+RETURN hotkey-overlay-title="Terminal" { spawn "kitty"; }
    Mod+SPACE hotkey-overlay-title="Apps" { spawn "fuzzel"; }
    Mod+F9 hotkey-overlay-title="Files" { spawn "nemo"; }
    Mod+F10 hotkey-overlay-title="Browser" { spawn "librewolf"; }
    Mod+F11 hotkey-overlay-title="Steam" { spawn "steam-performance"; }
    
    Super+Alt+L { spawn "swaylock"; }
    Ctrl+Alt+Delete { quit skip-confirmation=true; }
    
    XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }
    XF86AudioMute allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
    XF86AudioPlay allow-when-locked=true { spawn-sh "playerctl play-pause"; }
    XF86AudioNext allow-when-locked=true { spawn-sh "playerctl next"; }
    XF86AudioPrev allow-when-locked=true { spawn-sh "playerctl previous"; }
    
    Mod+W { spawn-sh "pkill -USR1 waybar"; }
    Mod+P { spawn-sh "~/.config/niri/scripts/change-wallpaper.sh"; }
    Mod+Shift+P { spawn-sh "~/.config/matugen/reload-all.sh"; }
    
    Mod+O repeat=false { toggle-overview; }
    Mod+K repeat=false { close-window; }
    Mod+F { maximize-column; }
    Mod+Shift+F { fullscreen-window; }
    
    Mod+Left { focus-column-left; }
    Mod+Down { focus-window-down; }
    Mod+Up { focus-window-up; }
    Mod+Right { focus-column-right; }
    Mod+Ctrl+Left { move-column-left; }
    Mod+Ctrl+Down { move-window-down; }
    Mod+Ctrl+Up { move-window-up; }
    Mod+Ctrl+Right { move-column-right; }
    Mod+Home { focus-column-first; }
    Mod+End { focus-column-last; }
    
    Mod+Shift+Left { focus-monitor-left; }
    Mod+Shift+Down { focus-monitor-down; }
    Mod+Shift+Up { focus-monitor-up; }
    Mod+Shift+Right { focus-monitor-right; }
    Mod+Shift+Ctrl+Left { move-column-to-monitor-left; }
    Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }
    
    Mod+Page_Down { focus-workspace-down; }
    Mod+Page_Up { focus-workspace-up; }
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    Mod+Shift+1 { move-column-to-workspace 1; }
    Mod+Shift+2 { move-column-to-workspace 2; }
}
EOF

# Waybar
cat > ~/.config/waybar/config.jsonc << 'EOF'
{
    "layer": "top", "position": "top", "height": 32, "spacing": 4,
    "margin-left": 8, "margin-right": 8,
    "modules-left": ["niri/workspaces", "niri/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "tray"],
    "niri/workspaces": { "format": "{icon}", "format-icons": { "1": "1", "2": "2", "3": "3", "4": "4", "5": "5" } },
    "niri/window": { "format": "{title}", "max-length": 80 },
    "clock": { "format": "{:%H:%M}", "tooltip-format": "{:%A, %d/%m/%Y}" },
    "pulseaudio": { "format": "{icon} {volume}%", "format-muted": "Muted", "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" },
    "tray": { "icon-size": 16, "spacing": 10 }
}
EOF

cat > ~/.config/waybar/style.css << 'EOF'
@import url("colors.css");
* { font-family: "JetBrains Mono", sans-serif; font-size: 13px; border: none; border-radius: 6px; }
window#waybar { background: alpha(@surface, 0.85); color: @on_surface; border-bottom: 2px solid alpha(@primary, 0.5); }
#workspaces { background: alpha(@surface_variant, 0.5); padding: 0 8px; margin: 4px 0; }
#workspaces button { padding: 0 6px; color: @on_surface_variant; }
#workspaces button.active { color: @primary; background: alpha(@primary, 0.2); }
#clock { background: alpha(@surface_variant, 0.5); padding: 0 15px; margin: 4px 0; font-weight: bold; }
#pulseaudio { background: alpha(@surface_variant, 0.5); padding: 0 12px; margin: 4px 0; }
#pulseaudio.muted { color: @error; }
#tray { background: alpha(@surface_variant, 0.5); padding: 0 8px; margin: 4px 0; }
EOF
ok

#==============================================================================
# 12. ZSH + SERVICES + WEBAPPS
#==============================================================================
((CURRENT++))

step "$CURRENT" "ZSH, services and webapps"

# ZSH (simples, sem oh-my-zsh)
cat > ~/.zshrc << 'EOF'
# Plugins
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Environment
export EDITOR=nvim
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland
export QT_QPA_PLATFORMTHEME=qt5ct
export QT_STYLE_OVERRIDE=kvantum
export XCURSOR_THEME=Bibata-Modern-Classic
export XCURSOR_SIZE=24

# Colors
[ -f ~/.config/matugen/colors.sh ] && source ~/.config/matugen/colors.sh

# Aliases
alias ls='ls --color=auto'
alias la='ls -a'
alias ll='ls -l'
alias lla='ls -al'
alias rm='rm -r'
alias cp='cp -r'
alias vi='nvim'
alias vim='nvim'
alias zshrc='nvim ~/.zshrc'
alias vimrc='nvim ~/.config/nvim/init.vim'
alias nc='nvim ~/.config/niri/config.kdl'
alias fetch='clear && fastfetch --logo none'
alias reload-theme='~/.config/matugen/reload-all.sh'

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select

# History
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY

# Auto-start niri
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec niri
fi
EOF

# Change shell (silently)
sudo chsh -s /bin/zsh "$USER" >> "$LOG_FILE" 2>&1

# Services
systemctl --user enable --now power-profiles-daemon.service >> "$LOG_FILE" 2>&1
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service >> "$LOG_FILE" 2>&1

# Matugen watcher
cat > ~/.config/systemd/user/matugen-watcher.path << EOF
[Unit]
Description=Watch wallpaper
[Path]
PathChanged=%h/.config/wallpaper/current.jpg
[Install]
WantedBy=default.target
EOF

cat > ~/.config/systemd/user/matugen-watcher.service << EOF
[Unit]
Description=Update themes
[Service]
Type=oneshot
ExecStart=%h/.config/matugen/reload-all.sh
EOF
systemctl --user daemon-reload >> "$LOG_FILE" 2>&1
systemctl --user enable --now matugen-watcher.path >> "$LOG_FILE" 2>&1

# Auto-login
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null << EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USER --noclear %I \$TERM
EOF

# Gaming wrappers
sudo tee /usr/local/bin/steam-performance > /dev/null << 'EOF'
#!/bin/bash
powerprofilesctl set performance
gamemoderun steam
powerprofilesctl set power-saver
EOF
sudo chmod +x /usr/local/bin/steam-performance

sudo tee /usr/local/bin/game-performance > /dev/null << 'EOF'
#!/bin/bash
powerprofilesctl set performance
gamemoderun "$@"
powerprofilesctl set power-saver
EOF
sudo chmod +x /usr/local/bin/game-performance

# Kernel params
echo "vm.swappiness=10
vm.vfs_cache_pressure=50" | sudo tee /etc/sysctl.d/99-gaming.conf > /dev/null
sudo sysctl --system > /dev/null 2>&1

# Webapps
for app in discord whatsapp spotify; do
    case $app in
        discord)
            URL="https://discord.com/app"
            CLASS="Discord"
            ;;
        whatsapp)
            URL="https://web.whatsapp.com"
            CLASS="WhatsApp"
            ;;
        spotify)
            URL="https://open.spotify.com"
            CLASS="Spotify"
            ;;
    esac
    
    cat > ~/.local/share/applications/${app}-webapp.desktop << EOF
[Desktop Entry]
Name=${app^}
Exec=librewolf --class $CLASS --new-window $URL
Icon=$app
Type=Application
Categories=Network;
StartupWMClass=$CLASS
EOF
done

# Fastfetch
cat > ~/.config/fastfetch/config.jsonc << EOF
{ "logo": { "type": "none" }, "modules": [ "title", "separator", "os", "host", "kernel", "cpu", "gpu", "memory", "shell", "wm", "terminal", "separator", "colors" ] }
EOF

# Environment
cat > ~/.config/environment.d/theme.conf << EOF
QT_QPA_PLATFORMTHEME=qt5ct
QT_STYLE_OVERRIDE=kvantum
XCURSOR_THEME=Bibata-Modern-Classic
XCURSOR_SIZE=24
EOF
ok

#==============================================================================
# FINISH
#==============================================================================

header "INSTALLATION COMPLETE"

echo -e "${GREEN}✓ Success:${NC} $SUCCESS"
echo -e "${RED}✗ Failed:${NC} $FAILS"

[ $FAILS -gt 0 ] && echo -e "\n${YELLOW}Failures:${NC}" && printf '  • %s\n' "${FAILED_ITEMS[@]}"

echo -e "\n${CYAN}Logs:${NC} $LOG_FILE"
echo -e "${CYAN}Errors:${NC} $ERROR_LOG"

echo -e "\n${YELLOW}Key shortcuts:${NC}"
echo "  Mod+Return   → Kitty"
echo "  Mod+Space    → Fuzzel"
echo "  Mod+F9       → Nemo"
echo "  Mod+F10      → Librewolf"
echo "  Mod+F11      → Steam"
echo "  Mod+W        → Toggle Waybar"
echo "  Mod+P        → Change Wallpaper"
echo "  Mod+1-5      → Workspaces"

echo -e "\n${GREEN}Reboot to start using Niri!${NC}"