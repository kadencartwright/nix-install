pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property color bg: "#1f2329"
    property color surface: "#252a31"
    property color elevated: "#2b313a"
    property color fg: "#a0a8b7"
    property color muted: "#7a818e"
    property color primary: "#4fa6ed"
    property color red: "#e55561"
    property color yellow: "#cc9057"
    property color green: "#8ebd6b"
    property color blue: "#48b0bd"
    readonly property string font: "Noto Sans"
    readonly property string iconFont: "Symbols Nerd Font Mono"

    function loadColors(raw) {
        const values = {}
        const lines = String(raw || "").split("\n")
        for (let index = 0; index < lines.length; index++) {
            const match = lines[index].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
            if (match) values[match[1]] = match[2]
        }

        if (values.background) root.bg = values.background
        if (values.dark_background) root.surface = values.dark_background
        if (values.lighter_background) root.elevated = values.lighter_background
        if (values.foreground) root.fg = values.foreground
        if (values.muted) root.muted = values.muted
        if (values.accent) root.primary = values.accent
        if (values.red) root.red = values.red
        if (values.yellow) root.yellow = values.yellow
        if (values.green) root.green = values.green
        if (values.blue) root.blue = values.blue
    }

    // Startup load only. Runtime changes arrive through the shell's IPC target,
    // avoiding a QML source change and therefore avoiding a shell reload.
    property FileView colorsFile: FileView {
        path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
        watchChanges: false
        printErrors: false
        onLoaded: root.loadColors(text())
    }
}
