#!/bin/bash

WALLPAPER_DIRECTORY=~/wallpapers

WALLPAPER=$(find "$WALLPAPER_DIRECTORY" -type f | shuf -n 1)

hyprctl hyprpaper preload "$WALLPAPER"
hyprctl hyprpaper wallpaper "DP-1,$WALLPAPER"
hyprctl hyprpaper wallpaper "DVI-I-1,$WALLPAPER"

sleep 1

hyprctl hyprpaper unload unused

HYPRPAPER_CONF="$HOME/.config/hypr/hyprpaper.conf"
echo " " > $HYPRPAPER_CONF
echo "preload = $WALLPAPER" >> $HYPRPAPER_CONF
echo "wallpaper = DP-1, $WALLPAPER" >> $HYPRPAPER_CONF
echo "wallpaper = DVI-I-1, $WALLPAPER" >> $HYPRPAPER_CONF
echo "splash = false" >> $HYPRPAPER_CONF
