#!/usr/bin/env bash
for i in $(seq 1 10); do
    battery=$(solaar show | awk '/PRO X 2 DEX/{found=1} found && /Battery:/{match($0, /[0-9]+%/); print substr($0, RSTART, RLENGTH); exit}')
    if [ -n "$battery" ]; then
        echo "$battery"
        exit 0
    fi
    sleep 1
done
echo "N/A"
