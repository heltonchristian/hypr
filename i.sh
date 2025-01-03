#!/bin/sh

# Instalar programas
sudo pacman -S --noconfirm git go vim hyprland egl-wayland hyprpaper polkit xorg-xwayland xorg-xlsclients qt5-wayland glfw-wayland qt5-wayland qt6-wayland wayland-utils xdg-desktop-portal xdg-desktop-portal-hyprland dkms nvidia-dkms libva-nvidia-driver lib32-nvidia-utils grim slurp waybar zsh kitty vim wofi nemo btop papirus-icon-theme ttf-nerd-fonts-symbols ttf-fira-code ttf-font-awesome neofetch pavucontrol firefox libreoffice-fresh orchis-theme nwg-look

# Mover .config
rm -r ~/.config
mv -f .config ~/

# Mover arquivos .zshrc,.xinitrc, Scripts ...  para ~/
mv -f .zshrc .zprofile wallpapers scripts ~/

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
yay -S --noconfirm papirus-folders hyprshot

#icones, temas e fontes
papirus-folders -C white --theme Papirus

cd
rm -rf ~/ly
rm -rf ~/yay
cd
