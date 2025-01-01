#!/bin/sh

# Instalar programas
sudo pacman -S --noconfirm git go hyprland qt5-wayland qt6-wayland desktop-portal-hyprland dkms nvidia-dkms intel-ucode dunst grim slurp waybar zsh kitty vim wofi nemo htop papirus-icon-theme ttf-nerd-fonts-symbols ttf-fira-code ttf-font-awesome redshift neofetch ncspot pavucontrol firefox chromium libreoffice-fresh orchis-theme

# Mover .config
rm -r ~/.config
mv -f .config ~/

# Mover arquivos .zshrc,.xinitrc, Scripts ...  para ~/
mv -f .zshrc .zprofile wallpapers Scripts ~/

# Dar permissões
chmod -R 755 ~/.config/hypr/hyprland.conf
chmod -R 755 ~/.config/wofi/config.conf
chmod -R 755 ~/Scripts/changewp.sh

#mouse
#echo -e 'Section "InputClass"\n     Identifier "My Mouse"\n     MatchIsPointer "yes"\n     Option "AccelerationProfile" "-1"\n     Option "AccelerationScheme" "none"\n     Option "AccelSpeed" "-1"\nEndSection' | sudo tee /etc/X11/xorg.conf.d/50-mouse-acceleration.conf

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

### Autologin ###
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
echo "[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin ly - \$TERM" | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null
