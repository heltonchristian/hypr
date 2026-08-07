local mainMod     = "SUPER"
local terminal    = "kitty"
local fileManager = "nautilus"
local menu        = "fuzzel"

local M = {}

M.gesture = {
    { 3, "horizontal", "workspace" },
}

M.bindm = {
    { mainMod, "mouse:272", "movewindow" },
    { mainMod, "mouse:273", "resizewindow" },
}

M.bind = {
    -- Window Management
    { "ALT", "F4", "exec", "hyprctl dispatch killactive" },
    { mainMod .. "&SHIFT_L", "F", "exec", "hyprctl dispatch togglefloating" },

    { mainMod .. "&CTRL", "left", "movewindow", "l" },
    { mainMod .. "&CTRL", "right", "movewindow", "r" },
    { mainMod .. "&CTRL", "up", "movewindow", "u" },
    { mainMod .. "&CTRL", "down", "movewindow", "d" },

    { mainMod, "left", "movefocus", "l" },
    { mainMod, "right", "movefocus", "r" },
    { mainMod, "up", "movefocus", "u" },
    { mainMod, "down", "movefocus", "d" },

    -- Applications
    { mainMod, "RETURN", "exec", terminal },
    { mainMod, "F9", "exec", browser },
    { mainMod, "F10", "exec", fileManager },

    -- Quickshell
    { mainMod, "R", "exec", "bash ~/.config/hypr/scripts/reload.sh" },
    { mainMod, "C", "exec", "~/.config/hypr/scripts/qs_manager.sh toggle clipboard" },
    { mainMod, "P", "exec", "~/.config/hypr/scripts/qs_manager.sh toggle movies" },
    { mainMod, "D", "exec", "bash ~/.config/hypr/scripts/qs_manager.sh toggle applauncher" },
    { mainMod .. "&SHIFT_L", "S", "exec", "bash ~/.config/hypr/scripts/qs_manager.sh toggle settings" },
    { mainMod, "Q", "exec", "bash ~/.config/hypr/scripts/qs_manager.sh toggle music" },
    { mainMod, "B", "exec", "bash ~/.config/hypr/scripts/qs_manager.sh toggle battery" },
    { mainMod, "W", "exec", "bash ~/.config/hypr/scripts/qs_manager.sh toggle wallpaper" },
    { mainMod, "S", "exec", "bash ~/.config/hypr/scripts/qs_manager.sh toggle calendar" },
    { mainMod, "N", "exec", "bash ~/.config/hypr/scripts/qs_manager.sh toggle network" },
    { mainMod .. "&SHIFT_L", "T", "exec", "bash ~/.config/hypr/scripts/qs_manager.sh toggle focustime" },
    { mainMod, "V", "exec", "bash ~/.config/hypr/scripts/qs_manager.sh toggle volume" },
    { mainMod, "H", "exec", "bash ~/.config/hypr/scripts/qs_manager.sh toggle guide" },

    { mainMod, "TAB", "exec", "~/.config/hypr/scripts/focus_next_monitor.sh" },
}

M.binde = {
    { mainMod .. "&SHIFT_L", "left", "resizeactive", "-50 0" },
    { mainMod .. "&SHIFT_L", "right", "resizeactive", "50 0" },
    { mainMod .. "&SHIFT_L", "up", "resizeactive", "0 -50" },
    { mainMod .. "&SHIFT_L", "down", "resizeactive", "0 50" },
}

M.bindl = {
    { "", "Caps_Lock", "exec", "sleep 0.1 && swayosd-client --caps-lock" },
    { "", "XF86MonBrightnessDown", "exec", "swayosd-client --brightness lower" },
    { "", "XF86MonBrightnessUp", "exec", "swayosd-client --brightness raise" },

    { "", "Print", "exec", "~/.config/hypr/scripts/screenshot.sh" },
    { "SHIFT_L", "Print", "exec", "~/.config/hypr/scripts/screenshot.sh --edit" },
    { "SUPER", "Print", "exec", "~/.config/hypr/scripts/screenshot.sh --full" },
    { "SUPER SHIFT_L", "Print", "exec", "~/.config/hypr/scripts/screenshot.sh --full --edit" },

    { "", "XF86PowerOff", "exec", "bash ~/.config/hypr/scripts/lock.sh" },

    { mainMod, "SPACE", "exec", "playerctl play-pause" },
    { "", "XF86AudioPause", "exec", "playerctl play-pause" },
    { "", "XF86AudioPlay", "exec", "playerctl play-pause" },
    { "", "XF86AudioMicMute", "exec", "swayosd-client --input-volume mute-toggle" },
    { "", "XF86AudioMute", "exec", "swayosd-client --output-volume mute-toggle" },
}

M.bindel = {
    { mainMod, "L", "exec", "bash ~/.config/hypr/scripts/lock.sh" },
    { "", "XF86AudioLowerVolume", "exec", "swayosd-client --output-volume lower" },
    { "", "XF86AudioRaiseVolume", "exec", "swayosd-client --output-volume raise" },
}

-- Workspaces
for i = 1, 10 do
    local key = (i == 10) and "0" or tostring(i)

    table.insert(M.bind, {
        mainMod,
        key,
        "exec",
        ("~/.config/hypr/scripts/qs_manager.sh %d"):format(i),
    })

    table.insert(M.bind, {
        mainMod .. " SHIFT",
        key,
        "exec",
        ("~/.config/hypr/scripts/qs_manager.sh %d move"):format(i),
    })
end

return M