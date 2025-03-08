#!/bin/sh

# Instalar programas
sudo pacman -S  --noconfirm git go hyprland hyprpaper waybar alacritty zsh neovim ttf-nerd-fonts-symbols nemo nemo-fileroller vlc
sudo pacman -S  --noconfirm grim slurp orchis-theme tela-circle-icon-theme-black neofetch ttf-fira-code firefox

# Mover .config
rm -r ~/.config
mv -f .config ~/

# Mover arquivos .zshrc,.xinitrc, Scripts ...  para ~/
mv -f .zshrc .zprofile scripts ~/

# Dar permissões
chmod +x ~/scripts/changewpH.sh
chmod +x ~/scripts/changeAudio.sh

#AUR Helper
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd

#AUR programas
yay -S --noconfirm --quiet --needed hyprshot tofi wl-gammarelay-rs cava bibata-cursor-theme

cd
rm -rf ~/hypr
rm -rf ~/yay
cd

#trocar o shell para zsh
chsh -s /bin/zsh

#autologin
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo mv -f autologin.conf /etc/systemd/system/getty@tty1.service.d
