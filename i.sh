#!/bin/sh

# Instalar programas
sudo pacman -S  git go xorg-server xorg-apps hyprland hyprpaper xdg-desktop-portal-hyprland polkit-kde-agent qt5-wayland qt6-wayland waybar kitty zsh vim remmina freerdp nwg-look gammastep nvidia-settings
sudo pacman -S  grim slurp papirus-icon-theme neofetch orchis-theme ttf-font-awesome ttf-nerd-fonts-symbols steam spotify-launcher

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
yay -S --removemake --noconfirm papirus-folders hyprshot librewolf-bin tofi wl-gammarelay

#icones, temas e fontes
papirus-folders -C black --theme Papirus

cd
rm -rf ~/hypr
rm -rf ~/yay
cd

#trocar o shell para zsh
chsh -s /bin/zsh
