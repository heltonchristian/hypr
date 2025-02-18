#!/bin/sh

# Instalar programas
sudo pacman -S  --noconfirm git go hyprland hyprpaper waybar alacritty zsh neovim ttf-nerd-fonts-symbols nemo nemo-fileroller vlc
sudo pacman -S  --noconfirm grim slurp tela-circle-icon-theme-black neofetch orchis-theme steam ttf-fira-code freerdp xdg-desktop-portal-wlr obs-studio

# Mover .config
rm -r ~/.config
mv -f .config ~/

# Mover arquivos .zshrc,.xinitrc, Scripts ...  para ~/
mv -f .zshrc .zprofile wallpapers scripts ~/

# Dar permissões
chmod +x ~/scripts/changewpH.sh
chmod +x ~/scripts/changeAudio.sh

#AUR Helper
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd

#AUR programas
yay -S --noconfirm --quiet --needed hyprshot tofi wl-gammarelay-rs cava librewolf-bin bibata-cursor-theme
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
