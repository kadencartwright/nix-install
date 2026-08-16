import QtQuick
import Quickshell

Item {
    id: root
    implicitWidth: 350; implicitHeight: 445
    property date shownMonth: new Date(clock.date.getFullYear(), clock.date.getMonth(), 1)
    readonly property var monthNames: ["January","February","March","April","May","June","July","August","September","October","November","December"]
    readonly property var dayNames: ["Su","Mo","Tu","We","Th","Fr","Sa"]
    function cellDate(index) {
        return new Date(shownMonth.getFullYear(), shownMonth.getMonth(), index - shownMonth.getDay() + 1)
    }
    function moveMonth(delta) { shownMonth = new Date(shownMonth.getFullYear(), shownMonth.getMonth()+delta, 1) }
    SystemClock { id: clock; precision: SystemClock.Seconds }
    Column {
        anchors.fill: parent; anchors.margins: 10; spacing: 0
        Item { width:parent.width; height:110
            Row { anchors.centerIn:parent; spacing:5
                Text { text:Qt.formatTime(clock.date,"hh:mm"); color:Theme.fg; font.family:Theme.font; font.pixelSize:54; font.weight:Font.Light }
                Text { anchors.bottom:parent.bottom; anchors.bottomMargin:10; text:Qt.formatTime(clock.date,"AP"); color:Theme.muted; font.pixelSize:16; font.weight:Font.DemiBold }
            }
            Text { anchors.horizontalCenter:parent.horizontalCenter; anchors.bottom:parent.bottom; text:"<b>"+Qt.formatDate(clock.date,"dddd")+",</b> "+Qt.formatDate(clock.date,"MMMM d, yyyy"); textFormat:Text.RichText; color:Theme.muted; font.pixelSize:12 }
        }
        Rectangle { width:parent.width; height:1; color:"#555d68" }
        Row { width:parent.width; height:40
            Text { width:190; anchors.verticalCenter:parent.verticalCenter; text:root.monthNames[root.shownMonth.getMonth()]+" "+root.shownMonth.getFullYear(); color:Theme.fg; font.pixelSize:12; font.weight:Font.DemiBold }
            Text { width:75; anchors.verticalCenter:parent.verticalCenter; text:"Today"; color:Theme.muted; font.pixelSize:12; MouseArea{anchors.fill:parent;onClicked:root.shownMonth=new Date(clock.date.getFullYear(),clock.date.getMonth(),1)} }
            Text { width:28; anchors.verticalCenter:parent.verticalCenter; text:"‹"; color:Theme.muted; font.pixelSize:20; MouseArea{anchors.fill:parent;onClicked:root.moveMonth(-1)} }
            Text { width:28; anchors.verticalCenter:parent.verticalCenter; text:"›"; color:Theme.muted; font.pixelSize:20; MouseArea{anchors.fill:parent;onClicked:root.moveMonth(1)} }
        }
        Rectangle {
            width:parent.width; height:270; color:Theme.elevated
            Grid {
                anchors.fill:parent; anchors.margins:8; columns:7
                Repeater { model:7; Text { required property int index; width:44;height:34;text:root.dayNames[index];horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;color:index===0||index===6?Theme.primary:Theme.muted;font.pixelSize:12 } }
                Repeater { model:42; Rectangle {
                    required property int index
                    property date value: root.cellDate(index)
                    property bool today: value.toDateString()===clock.date.toDateString()
                    width:44;height:36;color:today?Theme.primary:"transparent"
                    Text { anchors.centerIn:parent;text:parent.value.getDate();color:parent.today?Theme.bg:(parent.value.getMonth()===root.shownMonth.getMonth()?((parent.value.getDay()===0||parent.value.getDay()===6)?Theme.primary:Theme.fg):"#48505b");font.pixelSize:12;font.weight:parent.today?Font.DemiBold:Font.Normal }
                } }
            }
        }
    }
}
