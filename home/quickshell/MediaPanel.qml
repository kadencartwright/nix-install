import QtQuick
import Quickshell

Item {
    implicitWidth: 390; implicitHeight: 240
    Column {
        anchors.centerIn: parent; spacing: 8
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰝚"; color: Theme.muted; font.family: Theme.iconFont; font.pixelSize: 42 }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No Media"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold }
        Text { text: "No media playing"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
    }
}
