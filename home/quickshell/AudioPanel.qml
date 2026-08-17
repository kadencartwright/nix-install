import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root
    implicitWidth: 430
    implicitHeight: 445

    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var output: Pipewire.defaultAudioSink
    readonly property var input: Pipewire.defaultAudioSource
    readonly property var sinks: nodes.filter(node => node && node.ready && node.audio && node.isSink && !node.isStream)
    readonly property var sources: nodes.filter(node => node && node.ready && node.audio && !node.isSink && !node.isStream)
    readonly property var streams: nodes.filter(node => node && node.ready && node.audio && node.isStream && node.isSink)

    PwObjectTracker { objects: root.nodes }

    function labelFor(node, fallback) {
        if (!node) return fallback
        let props = node.properties || {}
        return node.nickname || node.description || props["application.name"] || props["media.name"] || node.name || fallback
    }

    function glyphFor(node, inputDevice) {
        if (!node) return inputDevice ? "󰍬" : "󰓃"
        let props = node.properties || {}
        let text = ((node.name || "") + " " + (node.description || "") + " " +
                    (props["device.icon-name"] || "")).toLowerCase()
        if (text.indexOf("bluetooth") >= 0) return "󰂯"
        if (text.indexOf("headphone") >= 0 || text.indexOf("headset") >= 0) return "󰋋"
        if (text.indexOf("hdmi") >= 0 || text.indexOf("display") >= 0) return "󰍹"
        return inputDevice ? "󰍬" : "󰓃"
    }

    component VolumeRow: Rectangle {
        id: volumeRow
        required property var node
        property string title: ""
        property string glyph: "󰓃"
        property bool selected: false
        width: parent ? parent.width : root.width
        height: 66
        radius: 8
        color: selected ? "#313b46" : Theme.elevated
        border.width: selected ? 1 : 0
        border.color: Theme.primary

        Row {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 9
            Text {
                width: 25
                anchors.verticalCenter: parent.verticalCenter
                text: volumeRow.glyph
                color: volumeRow.selected ? Theme.primary : Theme.muted
                font.family: Theme.iconFont
                font.pixelSize: 19
            }
            Column {
                width: parent.width - 75
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Text {
                    width: parent.width
                    text: volumeRow.title
                    elide: Text.ElideRight
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: volumeRow.selected ? Font.DemiBold : Font.Normal
                }
                Row {
                    spacing: 8
                    ShellSlider {
                        width: parent.parent.width - 48
                        value: volumeRow.node && volumeRow.node.audio ? volumeRow.node.audio.volume : 0
                        maximumValue: 1.5
                        accent: volumeRow.selected ? Theme.primary : Theme.blue
                        onMoved: value => { if (volumeRow.node && volumeRow.node.audio) volumeRow.node.audio.volume = value }
                    }
                    Text {
                        width: 34
                        horizontalAlignment: Text.AlignRight
                        text: volumeRow.node && volumeRow.node.audio ? Math.round(volumeRow.node.audio.volume * 100) + "%" : "--"
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 10
                    }
                }
            }
            Text {
                width: 20
                anchors.verticalCenter: parent.verticalCenter
                text: volumeRow.node && volumeRow.node.audio && volumeRow.node.audio.muted ? "󰖁" : "󰕾"
                color: volumeRow.node && volumeRow.node.audio && volumeRow.node.audio.muted ? Theme.red : Theme.muted
                font.family: Theme.iconFont
                font.pixelSize: 17
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (volumeRow.node && volumeRow.node.audio) volumeRow.node.audio.muted = !volumeRow.node.audio.muted
                }
            }
        }
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
            spacing: 8

            SectionTitle { icon: "󰓃"; title: "Audio Output" }
            VolumeRow {
                node: root.output
                title: root.labelFor(root.output, "No output device")
                glyph: root.glyphFor(root.output, false)
                selected: true
            }
            Repeater {
                model: root.sinks.filter(node => node !== root.output)
                VolumeRow {
                    required property var modelData
                    node: modelData
                    title: root.labelFor(modelData, "Audio output")
                    glyph: root.glyphFor(modelData, false)
                    MouseArea {
                        x: 0
                        y: 0
                        width: parent.width - 32
                        height: 32
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }
            }

            SectionTitle { icon: "󰍬"; title: "Microphone" }
            VolumeRow {
                node: root.input
                title: root.labelFor(root.input, "No microphone")
                glyph: root.glyphFor(root.input, true)
                selected: true
            }
            Repeater {
                model: root.sources.filter(node => node !== root.input)
                VolumeRow {
                    required property var modelData
                    node: modelData
                    title: root.labelFor(modelData, "Microphone")
                    glyph: root.glyphFor(modelData, true)
                    MouseArea {
                        x: 0
                        y: 0
                        width: parent.width - 32
                        height: 32
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Pipewire.preferredDefaultAudioSource = modelData
                    }
                }
            }

            SectionTitle { icon: "󰕾"; title: "Application Volume" }
            Repeater {
                model: root.streams
                VolumeRow {
                    required property var modelData
                    node: modelData
                    title: root.labelFor(modelData, "Audio stream")
                    glyph: "󰎆"
                }
            }
            Item {
                visible: root.streams.length === 0
                width: parent.width
                height: 76
                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰝟"; color: Theme.muted; font.family: Theme.iconFont; font.pixelSize: 26 }
                    Text { text: "No applications playing audio"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                }
            }
        }
    }
}
