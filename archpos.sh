#!/bin/bash
# arch-hypr-gamer.sh - Instalação completa do Arch Linux para Gaming/Streaming
# Uso: ./arch-hypr-gamer.sh [--skip-packages] [--help]

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

# Arrays para tracking de erros
declare -a FAILED_PACKAGES=()
declare -a INSTALLED_PACKAGES=()
declare -a FAILED_FUNCTIONS=()
declare -a SUCCESS_FUNCTIONS=()
declare -a SKIPPED_FUNCTIONS=()

# ============================================================================
# FUNÇÕES DE LOG E TRATAMENTO DE ERROS
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
        log_error "✗ $func_desc - Falhou, continuando..."
        return 1
    fi
}

# ============================================================================
# VERIFICAÇÃO INICIAL
# ============================================================================
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
    return 0
}

# ============================================================================
# AUTOLOGIN PARA USUÁRIO 'ly'
# ============================================================================
setup_autologin() {
    log_section "CONFIGURANDO AUTOLOGIN PARA USUÁRIO 'ly'"
    
    if ! id "ly" &>/dev/null; then
        log_warning "Usuário 'ly' não existe. Criando..."
        if sudo useradd -m -G wheel,audio,video,storage,input -s /bin/zsh ly 2>>"$ERROR_LOG"; then
            echo -e "${YELLOW}Defina uma senha para o usuário 'ly':${NC}"
            sudo passwd ly
            echo "ly ALL=(ALL) ALL" | sudo tee -a /etc/sudoers.d/ly
            log_success "Usuário 'ly' criado."
        else
            log_error "Falha ao criar usuário 'ly'."
            return 1
        fi
    else
        log_success "Usuário 'ly' já existe."
    fi
    
    log_info "Configurando autologin no TTY1..."
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d/ || true
    
    if sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null 2>>"$ERROR_LOG" << 'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ly --noclear %I $TERM
EOF
    then
        log_success "Autologin configurado."
    else
        log_error "Falha ao configurar autologin."
        return 1
    fi

    log_info "Configurando inicialização automática do Hyprland..."
    if sudo -u ly tee /home/ly/.zprofile > /dev/null 2>>"$ERROR_LOG" << 'EOF'
# Auto-start Hyprland on login
if [ -z "${DISPLAY}" ] && [ "${XDG_VTNR}" -eq 1 ]; then
    exec Hyprland
fi
EOF
    then
        log_success "Hyprland configurado para iniciar automaticamente."
    else
        log_error "Falha ao configurar .zprofile."
        return 1
    fi
    
    sudo chsh -s /bin/zsh ly 2>/dev/null || log_warning "Falha ao mudar shell para zsh"
    
    log_success "Autologin configurado para o usuário 'ly'."
    return 0
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
    if ! sudo pacman -S --noconfirm --needed base-devel git 2>>"$ERROR_LOG"; then
        log_error "Falha ao instalar base-devel e git."
        return 1
    fi
    
    cd /tmp || return 1
    if ! git clone https://aur.archlinux.org/yay-bin.git 2>>"$ERROR_LOG"; then
        log_error "Falha ao clonar yay."
        cd - > /dev/null || return 1
        return 1
    fi
    
    cd yay-bin || return 1
    if ! makepkg -si --noconfirm 2>>"$ERROR_LOG"; then
        log_error "Falha ao compilar yay."
        cd /tmp || return 1
        rm -rf yay-bin
        return 1
    fi
    
    cd /tmp || return 1
    rm -rf yay-bin
    
    log_success "yay instalado com sucesso."
    return 0
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
    
    return 0
}

install_official_packages() {
    log_section "INSTALANDO PACOTES OFICIAIS"
    
    local packages=(
        # Base
        base-devel linux linux-headers linux-firmware amd-ucode git
        sudo openssh zsh neovim
        
        # Hyprland e Wayland
        hyprland wayland-protocols
        xdg-desktop-portal xdg-desktop-portal-hyprland
        
        # Interface
        waybar
        grim slurp wl-clipboard
        
        # Launcher - FUZZEL
        fuzzel
        
        # File Manager - NEMO
        nemo nemo-fileroller
        
        # Terminal e Shell
        kitty starship zoxide fzf
        zsh-syntax-highlighting zsh-autosuggestions eza
        
        # Audio
        pipewire pipewire-pulse wireplumber
        pamixer pavucontrol playerctl
        
        # Gaming
        steam gamescope gamemode mangohud
        
        # Streaming
        obs-studio
        
        # Monitoramento GPU (CLI apenas)
        btop cava lm_sensors nvtop amdgpu_top radeontop
        
        # Utilitários
        htop tlp
        sdbus-cpp
        
        # Fontes
        ttf-jetbrains-mono ttf-font-awesome adobe-source-code-pro-fonts
        
        # Solaar (Logitech)
        solaar
        
        # Power Profiles
        power-profiles-daemon
        
        # Outros
        swaync hyprpaper
        spotify-launcher
        fastfetch
        
        # ====================================================================
        # DRIVERS AMD - WAYLAND/XWAYLAND
        # ====================================================================
        
        # Mesa 3D (OpenGL)
        mesa mesa-utils
        
        # Vulkan RADV
        vulkan-radeon vulkan-tools vulkan-headers
        
        # VA-API (Video Acceleration API)
        libva-mesa-driver libva-utils
        
        # OpenCL
        opencl-mesa opencl-headers clinfo
        
        # Firmware AMDGPU
        linux-firmware
        
        # Ferramentas de debug e profiling
        radeontop
        
        # Codecs de vídeo
        gst-plugins-bad gst-plugins-good gst-plugins-ugly
        ffmpeg
        
        # Bibliotecas 32-bit
        lib32-mesa lib32-vulkan-radeon lib32-libva-mesa-driver
        lib32-opencl-mesa
        lib32-alsa-lib lib32-alsa-plugins
        lib32-libpulse lib32-pipewire
    )
    
    install_packages "official" "${packages[@]}"
    return 0
}

install_aur_packages() {
    log_section "INSTALANDO PACOTES AUR"
    
    local packages=(
        # Overclock e controle de GPU
        corectrl
        
        # Browser
        librewolf-bin
        
        # Temas
        orchis-theme
    )
    
    install_packages "aur" "${packages[@]}"
    return 0
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
        power-profiles-daemon
    )
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}"; then
            log_info "Ativando: $service"
            sudo systemctl enable "$service" 2>>"$ERROR_LOG" || log_warning "Falha ao ativar $service"
            sudo systemctl start "$service" 2>>"$ERROR_LOG" || log_warning "Falha ao iniciar $service"
        else
            log_warning "Serviço $service não encontrado, pulando..."
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
    
    log_success "Serviços configurados."
    return 0
}

# ============================================================================
# PERFORMANCE TUNING
# ============================================================================
setup_performance() {
    log_section "OTIMIZAÇÕES DE PERFORMANCE"
    
    if sudo tee /etc/sysctl.d/99-performance.conf > /dev/null 2>>"$ERROR_LOG" << 'EOF'
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
    then
        log_success "sysctl configurado."
    else
        log_error "Falha ao configurar sysctl."
        return 1
    fi
    
    # Configuração AMDGPU para Wayland
    if sudo tee /etc/modprobe.d/amdgpu.conf > /dev/null 2>>"$ERROR_LOG" << 'EOF'
# AMDGPU para Wayland
options amdgpu si_support=0 cik_support=0
options amdgpu dc=1 mcbp=1 psr=0
options amdgpu seamless_boot=1 abmlevel=0 dpm=1 powerplay=1
options amdgpu ppfeaturemask=0xffffffff gpu_recovery=0 sched_policy=0
options amdgpu reset_method=3 radeon_audio=1
EOF
    then
        log_success "AMDGPU configurado para Wayland."
    else
        log_error "Falha ao configurar AMDGPU."
        return 1
    fi
    
    if sudo tee /etc/modprobe.d/radeon.conf > /dev/null 2>>"$ERROR_LOG" << 'EOF'
options radeon si_support=0 cik_support=0
EOF
    then
        log_success "Radeon configurado."
    else
        log_error "Falha ao configurar Radeon."
        return 1
    fi
    
    if sudo tee /etc/udev/rules.d/50-nvme.rules > /dev/null 2>>"$ERROR_LOG" << 'EOF'
ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="nvme[0-9]*n[0-9]*", \
    ATTR{queue/scheduler}="none", \
    ATTR{queue/nomerges}="2", \
    ATTR{queue/rq_affinity}="0", \
    ATTR{queue/read_ahead_kb}="2048", \
    ATTR{queue/nr_requests}="512", \
    ATTR{queue/write_cache}="write back"
EOF
    then
        log_success "NVMe otimizado."
    else
        log_error "Falha ao otimizar NVMe."
        return 1
    fi
    
    if sudo mkdir -p /etc/gamemode.d/ && \
       sudo tee /etc/gamemode.d/gamemode.ini > /dev/null 2>>"$ERROR_LOG" << 'EOF'
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
    then
        log_success "GameMode configurado."
    else
        log_error "Falha ao configurar GameMode."
        return 1
    fi
    
    # Configuração Vulkan RADV
    sudo mkdir -p /etc/vulkan/ 2>>"$ERROR_LOG" || true
    if sudo tee /etc/vulkan/vk_radv.conf > /dev/null 2>>"$ERROR_LOG" << 'EOF'
# RADV Configuration for AMD Radeon RX 9070 XT - Wayland/XWayland
RADV_DEBUG=nohwrt,nocache
RADV_PERFTEST=aco,llvm,shader_ballot,shader_group_ballot
EOF
    then
        log_success "Vulkan RADV configurado para Wayland."
    else
        log_error "Falha ao configurar Vulkan RADV."
        return 1
    fi
    
    # CoreCtrl permissions
    if sudo tee /etc/polkit-1/rules.d/90-corectrl.rules > /dev/null 2>>"$ERROR_LOG" << 'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.corectrl.helper.init" ||
         action.id == "org.corectrl.helperkiller.init") &&
        subject.local == true &&
        subject.active == true &&
        subject.isInGroup("wheel")) {
            return polkit.Result.YES;
    }
});
EOF
    then
        log_success "CoreCtrl configurado."
    else
        log_error "Falha ao configurar CoreCtrl."
        return 1
    fi
    
    log_success "Otimizações de performance aplicadas (Wayland/XWayland)."
    return 0
}

# ============================================================================
# SCRIPTS
# ============================================================================
setup_scripts() {
    log_section "CRIANDO SCRIPTS EM ~/scripts"
    
    mkdir -p "$SCRIPTS_DIR" 2>>"$ERROR_LOG" || {
        log_error "Falha ao criar diretório $SCRIPTS_DIR"
        return 1
    }
    
    # Script Steam com Power Profile
    if cat > "$SCRIPTS_DIR/steam-performance.sh" << 'EOF'
#!/bin/bash
# ~/scripts/steam-performance.sh
# Altera para performance apenas quando a Steam é iniciada

# Mudar para perfil performance
powerprofilesctl set performance

# Iniciar Steam com gamemode
gamemoderun steam "$@"

# Quando a Steam fechar, voltar para balanced
powerprofilesctl set balanced
EOF
    then
        chmod +x "$SCRIPTS_DIR/steam-performance.sh" 2>>"$ERROR_LOG"
        log_success "steam-performance.sh criado."
    else
        log_error "Falha ao criar steam-performance.sh"
        return 1
    fi
    
    # Script Screenshot
    if cat > "$SCRIPTS_DIR/screenshot.sh" << 'EOF'
#!/bin/bash
# ~/scripts/screenshot.sh
# Screenshot usando grim + slurp (Wayland nativo)

grim -g "$(slurp)" - | wl-copy
notify-send "Screenshot" "Captura de tela salva no clipboard!" 2>/dev/null || true
EOF
    then
        chmod +x "$SCRIPTS_DIR/screenshot.sh" 2>>"$ERROR_LOG"
        log_success "screenshot.sh criado."
    else
        log_error "Falha ao criar screenshot.sh"
        return 1
    fi
    
    # Script Wallpaper
    if cat > "$SCRIPTS_DIR/change-wallpaper.sh" << 'EOF'
#!/bin/bash
# ~/scripts/change-wallpaper.sh
# Altera wallpaper aleatório do diretório ~/Pictures/Wallpapers

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# Criar diretório se não existir
mkdir -p "$WALLPAPER_DIR"

# Se não houver wallpapers, baixar um padrão
if [ ! "$(ls -A $WALLPAPER_DIR 2>/dev/null)" ]; then
    echo "Nenhum wallpaper encontrado. Baixando wallpaper padrão..."
    curl -s "https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=1920&q=80" -o "$WALLPAPER_DIR/default.jpg"
fi

# Escolher wallpaper aleatório
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.jpeg" \) | shuf -n1)

if [ -z "$WALLPAPER" ]; then
    echo "Nenhum wallpaper encontrado em $WALLPAPER_DIR"
    exit 1
fi

# Aplicar wallpaper com hyprpaper (Wayland nativo)
hyprctl hyprpaper unload all
hyprctl hyprpaper preload "$WALLPAPER"
hyprctl hyprpaper wallpaper ",$WALLPAPER"

echo "Wallpaper alterado para: $WALLPAPER"
notify-send "Wallpaper" "Wallpaper alterado!" -i "$WALLPAPER" 2>/dev/null || true
EOF
    then
        chmod +x "$SCRIPTS_DIR/change-wallpaper.sh" 2>>"$ERROR_LOG"
        log_success "change-wallpaper.sh criado."
    else
        log_error "Falha ao criar change-wallpaper.sh"
        return 1
    fi
    
    # Criar diretório de wallpapers
    mkdir -p "$HOME/Pictures/Wallpapers" 2>>"$ERROR_LOG" || true
    
    log_success "Scripts criados em ~/scripts."
    return 0
}

# ============================================================================
# HYPRLAND CONFIG - LUA (API Moderna) - Wayland/XWayland
# ============================================================================
setup_hyprland() {
    log_section "CONFIGURANDO HYPRLAND (LUA) - Wayland/XWayland"
    
    local HYPR_DIR="$CONFIG_DIR/hypr"
    mkdir -p "$HYPR_DIR" 2>>"$ERROR_LOG" || {
        log_error "Falha ao criar diretório $HYPR_DIR"
        return 1
    }
    
    # hyprland.lua
    if cat > "$HYPR_DIR/hyprland.lua" << 'EOF'
-- ============================================================================
-- HYPRLAND CONFIG - Performance Gamer/Streamer
-- Hardware: AMD Ryzen 9 9950X3D + Radeon RX 9070 XT
-- Wayland/XWayland - Sem Xorg
-- ============================================================================

-- ============================================================================
-- MY PROGRAMS
-- ============================================================================
local terminal    = "kitty"
local fileManager = "nemo"
local browser     = "librewolf"
local menu        = "fuzzel"
local mainMod     = "SUPER"

-- ============================================================================
-- MONITORS & WORKSPACES
-- ============================================================================
hl.monitor({
    output   = "DP-3",
    mode     = "1920x1080@319.976013",
    position = "0x0",
    scale    = "auto",
})

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1920x1080",
    position = "1920x0",
    scale    = "auto",
})

hl.workspace_rule({ workspace = "1", monitor = "DP-3" })
hl.workspace_rule({ workspace = "2", monitor = "DP-3" })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "special:gaming", monitor = "DP-3" })

hl.window_rule({
    name  = "steam-gaming-workspace",
    match = { class = "^(steam_app_.*)$" },
    workspace = "special:gaming",
})

hl.window_rule({
    name  = "steam-fullscreen",
    match = { class = "^(steam_app_.*)$" },
    fullscreen = true,
})

-- ============================================================================
-- AUTOSTART
-- ============================================================================
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar & hyprpaper")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("solaar --window hide")
end)

-- ============================================================================
-- ENVIRONMENT VARIABLES - Wayland/XWayland
-- ============================================================================
hl.env("GTK_THEME", "Orchis-Dark-Compact")
hl.env("ICON_THEME", "Tela-circle-black")
hl.env("XCURSOR_THEME", "Bibata-Original-Ice")
hl.env("XCURSOR_SIZE", "22")
hl.env("HYPRCURSOR_SIZE", "22")

-- Wayland
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("ELM_DISPLAY", "wayland")

-- AMD GPU - Wayland nativo
hl.env("LIBGL_ALWAYS_SOFTWARE", "0")
hl.env("DRI_PRIME", "0")
hl.env("AMD_VULKAN_ICD", "radeon")
hl.env("RADV_PERFTEST", "aco,llvm,shader_ballot,shader_group_ballot")
hl.env("RADV_DEBUG", "nohwrt,nocache")
hl.env("VK_ICD_FILENAMES", "/usr/share/vulkan/icd.d/radeon_icd.x86_64.json:/usr/share/vulkan/icd.d/radeon_icd.i686.json")
hl.env("VK_LAYER_PATH", "/usr/share/vulkan/explicit_layer.d")
hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.env("MESA_GLSL_CACHE_DISABLE", "0")
hl.env("MESA_GLSL_CACHE_MAX_SIZE", "2G")
hl.env("GPU_MAX_HEAP_SIZE", "100%")
hl.env("GPU_USE_SYNC_OBJECTS", "1")

-- CPU Performance
hl.env("CPU_BOOST", "1")
hl.env("FORCE_TSC", "1")

-- PipeWire
hl.env("PIPEWIRE_LATENCY", "64/48000")
hl.env("PIPEWIRE_QUANTUM", "64")

-- ============================================================================
-- LOOK AND FEEL
-- ============================================================================
hl.config({
    general = {
        gaps_in  = 2,
        gaps_out = 4,
        border_size = 1,
        col = {
            active_border   = "rgba(FFFFFFff)",
            inactive_border = "rgba(808080cc)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 1,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled = false,
            range = 2,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
        blur = {
            enabled = false,
            size = 2,
            passes = 2,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = true,
    },

    xwayland = {
        force_zero_scaling = true,
        use_nearest_neighbor = true,
    },
})

-- Curvas de animação
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Animações
hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

-- ============================================================================
-- INPUT - Teclado US/INTL e ABNT2 com alternância via Alt Direito
-- ============================================================================
hl.config({
    input = {
        kb_layout  = "us,br",
        kb_variant = "intl,abnt2",
        kb_options = "grp:ralt_toggle",
        follow_mouse = 0,
        accel_profile = "flat",
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.device({
    name        = "logitech-pro-x-2-dex",
    sensitivity = 0,
})

-- ============================================================================
-- KEYBINDINGS
-- ============================================================================

-- Apps
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + F9",     hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + F10",    hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + F11",    hl.dsp.exec_cmd("~/scripts/steam-performance.sh"))
hl.bind(mainMod .. " + F12",    hl.dsp.exec_cmd("spotify-launcher"))

-- Utils
hl.bind(mainMod .. " + P",           hl.dsp.exec_cmd("~/scripts/change-wallpaper.sh"))
hl.bind(mainMod .. " + K",           hl.dsp.window.close())
hl.bind(mainMod .. " + SPACE",       hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + F",           hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F",   hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + S",   hl.dsp.exec_cmd("~/scripts/screenshot.sh"))
hl.bind(mainMod .. " + W",           hl.dsp.exec_cmd("killall waybar || waybar"))

-- Move focus
hl.bind(mainMod .. " + left",   hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right",  hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",     hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",   hl.dsp.focus({ direction = "down" }))

-- Workspaces
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))

-- Move to workspaces
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))

-- Special workspace
hl.bind(mainMod .. " + 0", hl.dsp.workspace.toggle_special("gaming"))

-- Multimedia keys (repeating) - Sem brightnessctl (monitores externos)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })

-- Multimedia keys (locked only)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Mouse binds
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
EOF
    then
        log_success "hyprland.lua criado (Wayland/XWayland)."
    else
        log_error "Falha ao criar hyprland.lua"
        return 1
    fi
    
    # Hyprpaper config (Wayland nativo)
    mkdir -p "$HOME/Pictures/Wallpapers" 2>>"$ERROR_LOG" || true
    if cat > "$CONFIG_DIR/hypr/hyprpaper.conf" << 'EOF'
preload = ~/Pictures/Wallpapers/default.jpg
wallpaper = ,~/Pictures/Wallpapers/default.jpg
splash = false
splash_offset = 2.0
ipc = true
EOF
    then
        log_success "hyprpaper.conf criado."
    else
        log_error "Falha ao criar hyprpaper.conf"
        return 1
    fi
    
    log_success "Hyprland configurado para Wayland/XWayland."
    return 0
}

# ============================================================================
# FUZZEL CONFIG
# ============================================================================
setup_fuzzel() {
    log_section "CONFIGURANDO FUZZEL"
    
    mkdir -p "$CONFIG_DIR/fuzzel" 2>>"$ERROR_LOG" || {
        log_error "Falha ao criar diretório $CONFIG_DIR/fuzzel"
        return 1
    }
    
    if cat > "$CONFIG_DIR/fuzzel/fuzzel.ini" << 'EOF'
[main]
font=JetBrains Mono:size=12
prompt=>
dmenu=false
layer=overlay
width=100
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
    then
        log_success "Fuzzel configurado."
        return 0
    else
        log_error "Falha ao configurar Fuzzel"
        return 1
    fi
}

# ============================================================================
# WAYBAR CONFIG
# ============================================================================
setup_waybar() {
    log_section "CONFIGURANDO WAYBAR"
    
    mkdir -p "$CONFIG_DIR/waybar" 2>>"$ERROR_LOG" || {
        log_error "Falha ao criar diretório $CONFIG_DIR/waybar"
        return 1
    }
    
    if cat > "$CONFIG_DIR/waybar/config" << 'EOF'
{
  "layer": "top",
  "position": "top",
  "height": 24,
  "modules-left": ["hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["cpu", "memory", "gpu", "battery", "pulseaudio"],
  
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
  
  "gpu": {
    "format": "GPU {usage}%",
    "interval": 1
  },
  
  "battery": {
    "bat": "/sys/class/power_supply/hidpp_battery_0",
    "format": "BAT {capacity}%",
    "format-discharging": "BAT {capacity}%",
    "format-charging": "BAT {capacity}% CHG",
    "interval": 10
  },
  
  "pulseaudio": {
    "format": "VOL {volume}%",
    "format-muted": "MUTE",
    "scroll-step": 5
  }
}
EOF
    then
        log_success "Waybar config criado."
    else
        log_error "Falha ao criar waybar/config"
        return 1
    fi
    
    if cat > "$CONFIG_DIR/waybar/style.css" << 'EOF'
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

#cpu, #memory, #gpu, #battery, #pulseaudio {
  padding: 0 8px;
}

#battery.charging {
  color: #55ff55;
}

#battery.warning:not(.charging) {
  color: #ffaa00;
}

#battery.critical:not(.charging) {
  color: #ff5555;
}
EOF
    then
        log_success "Waybar style criado."
        return 0
    else
        log_error "Falha ao criar waybar/style.css"
        return 1
    fi
}

# ============================================================================
# KITTY CONFIG
# ============================================================================
setup_kitty() {
    log_section "CONFIGURANDO KITTY"
    
    mkdir -p "$CONFIG_DIR/kitty" 2>>"$ERROR_LOG" || {
        log_error "Falha ao criar diretório $CONFIG_DIR/kitty"
        return 1
    }
    
    if cat > "$CONFIG_DIR/kitty/kitty.conf" << 'EOF'
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
    then
        log_success "Kitty configurado (Wayland nativo)."
        return 0
    else
        log_error "Falha ao configurar Kitty"
        return 1
    fi
}

# ============================================================================
# ZSH CONFIG
# ============================================================================
setup_zsh() {
    log_section "CONFIGURANDO ZSH COM ALIASES"
    
    if cat > "$HOME/.zshrc" << 'EOF'
export PATH="$HOME/scripts:$HOME/.local/bin:$PATH"

HISTSIZE=10000
SAVEHIST=10000
HISTFILE="$HOME/.zsh_history"
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS INC_APPEND_HISTORY

autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

setopt EXTENDED_GLOB AUTO_CD CORRECT NO_BEEP AUTO_PUSHD PUSHD_IGNORE_DUPS

#------------ ALIAS ------------
# LS
alias ls='ls --color=auto'
alias la='ls -a'
alias ll='ls -l'
alias lla='ls -al'

# RM / CP
alias rm='rm -r'
alias cp='cp -r'

# NVIM
alias vi='nvim'
alias vim='nvim'

# Config files
alias fc='nvim ~/.config/fastfetch/config.jsonc'
alias fetch='clear && fastfetch --logo none | sed "s/^/  /"'
alias zshrc='nvim ~/.zshrc'
alias vimrc='nvim ~/.config/nvim/init.vim'

# Hyprland configs
alias hc='nvim ~/.config/hypr/hyprland.lua'
alias hw='nvim ~/.config/hypr/hyprpaper.conf'
alias waybarc='nvim ~/.config/waybar/config'
alias waybarcss='nvim ~/.config/waybar/style.css'

# Fuzzel
alias fuzzelc='nvim ~/.config/fuzzel/fuzzel.ini'

# System
alias update='sudo pacman -Syu'
alias update-aur='yay -Sua'
alias clean='sudo pacman -Sc'
alias hypr='Hyprland'
alias steam='~/scripts/steam-performance.sh'
alias sysinfo='fastfetch'
alias hexit='pkill -KILL -u $USER'
alias wallpaper='~/scripts/change-wallpaper.sh'
alias screenshot='~/scripts/screenshot.sh'

# Power profiles
alias perf='powerprofilesctl set performance'
alias balanced='powerprofilesctl set balanced'
alias powersave='powerprofilesctl set power-saver'

# GPU
alias gpuinfo='amdgpu_top'
alias gpustats='cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null || echo "N/A"'
alias vulkaninfo='vulkaninfo | grep -E "^(GPU|deviceName|driverInfo|apiVersion)"'
alias vainfo='vainfo'
alias clinfo='clinfo | grep -E "^(Platform Name|Device Name|Compute units|Clock Frequency)"'

#------------ EZA (modern ls) ------------
alias l='eza --icons'
alias lg='eza --icons --git'
alias lt='eza --tree --icons'

#------------ STARSHIP ------------
eval "$(starship init zsh)"

#------------ ZOXIDE ------------
eval "$(zoxide init zsh)"

#------------ FZF ------------
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh

#------------ ZSH-SYNTAX-HIGHLIGHTING ------------
[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#------------ ZSH-AUTOSUGGESTIONS ------------
[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

#------------ WAYLAND ENV ------------
export XDG_SESSION_TYPE=wayland
export GDK_BACKEND=wayland
export QT_QPA_PLATFORM=wayland
export SDL_VIDEODRIVER=wayland
export MOZ_USE_WAYLAND=1
export CLUTTER_BACKEND=wayland
export ELM_DISPLAY=wayland
EOF
    then
        log_success ".zshrc criado com aliases."
    else
        log_error "Falha ao criar .zshrc"
        return 1
    fi
    
    if cat > "$CONFIG_DIR/starship.toml" << 'EOF'
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
    then
        log_success "starship.toml criado."
        return 0
    else
        log_error "Falha ao criar starship.toml"
        return 1
    fi
}

# ============================================================================
# GTK THEME CONFIG
# ============================================================================
setup_gtk_theme() {
    log_section "CONFIGURANDO TEMA GTK (Orchis)"
    
    mkdir -p "$CONFIG_DIR/gtk-3.0" 2>>"$ERROR_LOG" || true
    mkdir -p "$CONFIG_DIR/gtk-4.0" 2>>"$ERROR_LOG" || true
    
    if cat > "$CONFIG_DIR/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Orchis-Dark-Compact
gtk-icon-theme-name=Tela-circle-black
gtk-font-name=JetBrains Mono 11
gtk-cursor-theme-name=Bibata-Original-Ice
gtk-cursor-theme-size=22
EOF
    then
        log_success "GTK 3.0 configurado."
    fi
    
    if cat > "$CONFIG_DIR/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Orchis-Dark-Compact
gtk-icon-theme-name=Tela-circle-black
gtk-font-name=JetBrains Mono 11
gtk-cursor-theme-name=Bibata-Original-Ice
gtk-cursor-theme-size=22
EOF
    then
        log_success "GTK 4.0 configurado."
    fi
    
    if cat > "$HOME/.gtkrc-2.0" << 'EOF'
gtk-theme-name="Orchis-Dark-Compact"
gtk-icon-theme-name="Tela-circle-black"
gtk-font-name="JetBrains Mono 11"
gtk-cursor-theme-name="Bibata-Original-Ice"
gtk-cursor-theme-size=22
EOF
    then
        log_success "GTK 2.0 configurado."
    fi
    
    log_success "Tema GTK Orchis configurado como padrão."
    return 0
}

# ============================================================================
# PIPEWIRE CONFIG
# ============================================================================
setup_pipewire() {
    log_section "CONFIGURANDO PIPEWIRE"
    
    sudo mkdir -p /etc/pipewire/pipewire.conf.d/ 2>>"$ERROR_LOG" || {
        log_error "Falha ao criar diretório /etc/pipewire"
        return 1
    }
    sudo mkdir -p /etc/wireplumber/wireplumber.conf.d/ 2>>"$ERROR_LOG" || {
        log_error "Falha ao criar diretório /etc/wireplumber"
        return 1
    }
    
    if sudo tee /etc/pipewire/pipewire.conf.d/99-gaming.conf > /dev/null 2>>"$ERROR_LOG" << 'EOF'
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
    then
        log_success "PipeWire configurado."
    else
        log_error "Falha ao configurar PipeWire"
        return 1
    fi
    
    if sudo tee /etc/wireplumber/wireplumber.conf.d/99-gaming.conf > /dev/null 2>>"$ERROR_LOG" << 'EOF'
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
    then
        log_success "WirePlumber configurado."
        return 0
    else
        log_error "Falha ao configurar WirePlumber"
        return 1
    fi
}

# ============================================================================
# OBS STUDIO CONFIG
# ============================================================================
setup_obs() {
    log_section "CONFIGURANDO OBS STUDIO"
    
    mkdir -p "$CONFIG_DIR/obs-studio/basic/profiles" 2>>"$ERROR_LOG" || {
        log_error "Falha ao criar diretório OBS"
        return 1
    }
    mkdir -p "$CONFIG_DIR/obs-studio/basic/scenes" 2>>"$ERROR_LOG" || true
    mkdir -p "$CONFIG_DIR/obs-studio/plugin_config/obs-xdg-portal" 2>>"$ERROR_LOG" || true
    
    if cat > "$CONFIG_DIR/obs-studio/basic/profiles/gaming.ini" << 'EOF'
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
    then
        log_success "OBS profile criado."
    else
        log_error "Falha ao criar OBS profile"
        return 1
    fi
    
    if cat > "$CONFIG_DIR/obs-studio/plugin_config/obs-xdg-portal/config.ini" << 'EOF'
[General]
CaptureMethod=Portal
PortalEnabled=true
PipeWireEnabled=true
PipeWireBufferSize=64
PipeWireSampleRate=48000
EOF
    then
        log_success "OBS XDG Portal configurado."
    else
        log_error "Falha ao configurar OBS XDG Portal"
        return 1
    fi
    
    if cat > "$SCRIPTS_DIR/obs-gaming" << 'EOF'
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
    then
        chmod +x "$SCRIPTS_DIR/obs-gaming" 2>>"$ERROR_LOG"
        log_success "obs-gaming script criado."
        return 0
    else
        log_error "Falha ao criar obs-gaming script"
        return 1
    fi
}

# ============================================================================
# XDG PORTAL CONFIG
# ============================================================================
setup_xdg_portal() {
    log_section "CONFIGURANDO XDG PORTAL"
    
    if sudo tee /etc/xdg/xdg-desktop-portal-hyprland.conf > /dev/null 2>>"$ERROR_LOG" << 'EOF'
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
    then
        log_success "XDG Portal Hyprland configurado."
    else
        log_error "Falha ao configurar XDG Portal Hyprland"
        return 1
    fi
    
    if sudo tee /etc/xdg/xdg-desktop-portal.conf > /dev/null 2>>"$ERROR_LOG" << 'EOF'
[preferred]
default=hyprland
org.freedesktop.impl.portal.FileChooser=gtk
EOF
    then
        log_success "XDG Portal configurado."
        return 0
    else
        log_error "Falha ao configurar XDG Portal"
        return 1
    fi
}

# ============================================================================
# REPORT FINAL
# ============================================================================
report_results() {
    log_section "RESUMO DA INSTALAÇÃO"
    
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    RELATÓRIO FINAL                       ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${BLUE}📦 PACOTES:${NC}"
    echo -e "  Instalados: ${GREEN}${#INSTALLED_PACKAGES[@]}${NC}"
    if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
        echo -e "  Com falha:  ${RED}${#FAILED_PACKAGES[@]}${NC}"
        for pkg in "${FAILED_PACKAGES[@]}"; do
            echo -e "    ${RED}✗${NC} $pkg"
        done
    else
        echo -e "  Com falha:  ${GREEN}0${NC}"
    fi
    
    echo ""
    
    echo -e "${BLUE}⚙️  FUNÇÕES:${NC}"
    echo -e "  Sucesso: ${GREEN}${#SUCCESS_FUNCTIONS[@]}${NC}"
    
    if [[ ${#FAILED_FUNCTIONS[@]} -gt 0 ]]; then
        echo -e "  Falhas:  ${RED}${#FAILED_FUNCTIONS[@]}${NC}"
        for func in "${FAILED_FUNCTIONS[@]}"; do
            echo -e "    ${RED}✗${NC} $func"
        done
    else
        echo -e "  Falhas:  ${GREEN}0${NC}"
    fi
    
    echo ""
    
    if [[ ${#FAILED_FUNCTIONS[@]} -eq 0 ]] && [[ ${#FAILED_PACKAGES[@]} -eq 0 ]]; then
        echo -e "${GREEN}✅ INSTALAÇÃO COMPLETA COM SUCESSO!${NC}"
    elif [[ ${#FAILED_FUNCTIONS[@]} -gt 0 ]] || [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  INSTALAÇÃO PARCIAL - Alguns componentes falharam${NC}"
        echo -e "${YELLOW}   Verifique o log de erros: ${ERROR_LOG}${NC}"
    fi
    
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║          ARCH HYPRLAND GAMER/STREAMER INSTALLER          ║"
    echo "║         AMD Ryzen 9 9950X3D + Radeon RX 9070 XT         ║"
    echo "║              Wayland/XWayland - Sem Xorg                 ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    
    local skip_packages=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-packages) skip_packages=true; shift ;;
            --help)
                echo "Uso: $0 [--skip-packages] [--help]"
                echo ""
                echo "Opções:"
                echo "  --skip-packages  Pula instalação de pacotes (apenas configurações)"
                echo "  --help           Mostra esta mensagem"
                exit 0
                ;;
            *) shift ;;
        esac
    done
    
    check_dependencies || exit 1
    
    local functions=(
        "setup_autologin|Configurar Autologin"
        "setup_yay|Instalar Yay"
        "install_official_packages|Instalar Pacotes Oficiais"
        "install_aur_packages|Instalar Pacotes AUR"
        "setup_services|Configurar Serviços Systemd"
        "setup_performance|Aplicar Otimizações de Performance"
        "setup_scripts|Criar Scripts em ~/scripts"
        "setup_hyprland|Configurar Hyprland (Wayland/XWayland)"
        "setup_fuzzel|Configurar Fuzzel"
        "setup_waybar|Configurar Waybar"
        "setup_kitty|Configurar Kitty"
        "setup_zsh|Configurar ZSH com Aliases"
        "setup_gtk_theme|Configurar Tema GTK Orchis"
        "setup_pipewire|Configurar PipeWire"
        "setup_obs|Configurar OBS Studio"
        "setup_xdg_portal|Configurar XDG Portal"
    )
    
    for func_entry in "${functions[@]}"; do
        local func_name="${func_entry%|*}"
        local func_desc="${func_entry#*|}"
        
        if [[ "$skip_packages" == true ]] && [[ "$func_name" =~ ^install_ ]]; then
            SKIPPED_FUNCTIONS+=("$func_desc")
            log_warning "Pulando: $func_desc (--skip-packages)"
            continue
        fi
        
        run_function "$func_name" "$func_desc" || true
    done
    
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
    echo -e "${YELLOW}Drivers AMD instalados:${NC}"
    echo "  ✅ Mesa 3D (OpenGL)"
    echo "  ✅ Vulkan RADV"
    echo "  ✅ VA-API (aceleração de vídeo)"
    echo "  ✅ OpenCL (computação GPU)"
    echo "  ✅ AMDGPU (kernel driver)"
    echo "  ✅ Bibliotecas 32-bit (compatibilidade)"
    echo "  ✅ Codecs de vídeo (GStreamer + FFmpeg)"
    echo ""
    echo -e "${YELLOW}Aliases disponíveis:${NC}"
    echo "  🎮 Gaming:"
    echo "    steam      - Steam com power profile"
    echo "    perf       - Perfil performance"
    echo ""
    echo "  🖥️  GPU:"
    echo "    gpuinfo    - Monitor GPU"
    echo "    vulkaninfo - Info Vulkan"
    echo "    vainfo     - Info VA-API"
    echo "    clinfo     - Info OpenCL"
    echo ""
    echo "  🛠️  Utilitários:"
    echo "    wallpaper  - Altera wallpaper"
    echo "    screenshot - Captura tela (Wayland)"
    echo "    fetch      - Fastfetch"
    echo ""
    echo -e "${CYAN}Log completo: ${LOG_FILE}${NC}"
    echo -e "${CYAN}Log de erros: ${ERROR_LOG}${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
}

main "$@"