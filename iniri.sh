#!/bin/bash
#==============================================================================
# Arch Linux Niri Gaming Setup v6.1 - FINAL
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

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

#==============================================================================
# FUNCTIONS
#==============================================================================

header() { echo -e "\n${BLUE}═══ ${CYAN}$1 ${BLUE}═══${NC}\n"; }
step() { echo -ne "${YELLOW}[$1/$TOTAL_STEPS]${NC} ${CYAN}$2${NC}... "; }
ok() { echo -e "${GREEN}✓${NC}"; ((SUCCESS++)); }
fail() { echo -e "${RED}✗${NC} $1"; ((FAILS++)); FAILED_ITEMS+=("$1"); echo "[ERROR] $1" >> "$ERROR_LOG"; }

install_pkgs() {
    local desc="$1"; shift
    local pkgs=("$@")
    local failed_pkgs=()
    
    for pkg in "${pkgs[@]}"; do
        if pacman -Q "$pkg" &>/dev/null; then continue; fi
        if ! pacman -Si "$pkg" &>/dev/null; then
            echo -e "\n  ${YELLOW}⚠${NC} Package '$pkg' not found - skipping"
            continue
        fi
        if ! sudo pacman -S --noconfirm --needed "$pkg" >> "$LOG_FILE" 2>&1; then
            failed_pkgs+=("$pkg")
        fi
    done
    
    [ ${#failed_pkgs[@]} -eq 0 ] && ok || fail "$desc - Failed: ${failed_pkgs[*]}"
}

install_aur_pkgs() {
    local desc="$1"; shift
    local pkgs=("$@")
    local failed_pkgs=()
    
    for pkg in "${pkgs[@]}"; do
        if pacman -Q "$pkg" &>/dev/null; then continue; fi
        if ! yay -S --noconfirm --needed "$pkg" >> "$LOG_FILE" 2>&1; then
            failed_pkgs+=("$pkg")
        fi
    done
    
    [ ${#failed_pkgs[@]} -eq 0 ] && ok || fail "$desc - Failed: ${failed_pkgs[*]}"
}

#==============================================================================
# START
#==============================================================================

clear
echo -e "${GREEN}"
echo "╔══════════════════════════════════════╗"
echo "║  Arch Linux Niri Gaming Setup v6.1  ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

[ "$EUID" -eq 0 ] && echo -e "${RED}Run as normal user${NC}" && exit 1

echo "Installation started: $(date)" > "$LOG_FILE"
echo "Error log: $(date)" > "$ERROR_LOG"

#==============================================================================
# 1. YAY
#==============================================================================
TOTAL_STEPS=10
CURRENT=1

header "AUR HELPER"
step "$CURRENT" "Installing yay"
if command -v yay &>/dev/null; then ok
else
    sudo pacman -S --noconfirm --needed base-devel git >> "$LOG_FILE" 2>&1
    rm -rf /tmp/yay 2>/dev/null
    git clone https://aur.archlinux.org/yay.git /tmp/yay >> "$LOG_FILE" 2>&1
    cd /tmp/yay && makepkg -si --noconfirm >> "$LOG_FILE" 2>&1 && cd ~
    command -v yay &>/dev/null && ok || fail "yay"
fi

#==============================================================================
# 2. MULTILIB
#==============================================================================
((CURRENT++))
step "$CURRENT" "Enabling multilib"
if grep -q "^#\[multilib\]" /etc/pacman.conf; then
    sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
    sudo pacman -Syu --noconfirm >> "$LOG_FILE" 2>&1 && ok || fail "multilib"
else ok; fi

#==============================================================================
# 3. CORE PACKAGES
#==============================================================================
((CURRENT++))
header "INSTALLING PACKAGES"
step "$CURRENT" "Core system packages"
install_pkgs "Core" \
    niri waybar swaybg swaylock \
    kitty bemenu \
    nemo nemo-fileroller \
    playerctl pavucontrol \
    power-profiles-daemon \
    xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
    grim slurp wl-clipboard \
    noto-fonts noto-fonts-emoji ttf-jetbrains-mono \
    qt5-wayland qt6-wayland \
    fastfetch git curl wget imagemagick jq \
    gtk3 gtk4 gnome-themes-extra \
    qt5ct qt6ct kvantum kvantum-qt5 papirus-icon-theme \
    neovim fnott \
    zsh zsh-completions zsh-syntax-highlighting zsh-autosuggestions \
    lm_sensors htop

#==============================================================================
# 4. GPU + GAMING
#==============================================================================
((CURRENT++))
step "$CURRENT" "AMD drivers + Gaming"
install_pkgs "GPU/Gaming" \
    mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon \
    vulkan-icd-loader lib32-vulkan-icd-loader amd-ucode \
    libva-mesa-driver lib32-libva-mesa-driver \
    steam mangohud lib32-mangohud gamemode lib32-gamemode gamescope \
    lutris wine-staging winetricks \
    giflib lib32-giflib libpng lib32-libpng \
    libldap lib32-libldap gnutls lib32-gnutls \
    mpg123 lib32-mpg123 openal lib32-openal \
    v4l-utils lib32-v4l-utils libpulse lib32-libpulse \
    alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib \
    libjpeg-turbo lib32-libjpeg-turbo \
    libxcomposite lib32-libxcomposite libxinerama lib32-libxinerama \
    ncurses lib32-ncurses opencl-icd-loader lib32-opencl-icd-loader \
    libxslt lib32-libxslt gperftools lib32-systemd lib32-libgcrypt

#==============================================================================
# 5. AUR + EXTRA
#==============================================================================
((CURRENT++))
step "$CURRENT" "AUR and extra packages"
install_aur_pkgs "AUR" librewolf-bin bibata-cursor-theme
install_pkgs "Extra" matugen obs-studio v4l2loopback-dkms

#==============================================================================
# 6. DIRECTORIES + THEMES
#==============================================================================
((CURRENT++))
header "CONFIGURING SYSTEM"
step "$CURRENT" "Directories and themes"
mkdir -p ~/.config/{niri/scripts,waybar,kitty,nvim,matugen,qt5ct,qt6ct,Kvantum,gtk-3.0,gtk-4.0,fastfetch,environment.d,wallpaper,systemd/user,bemenu,fnott}
mkdir -p ~/Pictures/{Wallpapers,Screenshots}
mkdir -p ~/.local/share/{applications,icons}

sudo mkdir -p /usr/share/icons/default/
echo "[Icon Theme]
Inherits=Bibata-Modern-Classic" | sudo tee /usr/share/icons/default/index.theme > /dev/null

cat > ~/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Noto Sans 10
gtk-application-prefer-dark-theme=true
EOF
cp ~/.config/gtk-3.0/settings.ini ~/.config/gtk-4.0/settings.ini 2>/dev/null

# Fnott config
cat > ~/.config/fnott/fnott.ini << 'EOF'
[main]
max-width=400
max-height=200
anchor=top-right
margin=10
padding=10
border-radius=8
timeout=2
font=JetBrains Mono:size=11
background=#1a1b26e6
border-color=#7aa2f7ff
border-width=2
text-color=#c0caf5ff
title-color=#7aa2f7ff
summary-color=#c0caf5ff
EOF
ok

#==============================================================================
# 7. WALLPAPERS + MATUGEN (SAME COLORS FOR KITTY + NVIM)
#==============================================================================
((CURRENT++))
step "$CURRENT" "Wallpapers and Matugen"

[ -d "$SCRIPT_DIR/Wallpapers" ] && [ -n "$(ls -A "$SCRIPT_DIR/Wallpapers" 2>/dev/null)" ] && \
    cp "$SCRIPT_DIR/Wallpapers"/* ~/Pictures/Wallpapers/ 2>/dev/null || {
    convert -size 1920x1080 gradient:'#1a1b26'-'#2d1b69' ~/Pictures/Wallpapers/purple.jpg 2>/dev/null
    convert -size 1920x1080 gradient:'#1b4332'-'#081c15' ~/Pictures/Wallpapers/green.jpg 2>/dev/null
    convert -size 1920x1080 gradient:'#312244'-'#3c096c' ~/Pictures/Wallpapers/dark.jpg 2>/dev/null
}

FIRST_WP=$(ls ~/Pictures/Wallpapers/*.jpg 2>/dev/null | head -1)
[ -n "$FIRST_WP" ] && cp "$FIRST_WP" ~/.config/wallpaper/current.jpg

cat > ~/.config/matugen/config.toml << 'EOF'
[general]
color_space = "lab"
saturate = 1.0
brightness = 1.0

[contrast]
dark = 0.3
light = -0.3

[colors]
primary = "blue"

[scheme]
mode = "dark"
EOF

cat > ~/.config/matugen/reload-all.sh << 'SCRIPT'
#!/bin/bash
WP="$HOME/.config/wallpaper/current.jpg"
[ ! -f "$WP" ] && exit 0

# Generate with --mode dark for consistency
matugen image "$WP" --mode dark --format kitty > ~/.config/kitty/colors.conf 2>/dev/null
matugen image "$WP" --mode dark --format env > ~/.config/matugen/colors.sh 2>/dev/null
matugen image "$WP" --mode dark --format css > ~/.config/waybar/colors.css 2>/dev/null
matugen image "$WP" --mode dark --format kdl > ~/.config/niri/colors.kdl 2>/dev/null

# Neovim uses the SAME colors as Kitty
cp ~/.config/kitty/colors.conf ~/.config/nvim/colors.vim 2>/dev/null
# Convert kitty format to vim format if needed
sed -i 's/^color/let/g' ~/.config/nvim/colors.vim 2>/dev/null
sed -i 's/=/ = /g' ~/.config/nvim/colors.vim 2>/dev/null

source ~/.config/matugen/colors.sh 2>/dev/null

# Bemenu config (dmenu replacement)
cat > ~/.config/bemenu/config << BEMENU
BEMENU_OPTS="--fixed-height 26 --line-height 26 --fn 'JetBrains Mono 11' --nb '${surface:-#1a1b26}' --nf '${on_surface:-#c0caf5}' --sb '${primary:-#7aa2f7}' --sf '${surface:-#1a1b26}' --tb '${surface:-#1a1b26}' --tf '${primary:-#7aa2f7}' --hb '${primary:-#7aa2f7}' --hf '${surface:-#1a1b26}' --scb '${surface_variant:-#24283b}' --scf '${on_surface:-#c0caf5}' --border 0 --margin 0 --width-factor 1.0 --center --wrap 0"
BEMENU

# GTK dark
cat > ~/.config/gtk-3.0/gtk.css << EOFG
@define-color theme_bg_color ${surface:-#1a1b26};
@define-color theme_fg_color ${on_surface:-#c0caf5};
@define-color theme_base_color ${surface:-#1a1b26};
@define-color theme_text_color ${on_surface:-#c0caf5};
@define-color theme_selected_bg_color ${primary:-#7aa2f7};
@define-color theme_selected_fg_color ${surface:-#1a1b26};
@define-color borders alpha(${on_surface:-#c0caf5}, 0.08);
* { background-color: @theme_bg_color; color: @theme_fg_color; }
window { background-color: @theme_bg_color; color: @theme_fg_color; }
button { background-color: @theme_selected_bg_color; color: @theme_selected_fg_color; border-radius: 2px; padding: 2px 8px; border: none; }
button:hover { opacity: 0.85; }
entry { background-color: @theme_base_color; color: @theme_text_color; border: 1px solid @borders; border-radius: 2px; padding: 2px 6px; }
EOFG
cp ~/.config/gtk-3.0/gtk.css ~/.config/gtk-4.0/gtk.css 2>/dev/null

# Kvantum dark
mkdir -p ~/.config/Kvantum/MatugenDark
cat > ~/.config/Kvantum/MatugenDark/MatugenDark.kvconfig << EOFK
[General]
author=Matugen
opacity=100

[%General]
base_color=${surface:-#1a1b26}
bg_color=${surface:-#1a1b26}
fg_color=${on_surface:-#c0caf5}
link_color=${primary:-#7aa2f7}
tooltip_bg_color=${surface_variant:-#24283b}
tooltip_fg_color=${on_surface:-#c0caf5}
EOFK

# Fnott colors
cat > ~/.config/fnott/fnott.ini << FNOTT
[main]
max-width=400
max-height=200
anchor=top-right
margin=10
padding=10
border-radius=8
timeout=2
font=JetBrains Mono:size=11
background=${surface:-#1a1b26}e6
border-color=${primary:-#7aa2f7}ff
border-width=2
text-color=${on_surface:-#c0caf5}ff
title-color=${primary:-#7aa2f7}ff
summary-color=${on_surface:-#c0caf5}ff
FNOTT

# Reload
pkill -USR1 kitty 2>/dev/null
pkill -USR2 waybar 2>/dev/null
pkill -HUP fnott 2>/dev/null
for s in /tmp/nvim.*/0; do nvim --server "$s" --remote-send ':source ~/.config/nvim/colors.vim<CR>' 2>/dev/null; done
exit 0
SCRIPT
chmod +x ~/.config/matugen/reload-all.sh

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
fnott "Wallpaper changed" 2>/dev/null &
exit 0
SCRIPT
chmod +x ~/.config/niri/scripts/change-wallpaper.sh

cat > ~/.config/qt5ct/qt5ct.conf << 'EOF'
[Appearance]
icon_theme=Papirus-Dark
standard_dialogs=gtk3
style=kvantum
EOF
cp ~/.config/qt5ct/qt5ct.conf ~/.config/qt6ct/qt6ct.conf

~/.config/matugen/reload-all.sh >> "$LOG_FILE" 2>&1 &
ok

#==============================================================================
# 8. KITTY + NEOVIM (SHARING SAME COLORS)
#==============================================================================
((CURRENT++))
step "$CURRENT" "Kitty and Neovim"

cat > ~/.config/kitty/kitty.conf << 'EOF'
include colors.conf
font_family JetBrains Mono
font_size 11.0
window_padding_width 6
hide_window_decorations yes
cursor_shape beam
shell /bin/zsh
scrollback_lines 10000
detect_urls yes
background_opacity 1.0
map ctrl+c copy_to_clipboard
map ctrl+v paste_from_clipboard
map ctrl+shift+n new_os_window
EOF

curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim 2>/dev/null

# Neovim config - uses same colors.vim as kitty
cat > ~/.config/nvim/init.vim << 'EOF'
" Load colors from matugen (same as kitty)
if filereadable(expand('~/.config/nvim/colors.vim'))
    source ~/.config/nvim/colors.vim
endif

" Set colors manually from the sourced variables
if exists('g:background')
    execute 'hi Normal guibg=' . g:background . ' guifg=' . g:foreground
    execute 'hi CursorLine guibg=' . g:color8
    execute 'hi StatusLine guibg=' . g:color4 . ' guifg=' . g:background
endif

call plug#begin('~/.local/share/nvim/plugged')
Plug 'nvim-lualine/lualine.nvim'
Plug 'preservim/nerdtree'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'neoclide/coc.nvim', {'branch': 'release'}
call plug#end()

set number relativenumber mouse=a clipboard=unnamedplus termguicolors
set tabstop=4 shiftwidth=4 expandtab
set cursorline
let mapleader = " "
nnoremap <leader>n :NERDTreeToggle<CR>

lua << LUA
require'nvim-treesitter.configs'.setup { highlight = { enable = true } }
require('lualine').setup {
  options = {
    theme = 'auto',
    component_separators = '',
    section_separators = '',
  }
}
LUA
EOF
ok

#==============================================================================
# 9. NIRI + WAYBAR + BEMENU (BORDER COLORS FIXED)
#==============================================================================
((CURRENT++))
step "$CURRENT" "Niri, Waybar and Bemenu"

[ -f ~/.config/niri/config.kdl ] && cp ~/.config/niri/config.kdl ~/.config/niri/config.kdl.backup

cat > ~/.config/niri/config.kdl << 'NIRIEOF'
spawn-at-startup "sh" "-c" "systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP QT_QPA_PLATFORM GDK_BACKEND && systemctl --user restart pipewire.service pipewire-pulse.service wireplumber.service 2>/dev/null || true"
spawn-at-startup "xwayland-satellite"
spawn-at-startup "waybar"
spawn-at-startup "fnott"
spawn-at-startup "power-profiles-daemon"
spawn-at-startup "sh" "-c" "[ -f ~/.config/wallpaper/current.jpg ] && swaybg -i ~/.config/wallpaper/current.jpg -m fill &"

hotkey-overlay {
    skip-at-startup
}

include "colors.kdl"

input {
    focus-follows-mouse
    keyboard {
        xkb {
            layout "us,br"
            variant "intl,"
        }
    }
    mouse {
        accel-profile "flat"
        accel-speed 0.0
    }
    trackpoint {
        accel-profile "flat"
    }
}

output "DP-3" {
    mode "1920x1080@319.976"
    scale 1
    position x=0 y=0
}

output "HDMI-A-1" {
    mode "1920x1080@60.000"
    scale 1
    position x=1920 y=0
}

layout {
    gaps 6
    center-focused-column "never"
    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }
    default-column-width {
        proportion 0.5
    }
    focus-ring {
        width 2
        active-color "#7aa2f7"
        inactive-color "#333333"
    }
    border {
        width 1
        active-color "#7aa2f7"
        inactive-color "#2a2a2a"
    }
    tab-indicator {}
    insert-hint {}
    struts {}
}

recent-windows {
    highlight {}
}

screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

animations {}

prefer-no-csd

// Gaming: fullscreen on DP-3 (main monitor), no waybar
window-rule {
    match app-id=r#"^gamescope$"#
    open-fullscreen true
    open-floating false
    open-on-output "DP-3"
}

window-rule {
    match app-id=r#"^cs2$"#
    open-fullscreen true
    open-on-output "DP-3"
}

window-rule {
    match title=r#"^Counter-Strike 2$"#
    open-fullscreen true
    open-on-output "DP-3"
}

// All Steam games
window-rule {
    match app-id=r#"^steam_app_.*$"#
    open-fullscreen true
    open-on-output "DP-3"
}

// OBS on secondary monitor
window-rule {
    match app-id=r#"^com\.obsproject\.Studio$"#
    open-on-output "HDMI-A-1"
}

binds {
    Print { screenshot; }
    Ctrl+Print { screenshot-screen; }
    Alt+Print { screenshot-window; }

    Mod+F1 { switch-layout "next"; }
    Mod+Shift+Slash { show-hotkey-overlay; }

    Mod+RETURN { spawn "kitty"; }
    Mod+SPACE { spawn-sh "bemenu-run"; }
    Mod+F9 { spawn "librewolf"; }
    Mod+F10 { spawn "nemo"; }
    Mod+F11 { spawn "steam"; }

    Super+Alt+L { spawn "swaylock"; }
    Super+Alt+W { spawn-sh "pkill -USR1 waybar"; }
    Ctrl+Alt+Delete { quit skip-confirmation=true; }

    XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }
    XF86AudioMute allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
    XF86AudioMicMute allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }
    XF86AudioPlay allow-when-locked=true { spawn-sh "playerctl play-pause"; }
    XF86AudioNext allow-when-locked=true { spawn-sh "playerctl next"; }
    XF86AudioPrev allow-when-locked=true { spawn-sh "playerctl previous"; }
    XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "set" "+10%"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "set" "10%-"; }

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
    Mod+Shift+Right { focus-monitor-right; }

    Mod+Shift+Ctrl+Left { move-column-to-monitor-left; }
    Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }
}
NIRIEOF

# Waybar
cat > ~/.config/waybar/config.jsonc << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 26,
    "spacing": 2,
    "margin-left": 0,
    "margin-right": 0,
    "margin-top": 0,
    "modules-left": ["niri/window"],
    "modules-center": ["clock"],
    "modules-right": ["cpu", "temperature", "memory", "pulseaudio", "custom/powerprofile", "tray"],
    "niri/window": {
        "format": "{title}",
        "max-length": 80
    },
    "clock": {
        "format": "{:%H:%M}",
        "tooltip-format": "{:%A, %d/%m/%Y}"
    },
    "cpu": {
        "interval": 2,
        "format": "CPU {usage}% {temperature}°C",
        "max-length": 16,
        "on-click": "kitty -e htop"
    },
    "temperature": {
        "hwmon-path": "/sys/class/hwmon/hwmon1/temp1_input",
        "critical-threshold": 90,
        "format": "GPU {temperatureC}°C",
        "interval": 2
    },
    "memory": {
        "interval": 2,
        "format": "RAM {percentage}%",
        "max-length": 10,
        "tooltip-format": "{used:0.1f}G / {total:0.1f}G"
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "Muted",
        "on-click": "pavucontrol"
    },
    "custom/powerprofile": {
        "exec": "powerprofilesctl get",
        "interval": 5,
        "format": "{}",
        "on-click": "powerprofilesctl set $(powerprofilesctl list | grep -v '*' | head -1 | awk '{print $1}')",
        "tooltip-format": "Power profile: {}\nClick to cycle"
    },
    "tray": {
        "icon-size": 14,
        "spacing": 6
    }
}
EOF

cat > ~/.config/waybar/style.css << 'EOF'
@import url("colors.css");

* {
    font-family: "JetBrains Mono", sans-serif;
    font-size: 11px;
    border: none;
    border-radius: 0;
    min-height: 0;
}

window#waybar {
    background: @surface;
    color: @on_surface;
}

window#waybar.hidden {
    background: alpha(@surface, 0.3);
}

#window {
    padding: 0 10px;
    margin: 1px 0;
    color: @primary;
}

#clock {
    padding: 0 10px;
    margin: 1px 0;
    font-weight: bold;
}

#cpu {
    padding: 0 8px;
    margin: 1px 0;
    color: @tertiary;
}

#temperature {
    padding: 0 8px;
    margin: 1px 0;
    color: @error;
}

#memory {
    padding: 0 8px;
    margin: 1px 0;
    color: @secondary;
}

#pulseaudio {
    padding: 0 8px;
    margin: 1px 0;
}

#pulseaudio.muted {
    color: @error;
}

#custom-powerprofile {
    padding: 0 8px;
    margin: 1px 0;
    color: @primary;
}

#tray {
    padding: 0 6px;
    margin: 1px 0;
}

tooltip {
    background: @surface;
    border: 1px solid @outline;
    border-radius: 4px;
}

tooltip label {
    color: @on_surface;
}
EOF

# Detect GPU hwmon
for hwmon in /sys/class/hwmon/hwmon*; do
    if [ -f "$hwmon/name" ] && grep -qi "amdgpu" "$hwmon/name" 2>/dev/null; then
        if [ -f "$hwmon/temp1_input" ]; then
            sed -i "s|\"hwmon-path\": \".*\"|\"hwmon-path\": \"$hwmon/temp1_input\"|" ~/.config/waybar/config.jsonc
            break
        fi
    fi
done
ok

#==============================================================================
# 10. ZSH + SERVICES + OBS + WEBAPPS + FINAL
#==============================================================================
((CURRENT++))
step "$CURRENT" "ZSH, services, OBS, webapps and final setup"

echo ""
[ ! -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && sudo pacman -S --noconfirm zsh-syntax-highlighting >> "$LOG_FILE" 2>&1
[ ! -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && sudo pacman -S --noconfirm zsh-autosuggestions >> "$LOG_FILE" 2>&1

cat > ~/.zshrc << 'ZSHEND'
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

export EDITOR=nvim
export VISUAL=nvim
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland
export XDG_SESSION_TYPE=wayland
export QT_QPA_PLATFORMTHEME=qt5ct
export QT_STYLE_OVERRIDE=kvantum
export GTK_THEME=Adwaita-dark
export XCURSOR_THEME=Bibata-Modern-Classic
export XCURSOR_SIZE=24

[ -f ~/.config/matugen/colors.sh ] && source ~/.config/matugen/colors.sh

alias ls='ls --color=auto'
alias la='ls -a'
alias ll='ls -l'
alias lla='ls -al'
alias rm='rm -r'
alias cp='cp -r'
alias vi='nvim'
alias vim='nvim'
alias fetch='clear && fastfetch'
alias zshrc='nvim ~/.zshrc'
alias vimrc='nvim ~/.config/nvim/init.vim'
alias nc='nvim ~/.config/niri/config.kdl'

autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS

autoload -Uz colors && colors
PROMPT='%F{cyan}%~%f %F{yellow}❯%f '

if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec niri
fi
ZSHEND

if [ "$SHELL" != "/bin/zsh" ] && [ "$SHELL" != "/usr/bin/zsh" ]; then
    chsh -s /bin/zsh "$USER" 2>/dev/null || sudo chsh -s /bin/zsh "$USER" 2>/dev/null
    echo -e "  ${GREEN}✓${NC} Default shell changed to ZSH"
else
    echo -e "  ${GREEN}✓${NC} ZSH already default shell"
fi

systemctl --user enable --now power-profiles-daemon.service pipewire.service pipewire-pulse.service wireplumber.service >> "$LOG_FILE" 2>&1

cat > ~/.config/systemd/user/matugen-watcher.path << 'SERVEOF'
[Unit]
Description=Watch wallpaper changes
[Path]
PathChanged=%h/.config/wallpaper/current.jpg
[Install]
WantedBy=default.target
SERVEOF

cat > ~/.config/systemd/user/matugen-watcher.service << 'SERVEOF'
[Unit]
Description=Update matugen themes
[Service]
Type=oneshot
ExecStart=%h/.config/matugen/reload-all.sh
SERVEOF

systemctl --user daemon-reload >> "$LOG_FILE" 2>&1
systemctl --user enable --now matugen-watcher.path >> "$LOG_FILE" 2>&1

sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
sudo rm -f /etc/systemd/system/getty@tty1.service.d/override.conf
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null << AUTOEOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USER --noclear %I \$TERM
AUTOEOF

cat > ~/.zprofile << 'ZPROFILE'
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    export MOZ_ENABLE_WAYLAND=1
    export QT_QPA_PLATFORM=wayland
    export GDK_BACKEND=wayland
    export XDG_SESSION_TYPE=wayland
    exec niri
fi
ZPROFILE

mkdir -p ~/.config/obs-studio
cat > ~/.config/obs-studio/global.ini << 'EOF'
[General]
Pre21Defaults=false
[BasicWindow]
DockState=AAAA/wAAAAF9AAAAAwAAAAAAAAArAAAABAAAAAEBAAQAAAAAAAACQAAAAAEAAAAAAAAABYAAAAMAAABaAAAAZAAAAAIAAAAEAAAABAAABYAAABAAAAAEBAAAEAAAAAAAACQAAAABAAAAAAAAAAABYAAAAFAAAAAEAAAAAAAAABAAAAAQAAAAAAAAABYAAAAEAAAAAAMAAAAAAAAAKwAAAAQAAAABAQAABAAAAAAAABwAAAABAAAAAQAAAAEAAAACAAAAAQAAABwAAAABAAAAAAAAAAABAAADAAAABYAAABAAAABYAAAASAAAAAEA
geometry=@ByteArray(\x1\xd9\xd0\xcb\0\x2\0\0\0\0\0\xb2\0\0\0\x1c\0\0\x3\xe8\0\0\x2\xf4\0\0\0\xb2\0\0\0\x1c\0\0\x3\xe8\0\0\x2\xf4\0\0\0\0\0\0\0\0\a\x80)
EOF

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

echo "vm.swappiness=10
vm.vfs_cache_pressure=50" | sudo tee /etc/sysctl.d/99-gaming.conf > /dev/null
sudo sysctl --system > /dev/null 2>&1

#==============================================================================
# WEBAPPS
#==============================================================================

echo -e "\n  ${CYAN}Configuring webapps...${NC}"

mkdir -p ~/.librewolf
cat > ~/.librewolf/user.js << 'EOF'
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("browser.tabs.inTitlebar", 0);
EOF

PROFILE=$(find ~/.librewolf -maxdepth 2 -name "*.default-release" -type d 2>/dev/null | head -1)
[ -z "$PROFILE" ] && { mkdir -p ~/.librewolf/chrome; PROFILE="$HOME/.librewolf"; } || mkdir -p "$PROFILE/chrome"

cat > "$PROFILE/chrome/userChrome.css" << 'EOF'
@namespace url("http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul");
#TabsToolbar, #nav-bar, #sidebar-box, #sidebar-header, #sidebar-splitter,
#PersonalToolbar, #toolbar-menubar, #titlebar {
    visibility: collapse !important;
    display: none !important;
}
.titlebar-buttonbox-container { display: none !important; }
#appcontent { margin: 0 !important; padding: 0 !important; border: none !important; }
EOF

for p in $(find ~/.librewolf -maxdepth 2 -name "*.default*" -type d 2>/dev/null); do
    mkdir -p "$p/chrome"
    cp "$PROFILE/chrome/userChrome.css" "$p/chrome/userChrome.css" 2>/dev/null
done

cat > ~/.local/share/applications/discord-webapp.desktop << 'EOF'
[Desktop Entry]
Name=Discord
Exec=librewolf --class Discord --new-window https://discord.com/app
Icon=discord
Type=Application
Categories=Network;
StartupWMClass=Discord
EOF

cat > ~/.local/share/applications/whatsapp-webapp.desktop << 'EOF'
[Desktop Entry]
Name=WhatsApp
Exec=librewolf --class WhatsApp --new-window https://web.whatsapp.com
Icon=whatsapp
Type=Application
Categories=Network;
StartupWMClass=WhatsApp
EOF

cat > ~/.local/share/applications/spotify-webapp.desktop << 'EOF'
[Desktop Entry]
Name=Spotify
Exec=librewolf --class Spotify --new-window https://open.spotify.com
Icon=spotify
Type=Application
Categories=Audio;
StartupWMClass=Spotify
EOF

echo -e "  ${GREEN}✓${NC} Webapps created"

#==============================================================================
# FASTFETCH
#==============================================================================

cat > ~/.config/fastfetch/config.jsonc << 'EOF'
{
    "logo": { "type": "none" },
    "display": { "separator": " → " },
    "modules": [
        { "type": "title", "format": "{user-name}@{host-name}" },
        "separator",
        { "type": "os", "key": "OS" },
        { "type": "kernel", "key": "Kernel" },
        { "type": "packages", "key": "Packages" },
        { "type": "shell", "key": "Shell" },
        { "type": "wm", "key": "WM" },
        { "type": "terminal", "key": "Terminal" },
        "separator",
        { "type": "cpu", "key": "CPU" },
        { "type": "gpu", "key": "GPU" },
        { "type": "memory", "key": "Memory" }
    ]
}
EOF

cat > ~/.config/environment.d/theme.conf << 'EOF'
QT_QPA_PLATFORMTHEME=qt5ct
QT_STYLE_OVERRIDE=kvantum
XCURSOR_THEME=Bibata-Modern-Classic
XCURSOR_SIZE=24
MOZ_ENABLE_WAYLAND=1
QT_QPA_PLATFORM=wayland
GDK_BACKEND=wayland
EOF

ok

#==============================================================================
# FINISH
#==============================================================================

header "INSTALLATION COMPLETE"

echo -e "${GREEN}✓ Success:${NC} $SUCCESS  ${RED}✗ Failed:${NC} $FAILS"
[ $FAILS -gt 0 ] && echo -e "\n${YELLOW}Failures:${NC}" && printf '  • %s\n' "${FAILED_ITEMS[@]}"

echo -e "\n${CYAN}Logs:${NC} $LOG_FILE"

echo -e "\n${YELLOW}Key bindings:${NC}"
echo "  Mod+Return      → Kitty"
echo "  Mod+Space       → Bemenu (dmenu style)"
echo "  Mod+F9          → Librewolf"
echo "  Mod+F10         → Nemo"
echo "  Mod+F11         → Steam"
echo "  Super+Alt+W     → Toggle Waybar"
echo "  Mod+P           → Change Wallpaper"
echo "  Mod+Shift+F     → Fullscreen game (no waybar)"
echo "  Mod+Shift+Left  → Focus DP-3"
echo "  Mod+Shift+Right → Focus HDMI-A-1"

echo -e "\n${YELLOW}Gaming:${NC}"
echo "  • Games auto fullscreen on DP-3 (main monitor)"
echo "  • Use Mod+Shift+F for fullscreen without waybar"
echo "  • Steam games: auto-detected"

echo -e "\n${YELLOW}Theme:${NC}"
echo "  • Kitty + Neovim: SAME colors from matugen"
echo "  • Focus border: active #7aa2f7 / inactive #2a2a2a"
echo "  • Focus ring: active #7aa2f7 / inactive #333333"

echo -e "\n${GREEN}Reboot to start Niri!${NC}"