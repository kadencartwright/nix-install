import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: root

    property var targetScreen: null
    property bool opened: false
    property bool running: false
    property bool expectedStop: false
    property string phase: ""
    property string connectionName: ""
    property string downloadMbps: ""
    property string uploadMbps: ""
    property string stderrText: ""
    property string errorText: ""
    property real fullScale: 100

    readonly property string speedTestBinary: {
        const configured = Quickshell.env("NETWORK_SPEEDTEST_BINARY")
        return configured && configured.length > 0 ? configured : "network-speedtest"
    }
    readonly property real downloadValue: measuredValue(downloadMbps)
    readonly property real uploadValue: measuredValue(uploadMbps)
    readonly property var scaleStops: [100, 250, 500, 1000, 2500, 5000, 10000]

    screen: targetScreen
    visible: opened
    color: "transparent"
    anchors { top: true; right: true; bottom: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-network-speedtest"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    function measuredValue(raw) {
        const value = parseFloat(raw)
        return isFinite(value) && value > 0 ? value : 0
    }

    function formattedValue(value) {
        if (value < 10) return value.toFixed(1)
        return Math.round(value).toLocaleString(Qt.locale(), "f", 0)
    }

    function updateScale(value) {
        for (let i = 0; i < scaleStops.length; i++) {
            if (value <= scaleStops[i] * 0.92) {
                if (scaleStops[i] > fullScale) fullScale = scaleStops[i]
                return
            }
        }
        fullScale = scaleStops[scaleStops.length - 1]
    }

    onDownloadValueChanged: updateScale(downloadValue)
    onUploadValueChanged: updateScale(uploadValue)

    function openTest(connection) {
        connectionName = connection && connection !== "Offline" ? connection : "Internet connection"
        opened = true
        Qt.callLater(function() {
            keyCatcher.forceActiveFocus()
            downloadDial.ignite()
            uploadDial.ignite()
            runTest()
        })
    }

    function closeTest() {
        opened = false
        phaseTimer.stop()
        phase = ""
        running = false
        if (speedProcess.running) {
            expectedStop = true
            speedProcess.running = false
        }
    }

    function runTest() {
        if (speedProcess.running) return
        errorText = ""
        stderrText = ""
        downloadMbps = ""
        uploadMbps = ""
        fullScale = scaleStops[0]
        running = true
        downloadDial.ignite()
        uploadDial.ignite()
        startPhase("down")
    }

    function startPhase(nextPhase) {
        if (!opened) return
        expectedStop = false
        phase = nextPhase
        stderrText = ""
        speedProcess.command = [root.speedTestBinary, nextPhase]
        speedProcess.running = true
        phaseTimer.restart()
    }

    function finishPhase() {
        if (!opened) return
        if (phase === "down") {
            startPhase("up")
        } else {
            phase = ""
            running = false
        }
    }

    function updateReading(line) {
        const value = parseFloat(line)
        if (!isFinite(value) || value < 0) return
        if (phase === "down") downloadMbps = String(value)
        else if (phase === "up") uploadMbps = String(value)
    }

    Process {
        id: speedProcess
        stdout: SplitParser { onRead: line => root.updateReading(line) }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.stderrText = String(text || "").trim()
        }
        onExited: function(exitCode) {
            phaseTimer.stop()
            if (!root.opened) {
                root.expectedStop = false
                return
            }
            if (!root.expectedStop && exitCode !== 0) {
                root.errorText = root.stderrText || "Speed test failed"
                root.phase = ""
                root.running = false
                return
            }
            root.expectedStop = false
            root.finishPhase()
        }
    }

    Timer {
        id: phaseTimer
        interval: 5000
        onTriggered: {
            if (speedProcess.running) {
                root.expectedStop = true
                speedProcess.running = false
            } else {
                root.finishPhase()
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.80)
        MouseArea { anchors.fill: parent; onClicked: root.closeTest() }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.closeTest()
        Keys.onReturnPressed: if (!root.running) root.runTest()
        Keys.onEnterPressed: if (!root.running) root.runTest()

        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 24
            width: 34
            height: 34
            radius: 17
            color: closeMouse.containsMouse ? "#3b424d" : "#2b313a"
            border.width: 1
            border.color: "#4a525e"
            Text { anchors.centerIn: parent; text: "×"; color: Theme.fg; font.pixelSize: 21 }
            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeTest()
            }
        }

        Item {
            id: cluster
            anchors.centerIn: parent
            width: 550
            height: 330
            scale: Math.min(1, (keyCatcher.width - 40) / width, (keyCatcher.height - 40) / height)

            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                anchors.centerIn: parent
                spacing: 16

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.connectionName.toUpperCase()
                    color: "#8d96a5"
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 54

                    SpeedDial {
                        id: downloadDial
                        label: "DOWNLOAD"
                        value: root.downloadValue
                        live: root.running && root.phase === "down"
                    }

                    SpeedDial {
                        id: uploadDial
                        label: "UPLOAD"
                        value: root.uploadValue
                        live: root.running && root.phase === "up"
                    }
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 108
                    height: 32
                    radius: 8
                    color: runMouse.containsMouse ? "#343c47" : "#292f37"
                    border.width: 1
                    border.color: root.running ? "transparent" : "#4a525e"
                    opacity: root.running ? 0 : 1
                    enabled: !root.running
                    Behavior on opacity { NumberAnimation { duration: 220 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Run Again"
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: runMouse
                        anchors.fill: parent
                        enabled: !root.running
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runTest()
                    }
                }

                Text {
                    visible: root.errorText !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 420
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.errorText
                    color: Theme.red
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
        }
    }

    component SpeedDial: Item {
        id: dial

        required property string label
        required property real value
        required property bool live
        property real shown: 0
        readonly property real fraction: root.fullScale > 0
            ? Math.max(0, Math.min(1, shown / root.fullScale)) : 0

        width: 220
        height: 238
        opacity: live || value > 0 ? 1 : 0.48
        Behavior on opacity { NumberAnimation { duration: 220 } }
        Behavior on shown {
            enabled: !ignition.running
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }
        onValueChanged: if (!ignition.running) shown = value
        onShownChanged: gauge.requestPaint()
        onFractionChanged: gauge.requestPaint()

        function ignite() { ignition.restart() }

        SequentialAnimation {
            id: ignition
            NumberAnimation { target: dial; property: "shown"; to: root.fullScale; duration: 520; easing.type: Easing.InOutCubic }
            NumberAnimation { target: dial; property: "shown"; to: 0; duration: 620; easing.type: Easing.OutCubic }
            onFinished: dial.shown = dial.value
        }

        Canvas {
            id: gauge
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 210
            height: 210
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const cx = width / 2
                const cy = height / 2
                const radius = width / 2 - 10
                const start = Math.PI * 0.75
                const sweep = Math.PI * 1.5

                ctx.lineCap = "round"
                ctx.lineWidth = 4
                ctx.strokeStyle = "#3f4650"
                ctx.beginPath()
                ctx.arc(cx, cy, radius, start, start + sweep, false)
                ctx.stroke()

                for (let i = 0; i < 46; i++) {
                    const major = i % 5 === 0
                    const angle = start + sweep * i / 45
                    const outer = radius - 8
                    const inner = outer - (major ? 10 : 6)
                    ctx.lineWidth = major ? 2 : 1
                    ctx.strokeStyle = major ? "#69717e" : "#464d58"
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.cos(angle) * inner, cy + Math.sin(angle) * inner)
                    ctx.lineTo(cx + Math.cos(angle) * outer, cy + Math.sin(angle) * outer)
                    ctx.stroke()
                }

                if (dial.fraction > 0.003) {
                    ctx.lineWidth = 10
                    ctx.strokeStyle = Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                    ctx.beginPath()
                    ctx.arc(cx, cy, radius, start, start + sweep * dial.fraction, false)
                    ctx.stroke()

                    ctx.lineWidth = 4
                    ctx.strokeStyle = Theme.primary
                    ctx.beginPath()
                    ctx.arc(cx, cy, radius, start, start + sweep * dial.fraction, false)
                    ctx.stroke()
                }

                const needleAngle = start + sweep * dial.fraction
                ctx.lineWidth = 3
                ctx.strokeStyle = Theme.primary
                ctx.beginPath()
                ctx.moveTo(cx + Math.cos(needleAngle) * 14, cy + Math.sin(needleAngle) * 14)
                ctx.lineTo(cx + Math.cos(needleAngle) * (radius - 22), cy + Math.sin(needleAngle) * (radius - 22))
                ctx.stroke()
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 100
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.formattedValue(dial.shown)
                color: "white"
                font.family: Theme.font
                font.pixelSize: 31
                font.weight: Font.Bold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Mbps"
                color: "#8d96a5"
                font.family: Theme.font
                font.pixelSize: 10
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            spacing: 7
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                radius: 3
                color: dial.live ? Theme.primary : "#59616d"
                SequentialAnimation on opacity {
                    running: dial.live
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1; duration: 500 }
                }
            }
            Text {
                text: dial.label
                color: "#8d96a5"
                font.family: Theme.font
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 1.5
            }
        }
    }
}
