#!/usr/bin/env bash

set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"

exec > >(tee -a "$HOME/instalacao-arch.log") 2>&1

echo "==> Iniciando instalação"

if [[ "$EUID" -eq 0 ]] || ! command -v pacman >/dev/null 2>&1; then
echo "Erro: execute como usuário normal em Arch Linux."
exit 1
fi

PACMAN_PACKAGES=(
hyprland hyprpaper hyprpolkitagent waybar uwsm
xorg-xwayland xdg-desktop-portal xdg-desktop-portal-hyprland
grim slurp wl-clipboard
zsh zsh-autosuggestions zsh-syntax-highlighting
nemo nemo-fileroller gvfs ntfs-3g
noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd ttf-liberation
vulkan-radeon vulkan-icd-loader vulkan-tools
steam steam-devices obs-studio discord vlc neovim mangohud
playerctl solaar zenity xdg-user-dirs xdg-utils nwg-look git python
)

AUR_PACKAGES=(tofi cemu hyprswitch spicetify-cli)

echo "==> Instalando pacotes oficiais"
sudo pacman -Syu --needed "${PACMAN_PACKAGES[@]}"

AUR_HELPER=""
if command -v yay >/dev/null 2>&1; then
AUR_HELPER="yay"
elif command -v paru >/dev/null 2>&1; then
AUR_HELPER="paru"
fi

if [[ -n "$AUR_HELPER" ]]; then
echo "==> Instalando pacotes AUR"
"$AUR_HELPER" -S --needed "${AUR_PACKAGES[@]}"
else
echo "Aviso: yay/paru não encontrado; pacotes AUR ignorados"
fi

move_contents() {
local source="$1" destination="$2" item name

[[ -d "$source" ]] || return 0
mkdir -p "$destination"

shopt -s dotglob nullglob
for item in "$source"/*; do
    [[ -e "$item" ]] || continue
    name="$(basename "$item")"

    if [[ ! -e "$destination/$name" ]]; then
        mv -- "$item" "$destination/"
        echo "==> Movido: $name"
    else
        echo "==> Mantido: $name"
    fi
done
shopt -u dotglob nullglob

}

echo "==> Aplicando configurações"
mkdir -p "$CONFIG_DIR" "$HOME/.local/bin"

move_contents "$REPO_DIR/.config" "$CONFIG_DIR"

for app in hypr waybar tofi discord nvim; do
move_contents "$REPO_DIR/$app" "$CONFIG_DIR/$app"
done

move_contents "$REPO_DIR/scripts" "$HOME/.local/bin"
chmod +x "$HOME"/.local/bin/* 2>/dev/null || true

xdg-user-dirs-update

echo "==> Instalação concluída"
