//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

ShellRoot {
    id: shell

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: bar
            required property var modelData
            screen: modelData
            color: Theme.bg
            implicitHeight: 36
            anchors { top: true; left: true; right: true }
            exclusiveZone: 36

            property string popupKind: ""
            property real popupAnchorX: 0
            property string networkName: "Offline"
            property string volume: "0%"
            property string battery: ""
            property string batteryStatus: ""
            property string profile: "Balanced"
            property string codex: "…"
            property bool volumeInitialized: false
            property bool brightnessInitialized: false
            property int lastVolume: 0
            property int lastBrightness: 0

            Command { command:["sh","-c","nmcli -t -f active,ssid dev wifi | sed -n 's/^yes://p' | head -1"]; interval:5000; onOutputChanged: bar.networkName=output||"Offline" }
            Command {
                command:["sh","-c","wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf \"%.0f\",$2*100}'"]
                interval:250
                onOutputChanged: {
                    if (!output) return
                    let value=Number(output); bar.volume=value+"%"
                    if (bar.volumeInitialized && value!==bar.lastVolume) bar.showOsd("󰕾","Volume",value)
                    bar.lastVolume=value; bar.volumeInitialized=true
                }
            }
            Command {
                command:["sh","-c","d=$(find /sys/class/backlight -mindepth 1 -maxdepth 1 -type l | head -1); [ -n \"$d\" ] && awk -v m=\"$(cat \"$d/max_brightness\")\" '{printf \"%.0f\",$1*100/m}' \"$d/brightness\""]
                interval:250
                onOutputChanged: {
                    if (!output) return
                    let value=Number(output)
                    if (bar.brightnessInitialized && value!==bar.lastBrightness) bar.showOsd("󰃠","Brightness",value)
                    bar.lastBrightness=value; bar.brightnessInitialized=true
                }
            }
            Command { command:["sh","-c","paste -d' ' /sys/class/power_supply/BAT0/capacity /sys/class/power_supply/BAT0/status 2>/dev/null"]; interval:10000; onOutputChanged: { let p=output.split(" "); bar.battery=p[0]?p[0]+"%":""; bar.batteryStatus=p[1]||"" } }
            Command { command:["sh","-c","powerprofilesctl get 2>/dev/null | sed 's/power-saver/Saver/;s/balanced/Balanced/;s/performance/Perf/'"]; interval:2000; onOutputChanged: if(output)bar.profile=output }
            Command { command:["sh","-c","codexbar --format '{session_pct}% - {session_reset}' 2>/dev/null | jq -r .text | sed 's/<[^>]*>//g'"]; interval:300000; onOutputChanged: if(output)bar.codex=output }

            function togglePopup(kind, x) {
                if (popupKind === kind && dropdown.visible) { dropdown.visible = false; popupKind = ""; return }
                popupKind = kind; popupAnchorX = x; dropdown.visible = true
            }
            function cyclePowerProfile() {
                let next = profile === "Balanced" ? "Perf" : profile === "Perf" ? "Saver" : "Balanced"
                profile = next
                Quickshell.execDetached(["powerprofilesctl", "set", next === "Perf" ? "performance" : next === "Saver" ? "power-saver" : "balanced"])
            }
            function showOsd(icon, label, value) {
                osd.icon=icon; osd.label=label; osd.value=Math.max(0,Math.min(100,value));osd.visible=true;osdTimer.restart()
            }

            Rectangle {
                anchors.fill: parent; anchors.margins: 4; color: Theme.surface
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; height: 28
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
                            width: 27; height: 28
                            color: modelData.active ? Theme.blue : "transparent"
                            Text { anchors.centerIn: parent; text: modelData.name; color:modelData.active?Theme.bg:Theme.muted; font.family:Theme.font; font.pixelSize:13; font.weight:Font.DemiBold }
                            MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: modelData.activate() }
                        }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: clockText.implicitWidth + 12; height: 28; color: bar.popupKind==="calendar"&&dropdown.visible?Theme.elevated:"transparent"
                    Text { id:clockText; anchors.centerIn:parent; text:Qt.formatDateTime(clock.date,"ddd MMM dd hh:mm AP"); color:Theme.fg; font.family:Theme.font; font.pixelSize:12; font.weight:Font.DemiBold }
                    SystemClock { id: clock; precision: SystemClock.Minutes }
                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:bar.togglePopup("calendar",bar.width/2) }
                }
                Row {
                    id: rightModules
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; height: 28; spacing: 4
                    BarButton { height:28; icon:"󰅩"; label:bar.codex; accent:Theme.green; selected:bar.popupKind==="codex"&&dropdown.visible; onClicked:x=>bar.togglePopup("codex",x) }
                    BarButton { height:28; icon:"󰎆"; accent:Theme.blue; onClicked:x=>bar.togglePopup("media",x) }
                    BarButton { height:28; icon:"󰖩"; label:bar.networkName; accent:Theme.blue; selected:bar.popupKind==="network"&&dropdown.visible; onClicked:x=>bar.togglePopup("network",x) }
                    BarButton { height:28; icon:"󰐥"; label:bar.profile; accent:Theme.muted; mouseArea.onClicked:bar.cyclePowerProfile() }
                    BarButton { visible:bar.battery!==""; height:28; icon:bar.batteryStatus==="Charging"?"":(Number(bar.battery.replace("%",""))<20?"":Number(bar.battery.replace("%",""))<40?"":Number(bar.battery.replace("%",""))<60?"":Number(bar.battery.replace("%",""))<80?"":""); label:bar.battery; accent:Theme.green; selected:bar.popupKind==="battery"&&dropdown.visible; onClicked:x=>bar.togglePopup("battery",x) }
                    BarButton { height:28; icon:"󰕾"; label:bar.volume; accent:Theme.muted; selected:bar.popupKind==="audio"&&dropdown.visible; onClicked:x=>bar.togglePopup("audio",x); mouseArea.onWheel: w=>Quickshell.execDetached(["wpctl","set-volume","@DEFAULT_AUDIO_SINK@",w.angleDelta.y>0?"4%+":"4%-"]) }
                }
            }

            PopupWindow {
                id: dropdown
                visible: false
                color: "transparent"
                grabFocus: true
                anchor.window: bar
                anchor.rect.x: Math.max(4, Math.min(bar.width - width - 8, bar.popupAnchorX - width/2))
                anchor.rect.y: bar.height + 3
                implicitWidth: bar.popupKind === "audio" ? 430 : bar.popupKind === "network" || bar.popupKind === "calendar" ? 350 : bar.popupKind === "codex" ? 340 : bar.popupKind === "battery" ? 380 : 390
                implicitHeight: bar.popupKind === "network" ? 500 : bar.popupKind === "audio" || bar.popupKind === "calendar" ? 488 : bar.popupKind === "codex" || bar.popupKind === "battery" ? 433 : 283
                onVisibleChanged: if (!visible) bar.popupKind = ""
                Rectangle {
                    anchors.fill: parent; color: Theme.surface; border.width: 1; border.color: "#363d47"
                    Column {
                        anchors.fill: parent
                        Rectangle {
                            width: parent.width; height: bar.popupKind === "codex" ? 0 : 43; color: Theme.elevated
                            clip: true
                            Row { anchors.fill:parent; anchors.leftMargin:13; anchors.rightMargin:13; spacing:9
                                Text { anchors.verticalCenter:parent.verticalCenter; text:bar.popupKind==="network"?"󰖩":bar.popupKind==="audio"?"󰕾":bar.popupKind==="media"?"󰎆":bar.popupKind==="calendar"?"󰃭":bar.popupKind==="battery"?"":"󰅩"; color:Theme.primary; font.family:Theme.iconFont; font.pixelSize:18 }
                                Text { anchors.verticalCenter:parent.verticalCenter; text:bar.popupKind==="codex"?"Codex Usage":bar.popupKind.charAt(0).toUpperCase()+bar.popupKind.slice(1); color:Theme.fg; font.family:Theme.font; font.pixelSize:14; font.weight:Font.DemiBold }
                                Item { width: parent.width-(bar.popupKind==="network"?135:80); height:1 }
                                Rectangle {
                                    visible: bar.popupKind === "network"
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 38; height: 20; radius: 10; color: bar.networkName === "Offline" ? "#424954" : Theme.primary
                                    Rectangle { anchors.verticalCenter:parent.verticalCenter; x:bar.networkName==="Offline"?3:21; width:14;height:14;radius:7;color:Theme.fg }
                                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:Quickshell.execDetached(["nmcli","radio","wifi",bar.networkName==="Offline"?"on":"off"]) }
                                }
                            }
                        }
                        Loader {
                            width: parent.width; height: parent.height - (bar.popupKind === "codex" ? 0 : 43)
                            clip: true
                            sourceComponent: bar.popupKind==="network"?networkComponent:bar.popupKind==="audio"?audioComponent:bar.popupKind==="calendar"?calendarComponent:bar.popupKind==="codex"?codexComponent:bar.popupKind==="battery"?batteryComponent:mediaComponent
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
                visible: false
                color: "transparent"
                implicitWidth: 290
                implicitHeight: 64
                anchors { top: true }
                margins.top: 40
                exclusionMode: ExclusionMode.Ignore
                aboveWindows: true
                Rectangle {
                    anchors.fill:parent
                    color:Theme.surface
                    border.width:1;border.color:"#3b434e"
                    Row {
                        anchors.fill:parent;anchors.margins:12;spacing:12
                        Text { anchors.verticalCenter:parent.verticalCenter;text:osd.icon;color:Theme.primary;font.family:Theme.iconFont;font.pixelSize:23;width:25 }
                        Column {
                            anchors.verticalCenter:parent.verticalCenter;spacing:5;width:parent.width-78
                            Row { width:parent.width;Text{text:osd.label;color:Theme.fg;font.pixelSize:11;font.weight:Font.DemiBold;width:parent.width-42}Text{text:osd.value+"%";color:Theme.muted;font.pixelSize:11} }
                            Rectangle { width:parent.width;height:7;radius:3;color:"#414854";Rectangle{width:parent.width*osd.value/100;height:parent.height;radius:3;color:Theme.primary} }
                        }
                    }
                }
                Timer { id:osdTimer;interval:1400;onTriggered:osd.visible=false }
            }
        }
    }
    Component { id: networkComponent; NetworkPanel {} }
    Component { id: audioComponent; AudioPanel {} }
    Component { id: mediaComponent; MediaPanel {} }
    Component { id: codexComponent; CodexPanel {} }
    Component { id: calendarComponent; CalendarPanel {} }
    Component { id: batteryComponent; BatteryPanel {} }
}
