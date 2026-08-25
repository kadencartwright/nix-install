import QtQuick
import Quickshell

Item {
    id: root

    signal themeSelected()

    implicitWidth: 440
    implicitHeight: 477

    property var themes: []
    property string errorMessage: ""
    property string applyingTheme: ""
    readonly property string themeBinary: {
        const configured = Quickshell.env("OMARCHY_THEME_BINARY")
        return configured && configured.length > 0 ? configured : "omarchy-theme"
    }
    readonly property var selectedTheme: {
        for (let index = 0; index < themes.length; index++)
            if (themes[index].selected) return themes[index]
        return null
    }

    function loadCatalog(raw) {
        try {
            const parsed = JSON.parse(raw || "[]")
            themes = Array.isArray(parsed) ? parsed : []
            errorMessage = themes.length > 0 ? "" : "No themes found"
            for (let index = 0; index < themes.length; index++) {
                if (themes[index].selected) {
                    themeGrid.currentIndex = index
                    Qt.callLater(function() { themeGrid.positionViewAtIndex(index, GridView.Center) })
                    break
                }
            }
        } catch (_) {
            themes = []
            errorMessage = "Could not read the theme catalog"
        }
    }

    function applyTheme(theme) {
        if (!theme || !theme.slug || applyingTheme !== "") return
        applyingTheme = theme.slug
        Quickshell.execDetached([themeBinary, "set", theme.slug])
        themeSelected()
    }

    Command {
        id: catalog
        command: [root.themeBinary, "catalog"]
        onOutputChanged: root.loadCatalog(output)
    }

    GridView {
        id: themeGrid
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.margins: 10
        anchors.bottomMargin: 8
        clip: true
        focus: true
        model: root.themes
        cellWidth: width / 2
        cellHeight: 132
        keyNavigationWraps: true

        Keys.onReturnPressed: root.applyTheme(root.themes[currentIndex])
        Keys.onEnterPressed: root.applyTheme(root.themes[currentIndex])

        delegate: Rectangle {
            id: themeCard

            required property var modelData
            required property int index

            width: themeGrid.cellWidth - 6
            height: themeGrid.cellHeight - 8
            radius: 10
            color: cardMouse.containsMouse || GridView.isCurrentItem ? Theme.elevated : Theme.bg
            border.width: modelData.selected ? 2 : 1
            border.color: modelData.selected ? Theme.primary : "#3b434e"
            clip: true

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 88
                color: Theme.surface
                clip: true

                Image {
                    id: preview
                    anchors.fill: parent
                    source: themeCard.modelData.preview ? "file://" + themeCard.modelData.preview : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                }

                Rectangle {
                    anchors.fill: parent
                    visible: preview.status !== Image.Ready
                    color: Theme.elevated
                    Text {
                        anchors.centerIn: parent
                        text: "󰏘"
                        color: Theme.muted
                        font.family: Theme.iconFont
                        font.pixelSize: 28
                    }
                }

                Rectangle {
                    visible: themeCard.modelData.source === "custom"
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6
                    width: customLabel.implicitWidth + 10
                    height: 18
                    radius: 9
                    color: Qt.rgba(0.08, 0.09, 0.11, 0.82)
                    Text {
                        id: customLabel
                        anchors.centerIn: parent
                        text: "CUSTOM"
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 8
                        font.weight: Font.Bold
                    }
                }
            }

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 9
                anchors.rightMargin: 9
                anchors.bottomMargin: 7
                spacing: 7

                Text {
                    text: themeCard.modelData.selected ? "󰄬" : ""
                    color: Theme.primary
                    font.family: Theme.iconFont
                    font.pixelSize: 13
                }
                Text {
                    width: parent.width - (themeCard.modelData.selected ? 20 : 0)
                    text: themeCard.modelData.label
                    elide: Text.ElideRight
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 11
                    font.weight: themeCard.modelData.selected ? Font.Bold : Font.Medium
                }
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    themeGrid.currentIndex = themeCard.index
                    root.applyTheme(themeCard.modelData)
                }
            }
        }
    }

    Text {
        anchors.centerIn: themeGrid
        visible: root.themes.length === 0
        text: root.errorMessage || "Loading themes…"
        color: Theme.muted
        font.family: Theme.font
        font.pixelSize: 12
    }

    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 44
        color: Theme.elevated

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - wallpaperButton.width - 30
            text: root.applyingTheme !== ""
                ? "Applying " + root.applyingTheme + "…"
                : root.selectedTheme ? "Current: " + root.selectedTheme.label : "Choose a theme"
            elide: Text.ElideRight
            color: Theme.muted
            font.family: Theme.font
            font.pixelSize: 10
        }

        Rectangle {
            id: wallpaperButton
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            width: 128
            height: 28
            radius: 8
            color: wallpaperMouse.containsMouse ? "#3b4652" : Theme.surface

            Row {
                anchors.centerIn: parent
                spacing: 6
                Text { text: "󰆊"; color: Theme.primary; font.family: Theme.iconFont; font.pixelSize: 14 }
                Text { text: "Next wallpaper"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold }
            }
            MouseArea {
                id: wallpaperMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached([root.themeBinary, "background", "next"])
                    root.themeSelected()
                }
            }
        }
    }
}
