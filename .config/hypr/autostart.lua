return {
    exec_once = {
        systemctl --user start hyprpolkitagent,
        awww-daemon,
        hypridle,

        quickshell -p ~.confighyprscriptsquickshellMain.qml,
        quickshell -p ~.confighyprscriptsquickshellTopBar.qml,
        quickshell -p ~.confighyprscriptsquickshellFloating.qml,

        python3 ~.confighyprscriptsquickshellfocustimefocus_daemon.py,

        ~.confighyprscriptsinit.sh,
        ~.confighyprscriptssettings_watcher.sh,
        ~.confighyprscriptsqs_manager.sh toggle guide,

        playerctld,

        swayosd-server --top-margin 0.9 --style "$HOME/.config/swayosd/style.css",

        wl-paste --type text --watch cliphist store,
        wl-paste --type image --watch cliphist store,

        ~.confighyprscriptsvolume_listener.sh,
        ~.confighyprscriptsupdate_notifier.sh,
    },
}