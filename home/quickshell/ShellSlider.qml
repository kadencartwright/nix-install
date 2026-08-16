import QtQuick

Item {
    id: root
    property real value: 0
    property real maximumValue: 1
    property color accent: Theme.primary
    signal moved(real value)
    implicitHeight: 18
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 7; radius: 3; color: "#414854" }
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Math.max(7, parent.width * Math.min(1, root.value/root.maximumValue)); height: 7; radius: 3; color: root.accent }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.SizeHorCursor
        onPressed: update(mouse.x)
        onPositionChanged: if (pressed) update(mouse.x)
        function update(x) { root.value = Math.max(0, Math.min(root.maximumValue, x / width * root.maximumValue)); root.moved(root.value) }
    }
}
