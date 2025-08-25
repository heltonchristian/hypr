#!/bin/sh
set -e

# Atualizar sistema
sudo pacman -Syu --noconfirm

# Pacotes oficiais
sudo pacman -S --noconfirm --needed \
  hyprland hyprpaper waybar alacritty grim slurp \
  noto-fonts-extra ttf-nerd-fonts-symbols ttf-fira-code \
  papirus-icon-theme orchis-theme libnotify \
  nemo nemo-fileroller vlc fastfetch btop \
  curl dialog freerdp iproute2 gnu-netcat \
  git go neovim zsh

# Backup e mover configs
mv ~/.config ~/.config.bak.$(date +%s) || true
cp -r .config ~/
cp -f .zshrc .zprofile -t ~/
cp -r scripts wallpapers -t ~/
chmod +x ~/scripts/*.sh

# AUR helper (yay)
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay

# AUR pacotes (somente os necessários/estáveis)
yay -S --noconfirm --needed librewolf-bin wl-gammarelay-rs cava bibata-cursor-theme

# Autologin
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo cp -f override.conf /etc/systemd/system/getty@tty1.service.d/

# Trocar shell para zsh
chsh -s /bin/zsh
