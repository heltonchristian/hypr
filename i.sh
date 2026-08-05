#!/bin/bash
# arch-hypr-gamer.sh - Instalação completa do Arch Linux para Gaming/Streaming
# Uso: ./arch-hypr-gamer.sh [--skip-packages] [--help]
# Hyprland no TTY1 | Niri no TTY2

set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# CORES E CONFIGURAÇÕES INICIAIS
# ============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${SCRIPT_DIR}/logs"
readonly LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"
readonly ERROR_LOG="${LOG_DIR}/errors-$(date +%Y%m%d-%H%M%S).log"
readonly CONFIG_DIR="${HOME}/.config"
readonly SCRIPTS_DIR="${HOME}/scripts"

declare -a FAILED_PACKAGES=()
declare -a INSTALLED_PACKAGES=()
declare -a FAILED_FUNCTIONS=()
declare -a SUCCESS_FUNCTIONS=()

# ============================================================================
# FUNÇÕES DE LOG
# ============================================================================
log_info()    { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" "$ERROR_LOG"; }
log_fatal()   { echo -e "${RED}[FATAL]${NC} $1" | tee -a "$LOG_FILE" "$ERROR_LOG"; exit 1; }

log_section() {
    echo ""
    echo -e "${MAGENTA}=========================================${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}=========================================${NC}"
    echo ""
}

run_function() {
    local func_name="$1"
    local func_desc="$2"
    log_info "Executando: $func_desc"
    if $func_name; then
        SUCCESS_FUNCTIONS+=("$func_desc")
        log_success "✓ $func_desc"
        return 0
    else
        FAILED_FUNCTIONS+=("$func_desc")
        log_error "✗ $func_desc"
        return 1
    fi
}

# ============================================================================
# VERIFICAÇÃO INICIAL
# ============================================================================
check_dependencies() {
    if [[ $EUID -eq 0 ]]; then
        log_fatal "Não execute como root."
    fi
    return 0
}

# ============================================================================
# AUTOLOGIN
# ============================================================================
setup_autologin() {
    log_section "AUTOLOGIN"
    
    if ! id "ly" &>/dev/null; then
        sudo useradd -m -G wheel,audio,video,storage,input -s /bin/zsh ly 2>>"$ERROR_LOG" || {
            log_error "Falha ao criar usuário"
            return 1
        }
        echo -e "${YELLOW}Defina uma senha para o usuário 'ly':${NC}"
        sudo passwd ly
        echo "ly ALL=(ALL) ALL" | sudo tee /etc/sudoers.d/ly > /dev/null
    fi
    
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
    sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null << 'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ly --noclear --skip-login %I $TERM
Type=simple
EOF
    
    sudo mkdir -p /etc/systemd/system/getty@tty2.service.d/
    sudo tee /etc/systemd/system/getty@tty2.service.d/autologin.conf > /dev/null << 'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ly --noclear --skip-login %I $TERM
Type=simple
EOF
    
    sudo -u ly tee /home/ly/.zprofile > /dev/null << 'EOF'
if [ -z "${DISPLAY}" ] && [ -z "${WAYLAND_DISPLAY}" ]; then
    case "${XDG_VTNR}" in
        1) exec start-hyprland ;;
        2) exec niri-session ;;
    esac
fi
EOF
    
    sudo chsh -s /bin/zsh ly 2>/dev/null || true
    return 0
}

# ============================================================================
# YAY
# ============================================================================
setup_yay() {
    log_section "YAY"
    
    if command -v yay &> /dev/null; then
        return 0
    fi
    
    sudo pacman -S --noconfirm --needed base-devel git 2>>"$ERROR_LOG" || return 1
    cd /tmp || return 1
    git clone https://aur.archlinux.org/yay-bin.git 2>>"$ERROR_LOG" || return 1
    cd yay-bin || return 1
    makepkg -si --noconfirm 2>>"$ERROR_LOG" || return 1
    cd /tmp && rm -rf yay-bin
    return 0
}

install_packages() {
    local package_type="$1"
    shift
    local packages=("$@")
    
    for package in "${packages[@]}"; do
        local return_code=0
        case "$package_type" in
            "official") sudo pacman -S --noconfirm --needed "$package" 2>>"$ERROR_LOG" || return_code=$? ;;
            "aur")      yay -S --noconfirm --needed "$package" 2>>"$ERROR_LOG" || return_code=$? ;;
        esac
        
        if [[ $return_code -eq 0 ]]; then
            INSTALLED_PACKAGES+=("$package")
        else
            FAILED_PACKAGES+=("$package")
        fi
    done
    return 0
}

# ============================================================================
# PACOTES
# ============================================================================
install_official_packages() {
    log_section "PACOTES OFICIAIS"
    
    local packages=(
        base-devel git sudo openssh zsh neovim amd-ucode linux-firmware
        hyprland wayland-protocols xorg-xwayland
        niri xwayland-satellite
        waybar grim slurp wl-clipboard
        fuzzel nemo nemo-fileroller
        kitty starship zoxide fzf zsh-syntax-highlighting zsh-autosuggestions eza
        pamixer pavucontrol playerctl
        steam gamescope gamemode mangohud
        obs-studio
        btop lm_sensors nvtop amdgpu_top htop tlp
        ttf-jetbrains-mono ttf-font-awesome adobe-source-code-pro-fonts
        solaar power-profiles-daemon swaync hyprpaper spotify-launcher fastfetch
        mesa mesa-utils
        vulkan-radeon vulkan-tools vulkan-headers vulkan-icd-loader
        lib32-vulkan-icd-loader lib32-vulkan-radeon
        libva-mesa-driver libva-utils lib32-libva-mesa-driver
        opencl-mesa opencl-headers clinfo lib32-opencl-mesa
        gst-plugins-bad gst-plugins-good gst-plugins-ugly gst-plugins-base gst-libav ffmpeg
        lib32-mesa lib32-mesa-utils
        lib32-alsa-lib lib32-alsa-plugins lib32-libpulse
        lib32-systemd lib32-gcc-libs lib32-glibc lib32-zlib
        lib32-freetype2 lib32-fontconfig lib32-libpng
        lib32-libx11 lib32-libxext lib32-libxcb lib32-libdrm
        lib32-libgl lib32-libglvnd lib32-llvm-libs
        lib32-libxrandr lib32-libxdamage lib32-libxfixes
        lib32-libxshmfence lib32-libxxf86vm lib32-libxss
        lib32-libxcomposite lib32-libxinerama lib32-libxcursor
        lib32-libxi lib32-libxtst lib32-libpciaccess
        lib32-libelf lib32-libxdmcp lib32-libxau lib32-expat
        qt5ct qt6ct kvantum
        xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
        orchis-theme matugen fnott
    )
    
    install_packages "official" "${packages[@]}"
    return 0
}

install_aur_packages() {
    log_section "PACOTES AUR"
    local packages=(
        librewolf-bin
        qs
        wps-office
        bibata-cursor-theme-bin
    )
    install_packages "aur" "${packages[@]}"
    return 0
}

# ============================================================================
# SERVIÇOS
# ============================================================================
setup_services() {
    log_section "SERVIÇOS"
    
    local services=(systemd-networkd systemd-resolved systemd-timesyncd fstrim.timer tlp power-profiles-daemon)
    for service in "${services[@]}"; do
        sudo systemctl enable "$service" 2>>"$ERROR_LOG" || true
        sudo systemctl start "$service" 2>>"$ERROR_LOG" || true
    done
    return 0
}

# ============================================================================
# PERFORMANCE
# ============================================================================
setup_performance() {
    log_section "PERFORMANCE"
    
    sudo tee /etc/sysctl.d/99-performance.conf > /dev/null << 'EOF'
vm.swappiness=10
vm.max_map_count=1048576
fs.inotify.max_user_watches=524288
EOF
    
    sudo tee /etc/modprobe.d/amdgpu.conf > /dev/null << 'EOF'
options amdgpu si_support=0 cik_support=0 dc=1
options amdgpu ppfeaturemask=0xffffffff
EOF
    
    sudo mkdir -p /etc/gamemode.d/
    sudo tee /etc/gamemode.d/gamemode.ini > /dev/null << 'EOF'
[general]
renice=0
desiredgov=performance
[gpu]
apply_gpu_optimisations=accept-responsibility
amd_performance_level=high
EOF
    return 0
}

# ============================================================================
# SCRIPTS
# ============================================================================
setup_scripts() {
    log_section "SCRIPTS"
    
    mkdir -p "$SCRIPTS_DIR" || return 1
    
    # Steam: performance apenas ao iniciar
    cat > "$SCRIPTS_DIR/steam-performance.sh" << 'EOF'
#!/bin/bash
powerprofilesctl set performance
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json:/usr/share/vulkan/icd.d/radeon_icd.i686.json
export AMD_VULKAN_ICD=RADV
export DISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1=1
gamemoderun steam
powerprofilesctl set balanced
EOF
    chmod +x "$SCRIPTS_DIR/steam-performance.sh"
    
    # Screenshot
    cat > "$SCRIPTS_DIR/screenshot.sh" << 'EOF'
#!/bin/bash
grim -g "$(slurp)" - | wl-copy
EOF
    chmod +x "$SCRIPTS_DIR/screenshot.sh"
    
    cat > "$SCRIPTS_DIR/change-wallpaper.sh" << 'EOF'
#!/bin/bash
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
mkdir -p "$WALLPAPER_DIR"

if [ ! "$(ls -A $WALLPAPER_DIR 2>/dev/null)" ]; then
    curl -s "https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=1920&q=80" -o "$WALLPAPER_DIR/default.jpg"
fi

if [ "$1" = "next" ]; then
    CURRENT=$(hyprctl hyprpaper listactive 2>/dev/null | head -1 | cut -d'=' -f2 | xargs)
    WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" \) | sort | grep -A1 "$CURRENT" | tail -1)
    [ -z "$WALLPAPER" ] && WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" \) | shuf -n1)
else
    WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" \) | shuf -n1)
fi

[ -z "$WALLPAPER" ] && exit 1

hyprctl hyprpaper unload all
hyprctl hyprpaper preload "$WALLPAPER"
hyprctl hyprpaper wallpaper ",$WALLPAPER"

# Aplicar cores do matugen
if command -v matugen &> /dev/null; then
    matugen image "$WALLPAPER" --mode dark --type scheme-tonal-spot
    # Recarregar waybar com novas cores
    pkill -USR1 waybar 2>/dev/null || true
fi

notify-send "Wallpaper" "Alterado!" 2>/dev/null || true
EOF
    chmod +x "$SCRIPTS_DIR/change-wallpaper.sh"
    
    # Toggle waybar
    cat > "$SCRIPTS_DIR/toggle-waybar.sh" << 'EOF'
#!/bin/bash
if pgrep waybar > /dev/null; then
    killall waybar
else
    waybar &
fi
EOF
    chmod +x "$SCRIPTS_DIR/toggle-waybar.sh"
    
    mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Screenshots"
    return 0
}

# ============================================================================
# HYPRLAND CONFIG
# ============================================================================
setup_hyprland() {
    log_section "HYPRLAND CONFIG"
    
    local HYPR_DIR="$CONFIG_DIR/hypr"
    mkdir -p "$HYPR_DIR" || return 1
    
    cat > "$HYPR_DIR/hyprland.lua" << 'EOF'
local terminal    = "kitty"
local fileManager = "nemo"
local browser     = "librewolf"
local menu        = "fuzzel"
local mainMod     = "SUPER"

hl.monitor({ output = "DP-3", mode = "1920x1080@319.976013", position = "0x0", scale = "auto" })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080", position = "1920x0", scale = "auto" })

hl.workspace_rule({ workspace = "1", monitor = "DP-3" })
hl.workspace_rule({ workspace = "2", monitor = "DP-3" })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "special:gaming", monitor = "DP-3" })

-- Jogos vão para special:gaming
hl.window_rule({ name = "steam-gaming", match = { class = "^(steam_app_.*)$" }, workspace = "special:gaming" })
hl.window_rule({ name = "steam-fullscreen", match = { class = "^(steam_app_.*)$" }, fullscreen = true })

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar -c ~/.config/waybar/config -s ~/.config/waybar/style.css &")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("fnott &")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user restart xdg-desktop-portal xdg-desktop-portal-hyprland")
    hl.exec_cmd("solaar --window hide")
end)

hl.env("GTK_THEME", "Orchis-Dark-Compact")
hl.env("ICON_THEME", "Tela-circle-black")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "22")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_SIZE", "22")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("QT_STYLE_OVERRIDE", "kvantum-dark")

hl.config({
    general = {
        gaps_in = 2, gaps_out = 4, border_size = 1,
        col = { active_border = "rgba(FFFFFFff)", inactive_border = "rgba(808080cc)" },
        resize_on_border = false, allow_tearing = false, layout = "dwindle",
    },
    decoration = {
        rounding = 0, active_opacity = 1.0, inactive_opacity = 1.0,
        shadow = { enabled = false }, blur = { enabled = false },
    },
    animations = { enabled = false },
    dwindle = { preserve_split = true },
    master = { new_status = "master" },
    misc = { force_default_wallpaper = -1, disable_hyprland_logo = true },
    xwayland = { force_zero_scaling = true, use_nearest_neighbor = true },
})

hl.config({
    input = {
        kb_layout = "us,br", kb_variant = "intl,abnt2", kb_options = "grp:ralt_toggle",
        follow_mouse = 0, accel_profile = "flat", sensitivity = 0,
        touchpad = { natural_scroll = false },
    },
})

hl.device({ name = "logitech-pro-x-2-dex", sensitivity = 0 })

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + F9", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + F10", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + F11", hl.dsp.exec_cmd("~/scripts/steam-performance.sh"))
hl.bind(mainMod .. " + F12", hl.dsp.exec_cmd("spotify-launcher"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("~/scripts/change-wallpaper.sh"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("~/scripts/toggle-waybar.sh"))
hl.bind(mainMod .. " + K", hl.dsp.window.close())
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("~/scripts/screenshot.sh"))
hl.bind(mainMod .. " + Q", hl.dsp.exit())
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + 0", hl.dsp.workspace.toggle_special("gaming"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
EOF
    
    mkdir -p "$HOME/Pictures/Wallpapers"
    cat > "$CONFIG_DIR/hypr/hyprpaper.conf" << 'EOF'
preload = ~/Pictures/Wallpapers/default.jpg
wallpaper = ,~/Pictures/Wallpapers/default.jpg
splash = false
ipc = true
EOF
    return 0
}

# ============================================================================
# NIRI CONFIG
# ============================================================================
setup_niri() {
    log_section "NIRI CONFIG"
    
    local NIRI_DIR="$CONFIG_DIR/niri"
    mkdir -p "$NIRI_DIR" || return 1
    
    cat > "$NIRI_DIR/config.kdl" << 'EOF'
spawn-at-startup "qs -c noctalia-shell"
spawn-at-startup "xwayland-satellite"
spawn-at-startup "waybar"
spawn-at-startup "fnott"

hotkey-overlay {
    skip-at-startup
}

input {
    focus-follows-mouse
    keyboard {
        xkb {
            layout "us,br"
            options "grp:ralt_toggle"
        }
    }
    mouse {
        accel-profile "flat"
        accel-speed 0.0
    }
}

output "DP-3" {
    mode "1920x1080@319.976"
    scale 1.0
    position x=0 y=0
}

output "HDMI-A-1" {
    mode "1920x1080@60.000"
    scale 1.0
    position x=1920 y=0
}

layout {
    gaps 10
    center-focused-column "never"
    default-column-width { proportion 0.5 }
    focus-ring {
        width 4
        active-color "#ffffff"
        inactive-color "#808080"
    }
    border {
        off
    }
}

screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"
animations {}
prefer-no-csd

binds {
    Print { screenshot; }
    Mod+Return { spawn "kitty"; }
    Mod+Space { spawn "fuzzel"; }
    Mod+F10 { spawn "nemo"; }
    Mod+F9 { spawn "librewolf"; }
    Mod+F11 { spawn "~/scripts/steam-performance.sh"; }
    Mod+F12 { spawn "spotify-launcher"; }
    XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }
    XF86AudioMute allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
    XF86AudioPlay allow-when-locked=true { spawn-sh "playerctl play-pause"; }
    XF86AudioNext allow-when-locked=true { spawn-sh "playerctl next"; }
    XF86AudioPrev allow-when-locked=true { spawn-sh "playerctl previous"; }
    Mod+O { toggle-overview; }
    Mod+K { close-window; }
    Mod+F { maximize-column; }
    Mod+Shift+F { fullscreen-window; }
    Mod+Left { focus-column-left; }
    Mod+Right { focus-column-right; }
    Mod+Up { focus-window-up; }
    Mod+Down { focus-window-down; }
    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+Shift+1 { move-column-to-workspace 1; }
    Mod+Shift+2 { move-column-to-workspace 2; }
    Mod+Shift+3 { move-column-to-workspace 3; }
    Mod+Shift+4 { move-column-to-workspace 4; }
}
EOF
    
    mkdir -p "$HOME/Pictures/Screenshots"
    return 0
}

# ============================================================================
# WAYBAR
# ============================================================================
setup_waybar() {
    log_section "WAYBAR"
    mkdir -p "$CONFIG_DIR/waybar" || return 1
    
    cat > "$CONFIG_DIR/waybar/config" << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 24,
    "modules-left": ["wlr/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["cpu", "memory", "pulseaudio"],
    "wlr/workspaces": {
        "format": "{icon}",
        "all-outputs": false,
        "active-only": false,
        "on-click": "activate"
    },
    "clock": {
        "format": "{:%H:%M}",
        "interval": 1,
        "tooltip": false
    },
    "cpu": {
        "format": "CPU {usage}%",
        "interval": 1
    },
    "memory": {
        "format": "RAM {}%",
        "interval": 1
    },
    "pulseaudio": {
        "format": "VOL {volume}%",
        "format-muted": "MUTE",
        "on-click": "pavucontrol"
    }
}
EOF
    
    cat > "$CONFIG_DIR/waybar/style.css" << 'EOF'
@import "../matugen/waybar.css";

* {
    border: none;
    border-radius: 0;
    font-family: "JetBrains Mono", monospace;
    font-size: 11px;
    min-height: 0;
}

window#waybar {
    background: alpha(@surface, 0.85);
    color: @on_surface;
}

#workspaces button {
    padding: 0 5px;
    color: alpha(@on_surface, 0.4);
}

#workspaces button.active {
    color: @primary;
}

#workspaces button.visible {
    color: alpha(@on_surface, 0.7);
}

#clock, #cpu, #memory, #pulseaudio {
    padding: 0 10px;
    color: @on_surface;
}

#pulseaudio.muted {
    color: @error;
}
EOF
    return 0
}

# ============================================================================
# FUZZEL
# ============================================================================
setup_fuzzel() {
    log_section "FUZZEL"
    mkdir -p "$CONFIG_DIR/fuzzel" || return 1
    cat > "$CONFIG_DIR/fuzzel/fuzzel.ini" << 'EOF'
[main]
font=JetBrains Mono:size=12
width=100
height=400
lines=10
[colors]
background=000000dd
text=ffffffff
match=ffaa00ff
selection=ffffff33
EOF
    return 0
}

# ============================================================================
# KITTY
# ============================================================================
setup_kitty() {
    log_section "KITTY"
    mkdir -p "$CONFIG_DIR/kitty" || return 1
    cat > "$CONFIG_DIR/kitty/kitty.conf" << 'EOF'
font_size 11.0
font_family JetBrains Mono
linux_display_server wayland
background_opacity 0.95
EOF
    return 0
}

# ============================================================================
# NEOVIM COM MATUGEN
# ============================================================================
setup_neovim() {
    log_section "NEOVIM"
    mkdir -p "$CONFIG_DIR/nvim" || return 1
    
    cat > "$CONFIG_DIR/nvim/init.vim" << 'EOF'
set number
set relativenumber
set termguicolors
set mouse=a
set clipboard=unnamedplus
set cursorline
set signcolumn=yes
syntax on
filetype plugin indent on
set tabstop=4
set shiftwidth=4
set expandtab

" Importar cores do matugen
lua require("matugen-colors")
EOF
    
    mkdir -p "$CONFIG_DIR/nvim/lua"
    cat > "$CONFIG_DIR/nvim/lua/matugen-colors.lua" << 'EOF'
local function hex_to_rgb(hex)
    hex = hex:gsub("#", "")
    return {
        tonumber(hex:sub(1, 2), 16),
        tonumber(hex:sub(3, 4), 16),
        tonumber(hex:sub(5, 6), 16)
    }
end

local function apply_colors()
    local file = io.open(vim.fn.expand("~/.config/matugen/colors.css"), "r")
    if not file then return end
    
    local colors = {}
    for line in file:lines() do
        local name, value = line:match("%-%-([%w_]+):%s*(#[%x]+);")
        if name and value then
            colors[name] = value
        end
    end
    file:close()
    
    if colors.background and colors.on_background then
        vim.cmd("highlight Normal guibg=" .. colors.background .. " guifg=" .. colors.on_background)
    end
    if colors.surface and colors.on_surface then
        vim.cmd("highlight LineNr guibg=" .. colors.surface .. " guifg=" .. colors.outline or colors.on_surface)
        vim.cmd("highlight CursorLine guibg=" .. colors.surface)
    end
    if colors.primary then
        vim.cmd("highlight Cursor guifg=" .. colors.on_primary .. " guibg=" .. colors.primary)
    end
end

vim.api.nvim_create_autocmd("VimEnter", { callback = apply_colors })
EOF
    return 0
}

# ============================================================================
# ZSH
# ============================================================================
setup_zsh() {
    log_section "ZSH"
    
    cat > "$HOME/.zshrc" << 'EOF'
export PATH="$HOME/scripts:$HOME/.local/bin:$PATH"
HISTSIZE=10000
SAVEHIST=10000
HISTFILE="$HOME/.zsh_history"
setopt HIST_IGNORE_ALL_DUPS INC_APPEND_HISTORY
autoload -Uz compinit && compinit

alias ls='ls --color=auto'
alias ll='ls -l'
alias vi='nvim'
alias vim='nvim'
alias hc='nvim ~/.config/hypr/hyprland.lua'
alias nc='nvim ~/.config/niri/config.kdl'
alias zshrc='nvim ~/.zshrc'
alias vimrc='nvim ~/.config/nvim/init.vim'
alias update='sudo pacman -Syu'
alias steam='~/scripts/steam-performance.sh'
alias wallpaper='~/scripts/change-wallpaper.sh'
alias screenshot='~/scripts/screenshot.sh'
alias perf='powerprofilesctl set performance'
alias fetch='clear && fastfetch --logo none'
alias l='eza --icons'
alias hexit='hyprctl dispatch exit'

eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

export XDG_SESSION_TYPE=wayland
export GDK_BACKEND=wayland
export QT_QPA_PLATFORM=wayland
export SDL_VIDEODRIVER=wayland
export MOZ_USE_WAYLAND=1
EOF
    
    cat > "$CONFIG_DIR/starship.toml" << 'EOF'
add_newline = false
[character]
success_symbol = "[>](green)"
error_symbol = "[>](red)"
EOF
    return 0
}

# ============================================================================
# TEMAS DARK ALINHADOS COM MATUGEN
# ============================================================================
setup_gtk_theme() {
    log_section "TEMAS DARK + MATUGEN"
    
    mkdir -p "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0" "$CONFIG_DIR/qt5ct" "$CONFIG_DIR/qt6ct"
    mkdir -p "$CONFIG_DIR/Kingsoft/Office6" "$CONFIG_DIR/fnott"
    
    # GTK
    for version in 3.0 4.0; do
        cat > "$CONFIG_DIR/gtk-$version/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Orchis-Dark-Compact
gtk-icon-theme-name=Tela-circle-black
gtk-font-name=JetBrains Mono 11
gtk-cursor-theme-name=Bibata-Modern-Ice
gtk-cursor-theme-size=22
gtk-application-prefer-dark-theme=1
gtk-enable-animations=0
EOF
    done
    
    cat > "$HOME/.gtkrc-2.0" << 'EOF'
gtk-theme-name="Orchis-Dark-Compact"
gtk-icon-theme-name="Tela-circle-black"
gtk-font-name="JetBrains Mono 11"
gtk-cursor-theme-name="Bibata-Modern-Ice"
gtk-cursor-theme-size=22
gtk-application-prefer-dark-theme=1
EOF
    
    # QT
    cat > "$CONFIG_DIR/qt5ct/qt5ct.conf" << 'EOF'
[Appearance]
style=kvantum-dark
custom_palette=true
icon_theme=Tela-circle-black
EOF
    
    cat > "$CONFIG_DIR/qt6ct/qt6ct.conf" << 'EOF'
[Appearance]
style=kvantum-dark
custom_palette=true
icon_theme=Tela-circle-black
EOF
    
    # WPS Office dark
    cat > "$CONFIG_DIR/Kingsoft/Office6/wpsconfig.ini" << 'EOF'
[General]
Theme=dark
UIMode=ribbon
EOF
    
    # Cursor global
    sudo mkdir -p /usr/share/icons/default
    sudo tee /usr/share/icons/default/index.theme > /dev/null << 'EOF'
[Icon Theme]
Inherits=Bibata-Modern-Ice
EOF
    
    # Fnott
    cat > "$CONFIG_DIR/fnott/fnott.ini" << 'EOF'
[main]
timeout=3
anchor=top-right
padding=10
max-width=400
font=JetBrains Mono:size=11
EOF
    
    # XDG Portal OBS
    sudo mkdir -p /etc/xdg
    sudo tee /etc/xdg/xdg-desktop-portal-hyprland.conf > /dev/null << 'EOF'
[preferred]
default=hyprland
org.freedesktop.impl.portal.ScreenCast=hyprland
org.freedesktop.impl.portal.Screenshot=hyprland
[screencast]
enable=true
EOF
    
    sudo tee /etc/xdg/xdg-desktop-portal.conf > /dev/null << 'EOF'
[preferred]
default=hyprland
org.freedesktop.impl.portal.FileChooser=gtk
EOF
    
    systemctl --user restart xdg-desktop-portal 2>/dev/null || true
    systemctl --user restart xdg-desktop-portal-hyprland 2>/dev/null || true
    
    return 0
}

# ============================================================================
# REPORT
# ============================================================================
report_results() {
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "Pacotes: ${GREEN}${#INSTALLED_PACKAGES[@]} ok${NC} / ${RED}${#FAILED_PACKAGES[@]} falha${NC}"
    if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
        for pkg in "${FAILED_PACKAGES[@]}"; do echo -e "  ${RED}x${NC} $pkg"; done
    fi
    echo -e "Funções: ${GREEN}${#SUCCESS_FUNCTIONS[@]} ok${NC} / ${RED}${#FAILED_FUNCTIONS[@]} falha${NC}"
    echo -e "TTY1: Hyprland | TTY2: Niri | Log: ${LOG_FILE}"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    
    local skip_packages=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-packages) skip_packages=true; shift ;;
            --help) echo "Uso: $0 [--skip-packages]"; exit 0 ;;
            *) shift ;;
        esac
    done
    
    check_dependencies || exit 1
    
    local functions=(
        "setup_autologin|Autologin"
        "setup_yay|Yay"
        "install_official_packages|Pacotes Oficiais"
        "install_aur_packages|Pacotes AUR"
        "setup_services|Serviços"
        "setup_performance|Performance"
        "setup_scripts|Scripts (gatilhos)"
        "setup_hyprland|Hyprland"
        "setup_niri|Niri"
        "setup_waybar|Waybar"
        "setup_fuzzel|Fuzzel"
        "setup_kitty|Kitty"
        "setup_neovim|Neovim + Matugen"
        "setup_zsh|ZSH"
        "setup_gtk_theme|Temas Dark + Fnott"
    )
    
    for func_entry in "${functions[@]}"; do
        local func_name="${func_entry%|*}"
        local func_desc="${func_entry#*|}"
        
        if [[ "$skip_packages" == true ]] && [[ "$func_name" =~ ^install_ ]]; then
            continue
        fi
        
        run_function "$func_name" "$func_desc" || true
    done
    
    report_results
}

main "$@"
