#!/bin/sh

#===== ENSURE SCRIPT RUNS WITH ROOT =====#
if [ "$EUID" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

ORIGINAL_USER="${SUDO_USER:-$USER}"

#===== SYSTEM UPDATE AND CORE PACKAGE INSTALLATION =====#
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm \
    git go \
    hyprland xdg-desktop-portal-hyprland hyprpaper hyprpolkitagent \
    waybar foot \
    zsh neovim \
    thunar thunar-archive-plugin \
    unzip p7zip unrar tar gzip bzip2 xz \
    vlc obs-studio spotify-launcher \
    fastfetch btop solaar libayatana-appindicator \
    papirus-icon-theme orchis-theme \
    ttf-nerd-fonts-symbols ttf-jetbrains-mono-nerd \
    pipewire pipewire-pulse pipewire-alsa pipewire-jack \
    wireplumber pipewire-media-session \
    noise-suppression-for-voice

#===== DEPLOY USER CONFIGURATION FILES =====#
rm -rf /home/"$ORIGINAL_USER"/.config
mv -f .config /home/"$ORIGINAL_USER"/
mv -f .zshrc .zprofile scripts wallpapers /home/"$ORIGINAL_USER"/

chmod +x /home/"$ORIGINAL_USER"/scripts/changewpH.sh
chmod +x /home/"$ORIGINAL_USER"/scripts/changeAudio.sh

#===== INSTALL YAY (AUR HELPER) AND AUR PACKAGES AS USER =====#
if ! sudo -u "$ORIGINAL_USER" command -v yay >/dev/null 2>&1; then
    sudo -u "$ORIGINAL_USER" git clone https://aur.archlinux.org/yay.git /home/"$ORIGINAL_USER"/yay
    cd /home/"$ORIGINAL_USER"/yay || exit
    sudo -u "$ORIGINAL_USER" makepkg -si --noconfirm
    cd ~ || exit
fi

sudo -u "$ORIGINAL_USER" yay -S --quiet --noconfirm \
    hyprshot wl-gammarelay-rs cava \
    bibata-cursor-theme librewolf-bin tofi

#===== CLEAN UNUSED DESKTOP ENTRIES =====#
sudo rm -rf /usr/share/applications/{ \
    btop.desktop,qv4l2.desktop,qvidcap.desktop,xgpsspeed.desktop, \
    bssh.desktop,xgps.desktop,avahi-discover.desktop,bvnc.desktop, \
    nvim.desktop }

#===== CONFIGURE LOGITECH UDEV PERMISSIONS =====#
sudo groupadd -f plugdev
sudo usermod -aG plugdev "$ORIGINAL_USER"

sudo tee /etc/udev/rules.d/99-logitech-mouse.rules <<'EOF'
SUBSYSTEMS=="usb", ATTRS{idVendor}=="046d", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="hid", ATTRS{idVendor}=="046d", GROUP="plugdev", MODE="0660"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger

#===== CONFIGURE TTY1 AUTOLOGIN =====#
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin ly - \$TERM
EOF

#===== OPTIONAL STEAM INSTALLATION (AMD SUPPORT) =====#
printf "\nInstall Steam with AMD multilib support? [y/N]: "
read -r install_steam

if [ "$install_steam" = "y" ] || [ "$install_steam" = "Y" ]; then
    echo "Enabling multilib repository..."
    sudo sed -i '/^\#\[multilib\]/,/^Include/ s/^#//' /etc/pacman.conf
    sudo pacman -Syu --noconfirm

    sudo pacman -S --noconfirm \
        steam \
        lib32-mesa \
        lib32-vulkan-radeon \
        vulkan-radeon

    echo "Steam installation completed."
fi

#===== ENABLE PIPEWIRE & CONFIGURE RNNOISE FOR DEFAULT MIC =====#
# Detect default microphone dynamically
DEFAULT_MIC=$(pactl info | grep "Default Source" | awk '{print $3}')

if [ -z "$DEFAULT_MIC" ]; then
    echo "Could not detect default microphone. RNNoise configuration skipped."
else
    mkdir -p /home/"$ORIGINAL_USER"/.config/pipewire

    cat > /home/"$ORIGINAL_USER"/.config/pipewire/pipewire-rnnoise.conf <<EOF
context.modules = [
    {
        name = libpipewire-module-ladspa-sink
        args = {
            node.name = "rnnoise-mic"
            master = "$DEFAULT_MIC"
            plugin = "noise-suppression-for-voice"
            label = "Noise Suppression (RNNoise)"
        }
    }
]
EOF

    chown "$ORIGINAL_USER":"$ORIGINAL_USER" /home/"$ORIGINAL_USER"/.config/pipewire/pipewire-rnnoise.conf

    # Restart PipeWire for changes to take effect
    sudo -u "$ORIGINAL_USER" systemctl --user restart pipewire pipewire-pulse wireplumber

    echo "RNNoise noise suppression configured for mic: $DEFAULT_MIC"
fi

#===== SET DEFAULT SHELL TO ZSH FOR USER =====#
if [ "$(getent passwd "$ORIGINAL_USER" | cut -d: -f7)" != "/bin/zsh" ]; then
    chsh -s /bin/zsh "$ORIGINAL_USER"
fi

#===== POST-INSTALL CLEANUP =====#
rm -rf /home/"$ORIGINAL_USER"/hypr
rm -rf /home/"$ORIGINAL_USER"/yay
cd

echo "Installation finished successfully."
