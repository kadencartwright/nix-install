import QtQuick
import Quickshell
import Quickshell.Networking

Item {
    id: root
    implicitWidth: 350
    implicitHeight: 457

    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property var wifiDevice: devices.find(device => device.type === DeviceType.Wifi) || null
    readonly property var networks: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
    readonly property var sortedNetworks: networks.slice().sort((left, right) => {
        if (left.connected !== right.connected) return left.connected ? -1 : 1
        if (left.known !== right.known) return left.known ? -1 : 1
        return right.signalStrength - left.signalStrength
    })

    property var selectedNetwork: null
    property string connectionError: ""

    onWifiDeviceChanged: if (wifiDevice) wifiDevice.scannerEnabled = true
    Component.onCompleted: if (wifiDevice) wifiDevice.scannerEnabled = true
    Component.onDestruction: if (wifiDevice) wifiDevice.scannerEnabled = false

    function needsPassword(network) {
        return network && network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe
    }

    function choose(network) {
        connectionError = ""
        if (network.connected) {
            network.disconnect()
        } else if (network.known || !needsPassword(network)) {
            network.connect()
        } else {
            selectedNetwork = network
            passwordInput.text = ""
            passwordInput.forceActiveFocus()
        }
    }

    function connectSelected() {
        if (!selectedNetwork || passwordInput.text.length === 0) return
        connectionError = ""
        selectedNetwork.connectWithPsk(passwordInput.text)
        selectedNetwork = null
        passwordInput.text = ""
    }

    component NetworkRow: Rectangle {
        id: row
        required property var network
        width: parent.width
        height: network.connected ? 62 : 48
        radius: 7
        color: network.connected ? Theme.elevated : mouse.containsMouse ? "#2c333c" : "transparent"

        Connections {
            target: row.network
            function onConnectionFailed(reason) {
                root.connectionError = reason === ConnectionFailReason.WifiAuthTimeout ? "Wrong password" : "Could not connect"
                if (root.needsPassword(row.network)) root.selectedNetwork = row.network
            }
        }

        Row {
            anchors.fill: parent
            spacing: 2
            Rectangle {
                width: 42
                height: parent.height
                radius: 7
                color: row.network.connected ? "#344554" : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: row.network.signalStrength > 0.70 ? "󰤨" : row.network.signalStrength > 0.40 ? "󰤥" : "󰤟"
                    color: row.network.connected ? Theme.primary : Theme.muted
                    font.family: Theme.iconFont
                    font.pixelSize: 20
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 77
                Text {
                    width: parent.width
                    text: row.network.name
                    elide: Text.ElideRight
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: row.network.connected ? Font.DemiBold : Font.Normal
                }
                Text {
                    text: row.network.connected ? "Connected · " + Math.round(row.network.signalStrength * 100) + "%"
                                                : row.network.known ? "Saved network" : WifiSecurityType.toString(row.network.security)
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 10
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.needsPassword(row.network) ? "󰌾" : ""
                color: Theme.muted
                font.family: Theme.iconFont
                font.pixelSize: 14
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.choose(row.network)
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 3

        Row {
            width: parent.width
            height: 28
            Text {
                width: parent.width - 54
                anchors.verticalCenter: parent.verticalCenter
                text: root.wifiDevice ? root.wifiDevice.name : "WI-FI"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
            Rectangle {
                width: 38
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                radius: 10
                color: Networking.wifiEnabled ? Theme.primary : "#424954"
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Networking.wifiEnabled ? 21 : 3
                    width: 14
                    height: 14
                    radius: 7
                    color: Theme.fg
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                }
            }
        }

        Text {
            visible: Networking.wifiEnabled && root.sortedNetworks.length > 0
            text: "NETWORKS"
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 10
            font.weight: Font.DemiBold
            height: 20
            verticalAlignment: Text.AlignVCenter
        }

        Repeater {
            model: Networking.wifiEnabled ? root.sortedNetworks.slice(0, 7) : []
            NetworkRow { required property var modelData; network: modelData }
        }

        Item {
            visible: !Networking.wifiEnabled || root.sortedNetworks.length === 0
            width: parent.width
            height: 250
            Column {
                anchors.centerIn: parent
                spacing: 8
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Networking.wifiEnabled ? "󰤭" : "󰤮"
                    color: Theme.muted
                    font.family: Theme.iconFont
                    font.pixelSize: 32
                }
                Text {
                    text: Networking.wifiEnabled ? "Scanning for networks…" : "Wi-Fi is turned off"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 13
                }
            }
        }
    }

    Rectangle {
        id: credentials
        visible: root.selectedNetwork !== null
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 136
        radius: 9
        color: Theme.elevated
        border.width: 1
        border.color: "#424b57"
        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            Row {
                width: parent.width
                Text {
                    width: parent.width - 25
                    text: root.selectedNetwork ? "Connect to " + root.selectedNetwork.name : ""
                    elide: Text.ElideRight
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "×"
                    color: Theme.muted
                    font.pixelSize: 18
                    MouseArea { anchors.fill: parent; anchors.margins: -7; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedNetwork = null }
                }
            }
            Rectangle {
                width: parent.width
                height: 34
                color: Theme.surface
                border.width: 1
                border.color: passwordInput.activeFocus ? Theme.primary : "#4a525e"
                TextInput {
                    id: passwordInput
                    anchors.fill: parent
                    anchors.leftMargin: 9
                    anchors.rightMargin: 34
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 12
                    echoMode: showPassword.checked ? TextInput.Normal : TextInput.Password
                    selectByMouse: true
                    Keys.onReturnPressed: root.connectSelected()
                    Text { visible: passwordInput.text.length === 0 && !passwordInput.activeFocus; anchors.verticalCenter: parent.verticalCenter; text: "Wi-Fi password"; color: Theme.muted; font.pixelSize: 12 }
                }
                Text {
                    id: showPassword
                    property bool checked: false
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    text: checked ? "󰈈" : "󰈉"
                    color: Theme.muted
                    font.family: Theme.iconFont
                    font.pixelSize: 15
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: showPassword.checked = !showPassword.checked }
                }
            }
            Row {
                anchors.right: parent.right
                spacing: 7
                Text { visible: root.connectionError !== ""; anchors.verticalCenter: parent.verticalCenter; text: root.connectionError; color: Theme.red; font.pixelSize: 10 }
                Rectangle {
                    width: 76
                    height: 30
                    radius: 6
                    color: passwordInput.text.length > 0 ? Theme.primary : "#4a5964"
                    Text { anchors.centerIn: parent; text: "Connect"; color: Theme.bg; font.pixelSize: 11; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; enabled: passwordInput.text.length > 0; cursorShape: Qt.PointingHandCursor; onClicked: root.connectSelected() }
                }
            }
        }
    }
}
