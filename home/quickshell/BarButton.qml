import QtQuick

Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property color accent: Theme.muted
    property bool selected: false
    property alias mouseArea: mouse
    signal clicked(real anchorX)
    implicitHeight: 32
    implicitWidth: row.implicitWidth
    color: selected ? Theme.elevated : Theme.surface
    radius: height / 2
    clip: true
    Behavior on implicitWidth { NumberAnimation { duration:180; easing.type:Easing.OutCubic } }

    Row {
        id: row
        height: parent.height
        Rectangle {
            visible: root.icon !== ""
            width: visible ? 28 : 0
            height: parent.height
            color: root.accent
            Text {
                anchors.centerIn: parent
                text: root.icon
                color: Theme.bg
                font.family: Theme.iconFont
                font.pixelSize: 17
            }
        }
        Text {
            visible: root.label !== ""
            height: parent.height
            leftPadding: 8; rightPadding: 8
            verticalAlignment: Text.AlignVCenter
            text: root.label
            color: root.accent
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked(root.mapToItem(null, 0, 0).x)
    }
}
