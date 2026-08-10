-- ============================================================================
-- MY PROGRAMS
-- ============================================================================
local terminal    = "kitty"
local fileManager = "nemo"
local browser     = "librewolf"
local menu        = "tofi-drun --drun-launch=true"
local mainMod     = "SUPER"

-- ============================================================================
-- AUTOSTART
-- ============================================================================
hl.on("hyprland.start", function()
    hl.exec_cmd("solaar show | awk '/PRO X 2 DEX/{found=1} found && /Battery:/{match($0, /[0-9]+%/); print substr($0, RSTART, RLENGTH); exit}'")
    hl.exec_cmd("powerprofilesctl set balanced")
    hl.exec_cmd("waybar & hyprpaper & steam -silent & spotify-launcher -silent")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
end)

-- ============================================================================
-- MONITORS & WORKSPACES
-- ============================================================================
hl.monitor({
    output   = "DP-3",
    mode     = "1920x1080@319.976013",
    position = "0x0",
    scale    = "auto",
})

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1920x1080",
    position = "1920x0",
    scale    = "auto",
})

hl.workspace_rule({ workspace = "1", monitor = "DP-3" })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "7", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "8", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "9", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "10", monitor = "HDMI-A-1" })

hl.workspace_rule({ workspace = "special" })

-- ============================================================================
-- WINDOW RULES
-- ============================================================================

--Steam app & Steam games
hl.window_rule({
    name  = "steam-client-special-workspace",
    match = { class = "^(steam)$" },
    workspace = 7,
})

hl.window_rule({
    name       = "steam-workspace",
    match      = { class = "^(steam_app_.*)$" },
    workspace  = 1,
    fullscreen = true,
    confine_pointer = true,
})

hl.window_rule({
    name  = "Counter-Strike 2",
    match = { class = "cs2" },
    immediate = true,
    fullscreen = true,
    workspace  = 1,
    focus_on_activate = true,
    confine_pointer = true,
})

--Librewolf
hl.window_rule({
    name  = "librewolf-special-workspace",
    match = { class = "^(librewolf)$" },
    workspace = "special:browser",
})

-- Discord
hl.window_rule({
    name  = "discord-workspace",
    match = { class = "^(discord)$" },
    workspace = 9,
})

-- OBS
hl.window_rule({
    name  = "obs-workspace",
    match = { class = "^(com.obsproject.Studio)$" },
    workspace = 10,
})

-- ============================================================================
-- INPUT
-- ============================================================================
hl.config({
    input = {
        kb_layout     = "us",
        kb_variant    = "intl",
        follow_mouse  = 0,
        accel_profile = "flat",
        sensitivity   = 0,

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.device({
    name        = "logitech-pro-x-2-dex",
    sensitivity = 0,
})

-- ============================================================================
-- PERFORMANCE ENVIRONMENT
-- ============================================================================
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("AMD_VULKAN_ICD", "radeon")
hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")

-- ============================================================================
-- LOOK & FEEL
-- ============================================================================
hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 4,
        border_size = 1,
        resize_on_border = false,
        allow_tearing = true,
        layout = "dwindle",

        col = {
            active_border   = "rgba(FFFFFFff)",
            inactive_border = "rgba(808080cc)",
        },
    },

    decoration = {
        rounding = 1,
        active_opacity = 0.95,
        inactive_opacity = 0.95,
        fullscreen_opacity = 1.0,

        shadow = {
            enabled = false,
            range = 2,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },

        blur = {
            enabled = false,
            size = 2,
            passes = 2,
            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo = true,
    },

    xwayland = {
        force_zero_scaling = true,
        use_nearest_neighbor = true,
    },
})

-- ============================================================================
-- ANIMATIONS
-- ============================================================================
hl.curve("easeOutQuint", {
    type = "bezier",
    points = { {0.23, 1}, {0.32, 1} },
})

hl.curve("easeInOutCubic", {
    type = "bezier",
    points = { {0.65, 0.05}, {0.36, 1} },
})

hl.curve("linear", {
    type = "bezier",
    points = { {0, 0}, {1, 1} },
})

hl.curve("almostLinear", {
    type = "bezier",
    points = { {0.5, 0.5}, {0.75, 1} },
})

hl.curve("quick", {
    type = "bezier",
    points = { {0.15, 0}, {0.1, 1} },
})

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

-- ============================================================================
-- GAME MODE
-- ============================================================================
local gameMode = false

local function setGameMode(enabled)
    gameMode = enabled

    if enabled then
        hl.exec_cmd("powerprofilesctl set performance")

        hl.config({
            general = {
                gaps_in = 1,
                gaps_out = 1,
                border_size = 1,
                allow_tearing = true,
            },

            decoration = {
                rounding = 0,
                shadow = {
                    enabled = false,
                },
                blur = {
                    enabled = false,
                },
            },

            animations = {
                enabled = false,
            },
        })

        return
    end

    hl.exec_cmd("powerprofilesctl set balanced")

    hl.config({
        general = {
            gaps_in = 2,
            gaps_out = 4,
            border_size = 1,
            allow_tearing = true,
        },

        decoration = {
            rounding = 1,
            shadow = {
                enabled = false,
                range = 2,
                render_power = 3,
                color = "rgba(1a1a1aee)",
            },
            blur = {
                enabled = false,
                size = 2,
                passes = 2,
                vibrancy = 0.1696,
            },
        },

        animations = {
            enabled = true,
        },
    })
end

-- ============================================================================
-- KEYBINDINGS
-- ============================================================================
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + F9",     hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + F10",    hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + F11",    hl.dsp.exec_cmd("steam"))
hl.bind(mainMod .. " + F12",    hl.dsp.exec_cmd("spotify-launcher"))

hl.bind(mainMod .. " + P",         hl.dsp.exec_cmd("~/scripts/changewpH.sh"))
hl.bind(mainMod .. " + K",         hl.dsp.window.close())
hl.bind(mainMod .. " + SPACE",     hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + PRINT",     hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshots"))
hl.bind(mainMod .. " + W",         hl.dsp.exec_cmd("killall waybar || waybar"))

hl.bind(mainMod .. " + F1", function()
    setGameMode(not gameMode)
end)

hl.bind(mainMod .. " + left", function()
    hl.dispatch(hl.dsp.focus({ direction = "left" }))
end)
hl.bind(mainMod .. " + right", function()
    hl.dispatch(hl.dsp.focus({ direction = "right" }))
end)
hl.bind(mainMod .. " + up", function()
    hl.dispatch(hl.dsp.focus({ direction = "up" }))
end)
hl.bind(mainMod .. " + down", function()
    hl.dispatch(hl.dsp.focus({ direction = "down" }))
end)

hl.bind(mainMod .. " + 1", function()
    hl.dispatch(hl.dsp.focus({ workspace = 1 }))
end)
hl.bind(mainMod .. " + 2", function()
    hl.dispatch(hl.dsp.focus({ workspace = 2 }))
end)

hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))

hl.bind(mainMod .. " + 7", function()
    hl.dispatch(hl.dsp.focus({ workspace = 7 }))
end)
hl.bind(mainMod .. " + 8", function()
    hl.dispatch(hl.dsp.focus({ workspace = 8 }))
end)
hl.bind(mainMod .. " + 9", function()
    hl.dispatch(hl.dsp.focus({ workspace = 9 }))
end)
hl.bind(mainMod .. " + 0", function()
    hl.dispatch(hl.dsp.focus({ workspace = 10 }))
end)

hl.bind(mainMod .. " + L", hl.dsp.workspace.toggle_special("browser"))

-- ============================================================================
-- MEDIA & HARDWARE KEYS
-- ============================================================================
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                    { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                    { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- ============================================================================
-- MOUSE BINDS
-- ============================================================================
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
