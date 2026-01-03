#!/bin/bash

WALLPAPER_DIRECTORY=~/wallpapers
WALLPAPERS=($(ls -1 "$WALLPAPER_DIRECTORY"))
NUM_WALLPAPERS=${#WALLPAPERS[@]}
HYPRPAPER_CONF="$HOME/.config/hypr/hyprpaper.conf"
INDEX_FILE="$HOME/.config/hypr/wallpaper_index.txt"

if [ ! -f "$INDEX_FILE" ]; then
    echo 0 > "$INDEX_FILE"
fi

INDEX=$(cat "$INDEX_FILE")
WALLPAPER="$WALLPAPER_DIRECTORY/${WALLPAPERS[$INDEX]}"

echo " " > $HYPRPAPER_CONF
echo "preload = $WALLPAPER" >> $HYPRPAPER_CONF
echo "wallpaper = DP-3, $WALLPAPER" >> $HYPRPAPER_CONF
echo "wallpaper = HDMI-A-1, $WALLPAPER" >> $HYPRPAPER_CONF
echo "splash = false" >> $HYPRPAPER_CONF

killall hyprpaper
hyprpaper &

NEXT_INDEX=$(( (INDEX + 1) % NUM_WALLPAPERS ))
echo $NEXT_INDEX > "$INDEX_FILE"

