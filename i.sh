#!/bin/sh

# Instalar programas
sudo pacman -Syu --noconfirm --needed git go hyprland hyprpaper waybar alacritty zsh neovim ttf-nerd-fonts-symbols noto-fonts-extra nemo nemo-fileroller vlc
sudo pacman -Syu --noconfirm --needed grim slurp orchis-theme papirus-icon-theme fastfetch ttf-fira-code btop
sudo pacman -Syu --noconfirm --needed curl dialog freerdp git iproute2 libnotify gnu-netcat

# Mover .config
rm -r ~/.config
mv -f .config ~/

# Mover arquivos .zshrc,.xinitrc, Scripts ...  para ~/
mv -f .zshrc .zprofile scripts wallpapers ~/

# Dar permissões
chmod +x ~/scripts/changewpH.sh
chmod +x ~/scripts/changeAudio.sh

#AUR Helper
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd

#AUR programas
yay -S --noconfirm --quiet --needed librewolf-bin hyprshot tofi wl-gammarelay-rs cava bibata-cursor-theme

#Autologin
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo mv -f override.conf /etc/systemd/system/getty@tty1.service.d

cd
rm -rf ~/hypr
rm -rf ~/yay
cd

#trocar o shell para zsh
chsh -s /bin/zsh
