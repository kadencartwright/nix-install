import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property string output: ""
    property bool autoRun: true
    property int interval: 0
    property var command: []
    Process {
        id: process
        command: root.command
        running: root.autoRun
        stdout: StdioCollector { onStreamFinished: root.output = text.trim() }
        onExited: if (root.interval > 0) restartTimer.restart()
    }
    Timer {
        id: restartTimer
        interval: root.interval
        repeat: false
        onTriggered: process.running = true
    }
}
