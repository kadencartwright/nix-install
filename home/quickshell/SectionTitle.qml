import QtQuick

Row {
    property string icon: ""
    property string title: ""
    spacing: 7
    height: 25
    Text { text: parent.icon; color: Theme.muted; font.family: Theme.iconFont; font.pixelSize: 15 }
    Text {
        text: parent.title.toUpperCase(); color: Theme.muted
        font.family: Theme.font; font.pixelSize: 13; font.weight: Font.DemiBold
        font.letterSpacing: 0.7
    }
}
