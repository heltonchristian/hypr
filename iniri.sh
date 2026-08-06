#!/bin/bash
#==============================================================================
# Arch Linux Niri Gaming Setup v3.1 - CORRIGIDO
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
        if pacman -Q "$pkg" &>/dev/null; then
            continue
        fi
        if ! sudo pacman -S --noconfirm --needed "$pkg" >> "$LOG_FILE" 2>&1; then
            failed_pkgs+=("$pkg")
        fi
    done
    
    if [ ${#failed_pkgs[@]} -eq 0 ]; then
        ok
    else
        fail "$desc - Failed: ${failed_pkgs[*]}"
    fi
}

install_aur_pkgs() {
    local desc="$1"; shift
    local pkgs=("$@")
    local failed_pkgs=()
    
    for pkg in "${pkgs[@]}"; do
        if pacman -Q "$pkg" &>/dev/null; then
            continue
        fi
        if ! yay -S --noconfirm --needed "$pkg" >> "$LOG_FILE" 2>&1; then
            failed_pkgs+=("$pkg")
        fi
    done
    
    if [ ${#failed_pkgs[@]} -eq 0 ]; then
        ok
    else
        fail "$desc - Failed: ${failed_pkgs[*]}"
    fi
}

#==============================================================================
# START
#==============================================================================

clear
echo -e "${GREEN}"
echo "╔══════════════════════════════════════╗"
echo "║  Arch Linux Niri Gaming Setup v3.1  ║"
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
if command -v yay &>/dev/null; then
    ok
else
    sudo pacman -S --noconfirm --needed base-devel git >> "$LOG_FILE" 2>&1
    rm -rf /tmp/yay 2>/dev/null
    if git clone https://aur.archlinux.org/yay.git /tmp/yay >> "$LOG_FILE" 2>&1; then
        cd /tmp/yay
        if makepkg -si --noconfirm >> "$LOG_FILE" 2>&1; then
            cd ~
            command -v yay &>/dev/null && ok || fail "yay not found after install"
        else
            fail "yay build failed"
        fi
    else
        fail "yay clone failed"
    fi
fi

#==============================================================================
# 2. MULTILIB
#==============================================================================
((CURRENT++))

step "$CURRENT" "Enabling multilib"
if grep -q "^#\[multilib\]" /etc/pacman.conf; then
    sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
    sudo pacman -Syu --noconfirm >> "$LOG_FILE" 2>&1 && ok || fail "multilib update failed"
else
    ok
fi

#==============================================================================
# 3. CORE PACKAGES
#==============================================================================
((CURRENT++))

header "INSTALLING PACKAGES"

step "$CURRENT" "Core system packages"
install_pkgs "Core" \
    niri waybar swaybg swaylock \
    kitty fuzzel \
    nemo nemo-fileroller \
    playerctl \
    power-profiles-daemon \
    xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
    grim slurp wl-clipboard \
    noto-fonts noto-fonts-emoji ttf-jetbrains-mono \
    qt5-wayland qt6-wayland \
    fastfetch git curl wget imagemagick jq \
    gtk3 gtk4 gtk-engine-murrine gnome-themes-extra \
    qt5ct qt6ct kvantum kvantum-qt5 papirus-icon-theme \
    neovim \
    zsh zsh-completions zsh-syntax-highlighting zsh-autosuggestions

#==============================================================================
# 4. GPU + GAMING
#==============================================================================
((CURRENT++))

step "$CURRENT" "AMD drivers + Gaming"
install_pkgs "GPU/Gaming" \
    mesa lib32-mesa \
    vulkan-radeon lib32-vulkan-radeon \
    vulkan-icd-loader lib32-vulkan-icd-loader \
    amd-ucode \
    libva-mesa-driver lib32-libva-mesa-driver \
    steam mangohud lib32-mangohud \
    gamemode lib32-gamemode gamescope \
    lutris wine-staging winetricks \
    giflib lib32-giflib libpng lib32-libpng \
    libldap lib32-libldap gnutls lib32-gnutls \
    mpg123 lib32-mpg123 openal lib32-openal \
    v4l-utils lib32-v4l-utils libpulse lib32-libpulse \
    alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib \
    libjpeg-turbo lib32-libjpeg-turbo \
    libxcomposite lib32-libxcomposite \
    libxinerama lib32-libxinerama \
    ncurses lib32-ncurses \
    opencl-icd-loader lib32-opencl-icd-loader \
    libxslt lib32-libxslt gperftools \
    lib32-systemd lib32-libgcrypt

#==============================================================================
# 5. AUR + EXTRA
#==============================================================================
((CURRENT++))

step "$CURRENT" "AUR and extra packages"
install_aur_pkgs "AUR" librewolf-bin bibata-cursor-theme
install_pkgs "Extra" matugen obs-studio v4l2loopback-dkms

#==============================================================================
# 6. DIRECTORIES + CURSOR
#==============================================================================
((CURRENT++))

header "CONFIGURING SYSTEM"

step "$CURRENT" "Directories and cursor"
mkdir -p ~/.config/{niri/scripts,waybar,kitty,nvim,matugen,qt5ct,qt6ct,Kvantum,gtk-3.0,gtk-4.0,fastfetch,environment.d,wallpaper,systemd/user}
mkdir -p ~/Pictures/{Wallpapers,Screenshots}
mkdir -p ~/.local/share/applications

# Cursor
sudo mkdir -p /usr/share/icons/default/
echo "[Icon Theme]
Inherits=Bibata-Modern-Classic" | sudo tee /usr/share/icons/default/index.theme > /dev/null

# GTK
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
ok

#==============================================================================
# 7. WALLPAPERS + MATUGEN
#==============================================================================
((CURRENT++))

step "$CURRENT" "Wallpapers and Matugen"

# Wallpapers
if [ -d "$SCRIPT_DIR/Wallpapers" ] && [ -n "$(ls -A "$SCRIPT_DIR/Wallpapers" 2>/dev/null)" ]; then
    cp "$SCRIPT_DIR/Wallpapers"/* ~/Pictures/Wallpapers/ 2>/dev/null
else
    convert -size 1920x1080 gradient:'#1a1b26'-'#2d1b69' ~/Pictures/Wallpapers/purple.jpg 2>/dev/null
    convert -size 1920x1080 gradient:'#1b4332'-'#081c15' ~/Pictures/Wallpapers/green.jpg 2>/dev/null
    convert -size 1920x1080 gradient:'#312244'-'#3c096c' ~/Pictures/Wallpapers/dark.jpg 2>/dev/null
fi

FIRST_WP=$(ls ~/Pictures/Wallpapers/*.jpg 2>/dev/null | head -1)
[ -n "$FIRST_WP" ] && cp "$FIRST_WP" ~/.config/wallpaper/current.jpg

# Matugen config
cat > ~/.config/matugen/config.toml << 'EOF'
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

matugen image "$WP" --format kitty > ~/.config/kitty/colors.conf 2>/dev/null
matugen image "$WP" --format env > ~/.config/matugen/colors.sh 2>/dev/null
matugen image "$WP" --format nvim > ~/.config/nvim/colors.vim 2>/dev/null
matugen image "$WP" --format css > ~/.config/waybar/colors.css 2>/dev/null

# GTK colors
source ~/.config/matugen/colors.sh 2>/dev/null
cat > ~/.config/gtk-3.0/gtk.css << EOFG
@define-color theme_bg_color ${surface:-#1a1b26};
@define-color theme_fg_color ${on_surface:-#c0caf5};
@define-color theme_selected_bg_color ${primary:-#7aa2f7};
window { background-color: @theme_bg_color; color: @theme_fg_color; }
button { background-color: @theme_selected_bg_color; border-radius: 4px; padding: 4px 12px; }
EOFG
cp ~/.config/gtk-3.0/gtk.css ~/.config/gtk-4.0/gtk.css 2>/dev/null

# Kvantum
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

# Reload apps
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

# Qt
cat > ~/.config/qt5ct/qt5ct.conf << 'EOF'
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
# 8. KITTY + NEOVIM
#==============================================================================
((CURRENT++))

step "$CURRENT" "Kitty and Neovim configs"

cat > ~/.config/kitty/kitty.conf << 'EOF'
include colors.conf
font_family JetBrains Mono
font_size 11.0
window_padding_width 10
hide_window_decorations yes
cursor_shape beam
shell /bin/zsh
scrollback_lines 10000
detect_urls yes
map ctrl+c copy_to_clipboard
map ctrl+v paste_from_clipboard
map ctrl+shift+n new_os_window
EOF

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
# 9. NIRI + WAYBAR (CORRIGIDO)
#==============================================================================
((CURRENT++))

step "$CURRENT" "Niri and Waybar configs"

[ -f ~/.config/niri/config.kdl ] && cp ~/.config/niri/config.kdl ~/.config/niri/config.kdl.backup

cat > ~/.config/niri/config.kdl << 'NIRIEOF'
//==============================================================================
// NIRI CONFIGURATION
//==============================================================================

// Pipewire audio
spawn-at-startup "sh" "-c" "systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && systemctl --user restart pipewire.service pipewire-pulse.service wireplumber.service 2>/dev/null || true"

// Core services
spawn-at-startup "xwayland-satellite"
spawn-at-startup "waybar"
spawn-at-startup "power-profiles-daemon"

// Wallpaper
spawn-at-startup "sh" "-c" "[ -f ~/.config/wallpaper/current.jpg ] && swaybg -i ~/.config/wallpaper/current.jpg -m fill &"

hotkey-overlay {
    skip-at-startup
}

//==============================================================================
// INPUT
//==============================================================================

input {
    focus-follows-mouse
    keyboard {
        xkb {
            layout "us,br"
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

//==============================================================================
// DISPLAYS
//==============================================================================

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

//==============================================================================
// LAYOUT
//==============================================================================

layout {
    gaps 10
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
        width 4
    }
    border {
        width 2
    }
    shadow {
        softness 30
        spread 5
        offset x=0 y=5
        color "#0007"
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

//==============================================================================
// WINDOW RULES
//==============================================================================

window-rule {
    match app-id=r#"firefox$"# title="^Picture-in-Picture$"
    open-floating true
}

window-rule {
    match app-id=r#"^gamescope$"#
    open-fullscreen true
    open-floating false
}

window-rule {
    match app-id=r#"^cs2$"#
    open-fullscreen true
}

window-rule {
    match title=r#"^Counter-Strike 2$"#
    open-fullscreen true
}

window-rule {
    match app-id=r#"^steam$"#
    open-floating true
}

//==============================================================================
// KEYBINDINGS
//==============================================================================

binds {
    // Screenshots
    Print { screenshot; }
    Ctrl+Print { screenshot-screen; }
    Alt+Print { screenshot-window; }

    // Layout
    Mod+F1 { switch-layout "next"; }
    Mod+Shift+Slash { show-hotkey-overlay; }

    // Applications - CORRIGIDO: F9=Librewolf, F10=Nemo
    Mod+RETURN hotkey-overlay-title="Terminal: Kitty" { spawn "kitty"; }
    Mod+SPACE hotkey-overlay-title="App Launcher: Fuzzel" { spawn "fuzzel"; }
    Mod+F9 hotkey-overlay-title="Browser: Librewolf" { spawn "librewolf"; }
    Mod+F10 hotkey-overlay-title="File Manager: Nemo" { spawn "nemo"; }
    Mod+F11 hotkey-overlay-title="Steam" { spawn "steam-performance"; }

    // System
    Super+Alt+L hotkey-overlay-title="Lock Screen" { spawn "swaylock"; }
    Ctrl+Alt+Delete { quit skip-confirmation=true; }

    // Multimedia
    XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }
    XF86AudioMute allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
    XF86AudioMicMute allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }
    XF86AudioPlay allow-when-locked=true { spawn-sh "playerctl play-pause"; }
    XF86AudioNext allow-when-locked=true { spawn-sh "playerctl next"; }
    XF86AudioPrev allow-when-locked=true { spawn-sh "playerctl previous"; }
    XF86MonBrightnessUp allow-when-locked=true { spawn "brightnessctl" "set" "+10%"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "set" "10%-"; }

    // Appearance
    Mod+W { spawn-sh "pkill -USR1 waybar"; }
    Mod+P { spawn-sh "~/.config/niri/scripts/change-wallpaper.sh"; }
    Mod+Shift+P { spawn-sh "~/.config/matugen/reload-all.sh"; }

    // Window management
    Mod+O repeat=false { toggle-overview; }
    Mod+K repeat=false { close-window; }
    Mod+F { maximize-column; }
    Mod+Shift+F { fullscreen-window; }

    // Focus movement
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
    Mod+Ctrl+Home { move-column-to-first; }
    Mod+Ctrl+End { move-column-to-last; }

    // Monitor navigation
    Mod+Shift+Left { focus-monitor-left; }
    Mod+Shift+Down { focus-monitor-down; }
    Mod+Shift+Up { focus-monitor-up; }
    Mod+Shift+Right { focus-monitor-right; }
    Mod+Shift+Ctrl+Left { move-column-to-monitor-left; }
    Mod+Shift+Ctrl+Down { move-column-to-monitor-down; }
    Mod+Shift+Ctrl+Up { move-column-to-monitor-up; }
    Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }

    // Workspace navigation
    Mod+Page_Down { focus-workspace-down; }
    Mod+Page_Up { focus-workspace-up; }
    Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
    Mod+Ctrl+Page_Up { move-column-to-workspace-up; }
    Mod+Shift+Page_Down { move-workspace-down; }
    Mod+Shift+Page_Up { move-workspace-up; }
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    Mod+Shift+1 { move-column-to-workspace 1; }
    Mod+Shift+2 { move-column-to-workspace 2; }
}
NIRIEOF

# Waybar
cat > ~/.config/waybar/config.jsonc << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 32,
    "spacing": 4,
    "margin-left": 8,
    "margin-right": 8,
    "modules-left": ["niri/workspaces", "niri/window"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "tray"],
    "niri/workspaces": {
        "format": "{icon}",
        "format-icons": { "1": "1", "2": "2", "3": "3", "4": "4", "5": "5" }
    },
    "niri/window": {
        "format": "{title}",
        "max-length": 80
    },
    "clock": {
        "format": "{:%H:%M}",
        "tooltip-format": "{:%A, %d/%m/%Y}"
    },
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-muted": "Muted",
        "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
    },
    "tray": {
        "icon-size": 16,
        "spacing": 10
    }
}
EOF

cat > ~/.config/waybar/style.css << 'EOF'
@import url("colors.css");
* {
    font-family: "JetBrains Mono", sans-serif;
    font-size: 13px;
    border: none;
    border-radius: 6px;
    min-height: 0;
}
window#waybar {
    background: alpha(@surface, 0.85);
    color: @on_surface;
    border-bottom: 2px solid alpha(@primary, 0.5);
}
#workspaces {
    background: alpha(@surface_variant, 0.5);
    padding: 0 8px;
    margin: 4px 0;
}
#workspaces button {
    padding: 0 6px;
    color: @on_surface_variant;
}
#workspaces button.active {
    color: @primary;
    background: alpha(@primary, 0.2);
}
#window {
    background: alpha(@surface_variant, 0.3);
    color: @primary;
    padding: 0 15px;
    margin: 4px 0;
}
#clock {
    background: alpha(@surface_variant, 0.5);
    padding: 0 15px;
    margin: 4px 0;
    font-weight: bold;
}
#pulseaudio {
    background: alpha(@surface_variant, 0.5);
    padding: 0 12px;
    margin: 4px 0;
}
#pulseaudio.muted {
    color: @error;
}
#tray {
    background: alpha(@surface_variant, 0.5);
    padding: 0 8px;
    margin: 4px 0;
}
tooltip {
    background: @surface;
    border: 1px solid @outline;
    border-radius: 6px;
}
tooltip label {
    color: @on_surface;
}
EOF
ok

#==============================================================================
# 10. ZSH + SERVICES + WEBAPPS + FINAL
#==============================================================================
((CURRENT++))

step "$CURRENT" "ZSH, services, webapps and final setup"

# ZSH config
cat > ~/.zshrc << 'ZSHEND'
# Plugins
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# Environment
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

# Matugen colors
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
alias fc='nvim ~/.config/fastfetch/config.jsonc'
alias fetch='clear && fastfetch --logo none'
alias zshrc='nvim ~/.zshrc'
alias vimrc='nvim ~/.config/nvim/init.vim'
alias waybarc='nvim ~/.config/waybar/config.jsonc'
alias waybarcss='nvim ~/.config/waybar/style.css'
alias nc='nvim ~/.config/niri/config.kdl'
alias reload-theme='~/.config/matugen/reload-all.sh'
alias steam='steam-performance'

# Auto-completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# History
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS

# Auto-start niri on tty1
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec niri
fi
ZSHEND

# Change shell to ZSH
if [ "$SHELL" != "/bin/zsh" ] && [ "$SHELL" != "/usr/bin/zsh" ]; then
    sudo chsh -s /bin/zsh "$USER" >> "$LOG_FILE" 2>&1
fi

# Services
systemctl --user enable --now power-profiles-daemon.service >> "$LOG_FILE" 2>&1
systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service >> "$LOG_FILE" 2>&1

# Matugen watcher
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

# Kernel
echo "vm.swappiness=10
vm.vfs_cache_pressure=50" | sudo tee /etc/sysctl.d/99-gaming.conf > /dev/null
sudo sysctl --system > /dev/null 2>&1

# Webapps
cat > ~/.local/share/applications/discord-webapp.desktop << EOF
[Desktop Entry]
Name=Discord
Exec=librewolf --class Discord --new-window https://discord.com/app
Icon=discord
Type=Application
Categories=Network;
StartupWMClass=Discord
EOF

cat > ~/.local/share/applications/whatsapp-webapp.desktop << EOF
[Desktop Entry]
Name=WhatsApp
Exec=librewolf --class WhatsApp --new-window https://web.whatsapp.com
Icon=whatsapp
Type=Application
Categories=Network;
StartupWMClass=WhatsApp
EOF

cat > ~/.local/share/applications/spotify-webapp.desktop << EOF
[Desktop Entry]
Name=Spotify
Exec=librewolf --class Spotify --new-window https://open.spotify.com
Icon=spotify
Type=Application
Categories=Audio;
StartupWMClass=Spotify
EOF

# Fastfetch
cat > ~/.config/fastfetch/config.jsonc << EOF
{
    "logo": { "type": "none" },
    "modules": [
        "title", "separator", "os", "host", "kernel",
        "cpu", "gpu", "memory", "shell", "wm", "terminal",
        "separator", "colors"
    ]
}
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

echo -e "\n${YELLOW}Key bindings:${NC}"
echo "  Mod+Return   → Kitty (Terminal)"
echo "  Mod+Space    → Fuzzel (App Launcher)"
echo "  Mod+F9       → Librewolf (Browser)"
echo "  Mod+F10      → Nemo (File Manager)"
echo "  Mod+F11      → Steam"
echo "  Mod+W        → Toggle Waybar"
echo "  Mod+P        → Change Wallpaper"
echo "  Mod+1-5      → Workspaces 1-5"
echo "  Print        → Screenshot"

echo -e "\n${YELLOW}Webapps:${NC}"
echo "  Discord | WhatsApp | Spotify"
echo "  Find in app launcher (Fuzzel)"

echo -e "\n${GREEN}Reboot to start Niri!${NC}"
echo -e "${YELLOW}After reboot, ZSH will be default shell with all customizations${NC}"