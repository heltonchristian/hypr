#!/bin/bash

WALLPAPER_DIRECTORY=~/wallpapers

WALLPAPER=$(find "$WALLPAPER_DIRECTORY" -type f | shuf -n 1)

HYPRPAPER_CONF="$HOME/.config/hypr/hyprpaper.conf"
echo " " > $HYPRPAPER_CONF
echo "preload = $WALLPAPER" >> $HYPRPAPER_CONF
echo "wallpaper = DP-1, $WALLPAPER" >> $HYPRPAPER_CONF
echo "wallpaper = DVI-I-1, $WALLPAPER" >> $HYPRPAPER_CONF
echo "splash = false" >> $HYPRPAPER_CONF

killall hyprpaper
hyprpaper &

