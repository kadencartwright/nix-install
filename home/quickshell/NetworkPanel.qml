import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    implicitWidth: 350; implicitHeight: 457
    property var activeNetwork: null
    property var availableNetworks: []
    property var selectedNetwork: null
    property string connectionError: ""
    property bool connecting: false
    function refresh() { scanProcess.run() }
    function choose(network) {
        connectionError = ""
        selectedNetwork = network
        passwordInput.text = ""
    }
    function connectSelected() {
        if (!selectedNetwork || connecting) return
        connectionError = ""
        connecting = true
        connector.command = selectedNetwork.security
            ? ["nmcli", "device", "wifi", "connect", selectedNetwork.ssid, "password", passwordInput.text]
            : ["nmcli", "device", "wifi", "connect", selectedNetwork.ssid]
        connector.running = true
    }
    Process {
        id: connector
        running: false
        property string errors: ""
        stdout: StdioCollector { onStreamFinished: connector.errors = text.trim() }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) connector.errors = text.trim() }
        onStarted: errors = ""
        onExited: code => {
            root.connecting = false
            if (code === 0) {
                root.selectedNetwork = null
                root.refresh()
            } else {
                root.connectionError = errors || "Could not connect to this network."
            }
        }
    }
    Command {
        id: scanProcess
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
        MouseArea {
            anchors.fill:parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (row.connected)
                    Quickshell.execDetached(["sh", "-c", "nmcli device disconnect \"$(nmcli -t -f DEVICE,TYPE device | sed -n 's/:wifi$//p' | head -1)\""])
                else
                    root.choose(row.network)
            }
        }
    }
    Column {
        anchors.fill:parent; anchors.margins:10; spacing:3
        Text { text:"ACTIVE CONNECTION";color:Theme.muted;font.pixelSize:11;font.weight:Font.DemiBold;height:22;verticalAlignment:Text.AlignVCenter }
        NetworkRow { visible:root.activeNetwork!==null; network:root.activeNetwork||({ssid:"",signal:0,security:""}); connected:true }
        Text { text:"AVAILABLE NETWORKS";color:Theme.muted;font.pixelSize:11;font.weight:Font.DemiBold;height:30;verticalAlignment:Text.AlignBottom }
        Repeater { model:root.availableNetworks; NetworkRow { required property var modelData; network:modelData } }
    }
    Rectangle {
        id: credentials
        visible: root.selectedNetwork !== null
        anchors.left:parent.left; anchors.right:parent.right; anchors.bottom:parent.bottom
        height: 154
        color: Theme.elevated
        border.width:1; border.color:"#424b57"
        Column {
            anchors.fill:parent; anchors.margins:12; spacing:8
            Row {
                width:parent.width
                Text { width:parent.width-25;text:root.selectedNetwork?"Connect to "+root.selectedNetwork.ssid:"";elide:Text.ElideRight;color:Theme.fg;font.pixelSize:13;font.weight:Font.DemiBold }
                Text { text:"×";color:Theme.muted;font.pixelSize:18;MouseArea{anchors.fill:parent;anchors.margins:-7;cursorShape:Qt.PointingHandCursor;onClicked:root.selectedNetwork=null} }
            }
            Rectangle {
                visible: root.selectedNetwork && root.selectedNetwork.security
                width:parent.width;height:34;color:Theme.surface;border.width:1;border.color:passwordInput.activeFocus?Theme.primary:"#4a525e"
                TextInput {
                    id:passwordInput
                    anchors.fill:parent;anchors.leftMargin:9;anchors.rightMargin:34
                    verticalAlignment:TextInput.AlignVCenter
                    color:Theme.fg;font.pixelSize:12
                    echoMode:showPassword.checked?TextInput.Normal:TextInput.Password
                    selectByMouse:true
                    Keys.onReturnPressed:root.connectSelected()
                    onVisibleChanged:if(visible)forceActiveFocus()
                    Text { visible:passwordInput.text.length===0&&!passwordInput.activeFocus;anchors.verticalCenter:parent.verticalCenter;text:"Wi-Fi password";color:Theme.muted;font.pixelSize:12 }
                }
                Text {
                    id:showPassword
                    property bool checked:false
                    anchors.right:parent.right;anchors.rightMargin:9;anchors.verticalCenter:parent.verticalCenter
                    text:checked?"󰈈":"󰈉";color:Theme.muted;font.family:Theme.iconFont;font.pixelSize:15
                    MouseArea{anchors.fill:parent;anchors.margins:-6;cursorShape:Qt.PointingHandCursor;onClicked:showPassword.checked=!showPassword.checked}
                }
            }
            Text { visible:root.connectionError!=="";width:parent.width;text:root.connectionError;elide:Text.ElideRight;color:Theme.red;font.pixelSize:10 }
            Row {
                anchors.right:parent.right;spacing:7
                Rectangle { width:65;height:30;color:Theme.surface;Text{anchors.centerIn:parent;text:"Cancel";color:Theme.muted;font.pixelSize:11}MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.selectedNetwork=null} }
                Rectangle {
                    width:76;height:30;color:root.connecting?"#4a5964":Theme.primary
                    Text{anchors.centerIn:parent;text:root.connecting?"Connecting…":"Connect";color:Theme.bg;font.pixelSize:11;font.weight:Font.DemiBold}
                    MouseArea{anchors.fill:parent;enabled:!root.connecting;cursorShape:Qt.PointingHandCursor;onClicked:root.connectSelected()}
                }
            }
        }
    }
}
