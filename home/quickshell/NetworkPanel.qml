import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Item {
    id: root
    implicitWidth: 350
    implicitHeight: 455

    readonly property string helperBinary: {
        const configured = Quickshell.env("NETWORK_PANEL_HELPER_BINARY")
        return configured && configured.length > 0 ? configured : "network-panel-helper"
    }
    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property var wifiDevice: devices.find(device => device.type === DeviceType.Wifi) || null
    readonly property var networks: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
    readonly property var sortedNetworks: networks.slice().sort((left, right) => {
        if (left.connected !== right.connected) return left.connected ? -1 : 1
        if (left.known !== right.known) return left.known ? -1 : 1
        return right.signalStrength - left.signalStrength
    })

    property var info: ({ connected: false })
    property real previousRxBytes: 0
    property real previousTxBytes: 0
    property real previousSampleTime: 0
    property string previousIface: ""
    property real receiveRate: 0
    property real sendRate: 0
    property var pingSamples: []
    property real pingLatency: -1
    property int packetLoss: 0
    property string pendingDns: ""
    property string pendingBand: ""
    property string actionError: ""
    property string actionStderr: ""
    property string actionKind: ""
    property var selectedNetwork: null
    property string connectionError: ""
    property bool customDnsPrompt: false
    property string qrSvg: ""
    property string qrError: ""
    property string copiedValue: ""

    readonly property string effectiveDns: pendingDns !== "" ? pendingDns : (info.dnsProvider || "DHCP")
    readonly property string effectiveBand: pendingBand !== "" ? pendingBand : (info.selectedBand || "auto")
    readonly property var bandChoices: {
        const choices = ["auto"]
        const available = info.availableBands || []
        for (let i = 0; i < available.length; i++)
            if (choices.indexOf(available[i]) < 0) choices.push(available[i])
        return choices
    }
    readonly property bool showBand: info.kind === "wifi"
        && (bandChoices.length > 2 || effectiveBand !== "auto")
    readonly property string connectionTitle: {
        if (!info.connected) return "No connection"
        if (info.kind === "wifi") return info.ssid || info.connection || "Wi-Fi"
        return info.linkSpeed && Number(info.linkSpeed) > 0
            ? "Ethernet (" + formatLinkSpeed(info.linkSpeed) + ")"
            : "Ethernet"
    }
    readonly property string connectionMeta: {
        if (!info.connected) return "NOT CONNECTED"
        if (info.kind === "wifi") {
            const bits = []
            if (info.currentBand) bits.push(bandLabel(info.currentBand))
            if (info.signalDbm) bits.push(info.signalDbm + " dBm")
            if (info.bitrate) bits.push(info.bitrate)
            return bits.join("  ·  ")
        }
        return info.iface || "CONNECTED"
    }

    onWifiDeviceChanged: if (wifiDevice) wifiDevice.scannerEnabled = true
    Component.onCompleted: {
        if (wifiDevice) wifiDevice.scannerEnabled = true
        refreshStatus()
    }
    Component.onDestruction: if (wifiDevice) wifiDevice.scannerEnabled = false

    function refreshStatus() {
        if (!statusProcess.running) {
            statusProcess.command = [helperBinary, "status"]
            statusProcess.running = true
        }
    }

    function updateStatus(raw) {
        let next
        try { next = JSON.parse(raw || "{}") } catch (_) { return }
        const now = Date.now() / 1000

        if (next.connected && next.iface === previousIface && previousSampleTime > 0) {
            const elapsed = Math.max(0.05, now - previousSampleTime)
            receiveRate = Math.max(0, (Number(next.rxBytes || 0) - previousRxBytes) / elapsed)
            sendRate = Math.max(0, (Number(next.txBytes || 0) - previousTxBytes) / elapsed)
        } else {
            receiveRate = 0
            sendRate = 0
            pingSamples = []
        }

        previousIface = next.iface || ""
        previousRxBytes = Number(next.rxBytes || 0)
        previousTxBytes = Number(next.txBytes || 0)
        previousSampleTime = now
        info = next

        const samples = pingSamples.slice()
        samples.push(Number(next.pingMs) >= 0 ? Number(next.pingMs) : null)
        while (samples.length > 20) samples.shift()
        pingSamples = samples

        let total = 0
        let count = 0
        const start = Math.max(0, samples.length - 5)
        for (let i = start; i < samples.length; i++) {
            if (typeof samples[i] === "number") {
                total += samples[i]
                count++
            }
        }
        pingLatency = count > 0 ? total / count : -1
        let lost = 0
        for (let i = 0; i < samples.length; i++) if (samples[i] === null) lost++
        packetLoss = samples.length > 0 ? Math.round(lost * 100 / samples.length) : 0
    }

    function formatBytes(bytes) {
        const value = Math.max(0, Number(bytes || 0))
        if (value < 1024) return Math.round(value) + " B"
        if (value < 1024 * 1024) return (value / 1024).toFixed(1) + " KB"
        if (value < 1024 * 1024 * 1024) return (value / (1024 * 1024)).toFixed(1) + " MB"
        return (value / (1024 * 1024 * 1024)).toFixed(2) + " GB"
    }

    function formatRate(bytes) { return formatBytes(bytes) + "/s" }
    function formatPing() {
        if (pingSamples.length === 0) return "--"
        if (pingLatency < 0) return "Timeout"
        return pingLatency.toFixed(pingLatency < 10 ? 1 : 0) + " ms"
    }
    function formatLinkSpeed(mbps) {
        const value = Number(mbps || 0)
        return value >= 1000 ? (value / 1000).toFixed(value % 1000 === 0 ? 0 : 1) + " Gbit" : value + " Mbit"
    }
    function bandLabel(band) { return band === "2.4" ? "2.4 GHz" : band + " GHz" }
    function copy(text) {
        if (!text) return
        Quickshell.execDetached(["wl-copy", text])
        copiedValue = text
        copyFeedback.restart()
    }

    function needsPassword(network) {
        return network && network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe
    }
    function choose(network) {
        connectionError = ""
        if (network.connected) network.disconnect()
        else if (network.known || !needsPassword(network)) network.connect()
        else {
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

    function runDns(provider, custom) {
        if (actionProcess.running) return
        if (provider === "Custom" && !custom) {
            customDnsPrompt = true
            customDnsInput.forceActiveFocus()
            return
        }
        actionError = ""
        actionStderr = ""
        actionKind = "dns"
        pendingDns = provider
        actionProcess.command = provider === "Custom"
            ? [helperBinary, "dns", provider, custom]
            : [helperBinary, "dns", provider]
        actionProcess.running = true
    }

    function runBand(band) {
        if (actionProcess.running || band === effectiveBand) return
        actionError = ""
        actionStderr = ""
        actionKind = "band"
        pendingBand = band
        actionProcess.command = [helperBinary, "band", band]
        actionProcess.running = true
    }

    function showQr() {
        if (qrProcess.running) return
        qrSvg = ""
        qrError = ""
        qrProcess.command = [helperBinary, "qr"]
        qrProcess.running = true
    }

    Process {
        id: statusProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.updateStatus(text)
        }
    }
    Timer { interval: 1500; repeat: true; running: root.visible; onTriggered: root.refreshStatus() }

    Process {
        id: actionProcess
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.actionStderr = String(text || "").trim()
        }
        onExited: function(exitCode) {
            if (exitCode !== 0) root.actionError = root.actionStderr || "Network change failed"
            root.pendingDns = ""
            root.pendingBand = ""
            root.actionKind = ""
            statusRefresh.restart()
        }
    }
    Timer { id: statusRefresh; interval: 500; onTriggered: root.refreshStatus() }
    Timer { id: copyFeedback; interval: 1200; onTriggered: root.copiedValue = "" }

    Process {
        id: qrProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.qrSvg = String(text || "")
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.qrError = String(text || "").trim()
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && root.qrError === "") root.qrError = "Could not create Wi-Fi QR code"
        }
    }

    component Divider: Rectangle {
        width: parent ? parent.width : 0
        height: 1
        color: "#3b434e"
    }

    component DetailPair: Item {
        id: pair
        property string label: ""
        property string value: "--"
        property bool copyable: false
        property color valueColor: Theme.fg
        width: 155
        height: 19

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: pair.label
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 10
        }
        Text {
            id: pairValue
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 88
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: root.copiedValue === pair.value ? "Copied ✓" : pair.value
            color: pairMouse.containsMouse || root.copiedValue === pair.value ? Theme.primary : pair.valueColor
            font.family: Theme.font
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.underline: pair.copyable && pairMouse.containsMouse && root.copiedValue !== pair.value
        }
        MouseArea {
            id: pairMouse
            anchors.fill: parent
            enabled: pair.copyable && pair.value !== "--"
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.copy(pair.value)
        }
    }

    component ChoicePill: Rectangle {
        id: pill
        property string label: ""
        property bool active: false
        property bool busy: false
        signal clicked()
        height: 30
        radius: 7
        color: active ? Theme.primary : pillMouse.containsMouse ? "#343d47" : Theme.elevated
        border.width: active ? 0 : 1
        border.color: "#424b57"
        opacity: busy ? 0.58 : 1

        Text {
            anchors.centerIn: parent
            text: pill.label
            color: pill.active ? Theme.bg : Theme.fg
            font.family: Theme.font
            font.pixelSize: 10
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            enabled: !pill.busy
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component NetworkRow: Rectangle {
        id: row
        required property var network
        width: parent.width
        height: network.connected ? 58 : 46
        radius: 7
        color: network.connected ? Theme.elevated : rowMouse.containsMouse ? "#2c333c" : "transparent"

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
                width: 40
                height: parent.height
                radius: 7
                color: row.network.connected ? "#344554" : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: row.network.signalStrength > 0.70 ? "󰤨" : row.network.signalStrength > 0.40 ? "󰤥" : "󰤟"
                    color: row.network.connected ? Theme.primary : Theme.muted
                    font.family: Theme.iconFont
                    font.pixelSize: 19
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 74
                Text {
                    width: parent.width
                    text: row.network.name
                    elide: Text.ElideRight
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: row.network.connected ? Font.DemiBold : Font.Normal
                }
                Text {
                    text: row.network.connected ? "Connected · " + Math.round(row.network.signalStrength * 100) + "%"
                                                : row.network.known ? "Saved network" : WifiSecurityType.toString(row.network.security)
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 9
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.needsPassword(row.network) ? "󰌾" : ""
                color: Theme.muted
                font.family: Theme.iconFont
                font.pixelSize: 13
            }
        }
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.choose(row.network)
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 10
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: parent.width
            spacing: 10

            Item {
                width: parent.width
                height: 58

                Rectangle {
                    id: heroIcon
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    radius: 12
                    color: "#344554"
                    Text {
                        anchors.centerIn: parent
                        text: !root.info.connected ? "󰤭" : root.info.kind === "wifi" ? "󰤨" : "󰈀"
                        color: root.info.connected ? Theme.primary : Theme.muted
                        font.family: Theme.iconFont
                        font.pixelSize: 23
                    }
                }

                Column {
                    anchors.left: heroIcon.right
                    anchors.right: qrButton.visible ? qrButton.left : parent.right
                    anchors.leftMargin: 11
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        width: parent.width
                        text: root.connectionTitle
                        elide: Text.ElideRight
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                    Text {
                        width: parent.width
                        text: root.connectionMeta
                        elide: Text.ElideRight
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }

                Rectangle {
                    id: qrButton
                    visible: root.info.connected && root.info.kind === "wifi"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    height: 30
                    radius: 8
                    color: qrMouse.containsMouse ? "#35404b" : Theme.elevated
                    Text { anchors.centerIn: parent; text: "󰐲"; color: Theme.primary; font.family: Theme.iconFont; font.pixelSize: 17 }
                    MouseArea {
                        id: qrMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showQr()
                    }
                }
            }

            Column {
                visible: root.info.connected
                width: parent.width
                spacing: 3

                Row {
                    width: parent.width
                    spacing: 10
                    DetailPair { label: "Ping"; value: root.formatPing(); valueColor: root.packetLoss > 0 ? Theme.red : Theme.fg }
                    DetailPair { label: "Packet loss"; value: root.pingSamples.length ? root.packetLoss + "%" : "--"; valueColor: root.packetLoss > 0 ? Theme.red : Theme.fg }
                }
                Row {
                    width: parent.width
                    spacing: 10
                    DetailPair { label: "Receiving"; value: root.formatRate(root.receiveRate) }
                    DetailPair { label: "Sending"; value: root.formatRate(root.sendRate) }
                }
                Row {
                    width: parent.width
                    spacing: 10
                    DetailPair { label: "Downloaded"; value: root.formatBytes(root.info.rxBytes) }
                    DetailPair { label: "Uploaded"; value: root.formatBytes(root.info.txBytes) }
                }
                Row {
                    width: parent.width
                    spacing: 10
                    DetailPair { label: "IP address"; value: root.info.ip || "--"; valueColor: Theme.primary; copyable: true }
                    DetailPair { label: "Gateway"; value: root.info.gateway || "--"; copyable: true }
                }
            }

            Divider { visible: root.showBand }

            Column {
                visible: root.showBand
                width: parent.width
                spacing: 7
                Text {
                    text: "WI-FI BAND" + (root.info.currentBand ? ": " + root.bandLabel(root.info.currentBand).toUpperCase() : "")
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
                Row {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: root.bandChoices
                        ChoicePill {
                            required property var modelData
                            width: (content.width - (root.bandChoices.length - 1) * 6) / root.bandChoices.length
                            label: modelData === "auto" ? "Automatic" : root.bandLabel(modelData)
                            active: root.effectiveBand === modelData
                            busy: root.actionKind !== ""
                            onClicked: root.runBand(modelData)
                        }
                    }
                }
            }

            Divider {}

            Column {
                width: parent.width
                spacing: 7
                Row {
                    width: parent.width
                    Text {
                        width: parent.width - 120
                        text: "DNS PROVIDER"
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: 120
                        horizontalAlignment: Text.AlignRight
                        text: root.info.dnsServers || ""
                        elide: Text.ElideRight
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 8
                    }
                }
                Row {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: ["DHCP", "Cloudflare", "Google", "Custom"]
                        ChoicePill {
                            required property var modelData
                            width: (content.width - 18) / 4
                            label: modelData
                            active: root.effectiveDns === modelData
                            busy: root.actionKind !== "" || !root.info.connected
                            onClicked: root.runDns(modelData, "")
                        }
                    }
                }
                Text {
                    visible: root.actionError !== ""
                    width: parent.width
                    text: root.actionError
                    wrapMode: Text.Wrap
                    color: Theme.red
                    font.family: Theme.font
                    font.pixelSize: 9
                }
            }

            Divider { visible: root.wifiDevice !== null }

            Text {
                visible: root.wifiDevice !== null
                text: "WI-FI NETWORKS"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 9
                font.weight: Font.DemiBold
            }

            Repeater {
                model: Networking.wifiEnabled ? root.sortedNetworks.slice(0, 12) : []
                NetworkRow { required property var modelData; network: modelData }
            }

            Item {
                visible: !Networking.wifiEnabled || root.sortedNetworks.length === 0
                width: parent.width
                height: 120
                Column {
                    anchors.centerIn: parent
                    spacing: 7
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Networking.wifiEnabled ? "󰤭" : "󰤮"
                        color: Theme.muted
                        font.family: Theme.iconFont
                        font.pixelSize: 28
                    }
                    Text {
                        text: Networking.wifiEnabled ? "Scanning for networks…" : "Wi-Fi is turned off"
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
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
        z: 20
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

    Rectangle {
        visible: root.customDnsPrompt
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 145
        radius: 9
        color: Theme.elevated
        border.width: 1
        border.color: "#424b57"
        z: 21
        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 9
            Row {
                width: parent.width
                Text { width: parent.width - 25; text: "Custom DNS servers"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold }
                Text { text: "×"; color: Theme.muted; font.pixelSize: 18; MouseArea { anchors.fill: parent; anchors.margins: -7; onClicked: root.customDnsPrompt = false } }
            }
            Rectangle {
                width: parent.width
                height: 36
                color: Theme.surface
                border.width: 1
                border.color: customDnsInput.activeFocus ? Theme.primary : "#4a525e"
                TextInput {
                    id: customDnsInput
                    anchors.fill: parent
                    anchors.margins: 9
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 11
                    selectByMouse: true
                    Keys.onReturnPressed: if (text.trim()) { root.customDnsPrompt = false; root.runDns("Custom", text.trim()) }
                    Text { visible: customDnsInput.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "e.g. 9.9.9.9 149.112.112.112"; color: Theme.muted; font.pixelSize: 10 }
                }
            }
            Rectangle {
                anchors.right: parent.right
                width: 70
                height: 29
                radius: 6
                color: customDnsInput.text.trim() ? Theme.primary : "#4a5964"
                Text { anchors.centerIn: parent; text: "Apply"; color: Theme.bg; font.pixelSize: 10; font.weight: Font.DemiBold }
                MouseArea {
                    anchors.fill: parent
                    enabled: customDnsInput.text.trim().length > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.customDnsPrompt = false; root.runDns("Custom", customDnsInput.text.trim()) }
                }
            }
        }
    }

    Rectangle {
        visible: root.qrSvg !== "" || root.qrError !== "" || qrProcess.running
        anchors.fill: parent
        radius: 10
        color: Theme.surface
        z: 22

        Column {
            anchors.centerIn: parent
            spacing: 12
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.info.ssid || root.info.connection || "Wi-Fi"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.Bold
            }
            Rectangle {
                visible: root.qrSvg !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                width: 238
                height: 238
                radius: 8
                color: "white"
                Image {
                    anchors.fill: parent
                    anchors.margins: 8
                    source: root.qrSvg ? "data:image/svg+xml;charset=utf-8," + encodeURIComponent(root.qrSvg) : ""
                    fillMode: Image.PreserveAspectFit
                    cache: false
                }
            }
            Text {
                visible: qrProcess.running
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Reading Wi-Fi credentials…"
                color: Theme.muted
                font.family: Theme.font
                font.pixelSize: 11
            }
            Text {
                visible: root.qrError !== ""
                width: 280
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.qrError
                color: Theme.red
                font.family: Theme.font
                font.pixelSize: 10
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 70
                height: 29
                radius: 6
                color: Theme.elevated
                border.width: 1
                border.color: "#4a525e"
                Text { anchors.centerIn: parent; text: "Close"; color: Theme.fg; font.pixelSize: 10 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.qrSvg = ""; root.qrError = "" } }
            }
        }
    }
}
