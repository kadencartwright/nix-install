import QtQuick

Item {
    id: root
    implicitWidth: 410
    implicitHeight: 568

    property var selectedSession: null
    property var selectedExternal: null
    property string pageMode: "meetings"
    property bool confirmingDelete: false
    property string selectedDestinationId: ""
    property string expandedSelector: ""
    readonly property bool selectedSessionUploaded: Boolean(selectedSession && selectedSession.notion && selectedSession.notion.blockId)
    readonly property bool selectedExternalUploaded: Boolean(selectedExternal && selectedExternal.notion && selectedExternal.notion.blockId)

    function reconcileDestination() {
        const choices = MeetingRecorder.destinations || []
        for (let index = 0; index < choices.length; index++) {
            if (String(choices[index].id) === selectedDestinationId) return
        }
        selectedDestinationId = choices.length > 0 ? String(choices[0].id) : ""
    }

    function duration(seconds) { return MeetingRecorder.formatElapsed(seconds) }
    function sessionDate(session) {
        const date = MeetingRecorder.parseDate(session ? session.startedAt : "")
        return Qt.formatDateTime(date, "ddd, MMM d · h:mm AP")
    }
    function externalDate(file) {
        const date = MeetingRecorder.parseDate(file ? file.recordedAt : "")
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
        id: deviceCard
        property string title: ""
        property string description: ""
        property string icon: ""
        property string selectorKey: parent === mainPage ? (title === "MICROPHONE" ? "microphone" : "output") : ""
        property var choices: selectorKey === "microphone" ? MeetingRecorder.availableMicrophones : MeetingRecorder.availableOutputs
        property string selectedNode: selectorKey === "microphone" ? MeetingRecorder.selectedMicrophoneNode : MeetingRecorder.selectedOutputNode
        property bool selectable: selectorKey !== "" && !MeetingRecorder.recording
        readonly property bool expanded: selectable && root.expandedSelector === selectorKey
        signal selected(string nodeName)
        onSelected: nodeName => {
            if (selectorKey === "microphone") MeetingRecorder.selectMicrophone(nodeName)
            else if (selectorKey === "output") MeetingRecorder.selectOutput(nodeName)
        }
        height: 58 + (expanded ? Math.min(4, choices.length) * 39 + 6 : 0)
        radius: 9
        color: Theme.elevated
        Behavior on height { NumberAnimation { duration: 110 } }
        Row {
            width: parent.width - 20
            height: 58
            x: 10
            spacing: 10
            Text { anchors.verticalCenter: parent.verticalCenter; text: icon; color: Theme.primary; font.family: Theme.iconFont; font.pixelSize: 19; width: 23 }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 33 - (deviceCard.selectable ? 20 : 0)
                spacing: 2
                Text { text: title; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold }
                Text { width: parent.width; text: description || "Unavailable"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 12; elide: Text.ElideRight }
            }
            Text {
                visible: deviceCard.selectable
                anchors.verticalCenter: parent.verticalCenter
                text: deviceCard.expanded ? "▲" : "▼"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
                width: 20
            }
        }
        MouseArea {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 58
            enabled: deviceCard.selectable
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expandedSelector = deviceCard.expanded ? "" : deviceCard.selectorKey
        }
        ListView {
            y: 58
            width: parent.width
            height: deviceCard.expanded ? Math.min(4, deviceCard.choices.length) * 39 : 0
            visible: deviceCard.expanded
            clip: true
            model: deviceCard.choices
            delegate: Rectangle {
                id: deviceChoice
                required property var modelData
                width: ListView.view.width
                height: 39
                color: choiceMouse.containsMouse ? "#343c46" : "transparent"
                Rectangle {
                    width: 3; height: 22; radius: 2
                    anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                    color: String(deviceChoice.modelData.nodeName) === deviceCard.selectedNode ? Theme.primary : "transparent"
                }
                Text {
                    anchors.left: parent.left; anchors.leftMargin: 21
                    anchors.right: parent.right; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: deviceChoice.modelData.description || deviceChoice.modelData.nodeName
                    color: String(deviceChoice.modelData.nodeName) === deviceCard.selectedNode ? Theme.primary : Theme.fg
                    font.family: Theme.font; font.pixelSize: 11; elide: Text.ElideRight
                }
                MouseArea {
                    id: choiceMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        deviceCard.selected(String(deviceChoice.modelData.nodeName))
                        root.expandedSelector = ""
                    }
                }
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
            } else if (operation === "externalUpload" && succeeded) {
                root.selectedExternal = null
            }
        }
        function onDestinationsChanged() { root.reconcileDestination() }
    }

    Column {
        id: mainPage
        visible: root.pageMode === "meetings" && root.selectedSession === null
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
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 9; height: 9; radius: 5; color: MeetingRecorder.paused ? Theme.muted : Theme.red }
                Text { visible: MeetingRecorder.paused; text: "Paused"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                Text { text: MeetingRecorder.formatElapsed(MeetingRecorder.elapsedSeconds); color: Theme.fg; font.family: Theme.font; font.pixelSize: 25; font.weight: Font.DemiBold }
            }
        }

        DeviceCard { width: parent.width; title: "MICROPHONE"; description: MeetingRecorder.microphone.description || "Unknown microphone"; icon: "󰍬" }
        DeviceCard { width: parent.width; title: "OUTPUT · ENTIRE SINK"; description: MeetingRecorder.output.description || "Unknown output"; icon: "󰓃" }

        ActionButton {
            width: parent.width
            height: MeetingRecorder.recording ? 0 : 44
            visible: height > 0
            label: MeetingRecorder.busy ? "Starting…" : "Start recording"
            icon: MeetingRecorder.recording ? "󰓛" : "󰑋"
            accent: Theme.primary
            enabled: !MeetingRecorder.busy
            onClicked: MeetingRecorder.start()
        }

        Row {
            width: parent.width
            height: MeetingRecorder.recording ? 44 : 0
            visible: height > 0
            spacing: 7
            ActionButton {
                width: (parent.width - 7) / 2
                height: parent.height
                label: MeetingRecorder.busy ? "Working…" : (MeetingRecorder.paused ? "Resume" : "Pause")
                icon: MeetingRecorder.paused ? "▶" : "⏸"
                enabled: !MeetingRecorder.busy
                onClicked: MeetingRecorder.paused ? MeetingRecorder.resume() : MeetingRecorder.pause()
            }
            ActionButton {
                width: (parent.width - 7) / 2
                height: parent.height
                label: MeetingRecorder.busy ? "Working…" : "Stop"
                icon: "■"
                accent: Theme.red
                enabled: !MeetingRecorder.busy
                onClicked: MeetingRecorder.stop()
            }
        }

        ActionButton {
            width: parent.width
            height: MeetingRecorder.recording ? 0 : 38
            visible: height > 0
            label: "Browse USB voice recorder"
            icon: "󰃇"
            enabled: !MeetingRecorder.busy
            onClicked: {
                root.pageMode = "external"
                root.selectedExternal = null
                MeetingRecorder.externalError = ""
                MeetingRecorder.refreshExternal()
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
                        root.reconcileDestination()
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
        visible: root.pageMode === "meetings" && root.selectedSession !== null
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

        Column {
            width: parent.width
            spacing: 5
            visible: !Boolean(root.selectedSession && root.selectedSession.notion)

            Text {
                text: "NOTION DESTINATION"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
            ListView {
                width: parent.width
                height: 34
                orientation: ListView.Horizontal
                spacing: 6
                clip: true
                model: MeetingRecorder.destinations
                delegate: Rectangle {
                    id: destinationChoice
                    required property var modelData
                    height: 32
                    width: Math.max(108, destinationLabel.implicitWidth + 24)
                    radius: 8
                    color: root.selectedDestinationId === String(modelData.id)
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                        : (destinationMouse.containsMouse ? Qt.lighter(Theme.elevated, 1.12) : Theme.elevated)
                    border.width: 1
                    border.color: root.selectedDestinationId === String(modelData.id) ? Theme.primary : "#414852"
                    Text {
                        id: destinationLabel
                        anchors.centerIn: parent
                        text: destinationChoice.modelData.label
                        color: root.selectedDestinationId === String(destinationChoice.modelData.id) ? Theme.primary : Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    MouseArea {
                        id: destinationMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedDestinationId = String(destinationChoice.modelData.id)
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: MeetingRecorder.destinations.length === 0
                    text: "No destinations configured"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
        }

        ActionButton {
            width: parent.width
            label: root.selectedSessionUploaded ? "View in Notion" : (MeetingRecorder.destinations.length === 0 ? "Configure a Notion destination" : (MeetingRecorder.busy ? "Uploading to Notion…" : "Create Notion meeting note"))
            icon: root.selectedSessionUploaded ? "󰄬" : "󰅧"
            accent: root.selectedSessionUploaded ? Theme.green : Theme.primary
            enabled: !MeetingRecorder.busy && (root.selectedSessionUploaded || (root.selectedDestinationId !== "" && Boolean(root.selectedSession && root.selectedSession.mergedFile)))
            onClicked: root.selectedSessionUploaded
                ? MeetingRecorder.viewNotion(root.selectedSession.id)
                : MeetingRecorder.uploadSession(root.selectedSession.id, root.selectedDestinationId)
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

    Column {
        id: externalPage
        visible: root.pageMode === "external" && root.selectedExternal === null
        anchors.fill: parent
        anchors.margins: 12
        spacing: 9

        Row {
            width: parent.width
            height: 30
            Rectangle {
                width: 30; height: 30; radius: 8; color: externalBackMouse.containsMouse ? Theme.elevated : "transparent"
                Text { anchors.centerIn: parent; text: "󰁍"; color: Theme.primary; font.family: Theme.iconFont; font.pixelSize: 17 }
                MouseArea { id: externalBackMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pageMode = "meetings" }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "USB voice recorder"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold; width: parent.width - 60 }
            Rectangle {
                width: 30; height: 30; radius: 8; color: externalRefreshMouse.containsMouse ? Theme.elevated : "transparent"
                Text { anchors.centerIn: parent; text: "󰓐"; color: Theme.muted; font.family: Theme.iconFont; font.pixelSize: 15 }
                MouseArea { id: externalRefreshMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: MeetingRecorder.refreshExternal() }
            }
        }

        Rectangle {
            width: parent.width; height: 54; radius: 9; color: Theme.elevated
            Row {
                anchors.fill: parent; anchors.margins: 10; spacing: 10
                Text { anchors.verticalCenter: parent.verticalCenter; text: "󰃇"; color: MeetingRecorder.externalRecorders.length > 0 && MeetingRecorder.externalRecorders[0].connected ? Theme.green : Theme.muted; font.family: Theme.iconFont; font.pixelSize: 19; width: 23 }
                Column {
                    anchors.verticalCenter: parent.verticalCenter; width: parent.width - 33; spacing: 2
                    Text { text: MeetingRecorder.externalRecorders.length > 0 ? MeetingRecorder.externalRecorders[0].label : "Voice recorder"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Text {
                        text: MeetingRecorder.externalRecorders.length === 0 ? "Checking…" : (MeetingRecorder.externalRecorders[0].connected ? (MeetingRecorder.externalRecorders[0].mounted ? MeetingRecorder.externalFiles.length + " recordings · read-only" : "Connected, unable to mount") : "Connect the recorder over USB")
                        color: Theme.muted; font.family: Theme.font; font.pixelSize: 10
                    }
                }
            }
        }

        Text {
            visible: MeetingRecorder.externalError !== ""
            width: parent.width; text: MeetingRecorder.externalError; color: Theme.red
            font.family: Theme.font; font.pixelSize: 11; wrapMode: Text.Wrap
        }

        ListView {
            width: parent.width
            height: parent.height - y
            clip: true
            spacing: 5
            model: MeetingRecorder.externalFiles
            delegate: Rectangle {
                id: externalRow
                required property var modelData
                width: ListView.view.width; height: 56; radius: 8
                color: externalRowMouse.containsMouse ? "#343c46" : Theme.elevated
                Row {
                    anchors.fill: parent; anchors.margins: 9; spacing: 8
                    Text { anchors.verticalCenter: parent.verticalCenter; text: externalRow.modelData.notion ? "󰄬" : "󰍷"; color: externalRow.modelData.notion ? Theme.green : Theme.primary; font.family: Theme.iconFont; font.pixelSize: 17; width: 22 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; width: parent.width - 92; spacing: 2
                        Text { width: parent.width; text: root.externalDate(externalRow.modelData); color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        Text { width: parent.width; text: externalRow.modelData.name; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; elide: Text.ElideRight }
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; width: 53; horizontalAlignment: Text.AlignRight; text: root.duration(externalRow.modelData.durationSeconds); color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }
                }
                MouseArea {
                    id: externalRowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.selectedExternal = externalRow.modelData
                        root.reconcileDestination()
                        MeetingRecorder.error = ""
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: MeetingRecorder.externalFiles.length === 0
                text: MeetingRecorder.externalRecorders.length > 0 && MeetingRecorder.externalRecorders[0].connected ? "No audio files found" : "Recorder not connected"
                color: Theme.muted; font.family: Theme.font; font.pixelSize: 11
            }
        }
    }

    Column {
        id: externalDetailPage
        visible: root.pageMode === "external" && root.selectedExternal !== null
        anchors.fill: parent
        anchors.margins: 12
        spacing: 9

        Row {
            width: parent.width; height: 30
            Rectangle {
                width: 30; height: 30; radius: 8; color: externalDetailBackMouse.containsMouse ? Theme.elevated : "transparent"
                Text { anchors.centerIn: parent; text: "󰁍"; color: Theme.primary; font.family: Theme.iconFont; font.pixelSize: 17 }
                MouseArea { id: externalDetailBackMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedExternal = null }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: root.externalDate(root.selectedExternal); color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
        }

        Rectangle {
            width: parent.width; height: 76; radius: 9; color: Theme.elevated
            Column {
                anchors.centerIn: parent; spacing: 3
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.selectedExternal ? root.duration(root.selectedExternal.durationSeconds) : "00:00"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 22; font.weight: Font.DemiBold }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.selectedExternal ? root.selectedExternal.name + " · " + root.selectedExternal.sampleRate / 1000 + " kHz · " + root.selectedExternal.channels + " ch" : ""; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10 }
            }
        }

        ActionButton { width: parent.width; label: "Play recording"; icon: "󰍷"; onClicked: MeetingRecorder.playExternal(root.selectedExternal.id) }

        Column {
            width: parent.width; spacing: 5
            visible: !root.selectedExternalUploaded
            Text { text: "NOTION DESTINATION"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold }
            ListView {
                width: parent.width; height: 34; orientation: ListView.Horizontal; spacing: 6; clip: true
                model: MeetingRecorder.destinations
                delegate: Rectangle {
                    id: externalDestinationChoice
                    required property var modelData
                    height: 32; width: Math.max(108, externalDestinationLabel.implicitWidth + 24); radius: 8
                    color: root.selectedDestinationId === String(modelData.id) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : (externalDestinationMouse.containsMouse ? Qt.lighter(Theme.elevated, 1.12) : Theme.elevated)
                    border.width: 1; border.color: root.selectedDestinationId === String(modelData.id) ? Theme.primary : "#414852"
                    Text { id: externalDestinationLabel; anchors.centerIn: parent; text: externalDestinationChoice.modelData.label; color: root.selectedDestinationId === String(externalDestinationChoice.modelData.id) ? Theme.primary : Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                    MouseArea { id: externalDestinationMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedDestinationId = String(externalDestinationChoice.modelData.id) }
                }
            }
        }

        ActionButton {
            width: parent.width
            label: root.selectedExternalUploaded ? "View in Notion" : (MeetingRecorder.busy ? "Uploading to Notion…" : "Create Notion voice memo")
            icon: root.selectedExternalUploaded ? "󰄬" : "󰅧"
            accent: root.selectedExternalUploaded ? Theme.green : Theme.primary
            enabled: !MeetingRecorder.busy && (root.selectedExternalUploaded || root.selectedDestinationId !== "")
            onClicked: root.selectedExternalUploaded ? MeetingRecorder.viewExternalNotion(root.selectedExternal.id) : MeetingRecorder.uploadExternal(root.selectedExternal.id, root.selectedDestinationId)
        }

        Text {
            visible: MeetingRecorder.error !== ""
            width: parent.width; text: MeetingRecorder.error; color: Theme.red
            font.family: Theme.font; font.pixelSize: 11; wrapMode: Text.Wrap
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

    Component.onCompleted: {
        MeetingRecorder.popupOpened()
        reconcileDestination()
    }
}
