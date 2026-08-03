#!/bin/bash
# arch-hypr-gamer.sh - Instalação completa do Arch Linux para Gaming/Streaming
# Uso: ./arch-hypr-gamer.sh [--full] [--help]

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

declare -a FAILED_PACKAGES=()
declare -a INSTALLED_PACKAGES=()

# ============================================================================
# FUNÇÕES DE LOG E UTILITÁRIOS
# ============================================================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" "$ERROR_LOG"
}

log_fatal() {
    echo -e "${RED}[FATAL]${NC} $1" | tee -a "$LOG_FILE" "$ERROR_LOG"
    exit 1
}

log_section() {
    echo ""
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC} ${CYAN}$1${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

check_dependencies() {
    log_info "Verificando dependências do sistema..."
    local deps=("pacman" "systemctl" "sudo")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_fatal "Dependências faltando: ${missing[*]}. Execute como root em um Arch Linux minimal."
    fi
    
    if [[ $EUID -eq 0 ]]; then
        log_fatal "Este script NÃO deve ser executado como root. Execute como um usuário normal com sudo."
    fi
    
    log_success "Todas as dependências estão instaladas."
}

# ============================================================================
# AUTOLOGIN PARA USUÁRIO EXISTENTE
# ============================================================================
setup_autologin() {
    log_section "CONFIGURANDO AUTOLOGIN PARA USUÁRIO 'ly'"
    
    # Verifica se o usuário existe
    if ! id "ly" &>/dev/null; then
        log_warning "Usuário 'ly' não existe. Criando..."
        sudo useradd -m -G wheel,audio,video,storage,input -s /bin/zsh ly || {
            log_error "Falha ao criar usuário 'ly'."
            return 1
        }
        echo -e "${YELLOW}Defina uma senha para o usuário 'ly':${NC}"
        sudo passwd ly
        echo "ly ALL=(ALL) ALL" | sudo tee -a /etc/sudoers.d/ly
        log_success "Usuário 'ly' criado."
    else
        log_success "Usuário 'ly' já existe."
    fi
    
    # Configurar autologin no TTY1
    log_info "Configurando autologin no TTY1..."
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/
    
    sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null << 'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ly --noclear %I $TERM
EOF

    # Configurar .zprofile para iniciar Hyprland automaticamente
    log_info "Configurando inicialização automática do Hyprland..."
    sudo -u ly tee /home/ly/.zprofile > /dev/null << 'EOF'
# Auto-start Hyprland on login
if [ -z "${DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
    exec Hyprland
fi
EOF
    
    # Garantir que o shell do usuário é zsh
    sudo chsh -s /bin/zsh ly || log_warning "Falha ao mudar shell para zsh"
    
    log_success "Autologin configurado para o usuário 'ly' no TTY1."
}

# ============================================================================
# INSTALAÇÃO DE PACOTES
# ============================================================================
setup_yay() {
    log_section "CONFIGURANDO YAY (AUR Helper)"
    
    if command -v yay &> /dev/null; then
        log_success "yay já está instalado."
        return 0
    fi
    
    log_info "Instalando dependências para yay..."
    sudo pacman -S --noconfirm --needed base-devel git || {
        log_error "Falha ao instalar base-devel e git."
        return 1
    }
    
    cd /tmp
    git clone https://aur.archlinux.org/yay-bin.git || {
        log_error "Falha ao clonar yay."
        return 1
    }
    
    cd yay-bin
    makepkg -si --noconfirm || {
        log_error "Falha ao compilar yay."
        cd /tmp
        rm -rf yay-bin
        return 1
    }
    
    cd /tmp
    rm -rf yay-bin
    
    log_success "yay instalado com sucesso."
}

install_packages() {
    local package_type="$1"
    shift
    local packages=("$@")
    
    log_info "Instalando pacotes $package_type..."
    
    for package in "${packages[@]}"; do
        local return_code=0
        
        case "$package_type" in
            "official")
                sudo pacman -S --noconfirm --needed "$package" 2>>"$ERROR_LOG" || return_code=$?
                ;;
            "aur")
                yay -S --noconfirm --needed "$package" 2>>"$ERROR_LOG" || return_code=$?
                ;;
        esac
        
        if [[ $return_code -eq 0 ]]; then
            INSTALLED_PACKAGES+=("$package")
            log_success "✓ $package"
        else
            FAILED_PACKAGES+=("$package")
            log_error "✗ $package (código: $return_code)"
        fi
    done
}

install_official_packages() {
    log_section "INSTALANDO PACOTES OFICIAIS"
    
    local packages=(
        # Base
        base-devel linux linux-headers linux-firmware amd-ucode git
        sudo openssh zsh neovim
        
        # Hyprland e Wayland
        hyprland wlroots wayland-protocols
        xdg-desktop-portal xdg-desktop-portal-hyprland
        
        # Interface
        waybar
        grim slurp wl-clipboard wl-gammarelay-rs
        
        # Launcher - FUZZEL
        fuzzel
        
        # File Manager
        nautilus
        
        # Terminal e Shell
        kitty starship atuin zoxide fzf
        zsh-syntax-highlighting zsh-autosuggestions eza
        
        # Audio
        pipewire pipewire-pulse wireplumber
        pamixer pavucontrol playerctl
        
        # Gaming
        steam gamescope gamemode mangohud
        
        # Streaming
        obs-studio
        
        # Monitoramento
        btop cava lm_sensors nvtop amdgpu_top
        
        # Utilitários
        htop brightnessctl acpilight tlp
        sdbus-cpp neofetch
        
        # GPU AMD
        mesa vulkan-radeon libva-mesa-driver
        
        # Networking
        systemd-networkd systemd-resolved
        
        # Fontes
        ttf-jetbrains-mono ttf-font-awesome adobe-source-code-pro-fonts
        
        # Outros
        swaync wlogout hyprpaper
        solaar
        spotify-launcher
        matugen
    )
    
    install_packages "official" "${packages[@]}"
}

install_aur_packages() {
    log_section "INSTALANDO PACOTES AUR"
    
    local packages=(
        libva-headless
        corectrl
        radeontop
        proton-ge-custom
        librewolf-bin
    )
    
    install_packages "aur" "${packages[@]}"
}

# ============================================================================
# SERVIÇOS SYSTEMD
# ============================================================================
setup_services() {
    log_section "CONFIGURANDO SERVIÇOS SYSTEMD"
    
    local services=(
        systemd-networkd
        systemd-resolved
        systemd-timesyncd
        fstrim.timer
        tlp
        acpid
    )
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}"; then
            log_info "Ativando: $service"
            sudo systemctl enable "$service" || log_warning "Falha ao ativar $service"
        fi
    done
    
    local user_services=(
        pipewire
        pipewire-pulse
        wireplumber
        xdg-desktop-portal
    )
    
    for service in "${user_services[@]}"; do
        log_info "Ativando serviço de usuário: $service"
        systemctl --user enable "$service" 2>/dev/null || log_warning "Falha ao ativar $service"
    done
    
    local disabled_services=(
        NetworkManager
        cups
        avahi-daemon
        ModemManager
        packagekit
        bluetooth
    )
    
    for service in "${disabled_services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}"; then
            log_info "Desativando: $service"
            sudo systemctl mask "$service" 2>/dev/null || log_warning "Falha ao desativar $service"
        fi
    done
    
    log_success "Serviços configurados."
}

# ============================================================================
# PERFORMANCE TUNING
# ============================================================================
setup_performance() {
    log_section "OTIMIZAÇÕES DE PERFORMANCE"
    
    sudo tee /etc/sysctl.d/99-performance.conf > /dev/null << 'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=20
vm.dirty_background_ratio=10
vm.dirty_expire_centisecs=3000
vm.dirty_writeback_centisecs=500
vm.max_map_count=1048576
vm.overcommit_memory=1
vm.overcommit_ratio=50

net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.core.netdev_max_backlog=5000

fs.inotify.max_user_watches=524288
fs.file-max=2097152

kernel.sched_autogroup_enabled=0
kernel.sched_latency_ns=2000000
kernel.sched_min_granularity_ns=400000
kernel.sched_wakeup_granularity_ns=200000
kernel.numa_balancing=0
kernel.watchdog=0
kernel.printk=3 3 3 3
EOF
    
    sudo tee /etc/modprobe.d/amdgpu.conf > /dev/null << 'EOF'
options amdgpu si_support=0 cik_support=0 dc=1 mcbp=1 psr=0
options amdgpu seamless_boot=1 abmlevel=0 dpm=1 powerplay=1
options amdgpu ppfeaturemask=0xffffffff gpu_recovery=0 sched_policy=0
options amdgpu reset_method=3 radeon_audio=1 enable_psr=0 enable_psr2=0
EOF
    
    sudo tee /etc/udev/rules.d/50-nvme.rules > /dev/null << 'EOF'
ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="nvme[0-9]*n[0-9]*", \
    ATTR{queue/scheduler}="none", \
    ATTR{queue/nomerges}="2", \
    ATTR{queue/rq_affinity}="0", \
    ATTR{queue/read_ahead_kb}="2048", \
    ATTR{queue/nr_requests}="512", \
    ATTR{queue/write_cache}="write back"
EOF
    
    sudo mkdir -p /etc/gamemode.d/
    sudo tee /etc/gamemode.d/gamemode.ini > /dev/null << 'EOF'
[general]
renice=0
desiredgov=performance
softrealtime=auto
reaper_freq=5

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
amd_performance_level=high
amdgpu_pp_override=performance
amdgpu_power_profile_mode=4
amdgpu_workload=3

[ioprio]
ioprio=0
ioclass=idle
EOF
    
    log_success "Otimizações de performance aplicadas."
}

# ============================================================================
# HYPRLAND CONFIG
# ============================================================================
setup_hyprland() {
    log_section "CONFIGURANDO HYPRLAND"
    
    local HYPR_DIR="$CONFIG_DIR/hypr"
    mkdir -p "$HYPR_DIR"
    mkdir -p "$HYPR_DIR/scripts"
    mkdir -p "$HOME/.local/bin"
    
    cat > "$HYPR_DIR/hyprland.lua" << 'EOF'
-- ============================================================================
-- HYPRLAND CONFIG - Performance Gamer/Streamer
-- Hardware: AMD Ryzen 9 9950X3D + Radeon RX 9070 XT
-- ============================================================================

local config = {}

-- ============================================================================
-- PROGRAMS
-- ============================================================================
local terminal = "kitty"
local fileManager = "nautilus"
local browser = "librewolf"
local menu = "fuzzel"
local mainMod = "SUPER"

-- ============================================================================
-- MONITORS & WORKSPACES
-- ============================================================================
config.monitors = {
    "DP-3,1920x1080@319.976013,0x0,auto",
    "HDMI-A-1,1920x1080,1920x0,auto"
}

config.workspaces = {
    "1, monitor:DP-3",
    "2, monitor:DP-3",
    "3, monitor:HDMI-A-1",
    "4, monitor:HDMI-A-1",
    "special:gaming, monitor:DP-3"
}

config.windowrulev2 = {
    "workspace special:gaming, class:^(steam_app_.*)$",
    "fullscreen 1, class:^(steam_app_.*)$",
    "nomaximizerequest, class:.*",
    "nofocus, class:.*",
    "noanim, class:.*",
    "noblur, class:.*",
    "noshadow, class:.*",
    "noborder, class:.*",
    "nofade, class:.*",
    "minsize 1 1, class:.*"
}

-- ============================================================================
-- AUTOSTART
-- ============================================================================
config.exec_once = {
    "waybar & hyprpaper & wl-gammarelay-rs",
    "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
    "solaar --window hide"
}

-- ============================================================================
-- ENVIRONMENT VARIABLES
-- ============================================================================
config.env = {
    -- Themes
    "GTK_THEME,Orchis-Dark-Compact",
    "ICON_THEME,Tela-circle-black",
    "XCURSOR_THEME,Bibata-Original-Ice",
    "XCURSOR_SIZE,22",

    -- Sessão
    "XDG_CURRENT_DESKTOP,Hyprland",
    "XDG_SESSION_TYPE,wayland",
    "XDG_SESSION_DESKTOP,Hyprland",
    "GDK_BACKEND,wayland,x11,*",
    "MOZ_ENABLE_WAYLAND,1",

    -- AMD GPU
    "LIBGL_ALWAYS_SOFTWARE,0",
    "DRI_PRIME,0",
    "AMD_VULKAN_ICD,radeon",
    "RADV_PERFTEST,aco,llvm,shader_ballot,shader_group_ballot",
    "RADV_DEBUG=nohwrt,nocache",
    "VK_ICD_FILENAMES,/usr/share/vulkan/icd.d/radeon_icd.x86_64.json:/usr/share/vulkan/icd.d/radeon_icd.i686.json",
    "VK_LAYER_PATH,/usr/share/vulkan/explicit_layer.d",
    "LIBVA_DRIVER_NAME,radeonsi",
    "MESA_GLSL_CACHE_DISABLE=0",
    "MESA_GLSL_CACHE_MAX_SIZE=2G",
    "GPU_MAX_HEAP_SIZE=100%",
    "GPU_USE_SYNC_OBJECTS=1",

    -- CPU
    "CPU_BOOST,1",
    "FORCE_TSC,1",
    
    -- PipeWire
    "PIPEWIRE_LATENCY=64/48000",
    "PIPEWIRE_QUANTUM=64"
}

-- ============================================================================
-- LOOK AND FEEL - MINIMALISTA
-- ============================================================================
config.general = {
    gaps_in = 0,
    gaps_out = 0,
    border_size = 0,
    col_active_border = "rgba(FFFFFFff)",
    col_inactive_border = "rgba(808080cc)",
    resize_on_border = false,
    allow_tearing = false,
    layout = "dwindle",
    no_cursor_warps = true,
    cursor_inactive_timeout = 0
}

config.decoration = {
    rounding = 0,
    active_opacity = 1,
    inactive_opacity = 1,
    shadow = {
        enabled = false,
        range = 0,
        render_power = 0,
        color = "rgba(00000000)"
    },
    blur = {
        enabled = false,
        size = 0,
        passes = 0,
        vibrancy = 0,
        new_optimizations = false,
        ignore_opacity = false
    },
    drop_shadow = false
}

config.animations = {
    enabled = false,
    bezier = {
        "linear,0,0,1,1"
    },
    animation = {
        "windows, 0, 1, linear, popin",
        "border, 0, 1, linear",
        "fade, 0, 1, linear",
        "workspaces, 0, 1, linear, slide"
    }
}

config.dwindle = {
    pseudotile = true,
    preserve_split = true,
    no_gaps_when_only = false
}

config.master = {
    new_status = "master"
}

config.misc = {
    force_default_wallpaper = -1,
    disable_hyprland_logo = true,
    render_ahead_of_time = 0,
    render_ahead_ms = 0,
    focus_force_dpi = 2,
    animate_manual_resizes = false,
    animate_mouse_windowdragging = false,
    disable_autoreload = true,
    no_direct_scanout = false,
    no_vfr = false,
    enable_swallow = false,
    vfr = true,
    vfr_ms = 1
}

config.xwayland = {
    force_zero_scaling = true,
    use_nearest_neighbor = true
}

-- ============================================================================
-- INPUT
-- ============================================================================
config.input = {
    kb_layout = "us",
    kb_variant = "intl",
    follow_mouse = 1,
    accel_profile = "flat",
    sensitivity = 0,
    force_no_accel = true,
    
    touchpad = {
        natural_scroll = false,
        disable_while_typing = true
    }
}

config.devices = {
    {
        name = "logitech-pro-x-2-dex",
        sensitivity = 0
    }
}

-- ============================================================================
-- KEYBINDINGS - MOVE FOCUS COM SETAS
-- ============================================================================
config.bind = {
    -- Apps
    { mainMod, "Return", "exec", terminal },
    { mainMod, "F9", "exec", browser },
    { mainMod, "F10", "exec", fileManager },
    { mainMod, "F11", "exec", "steam" },
    { mainMod, "F12", "exec", "spotify-launcher" },
    
    -- Utils
    { mainMod, "P", "exec", "~/.local/bin/change-wallpaper.sh" },
    { mainMod, "K", "killactive" },
    { mainMod, "SPACE", "exec", menu },
    { mainMod, "F", "fullscreen", "1" },
    { mainMod .. " SHIFT", "F", "fullscreen", "0" },
    { mainMod .. " SHIFT", "S", "exec", "grim -g \"$(slurp)\" - | wl-copy" },
    { mainMod, "W", "exec", "killall waybar || waybar" },
    { mainMod, "Q", "exit" },

    -- MOVE FOCUS COM SETAS
    { mainMod, "left", "movefocus", "l" },
    { mainMod, "right", "movefocus", "r" },
    { mainMod, "up", "movefocus", "u" },
    { mainMod, "down", "movefocus", "d" },

    -- Workspaces
    { mainMod, "1", "workspace", "1" },
    { mainMod, "2", "workspace", "2" },
    { mainMod, "3", "workspace", "3" },
    { mainMod, "4", "workspace", "4" },
    { mainMod, "S", "togglespecialworkspace", "gaming" },

    -- Move to workspaces
    { mainMod .. " SHIFT", "1", "movetoworkspace", "1" },
    { mainMod .. " SHIFT", "2", "movetoworkspace", "2" },
    { mainMod .. " SHIFT", "3", "movetoworkspace", "3" },
    { mainMod .. " SHIFT", "4", "movetoworkspace", "4" },
    { mainMod .. " SHIFT", "S", "movetoworkspace", "special:gaming" },
    
    -- Alt+Tab
    { "ALT", "Tab", "exec", "~/.config/hypr/scripts/alt-tab.sh" }
}

config.bindel = {
    { "", "XF86AudioRaiseVolume", "exec", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+" },
    { "", "XF86AudioLowerVolume", "exec", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" },
    { "", "XF86AudioMute", "exec", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" },
    { "", "XF86AudioMicMute", "exec", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" },
    { "", "XF86MonBrightnessUp", "exec", "brightnessctl s 5%+" },
    { "", "XF86MonBrightnessDown", "exec", "brightnessctl s 5%-" }
}

config.bindl = {
    { "", "XF86AudioNext", "exec", "playerctl next" },
    { "", "XF86AudioPause", "exec", "playerctl play-pause" },
    { "", "XF86AudioPlay", "exec", "playerctl play-pause" },
    { "", "XF86AudioPrev", "exec", "playerctl previous" }
}

config.bindm = {
    { mainMod, "mouse:272", "movewindow" },
    { mainMod, "mouse:273", "resizewindow" }
}

return config
EOF

    # Script Alt+Tab
    cat > "$HYPR_DIR/scripts/alt-tab.sh" << 'EOF'
#!/bin/bash
CURRENT=$(hyprctl activewindow | grep "Window" | cut -d " " -f 2)
WINDOWS=$(hyprctl clients | grep "Window" | cut -d " " -f 2 | tac)

POS=0
for WINDOW in $WINDOWS; do
    if [ "$WINDOW" = "$CURRENT" ]; then
        break
    fi
    ((POS++))
done

ALL_WINDOWS=($WINDOWS)
NEXT=${ALL_WINDOWS[$(( (POS + 1) % ${#ALL_WINDOWS[@]} ))]}
hyprctl dispatch focuswindow address:$NEXT
EOF
    
    chmod +x "$HYPR_DIR/scripts/alt-tab.sh"
    
    # Script wallpaper
    cat > "$HOME/.local/bin/change-wallpaper.sh" << 'EOF'
#!/bin/bash
WALLPAPER="$1"

if [ -z "$WALLPAPER" ]; then
    WALLPAPER=$(find ~/Pictures/Wallpapers -type f | shuf -n1)
fi

if [ ! -f "$WALLPAPER" ]; then
    echo "Wallpaper não encontrado: $WALLPAPER"
    exit 1
fi

hyprctl hyprpaper preload "$WALLPAPER"
hyprctl hyprpaper wallpaper ",$WALLPAPER"
matugen image "$WALLPAPER" --theme-mode dark
echo "Wallpaper atualizado: $WALLPAPER"
EOF
    
    chmod +x "$HOME/.local/bin/change-wallpaper.sh"
    
    # Hyprpaper config
    cat > "$CONFIG_DIR/hypr/hyprpaper.conf" << 'EOF'
preload = /usr/share/backgrounds/default.png
wallpaper = ,/usr/share/backgrounds/default.png
splash = false
splash_offset = 2.0
ipc = true
EOF
    
    log_success "Hyprland configurado."
}

# ============================================================================
# FUZZEL CONFIG
# ============================================================================
setup_fuzzel() {
    log_section "CONFIGURANDO FUZZEL"
    
    mkdir -p "$CONFIG_DIR/fuzzel"
    
    cat > "$CONFIG_DIR/fuzzel/fuzzel.ini" << 'EOF'
[main]
font=JetBrains Mono:size=12
prompt=>
dmenu=false
layer=overlay
width=800
height=400
lines=10
horizontal-pad=20
vertical-pad=20
inner-pad=10
border-radius=0
border-width=0

[colors]
background=000000dd
text=ffffffff
match=ffaa00ff
selection=ffffff33
selection-text=ffffffff
border=00000000
EOF
    
    log_success "Fuzzel configurado."
}

# ============================================================================
# WAYBAR CONFIG
# ============================================================================
setup_waybar() {
    log_section "CONFIGURANDO WAYBAR"
    
    mkdir -p "$CONFIG_DIR/waybar"
    
    cat > "$CONFIG_DIR/waybar/config" << 'EOF'
{
  "layer": "top",
  "position": "top",
  "height": 24,
  "modules-left": ["hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["cpu", "memory", "temperature", "network", "pulseaudio"],
  
  "hyprland/workspaces": {
    "format": "{icon}",
    "sort-by-number": true,
    "active-only": false,
    "persistent_workspaces": {
      "1": [], "2": [], "3": [], "4": [], "special:gaming": []
    }
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
  
  "temperature": {
    "format": "TEMP {temperatureC}°C",
    "critical-threshold": 80,
    "interval": 1
  },
  
  "network": {
    "format": "{ifname}",
    "format-ethernet": "{ifname}",
    "interval": 5
  },
  
  "pulseaudio": {
    "format": "VOL {volume}%",
    "format-muted": "MUTE",
    "scroll-step": 5
  }
}
EOF
    
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
  padding: 0 5px;
}

#workspaces button {
  padding: 0 8px;
  color: #666666;
}

#workspaces button.active {
  color: #ffffff;
}

#cpu, #memory, #temperature, #network, #pulseaudio {
  padding: 0 8px;
}

#temperature.critical {
  color: #ff5555;
}
EOF
    
    log_success "Waybar configurado."
}

# ============================================================================
# KITTY CONFIG
# ============================================================================
setup_kitty() {
    log_section "CONFIGURANDO KITTY"
    
    mkdir -p "$CONFIG_DIR/kitty"
    
    cat > "$CONFIG_DIR/kitty/kitty.conf" << 'EOF'
font_size 11.0
font_family JetBrains Mono

shell_integration enabled
cursor_shape block
cursor_blink_interval 0
mouse_hide_wait 0
confirm_os_window_close 0
copy_on_select no
allow_remote_control yes
enabled_layouts stack

wayland_titlebar_color system
linux_display_server wayland

sync_to_monitor yes
input_delay 0
fast_input yes
detect_urls no
visual_bell none
enable_audio_bell no
background_opacity 0.95
EOF
    
    log_success "Kitty configurado."
}

# ============================================================================
# ZSH CONFIG
# ============================================================================
setup_zsh() {
    log_section "CONFIGURANDO ZSH"
    
    cat > "$HOME/.zshrc" << 'EOF'
export PATH="$HOME/.local/bin:$PATH"

HISTSIZE=10000
SAVEHIST=10000
HISTFILE="$HOME/.zsh_history"
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS INC_APPEND_HISTORY

autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

setopt EXTENDED_GLOB AUTO_CD CORRECT NO_BEEP AUTO_PUSHD PUSHD_IGNORE_DUPS

alias ls='eza --icons'
alias ll='ls -l'
alias la='ls -la'
alias lt='ls --tree'
alias grep='grep --color=auto'
alias update='sudo pacman -Syu'
alias update-aur='yay -Sua'
alias clean='sudo pacman -Sc'
alias hypr='Hyprland'
alias vim='nvim'
alias steam='gamemoderun gamescope -- steam'

eval "$(starship init zsh)"
eval "$(atuin init zsh)"
eval "$(zoxide init zsh)"

[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

export XDG_SESSION_TYPE=wayland
export GDK_BACKEND=wayland
export QT_QPA_PLATFORM=wayland
export SDL_VIDEODRIVER=wayland
export MOZ_USE_WAYLAND=1
EOF
    
    cat > "$CONFIG_DIR/starship.toml" << 'EOF'
add_newline = false

[character]
success_symbol = "[❯](green)"
error_symbol = "[❯](red)"

[directory]
truncation_length = 2
truncation_symbol = "…/"

[git_branch]
symbol = " "

[time]
disabled = false
format = " [$time]($style) "
style = "bright-white"
time_format = "%H:%M"

[username]
show_always = false
EOF
    
    log_success "ZSH configurado."
}

# ============================================================================
# PIPEWIRE CONFIG
# ============================================================================
setup_pipewire() {
    log_section "CONFIGURANDO PIPEWIRE"
    
    sudo mkdir -p /etc/pipewire/pipewire.conf.d/
    sudo mkdir -p /etc/wireplumber/wireplumber.conf.d/
    
    sudo tee /etc/pipewire/pipewire.conf.d/99-gaming.conf > /dev/null << 'EOF'
context.properties = {
    default.clock.rate = 48000
    default.clock.quantum = 64
    default.clock.min-quantum = 32
    default.clock.max-quantum = 128
}

context.modules = [
    {
        name = libpipewire-module-rtkit
        args = {
            nice.level = -20
            rt.prio = 88
            rt.time.soft = 200000
            rt.time.hard = 200000
        }
        flags = [ ifexists nofail ]
    }
]

pulse.properties = {
    pulse.min.quantum = 64/48000
    pulse.default.clock.rate = 48000
    pulse.default.clock.quantum = 64
}

alsa.properties = {
    alsa.rate = 48000
    alsa.period-num = 2
    alsa.period-size = 64
}
EOF
    
    sudo tee /etc/wireplumber/wireplumber.conf.d/99-gaming.conf > /dev/null << 'EOF'
monitor.alsa.rules = [
    {
        matches = [ { node.name = "~alsa_output.*" } ]
        apply_properties = {
            ["audio.rate"] = 48000
            ["audio.format"] = "S32LE"
            ["node.latency"] = "64/48000"
        }
    }
]
EOF
    
    log_success "PipeWire configurado."
}

# ============================================================================
# OBS STUDIO CONFIG
# ============================================================================
setup_obs() {
    log_section "CONFIGURANDO OBS STUDIO"
    
    mkdir -p "$CONFIG_DIR/obs-studio/basic/profiles"
    mkdir -p "$CONFIG_DIR/obs-studio/basic/scenes"
    mkdir -p "$CONFIG_DIR/obs-studio/plugin_config/obs-xdg-portal"
    
    cat > "$CONFIG_DIR/obs-studio/basic/profiles/gaming.ini" << 'EOF'
[General]
Name=Gaming
Rate=60
FPS=60
BaseCX=1920
BaseCY=1080
OutputCX=1920
OutputCY=1080
SampleRate=48000
VideoEncoderId=obs_amf_h264
AudioDevice=pipewire
UseMultiview=0
UseIdleTime=1
IdleTime=0

[Advanced]
ProcessPriority=HIGH
Renderer=opengl
GPUConversionMode=1
GPUScaleType=1
ColorFormat=NV12
ColorSpace=709
ColorRange=Partial
ScaleType=2
ForceGPU=0
EnableHDR=1

[Audio]
Device=pipewire
SampleRate=48000
Channels=2
BufferSize=64
DisableAudioDucking=1
Track1=1
EOF
    
    cat > "$CONFIG_DIR/obs-studio/plugin_config/obs-xdg-portal/config.ini" << 'EOF'
[General]
CaptureMethod=Portal
PortalEnabled=true
PipeWireEnabled=true
PipeWireBufferSize=64
PipeWireSampleRate=48000
EOF
    
    cat > "$HOME/.local/bin/obs-gaming" << 'EOF'
#!/bin/bash
export OBS_USE_EGL=1
export OBS_USE_GBM=1
export OBS_VAAPI_DEVICE=/dev/dri/renderD128
export PIPEWIRE_LATENCY=64/48000
export PIPEWIRE_QUANTUM=64
export OBS_USE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland

exec nice -n -10 obs-studio --profile Gaming "$@"
EOF
    
    chmod +x "$HOME/.local/bin/obs-gaming"
    
    log_success "OBS Studio configurado."
}

# ============================================================================
# STEAM CONFIG
# ============================================================================
setup_steam() {
    log_section "CONFIGURANDO STEAM"
    
    mkdir -p "$HOME/.config"
    
    cat > "$HOME/.config/gamescope.conf" << 'EOF'
resolution=1920x1080
refresh=319
fullscreen=true
force-grab-cursor=true
adaptive-sync=true
hdr-enabled=true
upscale-filter=linear
framerate-limit=319
immediate-flips=true
rt=true
rt-priority=90
nice-level=-15
EOF
    
    local proton_dir="$HOME/.steam/root/compatibilitytools.d"
    mkdir -p "$proton_dir"
    
    log_info "Baixando Proton GE..."
    cd /tmp
    wget -q https://github.com/GloriousEggroll/proton-ge-custom/releases/latest/download/GE-Proton.tar.gz -O proton-ge.tar.gz 2>/dev/null || {
        log_warning "Falha ao baixar Proton GE."
    }
    
    if [[ -f "proton-ge.tar.gz" ]]; then
        tar xf proton-ge.tar.gz -C "$proton_dir" 2>/dev/null
        rm proton-ge.tar.gz
        log_success "Proton GE instalado."
    fi
    
    log_success "Steam configurado."
}

# ============================================================================
# XDG PORTAL CONFIG
# ============================================================================
setup_xdg_portal() {
    log_section "CONFIGURANDO XDG PORTAL"
    
    sudo tee /etc/xdg/xdg-desktop-portal-hyprland.conf > /dev/null << 'EOF'
[preferred]
default=hyprland

screen-cast=enabled
screencast-chooser=hyprland
org.freedesktop.impl.portal.ScreenCast=hyprland
org.freedesktop.impl.portal.Screenshot=hyprland
org.freedesktop.impl.portal.Wallpaper=hyprland

implicit-commit=1
force-dpms=0
force-drm=1
EOF
    
    sudo tee /etc/xdg/xdg-desktop-portal.conf > /dev/null << 'EOF'
[preferred]
default=hyprland
org.freedesktop.impl.portal.FileChooser=gtk
EOF
    
    log_success "XDG Portal configurado."
}

# ============================================================================
# REPORT
# ============================================================================
report_results() {
    log_section "RESUMO DA INSTALAÇÃO"
    
    log_info "Pacotes instalados: ${#INSTALLED_PACKAGES[@]}"
    
    if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
        log_error "Pacotes com falha (${#FAILED_PACKAGES[@]}):"
        for pkg in "${FAILED_PACKAGES[@]}"; do
            log_error "  ✗ $pkg"
        done
    else
        log_success "✓ Todos os pacotes instalados!"
    fi
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║          ARCH HYPRLAND GAMER/STREAMER INSTALLER          ║"
    echo "║         AMD Ryzen 9 9950X3D + Radeon RX 9070 XT         ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    mkdir -p "$LOG_DIR"
    
    local skip_packages=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-packages) skip_packages=true; shift ;;
            --help)
                echo "Uso: $0 [--skip-packages] [--help]"
                exit 0
                ;;
            *) shift ;;
        esac
    done
    
    check_dependencies
    
    # Configurar autologin primeiro (usuário ly já existe)
    setup_autologin
    
    if [[ "$skip_packages" != true ]]; then
        setup_yay
        install_official_packages
        install_aur_packages
    fi
    
    setup_services
    setup_performance
    setup_hyprland
    setup_fuzzel
    setup_waybar
    setup_kitty
    setup_zsh
    setup_pipewire
    setup_obs
    setup_steam
    setup_xdg_portal
    
    report_results
    
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ INSTALAÇÃO CONCLUÍDA!${NC}"
    echo ""
    echo -e "${YELLOW}Próximos passos:${NC}"
    echo "  1. Reinicie: sudo reboot"
    echo "  2. Login automático como 'ly'"
    echo "  3. Hyprland inicia automaticamente"
    echo ""
    echo -e "${YELLOW}Comandos úteis:${NC}"
    echo "  - Steam:      SUPER+F11"
    echo "  - OBS Gaming: obs-gaming"
    echo "  - Wallpaper:  change-wallpaper.sh <caminho>"
    echo "  - Atualizar:  update"
    echo ""
    echo -e "${CYAN}Log de erros: ${ERROR_LOG}${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
}

main "$@"
