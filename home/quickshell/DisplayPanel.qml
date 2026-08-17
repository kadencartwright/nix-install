import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: 430
    implicitHeight: 385 + Math.max(1,brightnessMonitors.length)*34 + Math.max(0,brightnessMonitors.length-1)*6

    property string initialMonitor: ""
    property var displayState: ({ "mode": "extend", "monitors": [] })
    property var brightnessState: ({})
    property var monitors: displayState.monitors || []
    property string selectedName: ""
    property string errorText: ""
    property bool busy: false
    property string pendingBrightnessName: ""
    property int pendingBrightness: 0
    property real snapGuideX: -1
    property real snapGuideY: -1
    property real canvasPanX: 0
    property real canvasPanY: 0
    property var draftPositions: ({})
    property bool hasPendingLayout: false
    property bool applyingLayout: false
    readonly property var activeMonitors: monitors.filter(monitor => monitor.enabled)
    readonly property var brightnessMonitors: {
        let result = []
        for (let index = 0; index < activeMonitors.length; index++) {
            let monitor = activeMonitors[index]
            let reading = brightnessState[monitor.name]
            if (!reading) continue
            let combined = {}
            for (let key in monitor) combined[key] = monitor[key]
            combined.brightness = reading.brightness
            combined.brightnessKind = reading.brightnessKind
            result.push(combined)
        }
        return result
    }
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
        layoutCommand.run()
        brightnessCommand.run()
    }

    function runAction(arguments, isLayoutApply) {
        if (busy) return
        errorText = ""
        busy = true
        applyingLayout = isLayoutApply === true
        actionProcess.command = ["display-control"].concat(arguments)
        actionProcess.running = true
    }

    function positionFor(monitor) {
        return draftPositions[monitor.name] || { "x": monitor.x, "y": monitor.y }
    }

    function stageMonitor(tile) {
        let rawX = (tile.x - layoutCanvas.originX) / layoutCanvas.scaleFactor
        let rawY = (tile.y - layoutCanvas.originY) / layoutCanvas.scaleFactor
        let position = snapPosition(tile.modelData.name, rawX, rawY)
        let next = {}
        for (let key in draftPositions) next[key] = draftPositions[key]
        next[tile.modelData.name] = { "x": position.x, "y": position.y }
        draftPositions = next
        hasPendingLayout = true
    }

    function applyDraftLayout() {
        if (!hasPendingLayout) return
        let arguments = ["positions"]
        for (let index = 0; index < activeMonitors.length; index++) {
            let monitor = activeMonitors[index]
            let position = positionFor(monitor)
            arguments.push(monitor.name, String(Math.round(position.x)), String(Math.round(position.y)))
        }
        runAction(arguments, true)
    }

    function discardDraftLayout() {
        draftPositions = ({})
        hasPendingLayout = false
        snapGuideX = -1
        snapGuideY = -1
    }

    function acceptDraftLayout() {
        let updated = []
        for (let index = 0; index < monitors.length; index++) {
            let monitor = monitors[index]
            let copy = {}
            for (let key in monitor) copy[key] = monitor[key]
            let position = draftPositions[monitor.name]
            if (position) {
                copy.x = position.x
                copy.y = position.y
            }
            updated.push(copy)
        }
        displayState = { "mode": displayState.mode, "monitors": updated }
        draftPositions = ({})
        hasPendingLayout = false
    }

    function panCanvas(wheel) {
        let amount = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
        if ((wheel.modifiers & Qt.ShiftModifier) !== 0)
            canvasPanX += amount * 0.3
        else
            canvasPanY += amount * 0.3
        wheel.accepted = true
    }

    function queueBrightness(name, value) {
        let next = {}
        for (let key in brightnessState) next[key] = brightnessState[key]
        next[name] = { "brightness": Math.round(value), "brightnessKind": brightnessState[name].brightnessKind }
        brightnessState = next
        pendingBrightnessName = name
        pendingBrightness = Math.round(value)
        brightnessTimer.restart()
    }

    function snapPosition(name, rawX, rawY) {
        let current = activeMonitors.find(monitor => monitor.name === name)
        if (!current) return { "x": Math.round(rawX), "y": Math.round(rawY), "snappedX": false, "snappedY": false }
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
            let otherPosition = positionFor(other)
            let otherWidth = other.width / Math.max(0.1, other.scale)
            let otherHeight = other.height / Math.max(0.1, other.scale)
            let xCandidates = [otherPosition.x, otherPosition.x + otherWidth, otherPosition.x - currentWidth, otherPosition.x + otherWidth - currentWidth]
            let yCandidates = [otherPosition.y, otherPosition.y + otherHeight, otherPosition.y - currentHeight, otherPosition.y + otherHeight - currentHeight]
            for (let xIndex = 0; xIndex < xCandidates.length; xIndex++) {
                let distance = Math.abs(rawX - xCandidates[xIndex])
                if (distance < closestX) { closestX = distance; snappedX = xCandidates[xIndex] }
            }
            for (let yIndex = 0; yIndex < yCandidates.length; yIndex++) {
                let distance = Math.abs(rawY - yCandidates[yIndex])
                if (distance < closestY) { closestY = distance; snappedY = yCandidates[yIndex] }
            }
        }
        return {
            "x": Math.round(snappedX),
            "y": Math.round(snappedY),
            "snappedX": closestX < threshold,
            "snappedY": closestY < threshold
        }
    }

    function previewMonitorSnap(tile) {
        let rawX = (tile.x - layoutCanvas.originX) / layoutCanvas.scaleFactor
        let rawY = (tile.y - layoutCanvas.originY) / layoutCanvas.scaleFactor
        let position = snapPosition(tile.modelData.name, rawX, rawY)
        if (position.snappedX) tile.x = layoutCanvas.originX + position.x * layoutCanvas.scaleFactor
        if (position.snappedY) tile.y = layoutCanvas.originY + position.y * layoutCanvas.scaleFactor
        snapGuideX = position.snappedX ? tile.x : -1
        snapGuideY = position.snappedY ? tile.y : -1
    }

    Command {
        id: layoutCommand
        command: ["display-control", "layout-status"]
        interval: 3000
        onOutputChanged: {
            if (!output) return
            try {
                let next = JSON.parse(output)
                if (!root.hasPendingLayout) root.displayState = next
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

    Command {
        id: brightnessCommand
        command: ["display-control", "brightness-status"]
        interval: 15000
        onOutputChanged: {
            if (!output) return
            try {
                root.brightnessState = JSON.parse(output).readings || {}
            } catch (error) {
                root.errorText = "Could not read display brightness"
            }
        }
    }

    Process {
        id: actionProcess
        stderr: StdioCollector { id: actionError }
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            root.errorText = actionError.text.trim()
            if (root.applyingLayout && exitCode === 0) {
                root.acceptDraftLayout()
            }
            root.applyingLayout = false
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
        opacity: root.busy || !button.enabled ? 0.55 : 1
        Row {
            anchors.centerIn: parent
            spacing: 6
            Text { text:button.icon; color:button.active?Theme.bg:Theme.muted; font.family:Theme.iconFont; font.pixelSize:15 }
            Text { text:button.label; color:button.active?Theme.bg:Theme.fg; font.family:Theme.font; font.pixelSize:11; font.weight:Font.DemiBold }
        }
        MouseArea { anchors.fill:parent; enabled:!root.busy&&button.enabled; cursorShape:Qt.PointingHandCursor; onClicked:button.clicked() }
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
            property real originX: (width-root.layoutBounds.width*scaleFactor)/2-root.layoutBounds.minX*scaleFactor+root.canvasPanX
            property real originY: (height-root.layoutBounds.height*scaleFactor)/2-root.layoutBounds.minY*scaleFactor+root.canvasPanY

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => root.panCanvas(wheel)
            }

            Rectangle {
                x: root.snapGuideX
                y: 0
                width: 2
                height: parent.height
                color: Theme.primary
                opacity: 0.75
                visible: root.snapGuideX >= 0
                z: 20
            }
            Rectangle {
                x: 0
                y: root.snapGuideY
                width: parent.width
                height: 2
                color: Theme.primary
                opacity: 0.75
                visible: root.snapGuideY >= 0
                z: 20
            }

            Repeater {
                model: root.activeMonitors
                Rectangle {
                    id: displayTile
                    required property var modelData
                    function syncPosition() {
                        if (tileMouse.drag.active) return
                        let position = root.positionFor(modelData)
                        x = layoutCanvas.originX + position.x * layoutCanvas.scaleFactor
                        y = layoutCanvas.originY + position.y * layoutCanvas.scaleFactor
                    }
                    Component.onCompleted: syncPosition()
                    width: Math.max(62, modelData.width / Math.max(0.1, modelData.scale) * layoutCanvas.scaleFactor)
                    height: Math.max(42, modelData.height / Math.max(0.1, modelData.scale) * layoutCanvas.scaleFactor)
                    radius: 7
                    color: root.selectedName===modelData.name ? "#34495b" : "#2d353f"
                    border.width: root.selectedName===modelData.name ? 2 : 1
                    border.color: root.selectedName===modelData.name ? Theme.primary : "#596471"
                    z: tileMouse.drag.active ? 10 : root.selectedName===modelData.name ? 2 : 1

                    Connections {
                        target: root
                        function onDraftPositionsChanged() { displayTile.syncPosition() }
                        function onCanvasPanXChanged() { displayTile.syncPosition() }
                        function onCanvasPanYChanged() { displayTile.syncPosition() }
                    }
                    Connections {
                        target: layoutCanvas
                        function onOriginXChanged() { displayTile.syncPosition() }
                        function onOriginYChanged() { displayTile.syncPosition() }
                        function onScaleFactorChanged() { displayTile.syncPosition() }
                    }

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
                        onWheel: wheel => root.panCanvas(wheel)
                        onPressed: {
                            root.selectedName = displayTile.modelData.name
                            startingX = displayTile.x
                            startingY = displayTile.y
                        }
                        onPositionChanged: {
                            if (drag.active) root.previewMonitorSnap(displayTile)
                        }
                        onReleased: {
                            root.previewMonitorSnap(displayTile)
                            root.snapGuideX = -1
                            root.snapGuideY = -1
                            if (Math.abs(displayTile.x-startingX)>2 || Math.abs(displayTile.y-startingY)>2)
                                root.stageMonitor(displayTile)
                        }
                        onCanceled: {
                            root.snapGuideX = -1
                            root.snapGuideY = -1
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
            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 7
                text: "Wheel pans · Shift+wheel horizontal"
                color: Theme.muted
                opacity: 0.7
                font.family: Theme.font
                font.pixelSize: 8
                z: 21
            }
        }

        Row {
            width: parent.width
            spacing: 8
            PanelButton {
                width: (parent.width-8)/2
                icon: "󰄬"
                label: "Apply layout"
                active: root.hasPendingLayout
                enabled: root.hasPendingLayout
                onClicked: root.applyDraftLayout()
            }
            PanelButton {
                width: (parent.width-8)/2
                icon: "󰜺"
                label: "Discard"
                enabled: root.hasPendingLayout
                onClicked: root.discardDraftLayout()
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
