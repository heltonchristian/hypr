#!/bin/bash

WALLPAPER_DIRECTORY="$HOME/Pictures/Wallpapers"
HYPRPAPER_CONF="$HOME/.config/hypr/hyprpaper.conf"
INDEX_FILE="$HOME/.config/hypr/wallpaper_index.txt"

mapfile -d '' WALLPAPERS < <(
    find "$WALLPAPER_DIRECTORY" -maxdepth 1 -type f \
    \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
    -print0 | sort -z
)

NUM_WALLPAPERS=${#WALLPAPERS[@]}

[ "$NUM_WALLPAPERS" -eq 0 ] && exit 1

[ ! -f "$INDEX_FILE" ] && echo 0 > "$INDEX_FILE"

INDEX=$(cat "$INDEX_FILE")

if ! [[ "$INDEX" =~ ^[0-9]+$ ]] || [ "$INDEX" -ge "$NUM_WALLPAPERS" ]; then
    INDEX=0
fi

WALLPAPER="${WALLPAPERS[$INDEX]}"

cat > "$HYPRPAPER_CONF" <<EOF
splash = false

wallpaper {
    monitor = DP-3
    path = $WALLPAPER
    fit_mode = cover
}

wallpaper {
    monitor = HDMI-A-1
    path = $WALLPAPER
    fit_mode = cover
}
EOF

killall hyprpaper 2>/dev/null
hyprpaper &

NEXT_INDEX=$(( (INDEX + 1) % NUM_WALLPAPERS ))
echo "$NEXT_INDEX" > "$INDEX_FILE"
