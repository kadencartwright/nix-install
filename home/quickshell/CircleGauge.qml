import QtQuick

Item {
    property int value: 0
    property string label: ""
    property color accent: Theme.green
    implicitWidth: 64; implicitHeight: 76
    Canvas {
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
        width: 50; height: 50
        onPaint: {
            let c = getContext("2d"); c.reset(); c.lineWidth = 4;
            c.strokeStyle = "#4b554d"; c.beginPath(); c.arc(25,25,20,0,Math.PI*2); c.stroke();
            c.strokeStyle = parent.accent; c.beginPath(); c.arc(25,25,20,-Math.PI/2,-Math.PI/2 + Math.PI*2*parent.value/100); c.stroke();
        }
        Text { anchors.centerIn: parent; text: parent.parent.value + "%"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
    }
    Text { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; text: parent.label; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
    onValueChanged: children[0].requestPaint()
}
