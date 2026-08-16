import QtQuick

Item {
    id: root
    implicitWidth: 380; implicitHeight: 390
    property int percent: 0
    property string status: "Unknown"
    property real energyNow: 0
    property real energyFull: 0
    property real energyDesign: 0
    property real power: 0
    property real voltage: 0
    property int cycles: 0
    property var samples: []
    readonly property int health: energyDesign > 0 ? Math.round(energyFull / energyDesign * 100) : 0
    readonly property string remaining: {
        if (power <= 0) return "Calculating…"
        let hours = status === "Charging" ? (energyFull-energyNow)/power : energyNow/power
        return Math.floor(hours) + "h " + Math.round((hours-Math.floor(hours))*60) + "m"
    }
    Command {
        command: ["sh","-c","b=/sys/class/power_supply/BAT0; printf '%s|%s|%s|%s|%s|%s|%s|%s' \"$(cat $b/capacity)\" \"$(cat $b/status)\" \"$(cat $b/energy_now 2>/dev/null || echo 0)\" \"$(cat $b/energy_full 2>/dev/null || echo 0)\" \"$(cat $b/energy_full_design 2>/dev/null || echo 0)\" \"$(cat $b/power_now 2>/dev/null || echo 0)\" \"$(cat $b/voltage_now 2>/dev/null || echo 0)\" \"$(cat $b/cycle_count 2>/dev/null || echo 0)\""]
        interval: 30000
        onOutputChanged: {
            let p=output.split("|"); if(p.length<8)return
            root.percent=Number(p[0]);root.status=p[1];root.energyNow=Number(p[2])/1000000;root.energyFull=Number(p[3])/1000000;root.energyDesign=Number(p[4])/1000000;root.power=Number(p[5])/1000000;root.voltage=Number(p[6])/1000000;root.cycles=Number(p[7]);
            root.samples=root.samples.concat([{pct:root.percent,watts:root.power}]).slice(-60)
            chart.requestPaint()
        }
    }
    component Stat: Column {
        property string value: ""; property string label: ""
        width: 82; spacing: 3
        Text { anchors.horizontalCenter:parent.horizontalCenter;text:parent.value;color:Theme.fg;font.pixelSize:14;font.weight:Font.DemiBold }
        Text { anchors.horizontalCenter:parent.horizontalCenter;text:parent.label;color:Theme.muted;font.pixelSize:10 }
    }
    Column {
        anchors.fill:parent; anchors.margins:14; spacing:12
        Row { width:parent.width
            Column { width:parent.width-90; spacing:3
                Text { text:root.percent+"%";color:Theme.fg;font.pixelSize:30;font.weight:Font.Light }
                Text { text:root.status+" · "+root.remaining+" remaining";color:Theme.muted;font.pixelSize:12 }
            }
            Text { anchors.verticalCenter:parent.verticalCenter;text:root.status==="Charging"?"":root.percent<20?"":root.percent<40?"":root.percent<60?"":root.percent<80?"":"";color:root.percent<15?Theme.red:Theme.green;font.family:Theme.iconFont;font.pixelSize:34 }
        }
        Rectangle { width:parent.width;height:1;color:"#4a515c" }
        Text { text:"CHARGE HISTORY";color:Theme.muted;font.pixelSize:11;font.weight:Font.DemiBold }
        Rectangle {
            width:parent.width;height:120;color:Theme.elevated
            Canvas { id:chart;anchors.fill:parent;anchors.margins:9
                onPaint: {
                    let c=getContext("2d");c.reset();c.lineWidth=1;c.strokeStyle="#414954";
                    for(let y=0;y<=4;y++){c.beginPath();c.moveTo(0,height*y/4);c.lineTo(width,height*y/4);c.stroke()}
                    let s=root.samples;if(!s.length)return;c.lineWidth=2;c.strokeStyle=Theme.green;c.beginPath();
                    for(let i=0;i<s.length;i++){let x=s.length===1?width:width*i/59;let y=height-(s[i].pct/100*height);if(i===0)c.moveTo(x,y);else c.lineTo(x,y)}c.stroke()
                }
            }
            Text { anchors.left:parent.left;anchors.leftMargin:8;anchors.top:parent.top;anchors.topMargin:5;text:"100%";color:Theme.muted;font.pixelSize:9 }
            Text { anchors.left:parent.left;anchors.leftMargin:8;anchors.bottom:parent.bottom;anchors.bottomMargin:5;text:"0%";color:Theme.muted;font.pixelSize:9 }
            Text { anchors.right:parent.right;anchors.rightMargin:8;anchors.bottom:parent.bottom;anchors.bottomMargin:5;text:root.samples.length<2?"Tracking started now":"Last "+root.samples.length+" samples";color:Theme.muted;font.pixelSize:9 }
        }
        Row { anchors.horizontalCenter:parent.horizontalCenter;spacing:5
            Stat { value:root.power.toFixed(1)+" W";label:root.status==="Charging"?"Charge rate":"Power draw" }
            Stat { value:root.energyNow.toFixed(1)+" Wh";label:"Remaining" }
            Stat { value:root.health+"%";label:"Health" }
            Stat { value:String(root.cycles);label:"Cycles" }
        }
        Rectangle { width:parent.width;height:1;color:"#4a515c" }
        Row { anchors.horizontalCenter:parent.horizontalCenter;spacing:24
            Text { text:"Full capacity  "+root.energyFull.toFixed(1)+" Wh";color:Theme.muted;font.pixelSize:11 }
            Text { text:"Voltage  "+root.voltage.toFixed(1)+" V";color:Theme.muted;font.pixelSize:11 }
        }
    }
}
