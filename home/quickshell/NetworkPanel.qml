import QtQuick
import Quickshell

Item {
    id: root
    implicitWidth: 350; implicitHeight: 457
    property var activeNetwork: null
    property var availableNetworks: []
    Command {
        command: ["sh", "-c", "nmcli -t --escape no -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list --rescan auto | jq -Rsc 'split(\"\\n\")|map(select(length>0)|split(\":\")|{active:(.[0]==\"yes\"),ssid:.[1],signal:(.[2]|tonumber),security:.[3]})'"]
        interval: 12000
        onOutputChanged: {
            try {
                let rows = JSON.parse(output).filter(row => row.ssid.length > 0)
                root.activeNetwork = rows.find(row => row.active) || null
                let seen = {}
                root.availableNetworks = rows.filter(row => {
                    if (row.active || seen[row.ssid]) return false
                    seen[row.ssid] = true
                    return true
                }).slice(0, 6)
            } catch (_) {}
        }
    }
    component NetworkRow: Rectangle {
        id: row
        required property var network
        property bool connected: false
        width: parent.width; height: connected ? 62 : 46
        color: connected ? Theme.elevated : "transparent"
        Row {
            anchors.fill: parent
            Rectangle { width:42;height:parent.height;color:row.connected?"#344554":"transparent";Text{anchors.centerIn:parent;text:row.network.signal>70?"󰤨":row.network.signal>40?"󰤥":"󰤟";color:row.connected?Theme.primary:Theme.muted;font.family:Theme.iconFont;font.pixelSize:20} }
            Column { anchors.verticalCenter:parent.verticalCenter;width:parent.width-76
                Text{text:row.network.ssid;color:Theme.fg;font.family:Theme.font;font.pixelSize:13;font.weight:row.connected?Font.DemiBold:Font.Normal}
                Text{text:row.connected?("Connected · "+row.network.signal+"%"):(row.network.security||"Open");color:Theme.muted;font.family:Theme.font;font.pixelSize:11}
            }
            Text { anchors.verticalCenter:parent.verticalCenter;text:row.network.security?"󰌾":"";color:Theme.muted;font.family:Theme.iconFont;font.pixelSize:14 }
        }
        MouseArea { anchors.fill:parent;enabled:!row.connected;onClicked:Quickshell.execDetached(["nmcli","connection","up","id",row.network.ssid]) }
    }
    Column {
        anchors.fill:parent; anchors.margins:10; spacing:3
        Text { text:"ACTIVE CONNECTION";color:Theme.muted;font.pixelSize:11;font.weight:Font.DemiBold;height:22;verticalAlignment:Text.AlignVCenter }
        NetworkRow { visible:root.activeNetwork!==null; network:root.activeNetwork||({ssid:"",signal:0,security:""}); connected:true }
        Text { text:"AVAILABLE NETWORKS";color:Theme.muted;font.pixelSize:11;font.weight:Font.DemiBold;height:30;verticalAlignment:Text.AlignBottom }
        Repeater { model:root.availableNetworks; NetworkRow { required property var modelData; network:modelData } }
    }
}
