pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string status: "idle"
    property string error: ""
    property string lastFile: ""
    property bool microphone: false
    property int elapsed: 0
    property double startedAt: 0
    readonly property bool recording: status === "recording"
    readonly property bool busy: process.running
    readonly property string duration: Math.floor(elapsed / 60) + ":" + String(elapsed % 60).padStart(2, "0")

    function start(output) {
        if (busy || !output) return
        error = ""
        elapsed = 0
        status = "starting"
        process.command = ["screen-record", output].concat(microphone ? ["--microphone"] : [])
        process.running = true
    }
    function stop() {
        if (!recording) return
        status = "stopping"
        process.write("stop\n")
    }
    function playLast() {
        if (lastFile) Quickshell.execDetached(["mpv", "--", lastFile])
    }
    function openFolder() {
        if (lastFile) Quickshell.execDetached(["xdg-open", lastFile.slice(0, lastFile.lastIndexOf("/"))])
    }
    Process {
        id: process
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const state = JSON.parse(data)
                    root.status = state.status
                    if (state.status === "recording") root.startedAt = Date.now()
                    if (state.path) root.lastFile = state.path
                    if (state.error) root.error = state.error
                } catch (_) {}
            }
        }
        onExited: (code, exitStatus) => {
            if (root.status !== "saved" && root.status !== "error") {
                root.status = "error"
                root.error = "Screen recorder exited unexpectedly (" + code + ")."
            }
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        onTriggered: root.elapsed = Math.floor((Date.now() - root.startedAt) / 1000)
    }
}
