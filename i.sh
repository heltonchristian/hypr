#!/bin/sh

# Instalar programas
sudo pacman -S --noconfirm git go hyprland hyprpaper xdg-desktop-portal-hyprland waybar wofi kitty zsh vim

sudo pacman -S --noconfirm linux-headers nvidia-dkms nvidia-utils libva libva-nvidia-driver lib32-nvidia-utils

sudo pacman -S --noconfirm nemo nemo-fileroller pavucontrol grim slurp btop papirus-icon-theme neofetch pavucontrol firefox libreoffice-fresh orchis-theme mako

# Mover .config
rm -r ~/.config
mv -f .config ~/

# Mover arquivos .zshrc,.xinitrc, Scripts ...  para ~/
mv -f .zshrc .zprofile .gtkrc-2.0 wallpapers scripts ~/

# Dar permissões
chmod -R 755 ~/scripts/changewpH.sh
chmod -R 755 ~/scripts/changeAudio.sh

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
rm -rf ~/hypr
rm -rf ~/yay
cd

# Autologin
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
echo "[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin ly - \$TERM" | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null
