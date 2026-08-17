import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: 430
    implicitHeight: 477

    property string initialMonitor: ""
    property var displayState: ({ "mode": "extend", "monitors": [] })
    property var monitors: displayState.monitors || []
    property string selectedName: ""
    property string errorText: ""
    property bool busy: false
    property string pendingBrightnessName: ""
    property int pendingBrightness: 0
    readonly property var selectedMonitor: {
        for (let index = 0; index < monitors.length; index++) {
            if (monitors[index].name === selectedName) return monitors[index]
        }
        return null
    }

    function refresh() {
        statusCommand.run()
    }

    function runAction(arguments) {
        if (busy) return
        errorText = ""
        busy = true
        actionProcess.command = ["display-control"].concat(arguments)
        actionProcess.running = true
    }

    function queueBrightness(name, value) {
        pendingBrightnessName = name
        pendingBrightness = Math.round(value)
        brightnessTimer.restart()
    }

    Command {
        id: statusCommand
        command: ["display-control", "status"]
        interval: 10000
        onOutputChanged: {
            if (!output) return
            try {
                let next = JSON.parse(output)
                root.displayState = next
                if (!root.selectedName || !next.monitors.some(monitor => monitor.name === root.selectedName)) {
                    let initial = next.monitors.find(monitor => monitor.name === root.initialMonitor && monitor.enabled)
                    let focused = next.monitors.find(monitor => monitor.focused && monitor.enabled)
                    let active = next.monitors.find(monitor => monitor.enabled)
                    root.selectedName = (initial || focused || active || { "name": "" }).name
                }
            } catch (error) {
                root.errorText = "Could not read the current display state"
            }
        }
    }

    Process {
        id: actionProcess
        stdout: StdioCollector { id: actionOutput }
        stderr: StdioCollector { id: actionError }
        onExited: {
            root.busy = false
            root.errorText = actionError.text.trim()
            refreshTimer.restart()
        }
    }

    Timer {
        id: refreshTimer
        interval: 450
        onTriggered: root.refresh()
    }

    Timer {
        id: brightnessTimer
        interval: 180
        onTriggered: root.runAction(["brightness", root.pendingBrightnessName, String(root.pendingBrightness)])
    }

    component PanelButton: Rectangle {
        id: button
        property string label: ""
        property string icon: ""
        property bool active: false
        signal clicked()
        height: 34
        radius: 8
        color: active ? Theme.primary : Theme.elevated
        border.width: active ? 0 : 1
        border.color: "#3b434e"
        opacity: root.busy ? 0.65 : 1
        Row {
            anchors.centerIn: parent
            spacing: 6
            Text { text: button.icon; color:button.active?Theme.bg:Theme.muted; font.family:Theme.iconFont; font.pixelSize:15 }
            Text { text:button.label; color:button.active?Theme.bg:Theme.fg; font.family:Theme.font; font.pixelSize:11; font.weight:Font.DemiBold }
        }
        MouseArea { anchors.fill:parent; enabled:!root.busy; cursorShape:Qt.PointingHandCursor; onClicked:button.clicked() }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 12
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: parent.width
            spacing: 9

            SectionTitle { icon: "󰍹"; title: "Display Mode" }
            Row {
                width: parent.width
                spacing: 8
                PanelButton {
                    width: (parent.width - 8) / 2
                    icon: "󰍺"
                    label: "Extend"
                    active: root.displayState.mode === "extend"
                    onClicked: root.runAction(["extend"])
                }
                PanelButton {
                    width: (parent.width - 8) / 2
                    icon: "󰍹"
                    label: "Mirror selected"
                    active: root.displayState.mode === "mirror"
                    onClicked: root.runAction(["mirror", root.selectedName])
                }
            }

            SectionTitle { icon: "󰹑"; title: "Connected Displays" }
            Repeater {
                model: root.monitors
                Rectangle {
                    id: monitorCard
                    required property var modelData
                    width: parent.width
                    height: 62
                    radius: 8
                    color: root.selectedName === modelData.name ? "#313b46" : Theme.elevated
                    border.width: root.selectedName === modelData.name ? 1 : 0
                    border.color: Theme.primary
                    opacity: modelData.enabled ? 1 : 0.55

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedName = monitorCard.modelData.name
                    }
                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        Text {
                            width: 24
                            anchors.verticalCenter: parent.verticalCenter
                            text: monitorCard.modelData.name.indexOf("eDP") === 0 ? "󰌢" : "󰍹"
                            color: root.selectedName === monitorCard.modelData.name ? Theme.primary : Theme.muted
                            font.family: Theme.iconFont
                            font.pixelSize: 20
                        }
                        Column {
                            width: parent.width - 92
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3
                            Text {
                                width: parent.width
                                text: monitorCard.modelData.description
                                elide: Text.ElideRight
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: monitorCard.modelData.enabled
                                    ? monitorCard.modelData.name + "  ·  " + monitorCard.modelData.width + "×" + monitorCard.modelData.height + "  ·  " + monitorCard.modelData.scale + "×"
                                    : monitorCard.modelData.name + "  ·  Disabled"
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 10
                            }
                        }
                        Text {
                            width: 38
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: monitorCard.modelData.brightnessAvailable ? monitorCard.modelData.brightness + "%" : ""
                            color: Theme.blue
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            SectionTitle { icon: "󰆾"; title: "Arrange Selected Display" }
            Row {
                width: parent.width
                spacing: 6
                PanelButton { width:(parent.width-18)/4; icon:"󰁍"; label:"Left"; onClicked:root.runAction(["move",root.selectedName,"left"]) }
                PanelButton { width:(parent.width-18)/4; icon:"󰁔"; label:"Right"; onClicked:root.runAction(["move",root.selectedName,"right"]) }
                PanelButton { width:(parent.width-18)/4; icon:"󰁝"; label:"Up"; onClicked:root.runAction(["move",root.selectedName,"up"]) }
                PanelButton { width:(parent.width-18)/4; icon:"󰁅"; label:"Down"; onClicked:root.runAction(["move",root.selectedName,"down"]) }
            }
            Row {
                width: parent.width
                spacing: 8
                PanelButton { width:(parent.width-8)/2; icon:"󰕰"; label:"Horizontal row"; onClicked:root.runAction(["arrange","horizontal"]) }
                PanelButton { width:(parent.width-8)/2; icon:"󰕮"; label:"Vertical stack"; onClicked:root.runAction(["arrange","vertical"]) }
            }

            Column {
                width: parent.width
                spacing: 8
                visible: root.selectedMonitor && root.selectedMonitor.brightnessAvailable
                SectionTitle { icon: "󰃠"; title: "Brightness · " + (root.selectedMonitor ? root.selectedMonitor.brightnessKind : "") }
                Row {
                    width: parent.width
                    spacing: 10
                    Text { width:20; text:"󰃞"; color:Theme.muted; font.family:Theme.iconFont; font.pixelSize:16 }
                    ShellSlider {
                        width: parent.width - 72
                        value: root.selectedMonitor ? root.selectedMonitor.brightness : 0
                        maximumValue: 100
                        onMoved: value => root.queueBrightness(root.selectedName, value)
                    }
                    Text {
                        width: 42
                        horizontalAlignment: Text.AlignRight
                        text: root.selectedMonitor ? root.selectedMonitor.brightness + "%" : "--"
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }
            }

            Text {
                visible: root.selectedMonitor && !root.selectedMonitor.brightnessAvailable
                width: parent.width
                text: "This display does not advertise software brightness control."
                wrapMode: Text.WordWrap
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 10
            }
            Text {
                visible: root.errorText !== ""
                width: parent.width
                text: root.errorText
                wrapMode: Text.WordWrap
                color: Theme.red
                font.family: Theme.font
                font.pixelSize: 10
            }
        }
    }
}
