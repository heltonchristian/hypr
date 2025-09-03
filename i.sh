#!/bin/sh

# Instalar programas
sudo pacman -S --noconfirm git go hyprland hyprpaper waybar alacritty zsh neovim ttf-nerd-fonts-symbols nemo nemo-fileroller vlc

# Mover .config
rm -r ~/.config
mv -f .config ~/

# Mover arquivos .zshrc, .zprofile e scripts para ~/
mv -f .zshrc .zprofile scripts ~/

# Dar permissões
chmod +x ~/scripts/changewpH.sh
chmod +x ~/scripts/changeAudio.sh

# AUR Helper
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd

# AUR programas
yay -S --noconfirm --quiet --needed hyprshot tofi wl-gammarelay-rs cava bibata-cursor-theme librewolf-bin

cd
rm -rf ~/hypr
rm -rf ~/yay
cd

# Trocar o shell para zsh
chsh -s /bin/zsh
