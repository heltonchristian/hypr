#!/bin/bash
set -o pipefail

#==============================================================================
# VARIABLES & CONFIGURATION
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$HOME/niri-setup-$(date +%Y%m%d-%H%M%S).log"
ERROR_LOG="$HOME/niri-setup-errors-$(date +%Y%m%d-%H%M%S).log"
SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_ITEMS=()

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

#==============================================================================
# UTILITY FUNCTIONS
#==============================================================================

print_header() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${CYAN}$1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}\n"
}

print_step() {
    echo -e "${YELLOW}[$1/$TOTAL_STEPS]${NC} ${CYAN}$2${NC}..."
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    FAILED_ITEMS+=("$1")
}

print_warning() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

run_with_retry() {
    local max_attempts=3
    local attempt=1
    local cmd="$1"
    local description="$2"
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$cmd" >> "$LOG_FILE" 2>&1; then
            print_success "$description"
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                print_warning "Attempt $attempt failed, retrying..."
                sleep 2
            fi
            attempt=$((attempt + 1))
        fi
    done
    
    print_error "$description"
    echo "[ERROR] $description - Command: $cmd" >> "$ERROR_LOG"
    return 1
}

#==============================================================================
# INITIAL CHECKS
#==============================================================================

echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Arch Linux Niri Gaming Setup v2.1     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}\n"

if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Please run as normal user, not root${NC}"
    exit 1
fi

echo "Installation started at $(date)" > "$LOG_FILE"
echo "Error log - $(date)" > "$ERROR_LOG"

if ! ping -c 1 archlinux.org &> /dev/null; then
    echo -e "${RED}No internet connection. Please check your network.${NC}"
    exit 1
fi

#==============================================================================
# STEP 1: YAY INSTALLATION
#==============================================================================
TOTAL_STEPS=17
CURRENT_STEP=1

print_header "INSTALLING AUR HELPER"
print_step "$CURRENT_STEP" "Installing yay"

if command -v yay &> /dev/null; then
    print_success "yay already installed"
else
    run_with_retry "sudo pacman -S --needed --noconfirm base-devel git" "Installing base-devel and git"
    
    if [ -d "/tmp/yay" ]; then
        rm -rf /tmp/yay
    fi
    
    if git clone https://aur.archlinux.org/yay.git /tmp/yay >> "$LOG_FILE" 2>&1; then
        cd /tmp/yay
        run_with_retry "makepkg -si --noconfirm" "Building and installing yay"
        cd ~
    else
        print_error "Failed to clone yay repository"
    fi
fi

#==============================================================================
# STEP 2: ENABLE MULTILIB
#==============================================================================
CURRENT_STEP=2
print_step "$CURRENT_STEP" "Enabling multilib repository"

if grep -q "^\[multilib\]" /etc/pacman.conf; then
    if grep -q "^#\[multilib\]" /etc/pacman.conf; then
        sudo sed -i '/\[multilib\]/,/Include/s/^#//' /etc/pacman.conf
        run_with_retry "sudo pacman -Syu --noconfirm" "Updating system with multilib"
    else
        print_success "Multilib already enabled"
    fi
else
    print_warning "Multilib repository not found in pacman.conf"
fi

#==============================================================================
# STEP 3: CORE PACKAGES
#==============================================================================
CURRENT_STEP=3
print_step "$CURRENT_STEP" "Installing core packages"

# Nota: pipewire e wireplumber serão gerenciados pelo niri, não como systemd services
CORE_PACKAGES=(
    niri waybar swaybg swaylock kitty fuzzel nemo nemo-fileroller
    playerctl light power-profiles-daemon
    xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
    grim slurp wl-clipboard noto-fonts noto-fonts-emoji ttf-jetbrains-mono
    qt5-wayland qt6-wayland fastfetch zsh zsh-completions
    zsh-syntax-highlighting zsh-autosuggestions neovim git curl wget
    imagemagick jq inotify-tools
    gtk3 gtk4 gtk-engine-murrine gnome-themes-extra
    qt5ct qt6ct kvantum kvantum-qt5
    papirus-icon-theme
)

run_with_retry "sudo pacman -S --needed --noconfirm ${CORE_PACKAGES[*]}" "Core packages"

#==============================================================================
# STEP 4: AMD GPU DRIVERS
#==============================================================================
CURRENT_STEP=4
print_step "$CURRENT_STEP" "Installing AMD GPU drivers"

AMD_PACKAGES=(
    mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon
    vulkan-icd-loader lib32-vulkan-icd-loader amd-ucode
    libva-mesa-driver lib32-libva-mesa-driver
)

run_with_retry "sudo pacman -S --needed --noconfirm ${AMD_PACKAGES[*]}" "AMD GPU drivers"

#==============================================================================
# STEP 5: GAMING PACKAGES
#==============================================================================
CURRENT_STEP=5
print_step "$CURRENT_STEP" "Installing gaming packages"

GAMING_PACKAGES=(
    steam mangohud lib32-mangohud gamemode lib32-gamemode
    gamescope lutris wine-staging winetricks
    giflib lib32-giflib libpng lib32-libpng libldap lib32-libldap
    gnutls lib32-gnutls mpg123 lib32-mpg123 openal lib32-openal
    v4l-utils lib32-v4l-utils libpulse lib32-libpulse
    alsa-plugins lib32-alsa-plugins alsa-lib lib32-alsa-lib
    libjpeg-turbo lib32-libjpeg-turbo libxcomposite lib32-libxcomposite
    libxinerama lib32-libxinerama ncurses lib32-ncurses
    opencl-icd-loader lib32-opencl-icd-loader libxslt lib32-libxslt
    gperftools lib32-systemd lib32-libgcrypt
)

run_with_retry "sudo pacman -S --needed --noconfirm ${GAMING_PACKAGES[*]}" "Gaming packages"

#==============================================================================
# STEP 6: THIRD-PARTY APPS
#==============================================================================
CURRENT_STEP=6
print_step "$CURRENT_STEP" "Installing Librewolf and matugen"

run_with_retry "yay -S --needed --noconfirm librewolf-bin" "Librewolf browser"
run_with_retry "sudo pacman -S --needed --noconfirm matugen" "Matugen color generator"

#==============================================================================
# STEP 7: OBS STUDIO
#==============================================================================
CURRENT_STEP=7
print_step "$CURRENT_STEP" "Installing OBS Studio"

run_with_retry "sudo pacman -S --needed --noconfirm obs-studio v4l2loopback-dkms" "OBS Studio"

#==============================================================================
# STEP 8: CURSOR THEME
#==============================================================================
CURRENT_STEP=8
print_step "$CURRENT_STEP" "Installing Bibata cursor theme"

run_with_retry "yay -S --needed --noconfirm bibata-cursor-theme" "Bibata cursor theme"

sudo mkdir -p /usr/share/icons/default/
echo "[Icon Theme]
Inherits=Bibata-Modern-Classic" | sudo tee /usr/share/icons/default/index.theme > /dev/null
print_success "System cursor theme configured"

mkdir -p ~/.config/gtk-3.0
echo "[Settings]
gtk-cursor-theme-name=Bibata-Modern-Classic
gtk-cursor-theme-size=24" > ~/.config/gtk-3.0/settings.ini
print_success "GTK cursor theme configured"

#==============================================================================
# STEP 9: COPY WALLPAPERS
#==============================================================================
CURRENT_STEP=9
print_step "$CURRENT_STEP" "Setting up wallpapers"

if [ -d "$SCRIPT_DIR/Wallpapers" ]; then
    mkdir -p ~/Pictures/Wallpapers
    cp -r "$SCRIPT_DIR/Wallpapers"/* ~/Pictures/Wallpapers/ 2>/dev/null
    print_success "Wallpapers copied from installation directory"
else
    print_warning "Wallpapers directory not found in $SCRIPT_DIR"
    print_warning "Creating sample wallpapers..."
    
    mkdir -p ~/Pictures/Wallpapers
    
    for color in "#1a1b26" "#2d1b69" "#1b4332" "#081c15" "#312244" "#3c096c"; do
        convert -size 1920x1080 xc:"$color" ~/Pictures/Wallpapers/wallpaper_${color//\#/}.jpg 2>/dev/null
    done
    
    convert -size 1920x1080 gradient:'#1a1b26'-'#2d1b69' ~/Pictures/Wallpapers/gradient_purple.jpg 2>/dev/null
    convert -size 1920x1080 gradient:'#1b4332'-'#081c15' ~/Pictures/Wallpapers/gradient_green.jpg 2>/dev/null
    convert -size 1920x1080 gradient:'#312244'-'#3c096c' ~/Pictures/Wallpapers/gradient_dark_purple.jpg 2>/dev/null
    
    print_success "Sample wallpapers created"
fi

#==============================================================================
# STEP 10: MATUGEN CONFIGURATION WITH FULL THEMING
#==============================================================================
CURRENT_STEP=10
print_step "$CURRENT_STEP" "Configuring matugen with full system theming"

mkdir -p ~/.config/matugen
mkdir -p ~/.config/wallpaper
mkdir -p ~/.config/waybar
mkdir -p ~/.config/gtk-3.0
mkdir -p ~/.config/gtk-4.0
mkdir -p ~/.config/qt5ct
mkdir -p ~/.config/qt6ct
mkdir -p ~/.config/Kvantum

# Set initial wallpaper
if [ -f ~/Pictures/Wallpapers/gradient_purple.jpg ]; then
    cp ~/Pictures/Wallpapers/gradient_purple.jpg ~/.config/wallpaper/current.jpg
elif [ -n "$(ls ~/Pictures/Wallpapers/*.jpg 2>/dev/null)" ]; then
    cp "$(ls ~/Pictures/Wallpapers/*.jpg | head -n 1)" ~/.config/wallpaper/current.jpg
fi

# Matugen configuration
cat > ~/.config/matugen/config.toml << 'MATUGENCONF'
[general]
color_space = "lab"
saturate = 1.0
brightness = 1.0

[contrast]
dark = 0.0
light = 0.0

[colors]
primary = "blue"
MATUGENCONF

# Script principal de recarregamento de temas
cat > ~/.config/matugen/reload-all.sh << 'RELOADSCRIPT'
#!/bin/bash
WALLPAPER="$HOME/.config/wallpaper/current.jpg"

if [ ! -f "$WALLPAPER" ]; then
    echo "No wallpaper found"
    exit 1
fi

echo "🎨 Generating color schemes from wallpaper..."

# 1. Kitty terminal
matugen image "$WALLPAPER" --format kitty > ~/.config/kitty/colors.conf
echo "  ✓ Kitty colors"

# 2. Environment variables
matugen image "$WALLPAPER" --format env > ~/.config/matugen/colors.sh
echo "  ✓ Environment variables"

# 3. Neovim
matugen image "$WALLPAPER" --format nvim > ~/.config/nvim/colors.vim
echo "  ✓ Neovim colors"

# 4. Waybar
matugen image "$WALLPAPER" --format css > ~/.config/waybar/colors.css
echo "  ✓ Waybar colors"

# 5. GTK3/GTK4 theme
if [ -f ~/.config/matugen/colors.sh ]; then
    source ~/.config/matugen/colors.sh
    
    cat > ~/.config/gtk-3.0/gtk.css << GTKCSS
@define-color theme_bg_color ${surface:-#1a1b26};
@define-color theme_fg_color ${on_surface:-#c0caf5};
@define-color theme_base_color ${surface:-#1a1b26};
@define-color theme_text_color ${on_surface:-#c0caf5};
@define-color theme_selected_bg_color ${primary:-#7aa2f7};
@define-color theme_selected_fg_color ${on_primary:-#1a1b26};
@define-color insensitive_bg_color ${surface_variant:-#24283b};
@define-color borders alpha(${on_surface:-#c0caf5}, 0.1);

window { background-color: @theme_bg_color; color: @theme_fg_color; }
button { background-color: @theme_selected_bg_color; color: @theme_selected_fg_color; border-radius: 4px; padding: 4px 12px; }
button:hover { opacity: 0.9; }
entry { background-color: @theme_base_color; color: @theme_text_color; border-color: @borders; }
GTKCSS
    
    cp ~/.config/gtk-3.0/gtk.css ~/.config/gtk-4.0/gtk.css 2>/dev/null || true
    echo "  ✓ GTK3/GTK4 themes"
fi

# 6. Qt theming
if [ -f ~/.config/matugen/colors.sh ]; then
    source ~/.config/matugen/colors.sh
    
    mkdir -p ~/.config/Kvantum/Matugen
    
    cat > ~/.config/Kvantum/Matugen/Matugen.kvconfig << KVANTUM
[General]
author=Matugen
comment=Auto-generated
opacity=100

[%General]
base_color=${surface:-#1a1b26}
bg_color=${surface:-#1a1b26}
fg_color=${on_surface:-#c0caf5}
link_color=${primary:-#7aa2f7}
tooltip_bg_color=${surface_variant:-#24283b}
tooltip_fg_color=${on_surface:-#c0caf5}
KVANTUM
    
    echo "  ✓ Qt themes via Kvantum"
fi

# 7. Reload applications
echo ""
echo "🔄 Reloading applications..."
pkill -USR1 kitty 2>/dev/null && echo "  ✓ Kitty reloaded" || true
pkill -USR2 waybar 2>/dev/null && echo "  ✓ Waybar reloaded" || true

for socket in $(ls /tmp/nvim.*/0 2>/dev/null); do
    nvim --server "$socket" --remote-send ':source ~/.config/nvim/colors.vim<CR>' 2>/dev/null || true
done
echo "  ✓ Neovim reloaded"

echo ""
echo "✅ All themes updated!"
RELOADSCRIPT
chmod +x ~/.config/matugen/reload-all.sh

# Change wallpaper script
cat > ~/.config/niri/scripts/change-wallpaper.sh << 'WALLSCRIPT'
#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

if [ ! -d "$WALLPAPER_DIR" ] || [ -z "$(ls -A "$WALLPAPER_DIR" 2>/dev/null)" ]; then
    notify-send "Wallpaper" "No wallpapers found" 2>/dev/null || true
    exit 1
fi

WALLPAPERS=($(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \)))
if [ ${#WALLPAPERS[@]} -eq 0 ]; then
    notify-send "Wallpaper" "No images found" 2>/dev/null || true
    exit 1
fi

RANDOM_WALLPAPER="${WALLPAPERS[RANDOM % ${#WALLPAPERS[@]}]}"
cp "$RANDOM_WALLPAPER" ~/.config/wallpaper/current.jpg
pkill swaybg 2>/dev/null || true
swaybg -i "$RANDOM_WALLPAPER" -m fill &
~/.config/matugen/reload-all.sh
notify-send -t 3000 "🎨 Wallpaper Changed" "All themes updated!" 2>/dev/null || true
WALLSCRIPT
chmod +x ~/.config/niri/scripts/change-wallpaper.sh

# Generate initial themes
~/.config/matugen/reload-all.sh >> "$LOG_FILE" 2>&1
print_success "Matugen configured with full system theming"

#==============================================================================
# STEP 11: ZSH CONFIGURATION
#==============================================================================
CURRENT_STEP=11
print_step "$CURRENT_STEP" "Configuring ZSH"

cat > ~/.zshrc << 'ZSHCONFIG'
# Plugins
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null

# Environment
export EDITOR='nvim'
export VISUAL='nvim'
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland
export XDG_SESSION_TYPE=wayland
export XCURSOR_THEME=Bibata-Modern-Classic
export XCURSOR_SIZE=24
export QT_QPA_PLATFORMTHEME=qt5ct
export QT_STYLE_OVERRIDE=kvantum
export GTK_THEME=Adwaita-dark

# Matugen colors
if [ -f ~/.config/matugen/colors.sh ]; then
    source ~/.config/matugen/colors.sh
fi

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
alias fetch='clear && fastfetch --logo none | sed "s/^/  /"'
alias zshrc='nvim ~/.zshrc'
alias vimrc='nvim ~/.config/nvim/init.vim'
alias waybarc='nvim ~/.config/waybar/config.jsonc'
alias waybarcss='nvim ~/.config/waybar/style.css'
alias nc='nvim ~/.config/niri/config.kdl'
alias reload-theme='~/.config/matugen/reload-all.sh'

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
    # Pipewire já está rodando como serviço de sistema (archinstall)
    # Apenas inicia o niri
    exec niri
fi
ZSHCONFIG

if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s $(which zsh) 2>/dev/null || print_warning "Could not change default shell to ZSH"
    print_success "ZSH configured"
else
    print_success "ZSH already default shell"
fi

#==============================================================================
# STEP 12: KITTY CONFIGURATION
#==============================================================================
CURRENT_STEP=12
print_step "$CURRENT_STEP" "Configuring Kitty terminal"

mkdir -p ~/.config/kitty

cat > ~/.config/kitty/kitty.conf << 'KITTYCONF'
include colors.conf

font_family JetBrains Mono
font_size 11.0
window_padding_width 10
hide_window_decorations yes
confirm_os_window_close 0
cursor_shape beam
cursor_beam_thickness 1.5
repaint_delay 6
input_delay 3
sync_to_monitor yes
term xterm-256color
shell zsh
scrollback_lines 10000
wheel_scroll_multiplier 5.0
detect_urls yes
open_url_with default
mouse_hide_wait 2.0

map ctrl+c copy_to_clipboard
map ctrl+v paste_from_clipboard
map ctrl+shift+n new_os_window
map ctrl+shift+c copy_to_clipboard
map ctrl+shift+v paste_from_clipboard
KITTYCONF
print_success "Kitty configured"

#==============================================================================
# STEP 13: NEOVIM CONFIGURATION
#==============================================================================
CURRENT_STEP=13
print_step "$CURRENT_STEP" "Configuring Neovim"

mkdir -p ~/.config/nvim
mkdir -p ~/.local/share/nvim/site/autoload

curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim 2>/dev/null
print_success "vim-plug installed"

cat > ~/.config/nvim/init.vim << 'NVIMCONF'
if filereadable(expand('~/.config/nvim/colors.vim'))
    source ~/.config/nvim/colors.vim
endif

call plug#begin('~/.local/share/nvim/plugged')
Plug 'nvim-lualine/lualine.nvim'
Plug 'kyazdani42/nvim-web-devicons'
Plug 'preservim/nerdtree'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'norcalli/nvim-colorizer.lua'
call plug#end()

set number
set relativenumber
set numberwidth=4
set cursorline
set signcolumn=yes
set ruler
set showcmd
set showmode
set title
set showtabline=2
set laststatus=2
set tabstop=4
set shiftwidth=4
set expandtab
set smartindent
set autoindent
set mouse=a
set clipboard=unnamedplus
set termguicolors

lua << EOF
require'nvim-treesitter.configs'.setup {
  highlight = { enable = true },
}
require('lualine').setup {
  options = { theme = 'auto', icons_enabled = true }
}
require'colorizer'.setup()
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<leader>fg', builtin.live_grep, {})
vim.keymap.set('n', '<leader>fb', builtin.buffers, {})
EOF

let mapleader = " "
nnoremap <leader>n :NERDTreeToggle<CR>
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
NVIMCONF
print_success "Neovim configured"

#==============================================================================
# STEP 14: NIRI CONFIGURATION
#==============================================================================
CURRENT_STEP=14
print_step "$CURRENT_STEP" "Configuring Niri"

mkdir -p ~/.config/niri/scripts

if [ -f ~/.config/niri/config.kdl ]; then
    cp ~/.config/niri/config.kdl ~/.config/niri/config.kdl.backup
    print_success "Existing niri config backed up"
fi

cat > ~/.config/niri/config.kdl << 'NIRICONFIG'
//==============================================================================
// NIRI CONFIGURATION
//==============================================================================

// Pipewire audio (inicia via systemd user services do archinstall)
spawn-at-startup "sh" "-c" "
    # Garante que os serviços pipewire estão rodando
    systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
    systemctl --user restart pipewire.service pipewire-pulse.service wireplumber.service 2>/dev/null || true
"

// XWayland
spawn-at-startup "xwayland-satellite"

// Waybar
spawn-at-startup "waybar"

// Power profiles
spawn-at-startup "power-profiles-daemon"

// Wallpaper
spawn-at-startup "sh" "-c" "
    if [ -f ~/.config/wallpaper/current.jpg ]; then
        swaybg -i ~/.config/wallpaper/current.jpg -m fill &
    fi
"

// Hotkey overlay
hotkey-overlay {
    skip-at-startup
}

//==============================================================================
// INPUT SETTINGS
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
// DISPLAY OUTPUTS
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
    default-column-width { proportion 0.5; }

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

//==============================================================================
// RECENT WINDOWS & COLORS
//==============================================================================

recent-windows {
    highlight {}
}

include "colors.kdl"

//==============================================================================
// SCREENSHOTS
//==============================================================================

screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

//==============================================================================
// ANIMATIONS
//==============================================================================

animations {}

//==============================================================================
// WINDOW PREFERENCES
//==============================================================================

prefer-no-csd

//==============================================================================
// WINDOW RULES
//==============================================================================

// Picture-in-Picture
window-rule {
    match app-id=r#"firefox$"# title="^Picture-in-Picture$"
    open-floating true
}

// Gaming
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

    // Hotkey overlay
    Mod+Shift+Slash { show-hotkey-overlay; }

    //==========================================================================
    // Applications
    //==========================================================================

    Mod+RETURN hotkey-overlay-title="Terminal: Kitty" { spawn "kitty"; }
    Mod+SPACE hotkey-overlay-title="App Launcher: Fuzzel" { spawn "fuzzel"; }
    Mod+F9 hotkey-overlay-title="File Manager: Nemo" { spawn "nemo"; }
    Mod+F10 hotkey-overlay-title="Web Browser: Librewolf" { spawn "librewolf"; }
    Mod+F11 hotkey-overlay-title="Steam" { spawn "steam-performance"; }

    //==========================================================================
    // System
    //==========================================================================

    Super+Alt+L hotkey-overlay-title="Lock Screen: Swaylock" { spawn "swaylock"; }
    Super+Alt+S allow-when-locked=true hotkey-overlay-title=null { spawn-sh "pkill orca || exec orca"; }
    Ctrl+Alt+Delete { quit skip-confirmation=true; }

    //==========================================================================
    // Multimedia
    //==========================================================================

    XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }
    XF86AudioMute        allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
    XF86AudioMicMute     allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }

    XF86AudioPlay  allow-when-locked=true { spawn-sh "playerctl play-pause"; }
    XF86AudioStop  allow-when-locked=true { spawn-sh "playerctl stop"; }
    XF86AudioPrev  allow-when-locked=true { spawn-sh "playerctl previous"; }
    XF86AudioNext  allow-when-locked=true { spawn-sh "playerctl next"; }

    XF86MonBrightnessUp   allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "+10%"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "--class=backlight" "set" "10%-"; }

    //==========================================================================
    // Appearance
    //==========================================================================

    Mod+W { spawn-sh "pkill -USR1 waybar"; }
    Mod+P { spawn-sh "~/.config/niri/scripts/change-wallpaper.sh"; }
    Mod+Shift+P { spawn-sh "~/.config/matugen/reload-all.sh"; }

    //==========================================================================
    // Window Management
    //==========================================================================

    Mod+O repeat=false { toggle-overview; }
    Mod+K repeat=false { close-window; }
    Mod+F { maximize-column; }
    Mod+Shift+F { fullscreen-window; }

    // Focus movement
    Mod+Left  { focus-column-left; }
    Mod+Down  { focus-window-down; }
    Mod+Up    { focus-window-up; }
    Mod+Right { focus-column-right; }

    Mod+Ctrl+Left  { move-column-left; }
    Mod+Ctrl+Down  { move-window-down; }
    Mod+Ctrl+Up    { move-window-up; }
    Mod+Ctrl+Right { move-column-right; }

    Mod+Home { focus-column-first; }
    Mod+End  { focus-column-last; }
    Mod+Ctrl+Home { move-column-to-first; }
    Mod+Ctrl+End  { move-column-to-last; }

    // Monitor navigation
    Mod+Shift+Left  { focus-monitor-left; }
    Mod+Shift+Down  { focus-monitor-down; }
    Mod+Shift+Up    { focus-monitor-up; }
    Mod+Shift+Right { focus-monitor-right; }

    Mod+Shift+Ctrl+Left  { move-column-to-monitor-left; }
    Mod+Shift+Ctrl+Down  { move-column-to-monitor-down; }
    Mod+Shift+Ctrl+Up    { move-column-to-monitor-up; }
    Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }

    // Workspace navigation
    Mod+Page_Down      { focus-workspace-down; }
    Mod+Page_Up        { focus-workspace-up; }
    Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
    Mod+Ctrl+Page_Up   { move-column-to-workspace-up; }

    Mod+Shift+Page_Down { move-workspace-down; }
    Mod+Shift+Page_Up   { move-workspace-up; }

    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    Mod+Shift+1 { move-column-to-workspace 1; }
    Mod+Shift+2 { move-column-to-workspace 2; }
}
NIRICONFIG
print_success "Niri configured"

#==============================================================================
# STEP 15: WAYBAR CONFIGURATION
#==============================================================================
CURRENT_STEP=15
print_step "$CURRENT_STEP" "Configuring Waybar"

mkdir -p ~/.config/waybar

cat > ~/.config/waybar/config.jsonc << 'WAYBARCONFIG'
{
    "layer": "top",
    "position": "top",
    "height": 32,
    "spacing": 4,
    "margin-top": 0,
    "margin-left": 8,
    "margin-right": 8,
    
    "modules-left": [
        "niri/workspaces",
        "niri/window"
    ],
    "modules-center": [
        "clock"
    ],
    "modules-right": [
        "pulseaudio",
        "backlight",
        "battery",
        "tray"
    ],
    
    "niri/workspaces": {
        "format": "{icon}",
        "format-icons": {
            "1": "1",
            "2": "2",
            "3": "3",
            "4": "4",
            "5": "5"
        },
        "active-only": false,
        "all-outputs": false,
        "on-click": "activate"
    },
    
    "niri/window": {
        "format": "{title}",
        "max-length": 80,
        "icon": true,
        "icon-size": 16
    },
    
    "clock": {
        "format": "{:%H:%M  %d/%m/%Y}",
        "format-alt": "{:%A, %d de %B de %Y}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    
    "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-bluetooth": "{icon} {volume}%",
        "format-muted": "Muted",
        "format-icons": {
            "default": ["", "", ""]
        },
        "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
        "scroll-step": 5
    },
    
    "backlight": {
        "device": "amdgpu_bl1",
        "format": "{icon} {percent}%",
        "format-icons": ["", "", "", "", "", "", "", ""]
    },
    
    "battery": {
        "states": {
            "warning": 30,
            "critical": 15
        },
        "format": "{icon} {capacity}%",
        "format-charging": " {capacity}%",
        "format-plugged": " {capacity}%",
        "format-alt": "{time}",
        "format-icons": ["", "", "", "", ""]
    },
    
    "tray": {
        "icon-size": 16,
        "spacing": 10
    }
}
WAYBARCONFIG

cat > ~/.config/waybar/style.css << 'WAYBARSTYLE'
@import url("colors.css");

* {
    font-family: "JetBrains Mono", "Noto Sans", sans-serif;
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

window#waybar.hidden {
    opacity: 0.2;
}

#workspaces {
    background: alpha(@surface_variant, 0.5);
    padding: 0 8px;
    margin: 4px 0;
}

#workspaces button {
    padding: 0 6px;
    color: @on_surface_variant;
    min-width: 24px;
}

#workspaces button.active {
    color: @primary;
    background: alpha(@primary, 0.2);
}

#workspaces button:hover {
    background: alpha(@primary, 0.1);
    box-shadow: none;
}

#window {
    background: alpha(@surface_variant, 0.3);
    color: @primary;
    padding: 0 15px;
    margin: 4px 0;
    font-style: italic;
}

#clock {
    background: alpha(@surface_variant, 0.5);
    color: @on_surface;
    padding: 0 15px;
    margin: 4px 0;
    font-weight: bold;
}

#pulseaudio {
    background: alpha(@surface_variant, 0.5);
    color: @on_surface;
    padding: 0 12px;
    margin: 4px 0;
}

#pulseaudio.muted {
    color: @error;
}

#backlight {
    background: alpha(@surface_variant, 0.5);
    color: @tertiary;
    padding: 0 12px;
    margin: 4px 0;
}

#battery {
    background: alpha(@surface_variant, 0.5);
    color: @on_surface;
    padding: 0 12px;
    margin: 4px 0;
}

#battery.charging {
    color: @primary;
}

#battery.warning:not(.charging) {
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
WAYBARSTYLE
print_success "Waybar configured"

#==============================================================================
# STEP 16: GAMING OPTIMIZATIONS
#==============================================================================
CURRENT_STEP=16
print_step "$CURRENT_STEP" "Applying gaming optimizations"

sudo tee /usr/local/bin/steam-performance > /dev/null << 'STEAMWRAPPER'
#!/bin/bash
powerprofilesctl set performance
gamemoderun steam
powerprofilesctl set power-saver
STEAMWRAPPER
sudo chmod +x /usr/local/bin/steam-performance
print_success "Steam performance wrapper created"

sudo tee /usr/local/bin/game-performance > /dev/null << 'GAMEWRAPPER'
#!/bin/bash
powerprofilesctl set performance
gamemoderun "$@"
powerprofilesctl set power-saver
GAMEWRAPPER
sudo chmod +x /usr/local/bin/game-performance
print_success "Game performance wrapper created"

sudo tee /etc/sysctl.d/99-gaming.conf > /dev/null << 'SYSCTL'
vm.swappiness=10
vm.vfs_cache_pressure=50
kernel.numa_balancing=0
SYSCTL
sudo sysctl --system > /dev/null 2>&1
print_success "Kernel parameters optimized"

#==============================================================================
# STEP 17: ENABLE SERVICES & AUTO-LOGIN
#==============================================================================
CURRENT_STEP=17
print_step "$CURRENT_STEP" "Enabling services and auto-login"

# Power profiles daemon
if systemctl --user enable power-profiles-daemon.service >> "$LOG_FILE" 2>&1; then
    systemctl --user start power-profiles-daemon.service >> "$LOG_FILE" 2>&1
    print_success "power-profiles-daemon enabled"
else
    print_error "Failed to enable power-profiles-daemon"
fi

# Pipewire - já configurado como systemd user services pelo archinstall
# Apenas verifica se estão ativos
print_step "$CURRENT_STEP" "Verifying Pipewire services (archinstall)"

for service in pipewire.service pipewire-pulse.service wireplumber.service; do
    if systemctl --user is-enabled --quiet "$service" 2>/dev/null; then
        print_success "$service enabled (archinstall)"
    else
        print_warning "$service not enabled - enabling now"
        systemctl --user enable --now "$service" >> "$LOG_FILE" 2>&1
    fi
done

# Matugen watcher
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/matugen-watcher.path << 'WATCHERPATH'
[Unit]
Description=Watch wallpaper for changes

[Path]
PathChanged=%h/.config/wallpaper/current.jpg

[Install]
WantedBy=default.target
WATCHERPATH

cat > ~/.config/systemd/user/matugen-watcher.service << 'WATCHERSERVICE'
[Unit]
Description=Update themes when wallpaper changes

[Service]
Type=oneshot
ExecStart=%h/.config/matugen/reload-all.sh
WATCHERSERVICE

systemctl --user daemon-reload >> "$LOG_FILE" 2>&1
systemctl --user enable --now matugen-watcher.path >> "$LOG_FILE" 2>&1
print_success "Matugen watcher enabled"

# Auto-login
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null << AUTO_LOGIN
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USER --noclear %I \$TERM
AUTO_LOGIN
print_success "Auto-login configured for $USER"

#==============================================================================
# CREATE WEBAPPS
#==============================================================================
print_header "CREATING WEBAPPS"

mkdir -p ~/.local/share/applications

# Discord
cat > ~/.local/share/applications/discord-webapp.desktop << 'DISCORD'
[Desktop Entry]
Name=Discord
Comment=Discord Web App
Exec=librewolf --class Discord --new-window https://discord.com/app
Icon=discord
Type=Application
Categories=Network;InstantMessaging;
StartupWMClass=Discord
DISCORD
print_success "Discord webapp created"

# WhatsApp
cat > ~/.local/share/applications/whatsapp-webapp.desktop << 'WHATSAPP'
[Desktop Entry]
Name=WhatsApp
Comment=WhatsApp Web App
Exec=librewolf --class WhatsApp --new-window https://web.whatsapp.com
Icon=whatsapp
Type=Application
Categories=Network;InstantMessaging;
StartupWMClass=WhatsApp
WHATSAPP
print_success "WhatsApp webapp created"

# Spotify
cat > ~/.local/share/applications/spotify-webapp.desktop << 'SPOTIFY'
[Desktop Entry]
Name=Spotify
Comment=Spotify Web Player
Exec=librewolf --class Spotify --new-window https://open.spotify.com
Icon=spotify
Type=Application
Categories=Audio;Music;Player;
StartupWMClass=Spotify
SPOTIFY
print_success "Spotify webapp created"

#==============================================================================
# FINAL SETUP
#==============================================================================
print_header "FINAL SETUP"

mkdir -p ~/Pictures/Screenshots
print_success "Screenshots directory created"

# Fastfetch config
mkdir -p ~/.config/fastfetch
cat > ~/.config/fastfetch/config.jsonc << 'FASTFETCH'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": { "type": "none" },
    "modules": [
        "title",
        "separator",
        "os",
        "host",
        "kernel",
        "uptime",
        "packages",
        "shell",
        "de",
        "wm",
        "terminal",
        "cpu",
        "gpu",
        "memory",
        "separator",
        "colors"
    ]
}
FASTFETCH
print_success "Fastfetch configured"

# Environment variables
cat > ~/.config/environment.d/theming.conf << 'THEMINGENV'
QT_QPA_PLATFORMTHEME=qt5ct
QT_STYLE_OVERRIDE=kvantum
GTK_THEME=Adwaita-dark
XCURSOR_THEME=Bibata-Modern-Classic
XCURSOR_SIZE=24
THEMINGENV
print_success "Environment variables configured"

# Set initial wallpaper if not exists
if [ ! -f ~/.config/wallpaper/current.jpg ]; then
    if [ -n "$(ls ~/Pictures/Wallpapers/*.jpg 2>/dev/null)" ]; then
        cp "$(ls ~/Pictures/Wallpapers/*.jpg | head -n 1)" ~/.config/wallpaper/current.jpg
    fi
fi

# Generate initial colors
~/.config/matugen/reload-all.sh >> "$LOG_FILE" 2>&1
print_success "Initial themes generated"

#==============================================================================
# SUMMARY
#==============================================================================
print_header "INSTALLATION SUMMARY"

echo -e "${GREEN}✓ Successful operations:${NC} $SUCCESS_COUNT"
echo -e "${RED}✗ Failed operations:${NC} $FAIL_COUNT"

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "\n${YELLOW}Failed items:${NC}"
    for item in "${FAILED_ITEMS[@]}"; do
        echo -e "  ${RED}•${NC} $item"
    done
    echo -e "\n${YELLOW}Check error log at:${NC} $ERROR_LOG"
fi

echo -e "\n${CYAN}Log file:${NC} $LOG_FILE"
echo -e "${CYAN}Error log:${NC} $ERROR_LOG"

echo -e "\n${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Installation Complete!            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}Key bindings:${NC}"
echo "  Mod+Return      → Terminal (Kitty)"
echo "  Mod+Space       → App Launcher (Fuzzel)"
echo "  Mod+F9          → File Manager (Nemo)"
echo "  Mod+F10         → Browser (Librewolf)"
echo "  Mod+F11         → Steam (Performance mode)"
echo "  Mod+W           → Toggle Waybar"
echo "  Mod+P           → Change Wallpaper + Update Themes"
echo "  Mod+Shift+P     → Reload Matugen Themes"
echo "  Print           → Screenshot"
echo ""
echo -e "${YELLOW}Audio (Pipewire):${NC}"
echo "  Started automatically by Niri (via systemd user services)"
echo "  Volume keys: XF86AudioRaise/Lower/Mute"
echo ""
echo -e "${YELLOW}Webapps installed:${NC}"
echo "  • Discord  → ~/.local/share/applications/discord-webapp.desktop"
echo "  • WhatsApp → ~/.local/share/applications/whatsapp-webapp.desktop"
echo "  • Spotify  → ~/.local/share/applications/spotify-webapp.desktop"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Add wallpapers to ~/Pictures/Wallpapers/"
echo "  2. Reboot to test auto-login"
echo "  3. First Neovim launch: run :PlugInstall"
echo "  4. Run 'reload-theme' anytime to refresh colors"
echo ""
echo "Enjoy! 🚀"