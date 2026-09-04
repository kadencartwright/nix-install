import QtQuick

Item {
    id: root
    implicitWidth: 410
    implicitHeight: 524

    property var selectedSession: null
    property bool confirmingDelete: false

    function duration(seconds) { return MeetingRecorder.formatElapsed(seconds) }
    function sessionDate(session) {
        const date = MeetingRecorder.parseDate(session ? session.startedAt : "")
        return Qt.formatDateTime(date, "ddd, MMM d · h:mm AP")
    }

    component ActionButton: Rectangle {
        id: action
        property string label: ""
        property string icon: ""
        property color accent: Theme.primary
        property bool enabled: true
        signal clicked()
        height: 38
        radius: 9
        color: mouse.containsMouse && enabled ? Qt.lighter(Theme.elevated, 1.12) : Theme.elevated
        border.width: 1
        border.color: enabled ? accent : "#414852"
        opacity: enabled ? 1 : 0.5
        Row {
            anchors.centerIn: parent
            spacing: 8
            Text { text: action.icon; color: action.accent; font.family: Theme.iconFont; font.pixelSize: 16 }
            Text { text: action.label; color: Theme.fg; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: action.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }
    }

    component DeviceCard: Rectangle {
        property string title: ""
        property string description: ""
        property string icon: ""
        height: 58
        radius: 9
        color: Theme.elevated
        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            Text { anchors.verticalCenter: parent.verticalCenter; text: icon; color: Theme.primary; font.family: Theme.iconFont; font.pixelSize: 19; width: 23 }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 33
                spacing: 2
                Text { text: title; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold }
                Text { width: parent.width; text: description || "Unavailable"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 12; elide: Text.ElideRight }
            }
        }
    }

    Connections {
        target: MeetingRecorder
        function onOperationFinished(operation, succeeded) {
            if (operation === "delete" && succeeded) {
                root.selectedSession = null
                root.confirmingDelete = false
            } else if (operation === "upload" && succeeded) {
                root.selectedSession = null
            }
        }
    }

    Column {
        id: mainPage
        visible: root.selectedSession === null
        anchors.fill: parent
        anchors.margins: 12
        spacing: 9

        Rectangle {
            width: parent.width
            height: MeetingRecorder.recording ? 67 : 0
            visible: height > 0
            radius: 10
            color: Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.11)
            border.width: 1
            border.color: Theme.red
            Row {
                anchors.centerIn: parent
                spacing: 11
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 9; height: 9; radius: 5; color: Theme.red }
                Text { text: MeetingRecorder.formatElapsed(MeetingRecorder.elapsedSeconds); color: Theme.fg; font.family: Theme.font; font.pixelSize: 25; font.weight: Font.DemiBold }
            }
        }

        DeviceCard { width: parent.width; title: "MICROPHONE"; description: MeetingRecorder.microphone.description || "Unknown microphone"; icon: "󰍬" }
        DeviceCard { width: parent.width; title: "OUTPUT · ENTIRE SINK"; description: MeetingRecorder.output.description || "Unknown output"; icon: "󰓃" }

        ActionButton {
            width: parent.width
            height: 44
            label: MeetingRecorder.busy ? (MeetingRecorder.recording ? "Stopping…" : "Starting…") : (MeetingRecorder.recording ? "Stop recording" : "Start recording")
            icon: MeetingRecorder.recording ? "󰓛" : "󰑋"
            accent: MeetingRecorder.recording ? Theme.red : Theme.primary
            enabled: !MeetingRecorder.busy
            onClicked: MeetingRecorder.recording ? MeetingRecorder.stop() : MeetingRecorder.start()
        }

        Text {
            visible: MeetingRecorder.error !== ""
            width: parent.width
            text: MeetingRecorder.error
            color: Theme.red
            font.family: Theme.font
            font.pixelSize: 11
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Row {
            width: parent.width
            height: 25
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Recent recordings"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold; width: parent.width - 28 }
            Rectangle {
                width: 25; height: 25; radius: 7; color: refreshMouse.containsMouse ? Theme.elevated : "transparent"
                Text { anchors.centerIn: parent; text: "󰑐"; color: Theme.muted; font.family: Theme.iconFont; font.pixelSize: 15 }
                MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MeetingRecorder.refreshSessions() }
            }
        }

        ListView {
            width: parent.width
            height: parent.height - y
            clip: true
            spacing: 5
            model: MeetingRecorder.sessions
            delegate: Rectangle {
                id: sessionRow
                required property var modelData
                width: ListView.view.width
                height: 52
                radius: 8
                color: rowMouse.containsMouse ? "#343c46" : Theme.elevated
                Row {
                    anchors.fill: parent
                    anchors.margins: 9
                    spacing: 8
                    Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.status === "failed" ? "󰅚" : "󰎈"; color: modelData.status === "failed" ? Theme.red : Theme.primary; font.family: Theme.iconFont; font.pixelSize: 17; width: 22 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 92
                        spacing: 2
                        Text { width: parent.width; text: root.sessionDate(modelData); color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        Text { width: parent.width; text: modelData.microphone.description || "Unknown microphone"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; elide: Text.ElideRight }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; width: 53; horizontalAlignment: Text.AlignRight; text: root.duration(modelData.durationSeconds); color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selectedSession = sessionRow.modelData
                        root.confirmingDelete = false
                        MeetingRecorder.error = ""
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: MeetingRecorder.sessions.length === 0
                text: "No recordings yet"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 11
            }
        }
    }

    Column {
        id: detailPage
        visible: root.selectedSession !== null
        anchors.fill: parent
        anchors.margins: 12
        spacing: 9

        Row {
            width: parent.width
            height: 30
            Rectangle {
                width: 30; height: 30; radius: 8; color: backMouse.containsMouse ? Theme.elevated : "transparent"
                Text { anchors.centerIn: parent; text: "󰁍"; color: Theme.primary; font.family: Theme.iconFont; font.pixelSize: 17 }
                MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.selectedSession = null; root.confirmingDelete = false } }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: root.sessionDate(root.selectedSession); color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
        }

        Rectangle {
            width: parent.width; height: 60; radius: 9; color: Theme.elevated
            Row {
                anchors.centerIn: parent; spacing: 10
                Text { text: "󰎈"; color: Theme.primary; font.family: Theme.iconFont; font.pixelSize: 20 }
                Text { text: root.duration(root.selectedSession ? root.selectedSession.durationSeconds : 0); color: Theme.fg; font.family: Theme.font; font.pixelSize: 22; font.weight: Font.DemiBold }
                Text { text: root.selectedSession && root.selectedSession.status === "failed" ? "Failed" : "Complete"; color: root.selectedSession && root.selectedSession.status === "failed" ? Theme.red : Theme.green; font.family: Theme.font; font.pixelSize: 11 }
            }
        }

        DeviceCard { width: parent.width; title: "MICROPHONE"; description: root.selectedSession ? root.selectedSession.microphone.description : ""; icon: "󰍬" }
        DeviceCard { width: parent.width; title: "OUTPUT · ENTIRE SINK"; description: root.selectedSession ? root.selectedSession.output.description : ""; icon: "󰓃" }

        Text { width: parent.width; text: root.selectedSession ? root.selectedSession.directory : ""; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; elide: Text.ElideMiddle }

        Row {
            width: parent.width; spacing: 7
            ActionButton { width: (parent.width - 7) / 2; label: "Play meeting"; icon: "󰎈"; enabled: Boolean(root.selectedSession && root.selectedSession.mergedFile); onClicked: MeetingRecorder.playMeeting(root.selectedSession.id) }
            ActionButton { width: (parent.width - 7) / 2; label: "Open folder"; icon: "󰉋"; onClicked: MeetingRecorder.openSession(root.selectedSession.id) }
        }
        Row {
            width: parent.width; spacing: 7
            ActionButton { width: (parent.width - 7) / 2; label: "Microphone only"; icon: "󰍬"; onClicked: MeetingRecorder.playLocal(root.selectedSession.id) }
            ActionButton { width: (parent.width - 7) / 2; label: "Output only"; icon: "󰓃"; onClicked: MeetingRecorder.playRemote(root.selectedSession.id) }
        }

        ActionButton {
            width: parent.width
            label: root.selectedSession && root.selectedSession.notion ? "Notion meeting note created" : (MeetingRecorder.busy ? "Uploading to Notion…" : "Create Notion meeting note")
            icon: root.selectedSession && root.selectedSession.notion ? "󰄬" : "󰅧"
            accent: root.selectedSession && root.selectedSession.notion ? Theme.green : Theme.primary
            enabled: !MeetingRecorder.busy && Boolean(root.selectedSession && root.selectedSession.mergedFile) && !Boolean(root.selectedSession && root.selectedSession.notion)
            onClicked: MeetingRecorder.uploadSession(root.selectedSession.id)
        }

        Rectangle {
            width: parent.width
            height: root.confirmingDelete ? 66 : 38
            radius: 9
            color: Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.08)
            border.width: 1
            border.color: Theme.red
            Loader {
                anchors.fill: parent
                sourceComponent: root.confirmingDelete ? confirmDelete : requestDelete
            }
        }

        Text {
            visible: MeetingRecorder.error !== ""
            width: parent.width
            text: MeetingRecorder.error
            color: Theme.red
            font.family: Theme.font
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }
    }

    Component {
        id: requestDelete
        Item {
            Text { anchors.centerIn: parent; text: "Delete recording"; color: Theme.red; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.confirmingDelete = true }
        }
    }

    Component {
        id: confirmDelete
        Item {
            Column {
                anchors.fill: parent; anchors.margins: 7; spacing: 5
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Delete this recording?"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 11 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 18
                    Text { text: "Cancel"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.confirmingDelete = false } }
                    Text { text: MeetingRecorder.busy ? "Deleting…" : "Delete"; color: Theme.red; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold; MouseArea { anchors.fill: parent; enabled: !MeetingRecorder.busy; cursorShape: Qt.PointingHandCursor; onClicked: MeetingRecorder.deleteSession(root.selectedSession.id) } }
                }
            }
        }
    }

    Component.onCompleted: MeetingRecorder.popupOpened()
}
