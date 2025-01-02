#!/bin/sh

# Instalar programas
sudo pacman -S --noconfirm git go vim hyprland egl-wayland hyprpaper polkit-gnome qt5-wayland qt6-wayland wayland-utils xdg-desktop-portal-hyprland dkms nvidia-dkms lib32-nvidia-utils intel-ucode grim slurp waybar zsh kitty vim wofi nemo htop papirus-icon-theme ttf-nerd-fonts-symbols ttf-fira-code ttf-font-awesome neofetch ncspot pavucontrol firefox chromium libreoffice-fresh orchis-theme nwg-look

# Mover .config
rm -r ~/.config
mv -f .config ~/

# Mover arquivos .zshrc,.xinitrc, Scripts ...  para ~/
mv -f .zshrc wallpapers scripts .gtkrc-2.0 ~/

# Dar permissões
chmod -R 755 ~/scripts/changewp.sh

#trocar o shell para zsh
chsh -s /bin/zsh

#AUR Helper
cd
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd

#AUR programas
yay -S --noconfirm papirus-folders

#icones, temas e fontes
papirus-folders -C white --theme Papirus

cd
rm -rf ~/ly
rm -rf ~/yay
