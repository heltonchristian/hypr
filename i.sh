#!/usr/bin/env bash

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

ORIGINAL_USER="${SUDO_USER:-${USER:-}}"
if [[ -z "$ORIGINAL_USER" || "$ORIGINAL_USER" == "root" ]]; then
  echo "Rode este script a partir da sua conta de usuário normal com acesso sudo."
  exit 1
fi

HOME_DIR="$(getent passwd "$ORIGINAL_USER" | cut -d: -f6)"
if [[ -z "$HOME_DIR" || ! -d "$HOME_DIR" ]]; then
  echo "Não foi possível resolver o home de: $ORIGINAL_USER"
  exit 1
fi

# ---------------------------------------------------------------------------
# Paleta Matrix
# ---------------------------------------------------------------------------
MX_BG="000000"
MX_GREEN="00ff41"
MX_GREEN_DIM="0a3d17"
MX_GREEN_MUTED="4d9e6a"

# Versão clara da mesma paleta matrix (fundo claro, texto verde escuro)
LT_BG="f4f4ef"
LT_GREEN="0b6e2c"
LT_GREEN_DIM="a9d9b8"
LT_GREEN_MUTED="3f8a5c"

# ---------------------------------------------------------------------------
# Pacotes (repositórios oficiais — preferidos sobre AUR)
# ---------------------------------------------------------------------------
PACMAN_PACKAGES=(
  # Kernel (linux-zen: scheduler mais agressivo p/ desktop/gaming, oficial)
  linux-zen linux-zen-headers amd-ucode

  # Base
  base-devel git fish neovim fastfetch btop lm_sensors cpupower
  reflector pacman-contrib

  # Hyprland / Wayland core
  # (sem xdg-desktop-portal-gtk: o portal-hyprland já cobre screenshot/screencast,
  # e evitamos puxar o backend GTK à toa — reduz a pegada GTK do sistema)
  hyprland xdg-desktop-portal-hyprland
  hyprpaper hypridle hyprlock hyprpolkitagent
  waybar fuzzel fnott foot
  qt5-wayland qt6-wayland xorg-xwayland

  # Arquivos / área de trabalho mínima
  dolphin gvfs

  # Áudio (PipeWire — nativo Wayland/moderno)
  pipewire pipewire-pulse pipewire-alsa pipewire-jack wireplumber

  # Utilitários Wayland-nativos
  wl-clipboard grim slurp playerctl brightnessctl

  # Gerenciamento do receptor Logitech (G Pro X Superlight 2)
  solaar

  # GPU AMD RX 9070 XT (RDNA4)
  mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon
  vulkan-icd-loader lib32-vulkan-icd-loader vulkan-tools
  libva-mesa-driver lib32-libva-mesa-driver mesa-utils

  # Gaming / performance
  steam gamescope gamemode lib32-gamemode mangohud lib32-mangohud

  # Streaming
  obs-studio

  # Btrfs / snapshots (estabilidade)
  btrfs-progs snapper snap-pac

  # Fontes
  ttf-jetbrains-mono-nerd noto-fonts-emoji
)

AUR_PACKAGES=(
  librewolf-bin
  bibata-cursor-theme
  wl-gammarelay-rs
)

WAYBAR_DIR="$HOME_DIR/.config/waybar"
WAYBAR_SCRIPTS_DIR="$WAYBAR_DIR/scripts"
FUZZEL_DIR="$HOME_DIR/.config/fuzzel"
MANGOHUD_DIR="$HOME_DIR/.config/MangoHud"
HYPR_DIR="$HOME_DIR/.config/hypr"
FOOT_DIR="$HOME_DIR/.config/foot"
FISH_DIR="$HOME_DIR/.config/fish"
GAMEMODE_DIR="/etc/gamemode.ini"

enable_multilib() {
  if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sed -i -e '/^\#\[multilib\]/, /^\#Include = \/etc\/pacman\.d\/mirrorlist/ s/^#//' /etc/pacman.conf
  fi
}

install_paru() {
  if command -v paru >/dev/null 2>&1; then return; fi
  echo "Instalando paru..."
  sudo -u "$ORIGINAL_USER" bash -lc '
    set -euo pipefail
    build_dir="$HOME/.cache/paru-build"
    rm -rf "$build_dir"
    git clone https://aur.archlinux.org/paru.git "$build_dir"
    cd "$build_dir"
    makepkg -si --noconfirm
    rm -rf "$build_dir"
  '
}

install_aur_packages() {
  echo "Instalando pacotes AUR com paru..."
  sudo -u "$ORIGINAL_USER" paru -S --needed --noconfirm "${AUR_PACKAGES[@]}"
}

install_system_packages() {
  enable_multilib
  pacman -Syu --noconfirm
  pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
  # driver Vulkan/Mesa userspace para AMD já coberto acima (vulkan-radeon)
}

configure_fish() {
  chsh -s "$(command -v fish)" "$ORIGINAL_USER" || true
  mkdir -p "$FISH_DIR"
  cat > "$FISH_DIR/config.fish" <<'EOF'
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx XDG_CURRENT_DESKTOP Hyprland
set -gx PATH $PATH /usr/bin/wl-gammarelay-rs

if status is-login
    if test -z "$WAYLAND_DISPLAY" -a -z "$DISPLAY" -a (tty) = /dev/tty1
        exec dbus-run-session Hyprland
    end
end

# Prompt minimalista: diretório atual em cinza
function fish_prompt
    set_color 888888
    echo -n (prompt_pwd)
    set_color normal
    echo -n ' > '
end

# --- aliases (portados do .zshrc do repositório) ---
alias ls='ls --color=auto'
alias la='ls -a'
alias ll='ls -l'
alias lla='ls -al'
alias rm='rm -r'
alias cp='cp -r'
alias vi='nvim'
alias vim='nvim'
alias fc='nvim ~/.config/fastfetch/config.jsonc'
alias fzc='nvim ~/.config/fuzzel/fuzzel.ini'
alias footc='nvim ~/.config/foot/foot.ini'
alias fetch='clear; fastfetch --logo none | sed "s/^/  /"'
alias fishrc='nvim ~/.config/fish/config.fish'
alias vimrc='nvim ~/.config/nvim/init.vim'
alias hc='nvim ~/.config/hypr/hyprland.conf'
alias hw='nvim ~/.config/hypr/hyprpaper.conf'
alias waybarc='nvim ~/.config/waybar/config.jsonc'
alias waybarcss='nvim ~/.config/waybar/style.css'
alias hexit='pkill -KILL -u $USER'
EOF
}

configure_hyprland() {
  mkdir -p "$HYPR_DIR"
  cat > "$HYPR_DIR/hyprland.conf" <<EOF
#----------------- MONITORS ---------------------------------------------
# Ajuste os nomes de conector (DP-1, HDMI-A-1 etc.) com 'hyprctl monitors'
# após o primeiro login. Exemplo abaixo: Dell 320Hz como principal (0x0) e
# Acer 144Hz ao lado (1920x0).
monitor = DP-1,1920x1080@320,0x0,auto
monitor = HDMI-A-1,1920x1080@144,1920x0,auto

workspace = 1,monitor:DP-1
workspace = 2,monitor:DP-1
workspace = 3,monitor:DP-1
workspace = 4,monitor:DP-1
workspace = 5,monitor:HDMI-A-1
workspace = 6,monitor:HDMI-A-1
workspace = 7,monitor:HDMI-A-1
workspace = 8,monitor:HDMI-A-1

#----------------- MY PROGRAMS ------------------------------------------
\$mainMod = SUPER
\$terminal = foot
\$fileManager = dolphin
\$browser = librewolf
\$menu = fuzzel

#----------------- AUTOSTART ---------------------------------------------
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland
exec-once = hyprctl setcursor Bibata-Modern-Ice 24
exec-once = hyprpolkitagent
exec-once = waybar
exec-once = fnott
exec-once = hypridle
exec-once = wl-gammarelay-rs
exec-once = solaar --window hide

#----------------- ENVIRONMENT VARIABLES ---------------------------------
# Sessão / backend
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
env = QT_QPA_PLATFORM,wayland
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = GDK_BACKEND,wayland,x11
env = MOZ_ENABLE_WAYLAND,1
env = SDL_VIDEODRIVER,wayland
env = CLUTTER_BACKEND,wayland
env = ELECTRON_OZONE_PLATFORM_HINT,auto

# Cursor
env = XCURSOR_THEME,Bibata-Modern-Ice
env = XCURSOR_SIZE,24

# AMD RX 9070 XT
env = LIBGL_ALWAYS_SOFTWARE,0
env = DRI_PRIME,0
env = AMD_VULKAN_ICD,radeon
env = RADV_PERFTEST,aco
env = VK_ICD_FILENAMES,/usr/share/vulkan/icd.d/radeon_icd.x86_64.json:/usr/share/vulkan/icd.d/radeon_icd.i686.json
env = LIBVA_DRIVER_NAME,radeonsi

# Ryzen 9 9950X3D
env = CPU_BOOST,1
env = FORCE_TSC,1

#----------------- INPUT --------------------------------------------------
input {
    kb_layout = us
    kb_variant = intl
    follow_mouse = 1
    sensitivity = 0
    accel_profile = flat
    touchpad {
        natural_scroll = yes
    }
}

# G Pro X Superlight 2: sensibilidade crua, sem aceleração.
# Rode 'hyprctl devices' após o login e troque o nome abaixo pelo real
# (algo como 'logitech-g-pro-x-superlight-2-wireless-gaming-mouse-dex').
device {
    name = logitech-g-pro-x-superlight-2
    sensitivity = 0
    accel_profile = flat
}

#----------------- LOOK AND FEEL ------------------------------------------
general {
    gaps_in = 2
    gaps_out = 4
    border_size = 2
    col.active_border = rgba(${MX_GREEN}ff)
    col.inactive_border = rgba(${MX_GREEN_DIM}cc)
    layout = dwindle
    resize_on_border = true
    allow_tearing = true
}

decoration {
    rounding = 0
    active_opacity = 1.0
    inactive_opacity = 0.96
    blur {
        enabled = false
    }
    shadow {
        enabled = false
    }
}

animations {
    enabled = false
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    background_color = rgb(000000)
    vfr = true
    vrr = 1
    force_default_wallpaper = 0
}

dwindle {
    preserve_split = true
    no_gaps_when_only = 0
}

master {
    new_status = master
}

# Evita escala fracionária custosa em apps legados X11 (Steam etc.)
xwayland {
    force_zero_scaling = true
    use_nearest_neighbor = true
}

#----------------- KEYBINDINGS ---------------------------------------------
bind = \$mainMod, RETURN, exec, \$terminal
bind = \$mainMod, F9, exec, \$browser
bind = \$mainMod, F10, exec, \$fileManager
bind = \$mainMod, F11, exec, steam
bind = \$mainMod, B, exec, \$browser
bind = \$mainMod, E, exec, \$fileManager
bind = \$mainMod, Q, killactive,
bind = \$mainMod, K, killactive,
bind = \$mainMod SHIFT, Q, exit,
bind = \$mainMod, F, fullscreen, 0
bind = \$mainMod, V, togglefloating,
bind = \$mainMod, SPACE, exec, \$menu
bind = \$mainMod, P, pseudo,
bind = \$mainMod, J, togglesplit,
bind = \$mainMod, L, exec, hyprlock
bind = \$mainMod, W, exec, killall waybar || waybar

bind = \$mainMod, LEFT, movefocus, l
bind = \$mainMod, RIGHT, movefocus, r
bind = \$mainMod, UP, movefocus, u
bind = \$mainMod, DOWN, movefocus, d
bind = \$mainMod SHIFT, LEFT, movewindow, l
bind = \$mainMod SHIFT, RIGHT, movewindow, r
bind = \$mainMod SHIFT, UP, movewindow, u
bind = \$mainMod SHIFT, DOWN, movewindow, d

bind = \$mainMod, 1, workspace, 1
bind = \$mainMod, 2, workspace, 2
bind = \$mainMod, 3, workspace, 3
bind = \$mainMod, 4, workspace, 4
bind = \$mainMod, 5, workspace, 5
bind = \$mainMod, 6, workspace, 6
bind = \$mainMod, 7, workspace, 7
bind = \$mainMod, 8, workspace, 8
bind = \$mainMod, 9, workspace, 9
bind = \$mainMod, 0, workspace, 10
bind = \$mainMod SHIFT, 1, movetoworkspace, 1
bind = \$mainMod SHIFT, 2, movetoworkspace, 2
bind = \$mainMod SHIFT, 3, movetoworkspace, 3
bind = \$mainMod SHIFT, 4, movetoworkspace, 4
bind = \$mainMod SHIFT, 5, movetoworkspace, 5
bind = \$mainMod SHIFT, 6, movetoworkspace, 6
bind = \$mainMod SHIFT, 7, movetoworkspace, 7
bind = \$mainMod SHIFT, 8, movetoworkspace, 8
bind = \$mainMod SHIFT, 9, movetoworkspace, 9
bind = \$mainMod SHIFT, 0, movetoworkspace, 10

# Workspace especial (scratchpad)
bind = \$mainMod, GRAVE, togglespecialworkspace, special
bind = \$mainMod SHIFT, GRAVE, movetoworkspace, special

# Screenshot: clipboard 
bind = \$mainMod, S, exec, bash -lc 'grim -g "\$(slurp)" - | wl-copy'
bind = \$mainMod SHIFT, S, exec, bash -lc 'grim - | wl-copy'

bind = \$mainMod, R, exec, \$menu

# Toggle MangoHud / modo performance manual
bind = \$mainMod, G, exec, ~/.local/bin/gpu-perf-toggle.sh

# Toggle modo escuro (matrix) / claro
bind = \$mainMod, T, exec, ~/.local/bin/theme-toggle.sh

# Teclas de mídia
bindel = ,XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
bindel = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindel = ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindel = ,XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
bindel = ,XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+
bindel = ,XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-
bindl = ,XF86AudioNext, exec, playerctl next
bindl = ,XF86AudioPause, exec, playerctl play-pause
bindl = ,XF86AudioPlay, exec, playerctl play-pause
bindl = ,XF86AudioPrev, exec, playerctl previous

bindm = \$mainMod, mouse:272, movewindow
bindm = \$mainMod, mouse:273, resizewindow

windowrulev2 = suppressevent maximize, class:.*
windowrulev2 = immediate, class:^(steam_app_.*)\$
windowrulev2 = immediate, class:^(gamescope)\$
EOF
}

configure_hypridle_hyprlock() {
  cat > "$HYPR_DIR/hypridle.conf" <<EOF
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
    ignore_dbus_inhibit = false
}

listener {
    timeout = 600
    on-timeout = loginctl lock-session
}

listener {
    timeout = 900
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}
EOF

  cat > "$HYPR_DIR/hyprlock.conf" <<EOF
background {
    color = rgb(${MX_BG})
}

label {
    text = \$TIME
    color = rgb(${MX_GREEN})
    font_family = JetBrainsMono Nerd Font
    font_size = 64
    position = 0, 100
    halign = center
    valign = center
}

input-field {
    size = 250, 50
    outline_thickness = 2
    outer_color = rgb(${MX_GREEN})
    inner_color = rgb(${MX_BG})
    font_color = rgb(${MX_GREEN})
    placeholder_text = <span foreground="##${MX_GREEN_MUTED}">Senha...</span>
    position = 0, -80
    halign = center
    valign = center
}
EOF
}

configure_waybar() {
  mkdir -p "$WAYBAR_SCRIPTS_DIR"
  cat > "$WAYBAR_DIR/config.jsonc" <<EOF
{
  "layer": "top",
  "position": "top",
  "height": 26,
  "spacing": 4,
  "margin-top": 4,
  "margin-left": 6,
  "margin-right": 6,
  "modules-left": ["hyprland/workspaces", "hyprland/window"],
  "modules-center": ["clock"],
  "modules-right": ["custom/mouse-battery", "custom/mouse-pollrate", "custom/temperature", "cpu", "memory", "wireplumber", "tray"],
  "hyprland/workspaces": { "format": "{name}" },
  "hyprland/window": { "format": "{}", "max-length": 40 },
  "custom/mouse-battery": { "exec": "${WAYBAR_SCRIPTS_DIR}/mouse-battery.sh", "interval": 60, "tooltip": true },
  "custom/mouse-pollrate": { "exec": "${WAYBAR_SCRIPTS_DIR}/mouse-pollrate.sh", "interval": 60 },
  "custom/temperature": { "exec": "${WAYBAR_SCRIPTS_DIR}/temperature.sh", "interval": 5 },
  "cpu": { "format": " {usage}%", "interval": 2 },
  "memory": { "format": " {used:0.1f}G/{total:0.1f}G", "interval": 2 },
  "wireplumber": { "format": " {volume}%", "format-muted": " muted" },
  "clock": { "format": " {:%d/%m %H:%M}" },
  "tray": { "spacing": 8 }
}
EOF

  cat > "$WAYBAR_DIR/style.css" <<EOF
* {
    border: none;
    border-radius: 0;
    min-height: 0;
    font-family: "JetBrainsMono Nerd Font";
    font-size: 12px;
}
window#waybar {
    background: #${MX_BG};
    color: #${MX_GREEN};
    border-bottom: 1px solid #${MX_GREEN_DIM};
}
#workspaces button {
    padding: 0 8px;
    color: #${MX_GREEN_MUTED};
    background: transparent;
}
#workspaces button.active {
    color: #${MX_BG};
    background: #${MX_GREEN};
}
#window, #clock, #cpu, #memory, #custom-temperature, #custom-mouse-battery, #custom-mouse-pollrate, #wireplumber, #tray {
    padding: 0 10px;
    color: #${MX_GREEN};
}
tooltip {
    background: #${MX_BG};
    border: 1px solid #${MX_GREEN};
}
tooltip label { color: #${MX_GREEN}; }
EOF

  cat > "$WAYBAR_SCRIPTS_DIR/temperature.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
temp="$(sensors 2>/dev/null | awk '
{
  while (match($0, /\+[0-9]+(\.[0-9]+)?°C/)) {
    value = substr($0, RSTART + 1, RLENGTH - 3)
    gsub(/\+/, "", value)
    if (value + 0 > max) max = value + 0
    $0 = substr($0, RSTART + RLENGTH)
  }
}
END { if (max != "") printf "%.0f", max }
')"
[[ -z "$temp" ]] && echo " --" || echo " ${temp}°C"
EOF
  chmod +x "$WAYBAR_SCRIPTS_DIR/temperature.sh"

  # Bateria e polling rate do G Pro X Superlight 2, lidos via solaar (é o
  # que fala o protocolo HID++ da Logitech por trás do receptor Lightspeed —
  # sem ele o mouse funciona normal como HID genérico, mas sem essas leituras).
  cat > "$WAYBAR_SCRIPTS_DIR/mouse-battery.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
out="$(solaar show 2>/dev/null || true)"
pct="$(echo "$out" | grep -iE 'battery' | grep -oE '[0-9]+%' | head -n1)"
if [[ -z "$pct" ]]; then
  echo '{"text":" --","tooltip":"Mouse não encontrado (solaar)"}'
else
  echo "{\"text\":\" ${pct}\",\"tooltip\":\"G Pro X Superlight 2: ${pct}\"}"
fi
EOF

  cat > "$WAYBAR_SCRIPTS_DIR/mouse-pollrate.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
out="$(solaar show 2>/dev/null || true)"
rate="$(echo "$out" | grep -iE 'report rate|polling rate' | grep -oE '[0-9]+ ?Hz' | head -n1)"
[[ -z "$rate" ]] && echo " --" || echo " ${rate}"
EOF
  chmod +x "$WAYBAR_SCRIPTS_DIR/mouse-battery.sh" "$WAYBAR_SCRIPTS_DIR/mouse-pollrate.sh"
}

configure_fuzzel() {
  mkdir -p "$FUZZEL_DIR"
  # Formato dmenu clássico: barra fina ancorada no topo, largura total da tela,
  # em vez da caixa flutuante centralizada padrão do fuzzel.
  cat > "$FUZZEL_DIR/fuzzel.ini" <<EOF
[main]
terminal=foot
font=JetBrainsMono Nerd Font:size=13
anchor=top
width=100
lines=8
horizontal-pad=14
vertical-pad=6
inner-pad=6
layer=overlay
prompt="\$ "
icons-enabled=no
match-mode=fuzzy
exit-on-keyboard-focus-loss=yes

[border]
radius=0
width=0

[colors]
background=${MX_BG}f2
text=${MX_GREEN}ff
match=${MX_GREEN}ff
selection=${MX_GREEN}ff
selection-text=${MX_BG}ff
border=${MX_GREEN}ff
EOF
}

configure_foot() {
  mkdir -p "$FOOT_DIR"
  cat > "$FOOT_DIR/foot.ini" <<EOF
font=JetBrainsMono Nerd Font:size=11
pad=8x8
[colors]
background=${MX_BG}
foreground=${MX_GREEN}
regular0=000000
regular2=${MX_GREEN}
bright2=${MX_GREEN}
selection-background=${MX_GREEN_DIM}
selection-foreground=${MX_BG}
EOF
}

configure_fnott() {
  mkdir -p "$HOME_DIR/.config/fnott"
  # fnott: notificador Wayland-nativo sem dependência de GTK (mesmo autor do
  # foot e do fuzzel) — troca direta do mako pra reduzir a pegada GTK do sistema.
  cat > "$HOME_DIR/.config/fnott/fnott.ini" <<EOF
[main]
anchor=top-right
max-icon-size=32
border-radius=0
border-size=1
background=${MX_BG}ee
border-color=${MX_GREEN}ff
title-color=${MX_GREEN}ff
summary-color=${MX_GREEN}ff
body-color=${MX_GREEN_MUTED}ff
title-font=JetBrainsMono Nerd Font:size=10:weight=bold
summary-font=JetBrainsMono Nerd Font:size=10
body-font=JetBrainsMono Nerd Font:size=10

[low]
timeout=4

[critical]
timeout=0
border-color=${MX_GREEN}ff
EOF
}

configure_theme_toggle() {
  local themes_dir="$HYPR_DIR/themes"
  mkdir -p "$themes_dir/dark" "$themes_dir/light"

  # A variante "dark" é uma cópia exata do que configure_waybar/fuzzel/foot/fnott
  # já escreveram nos caminhos reais (paleta matrix, já rodadas antes desta função).
  cp "$WAYBAR_DIR/style.css" "$themes_dir/dark/waybar.css"
  cp "$FUZZEL_DIR/fuzzel.ini" "$themes_dir/dark/fuzzel.ini"
  cp "$FOOT_DIR/foot.ini" "$themes_dir/dark/foot.ini"
  cp "$HOME_DIR/.config/fnott/fnott.ini" "$themes_dir/dark/fnott.ini"
  cat > "$themes_dir/dark/borders.conf" <<EOF
active_border=rgba(${MX_GREEN}ff)
inactive_border=rgba(${MX_GREEN_DIM}cc)
EOF

  # Variante clara: mesma paleta matrix, fundo claro e verde escuro no lugar do
  # verde neon sobre preto.
  cat > "$themes_dir/light/waybar.css" <<EOF
* {
    border: none;
    border-radius: 0;
    min-height: 0;
    font-family: "JetBrainsMono Nerd Font";
    font-size: 12px;
}
window#waybar {
    background: #${LT_BG};
    color: #${LT_GREEN};
    border-bottom: 1px solid #${LT_GREEN_DIM};
}
#workspaces button {
    padding: 0 8px;
    color: #${LT_GREEN_MUTED};
    background: transparent;
}
#workspaces button.active {
    color: #${LT_BG};
    background: #${LT_GREEN};
}
#window, #clock, #cpu, #memory, #custom-temperature, #wireplumber, #tray {
    padding: 0 10px;
    color: #${LT_GREEN};
}
tooltip {
    background: #${LT_BG};
    border: 1px solid #${LT_GREEN};
}
tooltip label { color: #${LT_GREEN}; }
EO
