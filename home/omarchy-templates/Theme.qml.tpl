pragma Singleton
import QtQuick

QtObject {
    readonly property color bg: "{{ background }}"
    readonly property color surface: "{{ dark_background }}"
    readonly property color elevated: "{{ lighter_background }}"
    readonly property color fg: "{{ foreground }}"
    readonly property color muted: "{{ muted }}"
    readonly property color primary: "{{ accent }}"
    readonly property color red: "{{ red }}"
    readonly property color yellow: "{{ yellow }}"
    readonly property color green: "{{ green }}"
    readonly property color blue: "{{ blue }}"
    readonly property string font: "Noto Sans"
    readonly property string iconFont: "Symbols Nerd Font Mono"
}
