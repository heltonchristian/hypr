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
# AUTOLOGIN - Hyprland TTY1 | Niri TTY2
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
    
    # TTY1 - Hyprland
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
    sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null << 'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ly --noclear %I $TERM
EOF
    
    # TTY2 - Niri
    sudo mkdir -p /etc/systemd/system/getty@tty2.service.d/
    sudo tee /etc/systemd/system/getty@tty2.service.d/autologin.conf > /dev/null << 'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ly --noclear %I $TERM
EOF
    
    # .zprofile - Iniciar WM conforme TTY
    sudo -u ly tee /home/ly/.zprofile > /dev/null << 'EOF'
if [ -z "${DISPLAY}" ] && [ -z "${WAYLAND_DISPLAY}" ]; then
    case "${XDG_VTNR}" in
        1) exec Hyprland ;;
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
        # Base
        base-devel git sudo openssh zsh neovim amd-ucode linux-firmware
        
        # Hyprland + Niri
        hyprland wayland-protocols xwayland
        niri xwayland-satellite
        
        # Interface
        waybar grim slurp wl-clipboard
        fuzzel nemo nemo-fileroller
        
        # Terminal
        kitty starship zoxide fzf zsh-syntax-highlighting zsh-autosuggestions eza
        
        # Audio
        pipewire pipewire-pulse wireplumber pipewire-alsa
        pamixer pavucontrol playerctl
        
        # Gaming
        steam gamescope gamemode mangohud
        
        # Streaming
        obs-studio
        
        # Monitoramento
        btop lm_sensors nvtop amdgpu_top
        
        # Utilitários
        htop tlp
        ttf-jetbrains-mono ttf-font-awesome adobe-source-code-pro-fonts
        solaar power-profiles-daemon swaync hyprpaper spotify-launcher fastfetch
        
        # ====================================================================
        # DRIVERS AMD - VULKAN
        # ====================================================================
        mesa mesa-utils
        vulkan-radeon vulkan-tools vulkan-headers vulkan-icd-loader
        lib32-vulkan-icd-loader lib32-vulkan-radeon
        libva-mesa-driver libva-utils lib32-libva-mesa-driver
        opencl-mesa opencl-headers clinfo lib32-opencl-mesa
        
        # Codecs
        gst-plugins-bad gst-plugins-good gst-plugins-ugly gst-plugins-base gst-libav ffmpeg
        
        # 32-bit para Steam
        lib32-mesa lib32-mesa-utils
        lib32-alsa-lib lib32-alsa-plugins lib32-libpulse lib32-pipewire
        lib32-systemd lib32-gcc-libs lib32-glibc lib32-zlib
        lib32-freetype2 lib32-fontconfig lib32-libpng
        lib32-libx11 lib32-libxext lib32-libxcb lib32-libdrm
        lib32-libgl lib32-libglvnd lib32-llvm-libs
        lib32-libxrandr lib32-libxdamage lib32-libxfixes
        lib32-libxshmfence lib32-libxxf86vm lib32-libxss
        lib32-libxcomposite lib32-libxinerama lib32-libxcursor
        lib32-libxi lib32-libxtst lib32-libpciaccess
        lib32-libelf lib32-libxdmcp lib32-libxau lib32-expat
    )
    
    install_packages "official" "${packages[@]}"
    return 0
}

install_aur_packages() {
    log_section "PACOTES AUR"
    local packages=(
        librewolf-bin
        orchis-theme-git
        qs
        wps-office
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
    
    local user_services=(pipewire pipewire-pulse wireplumber)
    for service in "${user_services[@]}"; do
        systemctl --user enable "$service" 2>/dev/null || true
        systemctl --user start "$service" 2>/dev/null || true
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
    
    sudo mkdir -p /etc/vulkan/
    sudo tee /etc/vulkan/vk_radv.conf > /dev/null << 'EOF'
RADV_PERFTEST=aco
EOF
    return 0
}

# ============================================================================
# SCRIPTS
# ============================================================================
setup_scripts() {
    log_section "SCRIPTS"
    
    mkdir -p "$SCRIPTS_DIR" || return 1
    
    cat > "$SCRIPTS_DIR/steam-performance.sh" << 'EOF'
#!/bin/bash
powerprofilesctl set performance
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json:/usr/share/vulkan/icd.d/radeon_icd.i686.json
export AMD_VULKAN_ICD=RADV
export RADV_PERFTEST=aco
export DISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1=1
gamemoderun steam "$@"
powerprofilesctl set balanced
EOF
    chmod +x "$SCRIPTS_DIR/steam-performance.sh"
    
    cat > "$SCRIPTS_DIR/screenshot.sh" << 'EOF'
#!/bin/bash
grim -g "$(slurp)" - | wl-copy
EOF
    chmod +x "$SCRIPTS_DIR/screenshot.sh"
    
    cat > "$SCRIPTS_DIR/change-wallpaper.sh" << 'EOF'
#!/bin/bash
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
mkdir -p "$WALLPAPER_DIR"
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" \) | shuf -n1)
[ -z "$WALLPAPER" ] && exit 1
hyprctl hyprpaper unload all
hyprctl hyprpaper preload "$WALLPAPER"
hyprctl hyprpaper wallpaper ",$WALLPAPER"
EOF
    chmod +x "$SCRIPTS_DIR/change-wallpaper.sh"
    
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

hl.window_rule({ name = "steam-gaming", match = { class = "^(steam_app_.*)$" }, workspace = "special:gaming" })
hl.window_rule({ name = "steam-fullscreen", match = { class = "^(steam_app_.*)$" }, fullscreen = true })

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar & hyprpaper")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("solaar --window hide")
end)

hl.env("GTK_THEME", "Orchis-Dark-Compact")
hl.env("ICON_THEME", "Tela-circle-black")
hl.env("XCURSOR_THEME", "Bibata-Original-Ice")
hl.env("XCURSOR_SIZE", "22")
hl.env("HYPRCURSOR_SIZE", "22")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("LIBGL_ALWAYS_SOFTWARE", "0")
hl.env("AMD_VULKAN_ICD", "radeon")
hl.env("RADV_PERFTEST", "aco")
hl.env("VK_ICD_FILENAMES", "/usr/share/vulkan/icd.d/radeon_icd.x86_64.json:/usr/share/vulkan/icd.d/radeon_icd.i686.json")
hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.env("PIPEWIRE_LATENCY", "64/48000")
hl.env("PIPEWIRE_QUANTUM", "64")

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
    misc = { force_default_wallpaper = -1, disable_hyprland_logo = true, animate_manual_resizes = false, animate_mouse_windowdragging = false },
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
hl.bind(mainMod .. " + K", hl.dsp.window.close())
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("~/scripts/screenshot.sh"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("killall waybar || waybar"))
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
// Niri Configuration - Gaming/Streaming

spawn-sh-at-startup "qs -c noctalia-shell"
spawn-at-startup "xwayland-satellite"
spawn-at-startup "waybar"

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
        active-color "#ffffff"
        inactive-color "#808080"
    }

    border {
        off
        width 2
        active-color "#ffffff"
        inactive-color "#808080"
        urgent-color "#9b0000"
    }

    shadow {
        softness 30
        spread 5
        offset x=0 y=5
        color "#0007"
    }
}

screenshot-path "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"

animations {
}

prefer-no-csd

window-rule {
    match app-id=r#"^org\.wezfurlong\.wezterm$"#
    default-column-width {}
}

window-rule {
    match app-id=r#"firefox$"# title="^Picture-in-Picture$"
    open-floating true
}

binds {
    Print { screenshot; }
    Ctrl+Print { screenshot-screen; }
    Alt+Print { screenshot-window; }

    Mod+F1 { switch-layout "next"; }

    Mod+Shift+Slash { show-hotkey-overlay; }

    Mod+RETURN { spawn "kitty"; }
    Mod+SPACE { spawn "fuzzel"; }
    Mod+F10 { spawn "nemo"; }
    Mod+F9 { spawn "librewolf"; }
    Mod+F11 { spawn "~/scripts/steam-performance.sh"; }
    Mod+F12 { spawn "spotify-launcher"; }

    Super+Alt+L { spawn "swaylock"; }

    XF86AudioRaiseVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn-sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"; }
    XF86AudioMute        allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; }
    XF86AudioMicMute     allow-when-locked=true { spawn-sh "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"; }

    XF86AudioPlay        allow-when-locked=true { spawn-sh "playerctl play-pause"; }
    XF86AudioStop        allow-when-locked=true { spawn-sh "playerctl stop"; }
    XF86AudioPrev        allow-when-locked=true { spawn-sh "playerctl previous"; }
    XF86AudioNext        allow-when-locked=true { spawn-sh "playerctl next"; }

    Mod+O repeat=false { toggle-overview; }
    Mod+K repeat=false { close-window; }

    Mod+F { maximize-column; }
    Mod+Shift+F { fullscreen-window; }

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

    Mod+Shift+Left  { focus-monitor-left; }
    Mod+Shift+Down  { focus-monitor-down; }
    Mod+Shift+Up    { focus-monitor-up; }
    Mod+Shift+Right { focus-monitor-right; }

    Mod+Shift+Ctrl+Left  { move-column-to-monitor-left; }
    Mod+Shift+Ctrl+Down  { move-column-to-monitor-down; }
    Mod+Shift+Ctrl+Up    { move-column-to-monitor-up; }
    Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }

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
    Mod+6 { focus-workspace 6; }
    Mod+7 { focus-workspace 7; }
    Mod+8 { focus-workspace 8; }
    Mod+9 { focus-workspace 9; }
    Mod+Shift+1 { move-column-to-workspace 1; }
    Mod+Shift+2 { move-column-to-workspace 2; }
    Mod+Shift+3 { move-column-to-workspace 3; }
    Mod+Shift+4 { move-column-to-workspace 4; }
    Mod+Shift+5 { move-column-to-workspace 5; }
    Mod+Shift+6 { move-column-to-workspace 6; }
    Mod+Shift+7 { move-column-to-workspace 7; }
    Mod+Shift+8 { move-column-to-workspace 8; }
    Mod+Shift+9 { move-column-to-workspace 9; }
}
EOF
    
    mkdir -p "$HOME/Pictures/Screenshots"
    return 0
}

# ============================================================================
# WAYBAR (Hyprland + Niri)
# ============================================================================
setup_waybar() {
    log_section "WAYBAR"
    
    mkdir -p "$CONFIG_DIR/waybar" || return 1
    
    # Config para Hyprland
    cat > "$CONFIG_DIR/waybar/config-hyprland" << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 24,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["cpu", "memory", "pulseaudio"],
    "hyprland/workspaces": {
        "format": "{icon}",
        "on-click": "activate",
        "persistent_workspaces": {
            "1": [], "2": [], "3": [], "4": [], "special:gaming": []
        }
    },
    "clock": {
        "format": "{:%H:%M}",
        "interval": 1
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
    
    # Config para Niri
    cat > "$CONFIG_DIR/waybar/config-niri" << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 24,
    "modules-left": ["wlr/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["cpu", "memory", "pulseaudio"],
    "wlr/workspaces": {
        "format": "{icon}",
        "on-click": "activate",
        "all-outputs": false
    },
    "clock": {
        "format": "{:%H:%M}",
        "interval": 1
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
    
    # Style comum
    cat > "$CONFIG_DIR/waybar/style.css" << 'EOF'
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrains Mono", monospace;
    font-size: 11px;
    min-height: 0;
}
window#waybar {
    background: rgba(0, 0, 0, 0.85);
    color: #ffffff;
}
#workspaces button {
    padding: 0 5px;
    color: #666666;
}
#workspaces button.active {
    color: #ffffff;
}
#workspaces button.visible {
    color: #aaaaaa;
}
#clock, #cpu, #memory, #pulseaudio {
    padding: 0 10px;
}
EOF
    
    # Script para iniciar waybar com config correta
    cat > "$SCRIPTS_DIR/start-waybar.sh" << 'EOF'
#!/bin/bash
if pgrep -x Hyprland > /dev/null; then
    killall waybar 2>/dev/null
    waybar -c ~/.config/waybar/config-hyprland &
elif pgrep -x niri > /dev/null; then
    killall waybar 2>/dev/null
    waybar -c ~/.config/waybar/config-niri &
fi
EOF
    chmod +x "$SCRIPTS_DIR/start-waybar.sh"
    
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
confirm_os_window_close 0
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
alias la='ls -a'
alias ll='ls -l'
alias vi='nvim'
alias vim='nvim'
alias hc='nvim ~/.config/hypr/hyprland.lua'
alias nc='nvim ~/.config/niri/config.kdl'
alias zshrc='nvim ~/.zshrc'
alias update='sudo pacman -Syu'
alias steam='~/scripts/steam-performance.sh'
alias wallpaper='~/scripts/change-wallpaper.sh'
alias screenshot='~/scripts/screenshot.sh'
alias perf='powerprofilesctl set performance'
alias balanced='powerprofilesctl set balanced'
alias fetch='clear && fastfetch --logo none'
alias l='eza --icons'

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
# GTK THEME
# ============================================================================
setup_gtk_theme() {
    log_section "TEMA GTK"
    
    mkdir -p "$CONFIG_DIR/gtk-3.0" "$CONFIG_DIR/gtk-4.0"
    
    for version in 3.0 4.0; do
        cat > "$CONFIG_DIR/gtk-$version/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Orchis-Dark-Compact
gtk-icon-theme-name=Tela-circle-black
gtk-font-name=JetBrains Mono 11
gtk-cursor-theme-name=Bibata-Original-Ice
gtk-cursor-theme-size=22
gtk-application-prefer-dark-theme=1
EOF
    done
    
    cat > "$HOME/.gtkrc-2.0" << 'EOF'
gtk-theme-name="Orchis-Dark-Compact"
gtk-icon-theme-name="Tela-circle-black"
gtk-font-name="JetBrains Mono 11"
EOF
    
    gsettings set org.gnome.desktop.interface gtk-theme "Orchis-Dark-Compact" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "Tela-circle-black" 2>/dev/null || true
    
    return 0
}

# ============================================================================
# PIPEWIRE
# ============================================================================
setup_pipewire() {
    log_section "PIPEWIRE"
    sudo mkdir -p /etc/pipewire/pipewire.conf.d/
    sudo tee /etc/pipewire/pipewire.conf.d/99-gaming.conf > /dev/null << 'EOF'
context.properties = { default.clock.rate = 48000, default.clock.quantum = 64 }
EOF
    return 0
}

# ============================================================================
# OBS
# ============================================================================
setup_obs() {
    log_section "OBS STUDIO"
    mkdir -p "$CONFIG_DIR/obs-studio/basic/profiles" "$CONFIG_DIR/obs-studio/plugin_config/obs-xdg-portal"
    
    cat > "$CONFIG_DIR/obs-studio/plugin_config/obs-xdg-portal/config.ini" << 'EOF'
[General]
PortalEnabled=true
PortalRestoreSession=true
PipeWireEnabled=true
RememberSourceSelection=true
EOF
    return 0
}

# ============================================================================
# XDG PORTAL
# ============================================================================
setup_xdg_portal() {
    log_section "XDG PORTAL"
    
    sudo mkdir -p /etc/xdg
    sudo tee /etc/xdg/xdg-desktop-portal-hyprland.conf > /dev/null << 'EOF'
[preferred]
default=hyprland
org.freedesktop.impl.portal.ScreenCast=hyprland
org.freedesktop.impl.portal.Screenshot=hyprland
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
    echo -e "${CYAN}         RELATÓRIO FINAL                ${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
    echo -e "Pacotes: ${GREEN}${#INSTALLED_PACKAGES[@]} ok${NC} / ${RED}${#FAILED_PACKAGES[@]} falha${NC}"
    if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
        for pkg in "${FAILED_PACKAGES[@]}"; do
            echo -e "  ${RED}x${NC} $pkg"
        done
    fi
    echo ""
    echo -e "Funções: ${GREEN}${#SUCCESS_FUNCTIONS[@]} ok${NC} / ${RED}${#FAILED_FUNCTIONS[@]} falha${NC}"
    if [[ ${#FAILED_FUNCTIONS[@]} -gt 0 ]]; then
        for func in "${FAILED_FUNCTIONS[@]}"; do
            echo -e "  ${RED}x${NC} $func"
        done
    fi
    echo ""
    if [[ ${#FAILED_FUNCTIONS[@]} -eq 0 ]] && [[ ${#FAILED_PACKAGES[@]} -eq 0 ]]; then
        echo -e "${GREEN}Tudo instalado com sucesso!${NC}"
    else
        echo -e "${YELLOW}Instalação parcial. Verifique os logs.${NC}"
    fi
    echo ""
    echo -e "TTY1: Hyprland | TTY2: Niri"
    echo -e "Log: ${LOG_FILE}"
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
        "setup_scripts|Scripts"
        "setup_hyprland|Hyprland"
        "setup_niri|Niri"
        "setup_waybar|Waybar"
        "setup_fuzzel|Fuzzel"
        "setup_kitty|Kitty"
        "setup_zsh|ZSH"
        "setup_gtk_theme|Tema GTK"
        "setup_pipewire|PipeWire"
        "setup_obs|OBS Studio"
        "setup_xdg_portal|XDG Portal"
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
