import QtQuick

Item {
    id: root
    property real value: 0
    property color accent: Theme.primary
    signal moved(real value)
    implicitHeight: 18
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 7; radius: 3; color: "#414854" }
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Math.max(7, parent.width * root.value); height: 7; radius: 3; color: root.accent }
    MouseArea {
        anchors.fill: parent
        onPressed: update(mouse.x)
        onPositionChanged: if (pressed) update(mouse.x)
        function update(x) { root.value = Math.max(0, Math.min(1, x / width)); root.moved(root.value) }
    }
}
