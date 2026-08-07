return {
    general = {
        border_size = 1,

        gaps_in = 5,
        gaps_out = 5,
        float_gaps = 8,

        resize_on_border = true,
        extend_border_grab_area = 30,

        ["col.active_border"] = "$active_border",
        ["col.inactive_border"] = "$inactive_border",
    },

    decoration = {
        rounding = 4,

        active_opacity = 1.0,
        inactive_opacity = 1.0,

        blur = {
            enabled = true,
            size = 6,
            passes = 1,
            new_optimizations = true,
        },

        shadow = {
            enabled = false,
        },
    },

    input = {
        kb_layout = "us",
        kb_variant = "intl",
        kb_options = "grp:alt_shift_toggle",

        follow_mouse = 0,

        sensitivity = 0,
        accel_profile = "flat",

        touchpad = {
            natural_scroll = true,
        },
    },

    device = {
        {
            name = "logitech-pro-x-2-dex",

            sensitivity = 0,
            accel_profile = "flat",

            natural_scroll = false,
            left_handed = false,
        },
    },

    cursor = {
        no_warps = true,
    },

    misc = {
        font_family = "JetBrains Mono",

        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
    },

    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },

    animations = {
        enabled = true,

        bezier = {
            { "hypr", 0.16, 1.00, 0.30, 1.00 },
        },

        animation = {
            { "windows",             1, 4, "hypr", "popin 80%" },
            { "windowsOut",          1, 4, "hypr", "popin 80%" },

            { "layers",              1, 4, "hypr", "fade" },
            { "layersIn",            1, 4, "hypr", "fade" },
            { "layersOut",           1, 4, "hypr", "fade" },

            { "fade",                1, 4, "hypr" },

            { "workspaces",          1, 4, "hypr", "slide" },

            { "specialWorkspaceIn",  1, 4, "hypr", "fade" },
            { "specialWorkspaceOut", 1, 4, "hypr", "fade" },
        },
    },
}