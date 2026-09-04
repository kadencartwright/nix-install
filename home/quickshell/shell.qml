//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Widgets

ShellRoot {
    id: shell
    property string mainDisplayBrightness: ""
    readonly property string trayWindowToggleBinary: {
        const configured=Quickshell.env("TRAY_WINDOW_TOGGLE_BINARY")
        return configured&&configured.length>0?configured:"tray-window-toggle"
    }

    IpcHandler {
        target: "theme"

        function apply(colorsB64: string): string {
            let colors = ""
            try { colors = Qt.atob(String(colorsB64 || "")) } catch (_) { return "invalid payload" }
            Theme.loadColors(colors)
            return "ok"
        }

        function background(): string {
            return Theme.bg.toString()
        }
    }

    Command {
        command:["display-control","main-brightness"]
        interval:15000
        onOutputChanged:shell.mainDisplayBrightness=output?output+"%":""
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: bar
            required property var modelData
            screen: modelData
            color: Qt.rgba(0, 0, 0, 0)
            implicitHeight: 40
            anchors { top: true; left: true; right: true }
            exclusiveZone: 40

            property string popupKind: ""
            property real popupAnchorX: 0
            property string networkName: "Offline"
            property bool wifiEnabled: false
            property string volume: "0%"
            property string displayBrightness: shell.mainDisplayBrightness
            property string battery: ""
            property string batteryStatus: ""
            property string profile: "Balanced"
            property string codex: "…"
            property string voxtypeState: "idle"
            property bool volumeInitialized: false
            property bool brightnessInitialized: false
            property int lastVolume: 0
            property int lastBrightness: 0
            property string backlightPath: ""
            property int backlightMax: 1
            property bool backlightMaxLoaded: false
            property int reactiveVolume: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
                ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) : 0

            Connections {
                target: keyboardMenu
                function onPanelRequested(kind, screenName) {
                    if (screenName !== bar.screen.name) return
                    bar.togglePopup(kind, bar.width / 2)
                }
            }

            Command { command:["sh","-c","nmcli -t -f active,ssid dev wifi | sed -n 's/^yes://p' | head -1"]; interval:5000; onOutputChanged: bar.networkName=output||"Offline" }
            Command { command:["nmcli","radio","wifi"]; interval:3000; onOutputChanged: bar.wifiEnabled=output==="enabled" }
            Command {
                command:["sh","-c","find /sys/class/backlight -mindepth 1 -maxdepth 1 -type l | head -1"]
                onOutputChanged: if(output) bar.backlightPath=output
            }
            PwObjectTracker { objects:Pipewire.defaultAudioSink?[Pipewire.defaultAudioSink]:[] }
            onReactiveVolumeChanged: {
                let value=reactiveVolume; volume=value+"%"
                if(volumeInitialized&&value!==lastVolume)showOsd("󰕾","Volume",value,150)
                lastVolume=value;volumeInitialized=true
            }
            FileView {
                id:backlightMaxFile
                path:bar.backlightPath?bar.backlightPath+"/max_brightness":""
                blockLoading:true
                onLoaded: {
                    bar.backlightMax=Number(text().trim())||1
                    bar.backlightMaxLoaded=true
                    bar.readBrightness()
                }
            }
            FileView {
                id:backlightValueFile
                path:bar.backlightPath?bar.backlightPath+"/brightness":""
                blockLoading:true
                watchChanges:true
                onLoaded:bar.readBrightness()
                onFileChanged:reload()
            }
            FileView {
                path: {
                    const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR")
                    return runtimeDir && runtimeDir.length > 0
                        ? runtimeDir + "/voxtype/state"
                        : "/run/user/1000/voxtype/state"
                }
                watchChanges:true
                printErrors:false
                onLoaded:bar.voxtypeState=(text()||"idle").trim()
                onLoadFailed:bar.voxtypeState="idle"
                onFileChanged:reload()
            }
            Command { command:["sh","-c","paste -d' ' /sys/class/power_supply/BAT0/capacity /sys/class/power_supply/BAT0/status 2>/dev/null"]; interval:10000; onOutputChanged: { let p=output.split(" "); bar.battery=p[0]?p[0]+"%":""; bar.batteryStatus=p[1]||"" } }
            Command { command:["sh","-c","powerprofilesctl get 2>/dev/null | sed 's/power-saver/Saver/;s/balanced/Balanced/;s/performance/Perf/'"]; interval:2000; onOutputChanged: if(output)bar.profile=output }
            Command { command:["sh","-c","codexbar --format '{session_pct}% - {session_reset}' 2>/dev/null | jq -r .text | sed 's/<[^>]*>//g'"]; interval:300000; onOutputChanged: if(output)bar.codex=output }
            function togglePopup(kind, x) {
                if (popupKind === kind && dropdown.visible) { closePopup(); return }
                dropdownCloseTimer.stop()
                popupKind = kind
                popupAnchorX = x
                if (!dropdown.visible) {
                    dropdown.expanded = false
                    dropdown.visible = true
                    dropdownOpenTimer.restart()
                }
            }
            function closePopup() {
                if (!dropdown.visible) return
                dropdownOpenTimer.stop()
                dropdown.expanded = false
                dropdownCloseTimer.restart()
            }
            function cyclePowerProfile() {
                let next = profile === "Balanced" ? "Perf" : profile === "Perf" ? "Saver" : "Balanced"
                profile = next
                Quickshell.execDetached(["powerprofilesctl", "set", next === "Perf" ? "performance" : next === "Saver" ? "power-saver" : "balanced"])
            }
            function showOsd(icon, label, value, maximum) {
                osd.icon=icon
                osd.label=label
                osd.maximum=maximum||100
                osd.value=Math.max(0,Math.min(osd.maximum,value))
                osd.visible=true
                osd.expanded=true
                osdTimer.restart()
            }
            function readBrightness() {
                if(!backlightMaxLoaded||!backlightValueFile.loaded)return
                let value=Math.round((Number(backlightValueFile.text().trim())||0)*100/backlightMax)
                if(brightnessInitialized&&value!==lastBrightness)showOsd("󰃠","Brightness",value)
                lastBrightness=value;brightnessInitialized=true
            }
            function activateTrayItem(item) {
                const identity=(item.id||item.title||"").toLowerCase()
                if(identity.indexOf("spotify")>=0)Quickshell.execDetached([shell.trayWindowToggleBinary,item.id||item.title])
                else item.activate()
            }
            function isSpotifyTrayItem(item) {
                return (item.id||item.title||"").toLowerCase().indexOf("spotify")>=0
            }

            Item {
                anchors.fill: parent
                Rectangle {
                    id:leftBubble
                    anchors.left:parent.left;anchors.leftMargin:8;anchors.verticalCenter:parent.verticalCenter
                    width:leftWorkspaces.implicitWidth+12;height:32
                    color:Theme.elevated;radius:16;clip:true
                    Behavior on width { NumberAnimation { duration:180;easing.type:Easing.OutCubic } }
                Row {
                    id:leftWorkspaces
                    anchors.left:parent.left;anchors.leftMargin:6;anchors.verticalCenter:parent.verticalCenter;height:26
                    ScriptModel {
                        id: workspaceModel
                        values: Hyprland.workspaces.values
                            .filter(workspace => workspace.id > 0 && workspace.monitor && workspace.monitor.name === bar.screen.name)
                            .sort((left, right) => left.id - right.id)
                    }
                    Repeater {
                        model: workspaceModel
                        Rectangle {
                            required property var modelData
                            width: 26; height: 26
                            color: modelData.active ? Theme.blue : "transparent"
                            radius:13
                            Text { anchors.centerIn: parent; text: modelData.name; color:modelData.active?Theme.bg:Theme.muted; font.family:Theme.font; font.pixelSize:13; font.weight:Font.DemiBold }
                            MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: modelData.activate() }
                        }
                    }
                }
                }
                Rectangle {
                    id:centerBubble
                    anchors.centerIn: parent
                    width: clockText.implicitWidth + 24; height:32
                    radius:16
                    color: bar.popupKind==="calendar"&&dropdown.visible?"#343c47":Theme.elevated
                    Behavior on width { NumberAnimation { duration:180;easing.type:Easing.OutCubic } }
                    Text { id:clockText; anchors.centerIn:parent; text:Qt.formatDateTime(clock.date,"ddd MMM dd hh:mm AP"); color:Theme.fg; font.family:Theme.font; font.pixelSize:12; font.weight:Font.DemiBold }
                    SystemClock { id: clock; precision: SystemClock.Minutes }
                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:bar.togglePopup("calendar",bar.width/2) }
                }
                Rectangle {
                    id:trayBubble
                    anchors.right:rightBubble.left;anchors.rightMargin:6;anchors.verticalCenter:parent.verticalCenter
                    visible:trayModel.values.length>0
                    width:visible?trayItems.implicitWidth+8:0;height:32
                    color:Theme.elevated;radius:16;clip:true
                    Behavior on width { NumberAnimation { duration:180;easing.type:Easing.OutCubic } }
                    ScriptModel {
                        id:trayModel
                        values:SystemTray.items.values.slice().sort((left,right)=>(left.title||left.id).localeCompare(right.title||right.id))
                    }
                    Row {
                        id:trayItems
                        anchors.centerIn:parent;height:28;spacing:2
                        Repeater {
                            model:trayModel
                            Rectangle {
                                id:trayItem
                                required property var modelData
                                width:28;height:28;radius:14
                                color:trayMouse.containsMouse?"#3a444f":"transparent"
                                border.width:modelData.status===Status.NeedsAttention?1:0
                                border.color:Theme.red
                                opacity:modelData.status===Status.Passive?0.62:1

                                IconImage {
                                    id:trayIcon
                                    anchors.centerIn:parent
                                    width:18;height:18
                                    source:trayItem.modelData.icon
                                    asynchronous:true
                                }
                                QsMenuAnchor {
                                    id:trayMenu
                                    menu:trayItem.modelData.hasMenu?trayItem.modelData.menu:null
                                    anchor.window:bar
                                    anchor.item:trayItem
                                    anchor.edges:Edges.Bottom
                                    anchor.gravity:Edges.Bottom
                                    anchor.adjustment:PopupAdjustment.All
                                }
                                MouseArea {
                                    id:trayMouse
                                    anchors.fill:parent
                                    acceptedButtons:Qt.LeftButton|Qt.RightButton|Qt.MiddleButton
                                    hoverEnabled:true
                                    cursorShape:Qt.PointingHandCursor
                                    onClicked:mouse=>{
                                        if(mouse.button===Qt.MiddleButton)trayItem.modelData.secondaryActivate()
                                        else if(mouse.button===Qt.RightButton)trayMenu.open()
                                        else if(bar.isSpotifyTrayItem(trayItem.modelData))bar.activateTrayItem(trayItem.modelData)
                                        else if(trayItem.modelData.onlyMenu&&trayItem.modelData.hasMenu)trayMenu.open()
                                        else bar.activateTrayItem(trayItem.modelData)
                                    }
                                    onWheel:wheel=>trayItem.modelData.scroll(wheel.angleDelta.y,wheel.angleDelta.x!==0)
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    id:rightBubble
                    anchors.right:parent.right;anchors.rightMargin:8;anchors.verticalCenter:parent.verticalCenter
                    width:rightModules.implicitWidth+12;height:32
                    color:Theme.elevated;radius:16;clip:true
                    Behavior on width { NumberAnimation { duration:180;easing.type:Easing.OutCubic } }
                Row {
                    id: rightModules
                    anchors.centerIn:parent;height:28;spacing:4
                    BarButton { height:28; icon:"󰅩"; label:bar.codex; accent:Theme.green; selected:bar.popupKind==="codex"&&dropdown.visible; onClicked:x=>bar.togglePopup("codex",x) }
                    BarButton { height:28; icon:"󰏘"; accent:Theme.primary; selected:bar.popupKind==="theme"&&dropdown.visible; onClicked:x=>bar.togglePopup("theme",x) }
                    BarButton { height:28; icon:"󰑋"; label:MeetingRecorder.recording?MeetingRecorder.formatElapsed(MeetingRecorder.elapsedSeconds):""; accent:MeetingRecorder.recording?Theme.red:Theme.muted; selected:bar.popupKind==="meeting"&&dropdown.visible; onClicked:x=>bar.togglePopup("meeting",x) }
                    BarButton { height:28; icon:bar.voxtypeState==="transcribing"?"󰔟":"󰍬"; accent:bar.voxtypeState==="recording"||bar.voxtypeState==="streaming"?Theme.red:bar.voxtypeState==="transcribing"?Theme.primary:Theme.muted; selected:bar.popupKind==="voxtype"&&dropdown.visible; onClicked:x=>bar.togglePopup("voxtype",x) }
                    BarButton { height:28; icon:"󰎆"; accent:Theme.blue; onClicked:x=>bar.togglePopup("media",x) }
                    BarButton { height:28; icon:"󰖩"; label:bar.networkName; accent:Theme.blue; selected:bar.popupKind==="network"&&dropdown.visible; onClicked:x=>bar.togglePopup("network",x) }
                    BarButton { height:28; icon:"󰐥"; label:bar.profile; accent:Theme.muted; mouseArea.onClicked:bar.cyclePowerProfile() }
                    BarButton { visible:bar.battery!==""; height:28; icon:bar.batteryStatus==="Charging"?"":(Number(bar.battery.replace("%",""))<20?"":Number(bar.battery.replace("%",""))<40?"":Number(bar.battery.replace("%",""))<60?"":Number(bar.battery.replace("%",""))<80?"":""); label:bar.battery; accent:Theme.green; selected:bar.popupKind==="battery"&&dropdown.visible; onClicked:x=>bar.togglePopup("battery",x) }
                    BarButton { height:28; icon:"󰃠"; label:bar.displayBrightness; accent:Theme.blue; selected:bar.popupKind==="display"&&dropdown.visible; onClicked:x=>bar.togglePopup("display",x); mouseArea.onWheel:w=>Quickshell.execDetached(["display-control","brightness","main",w.angleDelta.y>0?"+5":"-5"]) }
                    BarButton { height:28; icon:"󰕾"; label:bar.volume; accent:Theme.muted; selected:bar.popupKind==="audio"&&dropdown.visible; onClicked:x=>bar.togglePopup("audio",x); mouseArea.onWheel: w=>Quickshell.execDetached(["wpctl","set-volume","@DEFAULT_AUDIO_SINK@",w.angleDelta.y>0?"4%+":"4%-"]) }
                }
                }
            }

            NetworkSpeedTest {
                id: networkSpeedTest
                targetScreen: bar.screen
            }

            PopupWindow {
                id: dropdown
                property bool expanded: false
                visible: false
                color: "transparent"
                grabFocus: true
                anchor.window: bar
                anchor.rect.x: Math.max(4, Math.min(bar.width - width - 8, bar.popupAnchorX - width/2))
                anchor.rect.y: bar.height + 3
                implicitWidth: bar.popupKind === "theme" ? 440 : bar.popupKind === "audio" || bar.popupKind === "display" ? 430 : bar.popupKind === "voxtype" || bar.popupKind === "meeting" ? 410 : bar.popupKind === "network" || bar.popupKind === "calendar" ? 350 : bar.popupKind === "codex" ? 340 : bar.popupKind === "battery" ? 380 : 390
                implicitHeight: bar.popupKind === "theme" ? 520 : bar.popupKind === "meeting" ? 611 : bar.popupKind === "display" ? (panelLoader.item ? panelLoader.item.implicitHeight+43 : 420) : bar.popupKind === "network" || bar.popupKind === "voxtype" ? 498 : bar.popupKind === "audio" || bar.popupKind === "calendar" ? 488 : bar.popupKind === "codex" || bar.popupKind === "battery" ? 433 : 283
                onVisibleChanged: if (!visible) {
                    expanded = false
                    bar.popupKind = ""
                }
                Timer { id:dropdownOpenTimer;interval:1;onTriggered:dropdown.expanded=true }
                Timer { id:dropdownCloseTimer;interval:180;onTriggered:dropdown.visible=false }
                Rectangle {
                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                    height: dropdown.expanded ? parent.height : 0
                    opacity: dropdown.expanded ? 1 : 0
                    color: Theme.surface; border.width: 1; border.color: "#363d47"
                    radius: 14
                    clip: true
                    Behavior on height { NumberAnimation { duration:180;easing.type:Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration:130;easing.type:Easing.OutQuad } }
                    Column {
                        width: parent.width; height: dropdown.implicitHeight
                        Item {
                            width: parent.width; height: bar.popupKind === "codex" ? 0 : 43
                            Rectangle {
                                x: 1; y: 1; width: parent.width - 2; height: parent.height - 1
                                color: Theme.elevated; radius: 13
                            }
                            Rectangle {
                                x: 1; y: 14; width: parent.width - 2; height: parent.height - 14
                                color: Theme.elevated
                            }
                            Row { anchors.fill:parent; anchors.leftMargin:13; anchors.rightMargin:13; spacing:9
                                Text { anchors.verticalCenter:parent.verticalCenter; text:bar.popupKind==="theme"?"󰏘":bar.popupKind==="network"?"󰖩":bar.popupKind==="audio"?"󰕾":bar.popupKind==="display"?"󰍹":bar.popupKind==="media"?"󰎆":bar.popupKind==="calendar"?"󰃭":bar.popupKind==="battery"?"":bar.popupKind==="voxtype"?"󰍬":bar.popupKind==="meeting"?"󰑋":"󰅩"; color:bar.popupKind==="meeting"&&MeetingRecorder.recording?Theme.red:Theme.primary; font.family:Theme.iconFont; font.pixelSize:18 }
                                Text { anchors.verticalCenter:parent.verticalCenter; text:bar.popupKind==="theme"?"Themes":bar.popupKind==="codex"?"Codex Usage":bar.popupKind==="display"?"Displays":bar.popupKind==="voxtype"?"Voxtype History":bar.popupKind==="meeting"?"Meeting Recorder":bar.popupKind.charAt(0).toUpperCase()+bar.popupKind.slice(1); color:Theme.fg; font.family:Theme.font; font.pixelSize:14; font.weight:Font.DemiBold }
                                Item { width: parent.width-(bar.popupKind==="network"?168:80); height:1 }
                                Rectangle {
                                    visible: bar.popupKind === "network"
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 24; height: 24; radius: 7
                                    color: speedTestMouse.containsMouse ? "#3b4652" : "transparent"
                                    Text { anchors.centerIn:parent; text:"󰓅"; color:Theme.primary; font.family:Theme.iconFont; font.pixelSize:16 }
                                    MouseArea {
                                        id: speedTestMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            networkSpeedTest.openTest(bar.networkName)
                                            bar.closePopup()
                                        }
                                    }
                                }
                                Rectangle {
                                    visible: bar.popupKind === "network"
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 38; height: 20; radius: 10; color: bar.wifiEnabled ? Theme.primary : "#424954"
                                    Rectangle { anchors.verticalCenter:parent.verticalCenter; x:bar.wifiEnabled?21:3; width:14;height:14;radius:7;color:Theme.fg }
                                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:Quickshell.execDetached(["nmcli","radio","wifi",bar.wifiEnabled?"off":"on"]) }
                                }
                            }
                        }
                        Loader {
                            id: panelLoader
                            width: parent.width; height: parent.height - (bar.popupKind === "codex" ? 0 : 43)
                            clip: true
                            sourceComponent: bar.popupKind==="theme"?themeComponent:bar.popupKind==="network"?networkComponent:bar.popupKind==="audio"?audioComponent:bar.popupKind==="display"?displayComponent:bar.popupKind==="calendar"?calendarComponent:bar.popupKind==="codex"?codexComponent:bar.popupKind==="battery"?batteryComponent:bar.popupKind==="voxtype"?voxtypeComponent:bar.popupKind==="meeting"?meetingComponent:mediaComponent
                            onLoaded: if (bar.popupKind === "display" && item) item.initialMonitor = bar.screen.name
                        }
                    }
                }
            }
            PanelWindow {
                id: osd
                screen: bar.screen
                property string icon: "󰕾"
                property string label: "Volume"
                property int value: 0
                property int maximum: 100
                property bool expanded: false
                visible: false
                color: "transparent"
                implicitWidth: 290
                implicitHeight: 64
                anchors { top: true }
                margins.top: 40
                exclusionMode: ExclusionMode.Ignore
                aboveWindows: true
                Rectangle {
                    anchors.top:parent.top
                    anchors.horizontalCenter:parent.horizontalCenter
                    width:osd.expanded?parent.width:centerBubble.width
                    height:osd.expanded?64:0
                    opacity:osd.expanded?1:0
                    color:Theme.surface
                    border.width:1;border.color:"#3b434e"
                    radius:height>0?Math.min(16,height/2):0
                    clip:true
                    Behavior on height { NumberAnimation { duration:180;easing.type:Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration:180;easing.type:Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration:130;easing.type:Easing.OutQuad } }
                    Row {
                        anchors.fill:parent;anchors.margins:12;spacing:12
                        Text { anchors.verticalCenter:parent.verticalCenter;text:osd.icon;color:Theme.primary;font.family:Theme.iconFont;font.pixelSize:23;width:25 }
                        Column {
                            anchors.verticalCenter:parent.verticalCenter;spacing:5;width:parent.width-78
                            Row { width:parent.width;Text{text:osd.label;color:Theme.fg;font.pixelSize:11;font.weight:Font.DemiBold;width:parent.width-42}Text{text:osd.value+"%";color:Theme.muted;font.pixelSize:11} }
                            Rectangle {
                                width:parent.width;height:7;radius:3;color:"#414854";clip:true
                                Rectangle {
                                    width:parent.width*osd.value/osd.maximum;height:parent.height;radius:3;color:osd.value>100?Theme.red:Theme.primary
                                }
                            }
                        }
                    }
                }
                Timer { id:osdTimer;interval:1400;onTriggered:{osd.expanded=false;osdHideTimer.restart()} }
                Timer { id:osdHideTimer;interval:190;onTriggered:osd.visible=false }
            }
        }
    }
    Component { id: networkComponent; NetworkPanel {} }
    Component { id: audioComponent; AudioPanel {} }
    Component { id: displayComponent; DisplayPanel {} }
    Component { id: mediaComponent; MediaPanel {} }
    Component { id: codexComponent; CodexPanel {} }
    Component { id: calendarComponent; CalendarPanel {} }
    Component { id: batteryComponent; BatteryPanel {} }
    Component { id: voxtypeComponent; VoxtypePanel {} }
    Component { id: themeComponent; ThemePanel {} }
    Component { id: meetingComponent; MeetingRecorderPanel {} }
    KeyboardMenu { id: keyboardMenu }
}
