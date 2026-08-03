local config = {}

--------------------------------------------------------------------------------
-- MY PROGRAMS
--------------------------------------------------------------------------------
local terminal = "kitty"
local fileManager = "thunar"
local browser = "librewolf"
local menu = "tofi-drun --drun-launch=true"
local mainMod = "SUPER"

--------------------------------------------------------------------------------
-- MONITORS & WORKSPACES
--------------------------------------------------------------------------------
config.monitors = {
    "DP-3,1920x1080@319.976013, 0x0,auto",
    "HDMI-A-1,1920x1080,1920x0,auto"
}

config.workspaces = {
    "1, monitor:DP-3",
    "2, monitor:DP-3",
    "3, monitor:HDMI-A-1",
    "4, monitor:HDMI-A-1"
}

--------------------------------------------------------------------------------
-- AUTOSTART
--------------------------------------------------------------------------------
config.exec_once = {
    "waybar & hyprpaper & wl-gammarelay-rs",
    "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP",
    "solaar --window hide"
}

--------------------------------------------------------------------------------
-- ENVIRONMENT VARIABLES
--------------------------------------------------------------------------------
config.env = {
    -- Themes
    "GTK_THEME,Orchis-Dark-Compact",
    "ICON_THEME,Tela-circle-black",
    "XCURSOR_THEME,Bibata-Original-Ice",
    "XCURSOR_SIZE,22",

    -- Sessão e Backend
    "XDG_CURRENT_DESKTOP,Hyprland",
    "XDG_SESSION_TYPE,wayland",
    "XDG_SESSION_DESKTOP,Hyprland",
    "GDK_BACKEND,wayland,x11,*",
    "MOZ_ENABLE_WAYLAND,1",

    -- AMD
    "LIBGL_ALWAYS_SOFTWARE,0",
    "DRI_PRIME,0",
    "AMD_VULKAN_ICD,radeon",
    "RADV_PERFTEST,aco",
    "VK_ICD_FILENAMES,/usr/share/vulkan/icd.d/radeon_icd.x86_64.json:/usr/share/vulkan/icd.d/radeon_icd.i686.json",
    "VK_LAYER_PATH,/usr/share/vulkan/explicit_layer.d",
    "LIBVA_DRIVER_NAME,radeonsi",

    -- CPU Performance
    "CPU_BOOST,1",
    "FORCE_TSC,1"
}

--------------------------------------------------------------------------------
-- LOOK AND FEEL
--------------------------------------------------------------------------------
config.general = {
    gaps_in = 2,
    gaps_out = 4,
    border_size = 1,
    col_active_border = "rgba(FFFFFFff)",
    col_inactive_border = "rgba(808080cc)",
    resize_on_border = false,
    allow_tearing = false,
    layout = "dwindle"
}

config.decoration = {
    rounding = 1,
    active_opacity = 1,
    inactive_opacity = 1,
    shadow = {
        enabled = false,
        range = 2,
        render_power = 3,
        color = "rgba(1a1a1aee)"
    },
    blur = {
        enabled = false,
        size = 2,
        passes = 2,
        vibrancy = 0.1696
    }
}

config.animations = {
    enabled = true,
    bezier = {
        "easeOutQuint,0.23,1,0.32,1",
        "easeInOutCubic,0.65,0.05,0.36,1",
        "linear,0,0,1,1",
        "almostLinear,0.5,0.5,0.75,1.0",
        "quick,0.15,0,0.1,1"
    },
    animation = {
        "global, 1, 10, default",
        "border, 1, 5.39, easeOutQuint",
        "windows, 1, 4.79, easeOutQuint",
        "windowsIn, 1, 4.1, easeOutQuint, popin 87%",
        "windowsOut, 1, 1.49, linear, popin 87%",
        "fadeIn, 1, 1.73, almostLinear",
        "fadeOut, 1, 1.46, almostLinear",
        "fade, 1, 3.03, quick",
        "layers, 1, 3.81, easeOutQuint",
        "layersIn, 1, 4, easeOutQuint, fade",
        "layersOut, 1, 1.5, linear, fade",
        "fadeLayersIn, 1, 1.79, almostLinear",
        "fadeLayersOut, 1, 1.39, almostLinear",
        "workspaces, 1, 1.94, almostLinear, fade",
        "workspacesIn, 1, 1.21, almostLinear, fade",
        "workspacesOut, 1, 1.94, almostLinear, fade"
    }
}

config.dwindle = {
    pseudotile = true,
    preserve_split = true
}

config.master = {
    new_status = "master"
}

config.misc = {
    force_default_wallpaper = -1,
    disable_hyprland_logo = true
}

config.xwayland = {
    force_zero_scaling = true,
    use_nearest_neighbor = true
}

--------------------------------------------------------------------------------
-- INPUT (Configurado para precisão de mouse estilo Windows)
--------------------------------------------------------------------------------
config.input = {
    kb_layout = "us",
    kb_variant = "intl",
    follow_mouse = 0,
    
    -- Estas duas opções desativam a aceleração, igual ao Windows:
    accel_profile = "flat", 
    sensitivity = 0,
    
    touchpad = {
        natural_scroll = false
    }
}

config.devices = {
    {
        name = "logitech-pro-x-2-dex",
        sensitivity = 0
    }
}

--------------------------------------------------------------------------------
-- KEYBINDINGS
--------------------------------------------------------------------------------
config.bind = {
    -- Apps
    { mainMod, "Return", "exec", terminal },
    { mainMod, "F9", "exec", browser },
    { mainMod, "F10", "exec", fileManager },
    { mainMod, "F11", "exec", "steam" },
    { mainMod, "F12", "exec", "spotify-launcher" },
    
    -- Utils
    { mainMod, "P", "exec", "~/scripts/changewpH.sh" },
    { mainMod, "K", "killactive" },
    { mainMod, "SPACE", "exec", menu },
    { mainMod, "F", "fullscreen" },
    { mainMod .. " SHIFT", "S", "exec", "hyprshot -m region" },
    { mainMod, "W", "exec", "killall waybar || waybar" },

    -- Move focus
    { mainMod, "left", "movefocus", "l" },
    { mainMod, "right", "movefocus", "r" },
    { mainMod, "up", "movefocus", "u" },
    { mainMod, "down", "movefocus", "d" },

    -- Workspaces
    { mainMod, "1", "workspace", "1" },
    { mainMod, "2", "workspace", "2" },
    { mainMod, "3", "workspace", "3" },
    { mainMod, "4", "workspace", "4" },

    -- Move to workspaces
    { mainMod .. " SHIFT", "1", "movetoworkspace", "1" },
    { mainMod .. " SHIFT", "2", "movetoworkspace", "2" },
    { mainMod .. " SHIFT", "3", "movetoworkspace", "3" },
    { mainMod .. " SHIFT", "4", "movetoworkspace", "4" },
    
    -- Special workspace
    { mainMod, "0", "togglespecialworkspace", "special" }
}

-- Binds com repetição (bindel) e lock (bindl)
config.bindel = {
    { "", "XF86AudioRaiseVolume", "exec", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+" },
    { "", "XF86AudioLowerVolume", "exec", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" },
    { "", "XF86AudioMute", "exec", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" },
    { "", "XF86AudioMicMute", "exec", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" },
    { "", "XF86MonBrightnessUp", "exec", "brightnessctl -e4 -n2 set 5%+" },
    { "", "XF86MonBrightnessDown", "exec", "brightnessctl -e4 -n2 set 5%-" }
}

config.bindl = {
    { "", "XF86AudioNext", "exec", "playerctl next" },
    { "", "XF86AudioPause", "exec", "playerctl play-pause" },
    { "", "XF86AudioPlay", "exec", "playerctl play-pause" },
    { "", "XF86AudioPrev", "exec", "playerctl previous" }
}

config.bindm = {
    { mainMod, "mouse:272", "movewindow" },
    { mainMod, "mouse:273", "resizewindow" }
}

return config
