import QtQuick

Item {
    id: root
    implicitWidth: 340; implicitHeight: 390
    property string details: "Loading Codex usage…"
    Command {
        command: ["codexbar"]
        interval: 300000
        onOutputChanged: {
            try {
                let data = JSON.parse(output)
                root.details = (data.tooltip || data.text || "No usage data")
                    .replace(/<span[^>]*>/g, "").replace(/<\/span>/g, "")
            } catch (_) {}
        }
    }
    Column {
        anchors.fill: parent; anchors.margins: 18; spacing: 8
        Row {
            spacing: 9
            Rectangle { width:34; height:34; color:"#30495d"; Text { anchors.centerIn:parent; text:"‹›"; color:Theme.primary; font.pixelSize:21 } }
            Column { Text{text:"Codex";color:Theme.muted;font.pixelSize:10} Text{text:"Codex Usage";color:Theme.fg;font.pixelSize:13;font.weight:Font.DemiBold} }
        }
        Text {
            width: parent.width
            text: root.details
            color: Theme.fg
            font.family: Theme.iconFont
            font.pixelSize: 12
            lineHeight: 1.25
        }
    }
}
