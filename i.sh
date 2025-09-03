#!/bin/sh
set -e

echo "==> Atualizando sistema"
sudo pacman -Syu --noconfirm

echo "==> Instalando pacotes básicos do sistema e Hyprland"
sudo pacman -S --noconfirm --needed \
  hyprland hyprpaper waybar alacritty grim slurp firefox\
  noto-fonts-extra ttf-nerd-fonts-symbols ttf-fira-code \
  papirus-icon-theme orchis-theme libnotify \
  dolphin vlc fastfetch btop \
  curl dialog freerdp iproute2 gnu-netcat \
  git go neovim zsh

echo "==> Backup e cópia de configs"
mv ~/.config ~/.config.bak.$(date +%s) || true
cp -r .config ~/
cp -f .zshrc .zprofile -t ~/
cp -r scripts wallpapers -t ~/
chmod +x ~/scripts/*.sh

echo "==> Instalando yay (AUR helper)"
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay

echo "==> Instalando pacotes AUR estáveis"
yay -S --noconfirm --needed wl-gammarelay-rs cava bibata-cursor-theme tofi

echo "==> Configurando autologin no tty1"
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo cp -f override.conf /etc/systemd/system/getty@tty1.service.d/

echo "==> Trocando shell padrão para zsh"
chsh -s /bin/zsh

echo "==> Instalando pacotes de jogos"
sudo pacman -S --noconfirm --needed \
  steam goverlay \
  mangohud gamemode \
  mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon \
  vulkan-icd-loader lib32-vulkan-icd-loader \
  wine winetricks obs-studio \
  pipewire pipewire-pulse pipewire-alsa wireplumber

echo "==> Instalando pacotes de virtualização"
sudo pacman -S --noconfirm --needed \
  qemu-full virt-manager edk2-ovmf virt-viewer \
  dnsmasq vde2 bridge-utils openbsd-netcat iptables-nft

echo "==> Ativando libvirtd"
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $(whoami)

echo "==> Aplicando tema e ícones (Orchis + Papirus + Bibata)"
gsettings set org.gnome.desktop.interface gtk-theme "Orchis-Dark"
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice"

echo "==> Finalizado!"
echo "Reinicie o sistema para aplicar todas as mudanças."
