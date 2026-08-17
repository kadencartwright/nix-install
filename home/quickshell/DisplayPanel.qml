import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: 430
    implicitHeight: 343 + Math.max(1,brightnessMonitors.length)*34 + Math.max(0,brightnessMonitors.length-1)*6

    property string initialMonitor: ""
    property var displayState: ({ "mode": "extend", "monitors": [] })
    property var monitors: displayState.monitors || []
    property string selectedName: ""
    property string errorText: ""
    property bool busy: false
    property string pendingBrightnessName: ""
    property int pendingBrightness: 0
    readonly property var activeMonitors: monitors.filter(monitor => monitor.enabled)
    readonly property var brightnessMonitors: activeMonitors.filter(monitor => monitor.brightnessAvailable)
    readonly property var layoutBounds: {
        if (activeMonitors.length === 0) return { "minX": 0, "minY": 0, "width": 1, "height": 1 }
        let minX = activeMonitors[0].x
        let minY = activeMonitors[0].y
        let maxX = minX
        let maxY = minY
        for (let index = 0; index < activeMonitors.length; index++) {
            let monitor = activeMonitors[index]
            let logicalWidth = monitor.width / Math.max(0.1, monitor.scale)
            let logicalHeight = monitor.height / Math.max(0.1, monitor.scale)
            minX = Math.min(minX, monitor.x)
            minY = Math.min(minY, monitor.y)
            maxX = Math.max(maxX, monitor.x + logicalWidth)
            maxY = Math.max(maxY, monitor.y + logicalHeight)
        }
        return { "minX": minX, "minY": minY, "width": Math.max(1, maxX - minX), "height": Math.max(1, maxY - minY) }
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

    function snapPosition(name, rawX, rawY) {
        let current = activeMonitors.find(monitor => monitor.name === name)
        if (!current) return { "x": Math.round(rawX), "y": Math.round(rawY) }
        let currentWidth = current.width / Math.max(0.1, current.scale)
        let currentHeight = current.height / Math.max(0.1, current.scale)
        let threshold = 14 / Math.max(0.01, layoutCanvas.scaleFactor)
        let snappedX = rawX
        let snappedY = rawY
        let closestX = threshold
        let closestY = threshold

        for (let index = 0; index < activeMonitors.length; index++) {
            let other = activeMonitors[index]
            if (other.name === name) continue
            let otherWidth = other.width / Math.max(0.1, other.scale)
            let otherHeight = other.height / Math.max(0.1, other.scale)
            let xCandidates = [other.x, other.x + otherWidth, other.x - currentWidth, other.x + otherWidth - currentWidth]
            let yCandidates = [other.y, other.y + otherHeight, other.y - currentHeight, other.y + otherHeight - currentHeight]
            for (let xIndex = 0; xIndex < xCandidates.length; xIndex++) {
                let distance = Math.abs(rawX - xCandidates[xIndex])
                if (distance < closestX) { closestX = distance; snappedX = xCandidates[xIndex] }
            }
            for (let yIndex = 0; yIndex < yCandidates.length; yIndex++) {
                let distance = Math.abs(rawY - yCandidates[yIndex])
                if (distance < closestY) { closestY = distance; snappedY = yCandidates[yIndex] }
            }
        }
        return { "x": Math.round(snappedX), "y": Math.round(snappedY) }
    }

    function placeMonitor(name, canvasX, canvasY) {
        let rawX = (canvasX - layoutCanvas.originX) / layoutCanvas.scaleFactor
        let rawY = (canvasY - layoutCanvas.originY) / layoutCanvas.scaleFactor
        let position = snapPosition(name, rawX, rawY)
        runAction(["position", name, String(position.x), String(position.y)])
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
        stderr: StdioCollector { id: actionError }
        onExited: {
            root.busy = false
            root.errorText = actionError.text.trim()
            refreshTimer.restart()
        }
    }

    Timer { id:refreshTimer; interval:350; onTriggered:root.refresh() }
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
            Text { text:button.icon; color:button.active?Theme.bg:Theme.muted; font.family:Theme.iconFont; font.pixelSize:15 }
            Text { text:button.label; color:button.active?Theme.bg:Theme.fg; font.family:Theme.font; font.pixelSize:11; font.weight:Font.DemiBold }
        }
        MouseArea { anchors.fill:parent; enabled:!root.busy; cursorShape:Qt.PointingHandCursor; onClicked:button.clicked() }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        SectionTitle { icon:"󰍹"; title:"Display Mode" }
        Row {
            width: parent.width
            spacing: 8
            PanelButton { width:(parent.width-8)/2; icon:"󰍺"; label:"Extend"; active:root.displayState.mode==="extend"; onClicked:root.runAction(["extend"]) }
            PanelButton { width:(parent.width-8)/2; icon:"󰍹"; label:"Mirror selected"; active:root.displayState.mode==="mirror"; onClicked:root.runAction(["mirror",root.selectedName]) }
        }

        SectionTitle { icon:"󰹑"; title:"Drag Displays to Arrange" }
        Rectangle {
            id: layoutCanvas
            width: parent.width
            height: 170
            radius: 10
            color: "#20262e"
            border.width: 1
            border.color: "#363f49"
            clip: true
            property real scaleFactor: Math.max(0.01, Math.min((width-30)/root.layoutBounds.width, (height-30)/root.layoutBounds.height))
            property real originX: (width-root.layoutBounds.width*scaleFactor)/2-root.layoutBounds.minX*scaleFactor
            property real originY: (height-root.layoutBounds.height*scaleFactor)/2-root.layoutBounds.minY*scaleFactor

            Repeater {
                model: root.activeMonitors
                Rectangle {
                    id: displayTile
                    required property var modelData
                    x: layoutCanvas.originX + modelData.x * layoutCanvas.scaleFactor
                    y: layoutCanvas.originY + modelData.y * layoutCanvas.scaleFactor
                    width: Math.max(62, modelData.width / Math.max(0.1, modelData.scale) * layoutCanvas.scaleFactor)
                    height: Math.max(42, modelData.height / Math.max(0.1, modelData.scale) * layoutCanvas.scaleFactor)
                    radius: 7
                    color: root.selectedName===modelData.name ? "#34495b" : "#2d353f"
                    border.width: root.selectedName===modelData.name ? 2 : 1
                    border.color: root.selectedName===modelData.name ? Theme.primary : "#596471"
                    z: tileMouse.drag.active ? 10 : root.selectedName===modelData.name ? 2 : 1

                    Column {
                        anchors.centerIn: parent
                        width: parent.width-12
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: displayTile.modelData.name.indexOf("eDP")===0 ? "󰌢  "+displayTile.modelData.name : "󰍹  "+displayTile.modelData.name
                            color: root.selectedName===displayTile.modelData.name ? Theme.primary : Theme.fg
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: displayTile.modelData.width+"×"+displayTile.modelData.height
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 9
                        }
                    }
                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        property real startingX: 0
                        property real startingY: 0
                        drag.target: displayTile
                        drag.minimumX: -displayTile.width+6
                        drag.maximumX: layoutCanvas.width-6
                        drag.minimumY: -displayTile.height+6
                        drag.maximumY: layoutCanvas.height-6
                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        onPressed: {
                            root.selectedName = displayTile.modelData.name
                            startingX = displayTile.x
                            startingY = displayTile.y
                        }
                        onReleased: {
                            if (Math.abs(displayTile.x-startingX)>2 || Math.abs(displayTile.y-startingY)>2)
                                root.placeMonitor(displayTile.modelData.name,displayTile.x,displayTile.y)
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: root.activeMonitors.length===0
                text: "No active displays"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 11
            }
        }

        SectionTitle { icon:"󰃠"; title:"Brightness" }
        Column {
            width: parent.width
            spacing: 6
            Repeater {
                model: root.brightnessMonitors
                Rectangle {
                    id: brightnessRow
                    required property var modelData
                    width: parent.width
                    height: 34
                    radius: 7
                    color: Theme.elevated
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9
                        spacing: 8
                        Text {
                            width: 75
                            anchors.verticalCenter: parent.verticalCenter
                            text: brightnessRow.modelData.name
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                        ShellSlider {
                            width: parent.width-129
                            anchors.verticalCenter: parent.verticalCenter
                            value: brightnessRow.modelData.brightness
                            maximumValue: 100
                            onMoved: value => root.queueBrightness(brightnessRow.modelData.name,value)
                        }
                        Text {
                            width: 38
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: brightnessRow.modelData.brightness+"%"
                            color: Theme.blue
                            font.family: Theme.font
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
        Text {
            visible: root.brightnessMonitors.length===0
            width: parent.width
            text: "No connected display exposes backlight or DDC/CI brightness control."
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 9
        }
        Text { visible:root.errorText!==""; width:parent.width; text:root.errorText; wrapMode:Text.WordWrap; color:Theme.red; font.family:Theme.font; font.pixelSize:9 }
    }
}
