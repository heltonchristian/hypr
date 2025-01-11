#!/bin/sh

# Instalar programas
sudo pacman -S --noconfirm git go hyprland hyprpaper xorg-xwayland xdg-desktop-portal-hyprland waybar rofi kitty zsh vim nwg-look remmina freerdp krita

sudo pacman -S --noconfirm  dkms linux-headers nvidia-dkms nvidia-utils libva libva-nvidia-driver lib32-nvidia-utils xorg-server 

sudo pacman -S --noconfirm nemo nemo-fileroller grim slurp papirus-icon-theme neofetch firefox orchis-theme ttf-font-awesome ttf-fira-code steam spotify-launcher

#chromium libreoffice-fresh libreoffice-fresh-pt-br pavucontrol

# Mover .config
rm -r ~/.config
mv -f .config ~/

# Mover arquivos .zshrc,.xinitrc, Scripts ...  para ~/
mv -f .zshrc .zprofile wallpapers scripts ~/

# Dar permissões
chmod -R 755 ~/scripts/changewpH.sh
chmod -R 755 ~/scripts/changeAudio.sh

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

#Autologin
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
echo "[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin ly - \$TERM" | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null

#trocar o shell para zsh
chsh -s /bin/zsh
