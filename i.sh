#!/bin/sh

# Instalar programas
sudo pacman -S --noconfirm git go hyprland hyprpaper xdg-desktop-portal-hyprland waybar rofi kitty zsh vim remmina freerdp

sudo pacman -S --noconfirm nvidia-dkms nvidia-utils libva libva-nvidia-driver lib32-nvidia-utils

sudo pacman -S --noconfirm grim slurp papirus-icon-theme neofetch firefox orchis-theme ttf-font-awesome ttf-nerd-fonts-symbols steam spotify-launcher

# Mover .config
rm -r ~/.config
mv -f .config ~/

# Mover arquivos .zshrc,.xinitrc, Scripts ...  para ~/
mv -f .zshrc .zprofile wallpapers scripts ~/

# Dar permissões
chmod -R 755 ~/scripts/changewpH.sh
chmod -R 755 ~/scripts/changeAudio.sh

#AUR Helper
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd

#AUR programas
yay -S --noconfirm papirus-folders hyprshot librewolf-bin

#icones, temas e fontes
papirus-folders -C black --theme Papirus

cd
rm -rf ~/hypr
rm -rf ~/yay
cd

#trocar o shell para zsh
chsh -s /bin/zsh
