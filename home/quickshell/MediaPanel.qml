import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root
    implicitWidth: 390
    implicitHeight: 240

    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var player: {
        for (let index = 0; index < players.length; index++)
            if (players[index].playbackState === MprisPlaybackState.Playing) return players[index]
        for (let index = 0; index < players.length; index++)
            if (players[index].trackTitle || players[index].trackArtist) return players[index]
        return players.length > 0 ? players[0] : null
    }
    property real displayedPosition: 0
    property bool seeking: false

    onPlayerChanged: displayedPosition = player && player.positionSupported ? player.position : 0

    function formatTime(seconds) {
        let value = Math.max(0, Math.floor(Number(seconds || 0)))
        let minutes = Math.floor(value / 60)
        let remainder = value % 60
        return minutes + ":" + (remainder < 10 ? "0" : "") + remainder
    }

    function seekAt(mouseX) {
        if (!player || !player.canSeek || !player.lengthSupported || player.length <= 0) return
        let next = Math.max(0, Math.min(player.length, mouseX / progressTrack.width * player.length))
        displayedPosition = next
        player.position = next
    }

    Timer {
        interval: 500
        repeat: true
        running: root.visible && root.player !== null
        onTriggered: {
            if (!root.seeking && root.player && root.player.positionSupported)
                root.displayedPosition = root.player.position
        }
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onPositionChanged() {
            if (!root.seeking && root.player) root.displayedPosition = root.player.position
        }
        function onTrackChanged() {
            if (root.player) root.displayedPosition = root.player.positionSupported ? root.player.position : 0
        }
    }

    component MediaButton: Rectangle {
        id: mediaButton
        property string icon: ""
        property bool primary: false
        signal clicked()
        width: primary ? 42 : 34
        height: primary ? 42 : 34
        radius: height / 2
        color: primary ? Theme.primary : buttonMouse.containsMouse ? "#38424d" : Theme.elevated
        opacity: enabled ? 1 : 0.35

        Text {
            anchors.centerIn: parent
            text: mediaButton.icon
            color: mediaButton.primary ? Theme.bg : Theme.fg
            font.family: Theme.iconFont
            font.pixelSize: mediaButton.primary ? 20 : 16
        }
        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            enabled: mediaButton.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mediaButton.clicked()
        }
    }

    Column {
        visible: root.player !== null
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Row {
            width: parent.width
            height: 112
            spacing: 13

            Rectangle {
                width: 112
                height: 112
                radius: 10
                color: Theme.elevated
                clip: true

                Image {
                    id: albumArt
                    anchors.fill: parent
                    source: root.player ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: albumArt.status !== Image.Ready
                    text: "󰝚"
                    color: Theme.muted
                    font.family: Theme.iconFont
                    font.pixelSize: 38
                }
            }

            Column {
                width: parent.width - 125
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    width: parent.width
                    text: root.player ? (root.player.identity || root.player.desktopEntry || "Media player") : ""
                    elide: Text.ElideRight
                    color: Theme.primary
                    font.family: Theme.font
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                }
                Text {
                    width: parent.width
                    text: root.player ? (root.player.trackTitle || "Unknown track") : ""
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 15
                    font.weight: Font.Bold
                }
                Text {
                    width: parent.width
                    text: root.player ? (root.player.trackArtist || "Unknown artist") : ""
                    elide: Text.ElideRight
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 11
                }
                Text {
                    width: parent.width
                    text: root.player ? root.player.trackAlbum : ""
                    visible: text !== ""
                    elide: Text.ElideRight
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 9
                }
            }
        }

        Column {
            width: parent.width
            spacing: 4

            Rectangle {
                id: progressTrack
                width: parent.width
                height: 7
                radius: 4
                color: "#414854"

                Rectangle {
                    width: root.player && root.player.lengthSupported && root.player.length > 0
                        ? parent.width * Math.min(1, root.displayedPosition / root.player.length) : 0
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.player && root.player.canSeek && root.player.lengthSupported
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: mouse => { root.seeking = true; root.seekAt(mouse.x) }
                    onPositionChanged: mouse => { if (pressed) root.seekAt(mouse.x) }
                    onReleased: mouse => { root.seekAt(mouse.x); root.seeking = false }
                    onCanceled: root.seeking = false
                }
            }

            Row {
                width: parent.width
                Text {
                    width: parent.width / 2
                    text: root.formatTime(root.displayedPosition)
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 8
                }
                Text {
                    width: parent.width / 2
                    horizontalAlignment: Text.AlignRight
                    text: root.player && root.player.lengthSupported ? root.formatTime(root.player.length) : "--:--"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 8
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 13
            MediaButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "󰺢"
                onClicked: Quickshell.execDetached(["lyre-launch"])
            }
            MediaButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "󰒮"
                enabled: root.player && root.player.canGoPrevious
                onClicked: root.player.previous()
            }
            MediaButton {
                anchors.verticalCenter: parent.verticalCenter
                primary: true
                icon: root.player && root.player.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                enabled: root.player && root.player.canTogglePlaying
                onClicked: root.player.togglePlaying()
            }
            MediaButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "󰒭"
                enabled: root.player && root.player.canGoNext
                onClicked: root.player.next()
            }
        }
    }

    Column {
        visible: root.player === null
        anchors.centerIn: parent
        spacing: 8
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰝚"; color: Theme.muted; font.family: Theme.iconFont; font.pixelSize: 42 }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No Media"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 15; font.weight: Font.DemiBold }
        Text { text: "No media players found"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
    }
}
