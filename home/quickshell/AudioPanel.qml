import QtQuick
import Quickshell

Item {
    id: root
    implicitWidth: 430; implicitHeight: 445
    property real outputVolume: 0.4
    property real inputVolume: 1.0
    property string outputName: "Default audio output"
    property string inputName: "Default microphone"
    Command { command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print $2}'"]; interval: 2000; onOutputChanged: root.outputVolume = Number(output) || 0 }
    Command { command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | awk '{print $2}'"]; interval: 2000; onOutputChanged: root.inputVolume = Number(output) || 0 }
    Column {
        anchors.fill: parent; anchors.margins: 16; spacing: 14
        Rectangle {
            width: parent.width; height: 66; color: Theme.elevated
            Column { anchors.fill: parent; anchors.margins: 10; spacing: 5
                Row { width: parent.width
                    Text { text: "󰓃"; color: Theme.muted; font.family: Theme.iconFont; font.pixelSize: 18; width: 28 }
                    Column { width: parent.width - 58; Text { text: "OUTPUT"; color: Theme.muted; font.pixelSize: 10; font.weight: Font.Bold } Text { text: root.outputName; color: Theme.fg; font.pixelSize: 12 } }
                    Text { text: "󰝟"; color: Theme.muted; font.family: Theme.iconFont; font.pixelSize: 16 }
                }
                Row { spacing: 8; ShellSlider { width: parent.parent.width - 48; value: root.outputVolume; maximumValue:1.5; onMoved: v => Quickshell.execDetached(["wpctl","set-volume","@DEFAULT_AUDIO_SINK@",String(v)]) } Text { text: Math.round(root.outputVolume*100)+"%"; color: Theme.fg; font.pixelSize: 11 } }
            }
        }
        Rectangle {
            width: parent.width; height: 66; color: Theme.elevated
            Column { anchors.fill: parent; anchors.margins: 10; spacing: 5
                Row { width: parent.width
                    Text { text: "󰍬"; color: Theme.muted; font.family: Theme.iconFont; font.pixelSize: 18; width: 28 }
                    Column { width: parent.width - 58; Text { text: "INPUT"; color: Theme.muted; font.pixelSize: 10; font.weight: Font.Bold } Text { text: root.inputName; color: Theme.fg; font.pixelSize: 12 } }
                    Text { text: "󰍭"; color: Theme.muted; font.family: Theme.iconFont; font.pixelSize: 16 }
                }
                Row { spacing: 8; ShellSlider { width: parent.parent.width - 48; value: root.inputVolume; maximumValue:1.5; onMoved: v => Quickshell.execDetached(["wpctl","set-volume","@DEFAULT_AUDIO_SOURCE@",String(v)]) } Text { text: Math.round(root.inputVolume*100)+"%"; color: Theme.fg; font.pixelSize: 11 } }
            }
        }
        SectionTitle { icon: "󰕾"; title: "Application Volume" }
        Item { width: parent.width; height: 210
            Column { anchors.centerIn: parent; spacing: 8
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰝟"; color: Theme.muted; font.family: Theme.iconFont; font.pixelSize: 34 }
                Text { text: "No applications playing audio"; color: Theme.muted; font.pixelSize: 14; font.weight: Font.DemiBold }
            }
        }
    }
}
