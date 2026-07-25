#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    exec sudo -E bash "$0" "$@"
fi

ORIGINAL_USER="${SUDO_USER:-${USER:-}}"
if [[ -z "$ORIGINAL_USER" || "$ORIGINAL_USER" == "root" ]]; then
    echo "Run this script from your normal user account with sudo access."
    exit 1
fi

HOME_DIR="$(getent passwd "$ORIGINAL_USER" | cut -d: -f6)"
if [[ -z "$HOME_DIR" || ! -d "$HOME_DIR" ]]; then
    echo "Could not resolve home directory for user: $ORIGINAL_USER"
    exit 1
fi

PACMAN_PACKAGES=(
    base-devel
    git
    pciutils
    zsh
    neovim
    foot
    fastfetch
    btop
    hyprland
    xdg-desktop-portal
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    hyprpaper
    hyprpolkitagent
    waybar
    fuzzel
    mako
    xorg-xwayland
    qt5-wayland
    qt6-wayland
    pipewire
    pipewire-pulse
    pipewire-alsa
    pipewire-jack
    wireplumber
    wl-clipboard
    playerctl
    brightnessctl
    obs-studio
    gamemode
    lib32-gamemode
    mangohud
    lib32-mangohud
    mesa
    lib32-mesa
    mesa-utils
    vulkan-tools
    libva-utils
    lm_sensors
    papirus-icon-theme
    ttf-jetbrains-mono-nerd
    ttf-nerd-fonts-symbols
    noto-fonts-emoji
)

AUR_PACKAGES=(
    bibata-cursor-theme
    hyprshot
)

WAYBAR_DIR="$HOME_DIR/.config/waybar"
WAYBAR_SCRIPTS_DIR="$WAYBAR_DIR/scripts"
FUZZEL_DIR="$HOME_DIR/.config/fuzzel"
MANGOHUD_DIR="$HOME_DIR/.config/MangoHud"
HYPR_DIR="$HOME_DIR/.config/hypr"
SHELL_DIR="$HOME_DIR/.config"

enable_multilib() {
    if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        sed -i \
            -e '/^\#\[multilib\]/, /^\#Include = \/etc\/pacman\.d\/mirrorlist/ s/^#//' \
            /etc/pacman.conf
    fi
}

install_paru() {
    if command -v paru >/dev/null 2>&1; then
        return
    fi

    echo "Installing paru..."
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
    echo "Installing AUR packages with paru..."
    sudo -u "$ORIGINAL_USER" paru -S --needed --noconfirm "${AUR_PACKAGES[@]}"
}

detect_gpu_and_install_driver_userspace() {
    if lspci 2>/dev/null | grep -qiE 'AMD|Advanced Micro Devices'; then
        pacman -S --needed --noconfirm vulkan-radeon lib32-vulkan-radeon
    elif lspci 2>/dev/null | grep -qiE 'Intel'; then
        pacman -S --needed --noconfirm vulkan-intel lib32-vulkan-intel
    elif lspci 2>/dev/null | grep -qiE 'NVIDIA'; then
        pacman -S --needed --noconfirm nvidia-utils lib32-nvidia-utils
    fi
}

configure_zsh() {
    if ! command -v zsh >/dev/null 2>&1; then
        return
    fi

    chsh -s "$(command -v zsh)" "$ORIGINAL_USER" || true

    cat > "$HOME_DIR/.zprofile" <<EOF
# Auto-start Hyprland on TTY1
if [[ -z "\${WAYLAND_DISPLAY:-}" && -z "\${DISPLAY:-}" && "\$(tty)" == "/dev/tty1" ]]; then
    exec dbus-run-session Hyprland
fi
EOF

    if [[ ! -f "$HOME_DIR/.zshrc" ]]; then
        cat > "$HOME_DIR/.zshrc" <<'EOF'
export EDITOR=nvim
export VISUAL=nvim

autoload -Uz compinit
compinit

alias ls='ls --color=auto'
alias ll='ls -lah'
EOF
    fi
}

configure_hyprland() {
    mkdir -p "$HYPR_DIR"

    cat > "$HYPR_DIR/hyprland.conf" <<'EOF'
$mainMod = SUPER

env = XCURSOR_THEME,Bibata-Modern-Ice
env = XCURSOR_SIZE,24
env = XDG_CURRENT_DESKTOP,Hyprland
env = QT_QPA_PLATFORM,wayland
env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
env = MOZ_ENABLE_WAYLAND,1
env = ELECTRON_OZONE_PLATFORM_HINT,auto
env = SDL_VIDEODRIVER,wayland

monitor = ,preferred,auto,1

input {
    kb_layout = us
    kb_variant = intl
    follow_mouse = 1
    sensitivity = 0
    touchpad {
        natural_scroll = yes
    }
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(89b4faff)
    col.inactive_border = rgba(313244cc)
    layout = dwindle
    resize_on_border = true
    allow_tearing = true
}

decoration {
    rounding = 8

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
    vrr = 1
}

dwindle {
    preserve_split = true
    no_gaps_when_only = 0
}

exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland
exec-once = waybar
exec-once = mako
exec-once = hyprpaper
exec-once = hyprpolkitagent

bind = $mainMod, RETURN, exec, kitty
bind = $mainMod, SPACE, exec, fuzzel --dmenu
bind = $mainMod, k, killactive,
bind = $mainMod SHIFT, k, exit,
bind = $mainMod, F, fullscreen, 0

bind = $mainMod, LEFT, movefocus, l
bind = $mainMod, RIGHT, movefocus, r
bind = $mainMod, UP, movefocus, u
bind = $mainMod, DOWN, movefocus, d

bind = $mainMod SHIFT, LEFT, movewindow, l
bind = $mainMod SHIFT, RIGHT, movewindow, r
bind = $mainMod SHIFT, UP, movewindow, u
bind = $mainMod SHIFT, DOWN, movewindow, d

bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10

bind = $mainMod SHIFT, S, exec, hyprshot -m region

bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow

windowrulev2 = suppressevent maximize, class:.*
EOF
}

configure_waybar() {
    mkdir -p "$WAYBAR_SCRIPTS_DIR"

    cat > "$WAYBAR_DIR/config.jsonc" <<EOF
{
  "layer": "top",
  "position": "top",
  "height": 30,
  "spacing": 8,
  "margin-top": 6,
  "margin-left": 8,
  "margin-right": 8,
  "modules-left": [
    "hyprland/workspaces",
    "hyprland/window"
  ],
  "modules-center": [
    "clock"
  ],
  "modules-right": [
    "custom/netspeed",
    "custom/temperature",
    "cpu",
    "memory",
    "wireplumber",
    "tray"
  ],

  "hyprland/workspaces": {
    "format": "{name}",
    "persistent-workspaces": {
      "*": 5
    }
  },

  "hyprland/window": {
    "format": "{}",
    "max-length": 40
  },

  "custom/netspeed": {
    "exec": "${WAYBAR_SCRIPTS_DIR}/netspeed.sh",
    "interval": 1,
    "return-type": "json"
  },

  "custom/temperature": {
    "exec": "${WAYBAR_SCRIPTS_DIR}/temperature.sh",
    "interval": 5
  },

  "cpu": {
    "format": "󰍛 {usage}%",
    "interval": 2
  },

  "memory": {
    "format": "󰾆 {used:0.1f}G/{total:0.1f}G",
    "interval": 2
  },

  "wireplumber": {
    "format": "󰕾 {volume}%",
    "format-muted": "󰖁 muted",
    "scroll-step": 5
  },

  "clock": {
    "format": "󰥔 {:%d/%m %H:%M}"
  },

  "tray": {
    "spacing": 10
  }
}
EOF

    cat > "$WAYBAR_DIR/style.css" <<'EOF'
* {
  border: none;
  border-radius: 0;
  min-height: 0;
  font-family: "JetBrainsMono Nerd Font";
  font-size: 12px;
}

window#waybar {
  background: rgba(17, 17, 27, 0.92);
  color: #cdd6f4;
}

#workspaces button {
  padding: 0 8px;
  margin: 0 2px;
  background: transparent;
  color: #cdd6f4;
}

#workspaces button.active {
  background: #89b4fa;
  color: #11111b;
}

#workspaces button.urgent {
  background: #f38ba8;
  color: #11111b;
}

#window,
#clock,
#cpu,
#memory,
#custom-netspeed,
#custom-temperature,
#wireplumber,
#tray {
  padding: 0 10px;
  margin: 0 2px;
  background: rgba(49, 50, 68, 0.75);
  color: #cdd6f4;
}

#custom-netspeed,
#custom-temperature {
  font-weight: 600;
}

#tray > .passive {
  -gtk-icon-effect: dim;
}

tooltip {
  background: rgba(17, 17, 27, 0.96);
  border: 1px solid #89b4fa;
}

tooltip label {
  color: #cdd6f4;
}
EOF

    cat > "$WAYBAR_SCRIPTS_DIR/netspeed.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

iface="${1:-$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')}"
if [[ -z "${iface:-}" ]]; then
    echo '{"text":"󰅙 --/--"}'
    exit 0
fi

state_dir="${XDG_RUNTIME_DIR:-/tmp}/waybar"
state_file="$state_dir/netspeed-${iface}.state"
mkdir -p "$state_dir"

read -r prev_rx prev_tx prev_ts < "$state_file" 2>/dev/null || true
prev_rx="${prev_rx:-0}"
prev_tx="${prev_tx:-0}"
prev_ts="${prev_ts:-0}"

read -r rx tx < <(awk -v dev="$iface" '
    $1 ~ ":" {
        gsub(":", "", $1)
        if ($1 == dev) {
            print $2, $10
            exit
        }
    }
' /proc/net/dev)

now="$(date +%s)"

human() {
    awk -v b="$1" 'BEGIN {
        split("B K M G T", u, " ");
        x = b + 0;
        i = 1;
        while (x >= 1024 && i < 5) { x /= 1024; i++ }
        printf "%.1f%s", x, u[i]
    }'
}

if [[ "$prev_ts" -eq 0 ]]; then
    printf '%s %s %s\n' "$rx" "$tx" "$now" > "$state_file"
    echo '{"text":"󰅙 --/--"}'
    exit 0
fi

dt=$((now - prev_ts))
(( dt <= 0 )) && dt=1

down=$(( (rx - prev_rx) / dt ))
up=$(( (tx - prev_tx) / dt ))

printf '%s %s %s\n' "$rx" "$tx" "$now" > "$state_file"

echo "{\"text\":\"↑ $(human "$up") ↓ $(human "$down")\"}"
EOF

    cat > "$WAYBAR_SCRIPTS_DIR/temperature.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

temp="$(sensors 2>/dev/null | awk '
    {
        while (match($0, /\+[0-9]+(\.[0-9]+)?°C/)) {
            value = substr($0, RSTART + 1, RLENGTH - 3);
            gsub(/\+/, "", value);
            if (value + 0 > max) {
                max = value + 0;
            }
            $0 = substr($0, RSTART + RLENGTH);
        }
    }
    END {
        if (max != "") printf "%.0f", max
    }
')"

if [[ -z "$temp" ]]; then
    echo "󰔏 --"
else
    echo "󰔏 ${temp}°C"
fi
EOF

    chmod +x "$WAYBAR_SCRIPTS_DIR/netspeed.sh" "$WAYBAR_SCRIPTS_DIR/temperature.sh"
}

configure_fuzzel() {
    mkdir -p "$FUZZEL_DIR"

    cat > "$FUZZEL_DIR/fuzzel.ini" <<'EOF'
[main]
terminal=foot
font=JetBrainsMono Nerd Font:size=12
dpi-aware=no
width=40
lines=12
horizontal-pad=10
vertical-pad=8
inner-pad=8
layer=overlay
prompt="> "
icons-enabled=no
match-mode=fuzzy
exit-on-keyboard-focus-loss=yes

[border]
radius=0
width=2

[colors]
background=1e1e2eee
text=cdd6f4ff
match=89b4faff
selection=89b4faff
selection-text=11111bff
border=89b4faff
EOF
}

configure_mangohud() {
    mkdir -p "$MANGOHUD_DIR"

    cat > "$MANGOHUD_DIR/MangoHud.conf" <<'EOF'
legacy_layout=0
background_alpha=0.35
round_corners=8
font_size=20
position=top-left

fps
frametime
gpu_stats
gpu_temp
gpu_core_clock
gpu_mem_clock
cpu_stats
cpu_temp
ram
vram
engine_version
vulkan_driver
gamemode

toggle_hud=Shift_R+F12
EOF
}

configure_sensors_and_xdg() {
    xdg-user-dirs-update || true
    systemctl --user daemon-reload >/dev/null 2>&1 || true
}

configure_autologin_tty1() {
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin ${ORIGINAL_USER} - \$TERM
EOF
}

install_system_packages() {
    enable_multilib
    pacman -Syu --noconfirm
    pacman -S --needed --noconfirm "${PACMAN_PACKAGES[@]}"
    detect_gpu_and_install_driver_userspace
}

install_system_packages
install_paru
install_aur_packages
configure_zsh
configure_hyprland
configure_waybar
configure_fuzzel
configure_mangohud
configure_sensors_and_xdg
configure_autologin_tty1

chown -R "$ORIGINAL_USER:$ORIGINAL_USER" \
    "$HOME_DIR/.config" \
    "$HOME_DIR/.zprofile" \
    "$HOME_DIR/.zshrc" 2>/dev/null || true

echo
echo "Install completed."
echo "Log out, then log in again on TTY1 to start Hyprland."
