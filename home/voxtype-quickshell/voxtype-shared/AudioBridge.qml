import QtQuick
import Quickshell.Io

Item {
    id: root

    property string bridgeBinary: "voxtype-audio-bridge"
    property int restartDelayMs: 1000
    property bool running: false
    property real peak: 0
    property real rms: 0
    property bool vad: false

    signal frameReceived(real peak, real rms, bool vad, var tsMs)
    signal disconnected()

    function handleLine(line) {
        const value = (line || "").trim();
        if (value.length === 0)
            return;

        let message;
        try {
            message = JSON.parse(value);
        } catch (error) {
            console.warn("voxtype audio bridge returned invalid JSON:", value);
            return;
        }

        if (message.status === "disconnected") {
            running = false;
            disconnected();
            return;
        }

        if (typeof message.peak === "number" && typeof message.rms === "number") {
            peak = message.peak;
            rms = message.rms;
            vad = !!message.vad;
            running = true;
            frameReceived(peak, rms, vad,
                message.ts_ms === undefined ? 0 : message.ts_ms);
        }
    }

    Process {
        id: bridge
        command: [root.bridgeBinary]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.handleLine(data)
        }

        onRunningChanged: {
            if (!running) {
                root.running = false;
                root.disconnected();
                restartTimer.restart();
            }
        }
    }

    Timer {
        id: restartTimer
        interval: root.restartDelayMs
        onTriggered: bridge.running = true
    }
}
