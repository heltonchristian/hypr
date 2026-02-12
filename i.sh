#!/bin/sh

sudo pacman -S --noconfirm git go hyprland xdg-desktop-portal-hyprland hyprpaper waybar foot zsh neovim ttf-nerd-fonts-symbols thunar thunar-archive-plugin unzip p7zip unrar tar gzip bzip2 xz vlc papirus-icon-theme ttf-jetbrains-mono-nerd orchis-theme spotify-launcher solaar libayatana-appindicator hyprpolkitagent
obs-studio fastfetch btop

rm -r ~/.config
mv -f .config ~/

mv -f .zshrc .zprofile scripts wallpapers ~/

chmod +x ~/scripts/changewpH.sh
chmod +x ~/scripts/changeAudio.sh

git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd

yay -S --quiet hyprshot wl-gammarelay-rs cava bibata-cursor-theme librewolf-bin tofi

cd /usr/share/applications/
sudo rm -rf btop.desktop qv4l2.desktop qvidcap.desktop xgpsspeed.desktop bssh.desktop xgps.desktop avahi-discover.desktop bvnc.desktop nvim.desktop

sudo groupadd -f plugdev
sudo usermod -aG plugdev $USER
ls /usr/lib/udev/rules.d/42-logitech-unify-permissions.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo tee /etc/udev/rules.d/99-logitech-mouse.rules <<'EOF'
SUBSYSTEMS=="usb", ATTRS{idVendor}=="046d", GROUP="plugdev", MODE="0660"
SUBSYSTEMS=="hid", ATTRS{idVendor}=="046d", GROUP="plugdev", MODE="0660"
EOF

sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin ly - \$TERM
EOF

cd
rm -rf ~/hypr
rm -rf ~/yay
cd

chsh -s /bin/zsh
