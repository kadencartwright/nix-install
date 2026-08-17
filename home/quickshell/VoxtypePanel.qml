import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: 410
    implicitHeight: 455

    property var entries: []
    property int copiedIndex: -1
    readonly property string historyPath: {
        const stateHome = Quickshell.env("XDG_STATE_HOME")
        return (stateHome && stateHome.length > 0
            ? stateHome
            : Quickshell.env("HOME") + "/.local/state")
            + "/voxtype/history.jsonl"
    }

    function loadHistory(raw) {
        const parsed = []
        const lines = (raw || "").split("\n")
        for (let i = 0; i < lines.length; i++) {
            if (lines[i].trim().length === 0) continue
            try {
                const entry = JSON.parse(lines[i])
                if (entry.text && entry.text.trim().length > 0)
                    parsed.push(entry)
            } catch (_) {}
        }
        entries = parsed.slice(-10).reverse()
    }

    function copyEntry(text, index) {
        Quickshell.execDetached(["wl-copy", text])
        copiedIndex = index
        copiedTimer.restart()
    }

    function timeFor(timestamp) {
        const date = new Date(timestamp * 1000)
        const now = new Date()
        if (date.toDateString() === now.toDateString())
            return Qt.formatTime(date, "h:mm AP")
        return Qt.formatDate(date, "MMM d")
    }

    FileView {
        id: historyFile
        path: root.historyPath
        watchChanges: true
        printErrors: false
        onLoaded: root.loadHistory(text())
        onFileChanged: reload()
        onLoadFailed: root.entries = []
    }

    Timer {
        interval: 1500
        repeat: true
        running: true
        onTriggered: historyFile.reload()
    }

    Timer {
        id: copiedTimer
        interval: 1400
        onTriggered: root.copiedIndex = -1
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Row {
            width: parent.width
            height: 24

            Text {
                text: "LAST 10 DICTATIONS"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: parent.width - 190; height: 1 }

            Text {
                text: root.entries.length + (root.entries.length === 1 ? " entry" : " entries")
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Flickable {
            width: parent.width
            height: parent.height - 32
            contentWidth: width
            contentHeight: historyColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: historyColumn
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.entries

                    Rectangle {
                        id: entryRow
                        required property var modelData
                        required property int index
                        width: historyColumn.width
                        height: 55
                        radius: 8
                        color: entryMouse.containsMouse ? "#313b46" : Theme.elevated
                        border.width: root.copiedIndex === index ? 1 : 0
                        border.color: Theme.green

                        Column {
                            anchors.left: parent.left
                            anchors.right: copyIcon.left
                            anchors.leftMargin: 11
                            anchors.rightMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                width: parent.width
                                text: entryRow.modelData.text
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                                maximumLineCount: 2
                            }

                            Text {
                                text: root.timeFor(entryRow.modelData.timestamp)
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 9
                            }
                        }

                        Text {
                            id: copyIcon
                            anchors.right: parent.right
                            anchors.rightMargin: 11
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            horizontalAlignment: Text.AlignHCenter
                            text: root.copiedIndex === entryRow.index ? "󰄬" : "󰆏"
                            color: root.copiedIndex === entryRow.index ? Theme.green : Theme.muted
                            font.family: Theme.iconFont
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: entryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.copyEntry(entryRow.modelData.text, entryRow.index)
                        }
                    }
                }
            }

            Column {
                visible: root.entries.length === 0
                anchors.centerIn: parent
                spacing: 8

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "󰍬"
                    color: Theme.muted
                    font.family: Theme.iconFont
                    font.pixelSize: 30
                }
                Text {
                    text: "Your next dictation will appear here"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }
        }
    }
}
