#!/bin/sh

# Instalar programas
sudo pacman -S --noconfirm git go hyprland hyprpaper qt5-wayland qt6-wayland wayland-utils xdg-desktop-portal-hyprland dkms nvidia-dkms intel-ucode grim slurp waybar zsh kitty vim wmofi nemo htop papirus-icon-theme ttf-nerd-fonts-symbols ttf-fira-code ttf-font-awesome neofetch ncspot pavucontrol firefox chromium libreoffice-fresh orchis-theme nwg-look

# Mover .config
rm -r ~/.config
mv -f .config ~/

# Mover arquivos .zshrc,.xinitrc, Scripts ...  para ~/
mv -f .zshrc .zprofile wallpapers Scripts ~/

# Dar permissões
chmod -R 755 ~/.config/hypr/hyprland.conf
chmod -R 755 ~/.config/wofi/config.conf
chmod -R 755 ~/Scripts/changewp.sh

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

rm -rf ~/ly1
rm -rf ~/yay
