#!/bin/sh

# Instalar programas
sudo pacman -S  --noconfirm git go hyprland hyprpaper waybar alacritty zsh neovim ttf-nerd-fonts-symbols nemo nemo-fileroller vlc
sudo pacman -S  --noconfirm grim slurp orchis-theme papirus-icon-theme neofetch ttf-fira-code btop
sudo pacman -Syu --noconfirm --needed -y curl dialog freerdp git iproute2 libnotify gnu-netcat

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

cd
rm -rf ~/hypr
rm -rf ~/yay
cd

#trocar o shell para zsh
chsh -s /bin/zsh

#Autologin
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ly --noclear %I \$TERM
EOF
