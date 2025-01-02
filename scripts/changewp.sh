#!/bin/bash

wallpapers_dir="$HOME/wallpapers"
wallpapers=( "$wallpapers_dir"/* )

if [[ ! -f "$wallpapers_dir/current_wallpaper.txt" ]]; then
    echo "1" > "$wallpapers_dir/current_wallpaper.txt"
fi

current_page=$(cat "$wallpapers_dir/current_wallpaper.txt")
wallpapers_per_page=1
current_page_index=$(( (current_page - 1) * wallpapers_per_page ))
next_page_index=$(( current_page_index + wallpapers_per_page ))

if (( next_page_index >= ${#wallpapers[@]} )); then
    next_page_index=0
fi

hyprctl dispatch ewall "${wallpapers[next_page_index]}"

next_page=$(( (next_page_index / wallpapers_per_page) + 1 ))
echo "$next_page" > "$wallpapers_dir/current_wallpaper.txt"

notify-send "Wallpaper Alterado"

clear
