import QtQuick
import Quickshell

Item {
    id: root
    property string initialMonitor: ""
    property string selectedMonitor: initialMonitor
    implicitHeight: content.implicitHeight + 28

    component Action: Rectangle {
        id: action
        property string label: ""
        property color accent: Theme.primary
        signal clicked()
        width: parent.width
        height: 36
        radius: 8
        color: mouse.containsMouse ? Theme.elevated : Theme.bg
        opacity: enabled ? 1 : 0.5
        Text { anchors.centerIn: parent; text: action.label; color: action.accent; font.family: Theme.font; font.pixelSize: 12 }
        MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: action.clicked() }
    }

    Column {
        id: content
        x: 14; y: 14; width: parent.width - 28; spacing: 8
        Text { text: "SCREEN · 30 FPS · COMPRESSED MP4"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10 }
        Repeater {
            model: Quickshell.screens
            Action {
                required property var modelData
                label: (root.selectedMonitor === modelData.name ? "●  " : "○  ") + modelData.name
                enabled: !ScreenRecorder.busy
                onClicked: root.selectedMonitor = modelData.name
            }
        }
        Action {
            label: (ScreenRecorder.microphone ? "☑" : "☐") + "  Include microphone (default input)"
            enabled: !ScreenRecorder.busy
            onClicked: ScreenRecorder.microphone = !ScreenRecorder.microphone
        }
        Action {
            label: ScreenRecorder.recording ? "Stop & save · " + ScreenRecorder.duration
                : ScreenRecorder.busy ? (ScreenRecorder.status === "exporting" ? "Exporting MP4…" : "Working…") : "Start recording"
            accent: ScreenRecorder.recording ? Theme.red : Theme.primary
            enabled: ScreenRecorder.recording || (!ScreenRecorder.busy && root.selectedMonitor !== "")
            onClicked: ScreenRecorder.recording ? ScreenRecorder.stop() : ScreenRecorder.start(root.selectedMonitor)
        }
        Text {
            width: parent.width
            text: ScreenRecorder.error || (ScreenRecorder.status === "saved" ? "Saved: " + ScreenRecorder.lastFile : "Saves to Videos/Screen Recordings. Microphone is off by default; desktop audio is not recorded.")
            color: ScreenRecorder.error ? Theme.red : Theme.muted
            wrapMode: Text.WrapAnywhere
            font.family: Theme.font; font.pixelSize: 11
        }
        Action { visible: ScreenRecorder.lastFile !== ""; label: "Play last recording"; onClicked: ScreenRecorder.playLast() }
        Action { visible: ScreenRecorder.lastFile !== ""; label: "Open recordings folder"; onClicked: ScreenRecorder.openFolder() }
    }
}
