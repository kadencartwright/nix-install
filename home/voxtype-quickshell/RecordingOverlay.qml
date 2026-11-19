import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel

    property string daemonState: "idle"
    property var audio: null
    property var samples: []
    property real pendingPeak: 0
    property real smoothedPeak: 0

    readonly property int waveformColumns: 24
    readonly property bool recording:
        daemonState === "recording" || daemonState === "streaming"
    readonly property bool transcribing: daemonState === "transcribing"
    readonly property bool active: recording || transcribing

    visible: active
    implicitWidth: transcribing ? 158 : 154
    implicitHeight: 32
    color: "transparent"

    anchors.bottom: true
    margins.bottom: 22

    Behavior on implicitWidth {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    WlrLayershell.namespace: "voxtype-waveform"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
        intersection: Intersection.Subtract
        width: panel.width
        height: panel.height
    }

    function clearWaveform() {
        samples = []
        pendingPeak = 0
        smoothedPeak = 0
        waveform.requestPaint()
    }

    Connections {
        target: panel.audio
        enabled: panel.audio !== null

        function onFrameReceived(peak, rms, vad, tsMs) {
            if (panel.recording)
                panel.pendingPeak = Math.max(panel.pendingPeak, peak)
        }

        function onDisconnected() {
            panel.clearWaveform()
        }
    }

    // Audio arrives at roughly 100 Hz. Aggregate it into an 18 Hz visual
    // stream and ease between peaks so the waveform moves calmly and fluidly.
    Timer {
        interval: 55
        repeat: true
        running: panel.recording

        onTriggered: {
            panel.smoothedPeak = panel.smoothedPeak * 0.62
                + panel.pendingPeak * 0.38
            panel.pendingPeak = 0

            const next = panel.samples.slice()
            next.push(panel.smoothedPeak)
            while (next.length > panel.waveformColumns)
                next.shift()
            panel.samples = next
            waveform.requestPaint()
        }
    }

    onRecordingChanged: {
        if (!recording)
            clearWaveform()
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "#f2252a31"
        border.width: 1
        border.color: panel.transcribing ? "#994fa6ed" : "#99e55561"

        Behavior on border.color { ColorAnimation { duration: 160 } }

        Item {
            id: recordingContent
            anchors.fill: parent
            opacity: panel.transcribing ? 0 : 1

            Behavior on opacity { NumberAnimation { duration: 140 } }

            Row {
                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: "#e55561"

                    SequentialAnimation on opacity {
                        running: panel.recording
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 800 }
                        NumberAnimation { to: 1; duration: 800 }
                    }
                }

                Canvas {
                    id: waveform
                    width: 120
                    height: 18

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        const centerY = height / 2
                        const columnWidth = width / panel.waveformColumns
                        const values = panel.samples
                        const firstColumn = panel.waveformColumns - values.length

                        ctx.strokeStyle = "#557a818e"
                        ctx.lineWidth = 1
                        ctx.beginPath()
                        ctx.moveTo(0, centerY)
                        ctx.lineTo(width, centerY)
                        ctx.stroke()

                        ctx.strokeStyle = "#e55561"
                        ctx.lineWidth = Math.max(2, columnWidth * 0.48)
                        ctx.lineCap = "round"
                        ctx.beginPath()
                        for (let i = 0; i < values.length; i++) {
                            const x = (firstColumn + i + 0.5) * columnWidth
                            const halfHeight = Math.max(
                                1,
                                Math.min(centerY - 2, values[i] * (centerY - 2) * 8)
                            )
                            ctx.moveTo(x, centerY - halfHeight)
                            ctx.lineTo(x, centerY + halfHeight)
                        }
                        ctx.stroke()
                    }
                }
            }
        }

        Item {
            anchors.fill: parent
            opacity: panel.transcribing ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 160 } }

            Row {
                anchors.centerIn: parent
                spacing: 9

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 4
                    radius: 2
                    color: "#414854"

                    Rectangle {
                        width: 11
                        height: parent.height
                        radius: parent.radius
                        color: "#4fa6ed"

                        SequentialAnimation on x {
                            running: panel.transcribing
                            loops: Animation.Infinite
                            NumberAnimation {
                                to: 21
                                duration: 520
                                easing.type: Easing.InOutCubic
                            }
                            NumberAnimation {
                                to: 0
                                duration: 520
                                easing.type: Easing.InOutCubic
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Transcribing"
                    color: "#a0a8b7"
                    font.family: "Noto Sans"
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
            }
        }
    }
}
