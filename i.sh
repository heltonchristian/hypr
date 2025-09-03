#!/bin/sh

sudo pacman -S --noconfirm git go hyprland hyprpaper waybar alacritty zsh neovim ttf-nerd-fonts-symbols nemo nemo-fileroller vlc papirus-icon-theme ttf-fira-code orchis-theme
sudo pacman -S --noconfirm qemu virt-manager libvirt edk2-ovmf bridge-utils dnsmasq vde2 openbsd-netcat virt-viewer spice-server spice-gtk freerdp

rm -r ~/.config
mv -f .config ~/

mv -f .zshrc .zprofile scripts ~/

chmod +x ~/scripts/changewpH.sh
chmod +x ~/scripts/changeAudio.sh

git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd

yay -S --noconfirm --quiet --needed hyprshot tofi wl-gammarelay-rs cava bibata-cursor-theme librewolf-bin

cd
rm -rf ~/hypr
rm -rf ~/yay
cd

chsh -s /bin/zsh
