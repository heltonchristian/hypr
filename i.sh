#!/bin/sh

# Instalar programas
sudo pacman -S  --noconfirm git go hyprland hyprpaper waybar alacritty zsh neovide remmina freerdp nwg-look nemo nemo-fileroller
sudo pacman -S  --noconfirm grim slurp papirus-icon-theme neofetch orchis-theme ttf-fira-code ttf-nerd-fonts-symbols steam spotify-launcher

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
yay -S --removemake --noconfirm papirus-folders hyprshot librewolf-bin tofi wl-gammarelay-rs

#icones, temas e fontes
papirus-folders -C black --theme Papirus

cd
rm -rf ~/hypr
rm -rf ~/yay
cd

#trocar o shell para zsh
chsh -s /bin/zsh

#autologin
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
echo -e "[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\\\u' --noclear --autologin ly - \$TERM" | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null
