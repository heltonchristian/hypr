-- Monitors
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
hl.workspace_rule({ workspace = "2", monitor = "DP-3" })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-1" })
hl.workspace_rule({ workspace = "special:gaming", monitor = "DP-3" })