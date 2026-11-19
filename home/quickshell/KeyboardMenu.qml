import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Wayland

PanelWindow {
    id: root

    signal panelRequested(string kind, string screenName)

    property bool opened: false
    property var targetScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    property int pane: 0
    property int categoryIndex: 0
    property int actionIndex: 0
    property bool editing: false
    property bool filtering: false
    property string filterTerm: ""
    property int filterIndex: 0
    property string feedback: ""
    property var displayInfo: ({ "monitors": [] })
    property var networkInfo: ({ "connected": false })
    property string wifiState: ""
    property string powerProfile: ""
    property string batterySummary: ""
    property string codexSummary: ""
    property string currentTheme: ""
    property var voxtypeEntries: []

    readonly property string displayBinary: {
        const configured = Quickshell.env("DISPLAY_CONTROL_BINARY")
        return configured && configured.length > 0 ? configured : "display-control"
    }
    readonly property string networkBinary: {
        const configured = Quickshell.env("NETWORK_PANEL_HELPER_BINARY")
        return configured && configured.length > 0 ? configured : "network-panel-helper"
    }
    readonly property string trayToggleBinary: {
        const configured = Quickshell.env("TRAY_WINDOW_TOGGLE_BINARY")
        return configured && configured.length > 0 ? configured : "tray-window-toggle"
    }
    readonly property string themeBinary: {
        const configured = Quickshell.env("OMARCHY_THEME_BINARY")
        return configured && configured.length > 0 ? configured : "omarchy-theme"
    }
    readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var sinks: nodes.filter(node => node && node.ready && node.audio && node.isSink && !node.isStream)
    readonly property var sources: nodes.filter(node => node && node.ready && node.audio && !node.isSink && !node.isStream)
    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var player: {
        for (let index = 0; index < players.length; index++)
            if (players[index].playbackState === MprisPlaybackState.Playing) return players[index]
        return players.length > 0 ? players[0] : null
    }
    readonly property var categories: [
        { kind: "workspaces", label: "Workspaces", icon: "󰍹" },
        { kind: "calendar", label: "Calendar", icon: "󰃭" },
        { kind: "tray", label: "Tray Apps", icon: "󰀻" },
        { kind: "codex", label: "Codex Usage", icon: "󰅩" },
        { kind: "voxtype", label: "Voxtype", icon: "󰍬" },
        { kind: "media", label: "Media", icon: "󰎆" },
        { kind: "network", label: "Network", icon: "󰖩" },
        { kind: "theme", label: "Themes", icon: "󰏘" },
        { kind: "power", label: "Power Profile", icon: "󰐥" },
        { kind: "battery", label: "Battery", icon: "" },
        { kind: "display", label: "Displays", icon: "󰍹" },
        { kind: "audio", label: "Audio", icon: "󰕾" }
    ]
    readonly property var selectedCategory: categories[Math.max(0, Math.min(categoryIndex, categories.length - 1))]
    readonly property var currentActions: actionsFor(selectedCategory.kind)
    readonly property var filteredResults: buildFilteredResults(filterTerm)

    onFilteredResultsChanged: {
        if (filterIndex >= filteredResults.length) filterIndex = Math.max(0, filteredResults.length - 1)
    }

    screen: targetScreen
    visible: opened
    color: "transparent"
    anchors { top: true; right: true; bottom: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-keyboard-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    PwObjectTracker { objects: root.nodes }

    IpcHandler {
        target: "barMenu"
        function toggle(): void { root.toggleMenu() }
        function open(): void { root.openMenu() }
        function close(): void { root.closeMenu() }
    }

    FileView {
        id: voxtypeHistory
        path: {
            const stateHome = Quickshell.env("XDG_STATE_HOME")
            return (stateHome && stateHome.length > 0 ? stateHome : Quickshell.env("HOME") + "/.local/state")
                + "/voxtype/history.jsonl"
        }
        watchChanges: true
        printErrors: false
        onLoaded: root.loadVoxtype(text())
        onFileChanged: reload()
    }

    FileView {
        id: currentThemeFile
        path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
        watchChanges: true
        printErrors: false
        onLoaded: root.currentTheme = text().trim()
        onFileChanged: reload()
    }

    Command {
        id: displayStatus
        command: [root.displayBinary, "layout-status"]
        interval: 5000
        onOutputChanged: {
            try { root.displayInfo = JSON.parse(output || "{}") } catch (_) {}
        }
    }
    Command {
        id: networkStatus
        command: [root.networkBinary, "status"]
        interval: 3000
        onOutputChanged: {
            try { root.networkInfo = JSON.parse(output || "{}") } catch (_) {}
        }
    }
    Command { id: wifiStatus; command: ["nmcli", "radio", "wifi"]; interval: 3000; onOutputChanged: root.wifiState = output }
    Command { id: profileStatus; command: ["powerprofilesctl", "get"]; interval: 3000; onOutputChanged: root.powerProfile = output }
    Command {
        id: batteryStatus
        command: ["sh", "-c", "paste -d' ' /sys/class/power_supply/BAT0/capacity /sys/class/power_supply/BAT0/status 2>/dev/null"]
        interval: 10000
        onOutputChanged: root.batterySummary = output
    }
    Command {
        id: codexStatus
        command: ["sh", "-c", "codexbar --format '{session_pct}% · {session_reset}' 2>/dev/null | jq -r .text | sed 's/<[^>]*>//g'"]
        interval: 300000
        onOutputChanged: if (output) root.codexSummary = output
    }

    Timer {
        id: refreshTimer
        interval: 650
        onTriggered: root.refreshData()
    }
    Timer {
        id: feedbackTimer
        interval: 1800
        onTriggered: root.feedback = ""
    }

    function focusedScreen() {
        const monitorName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        for (let index = 0; index < Quickshell.screens.length; index++)
            if (Quickshell.screens[index].name === monitorName) return Quickshell.screens[index]
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    function toggleMenu() { opened ? closeMenu() : openMenu() }
    function openMenu() {
        targetScreen = focusedScreen()
        pane = 0
        actionIndex = 0
        editing = false
        filtering = false
        filterTerm = ""
        feedback = ""
        opened = true
        refreshData()
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
    function closeMenu() {
        editing = false
        filtering = false
        opened = false
    }
    function refreshData() {
        displayStatus.run()
        networkStatus.run()
        currentThemeFile.reload()
        wifiStatus.run()
        profileStatus.run()
        batteryStatus.run()
        codexStatus.run()
        voxtypeHistory.reload()
    }
    function loadVoxtype(raw) {
        const entries = []
        const lines = (raw || "").split("\n")
        for (let index = 0; index < lines.length; index++) {
            if (!lines[index].trim()) continue
            try {
                const entry = JSON.parse(lines[index])
                if (entry.text && entry.text.trim()) entries.push(entry)
            } catch (_) {}
        }
        voxtypeEntries = entries.slice(-10).reverse()
    }
    function nodeLabel(node, fallback) {
        if (!node) return fallback
        const props = node.properties || {}
        return node.nickname || node.description || props["application.name"] || node.name || fallback
    }
    function panelAction(kind) {
        return { label: "Open full widget", detail: "Show the bar panel", icon: "󰐕", type: "panel", value: kind }
    }
    function calendarUrl(offsetDays) {
        const date = new Date()
        date.setDate(date.getDate() + offsetDays)
        return "https://calendar.google.com/calendar/u/0/r/week/" + date.getFullYear() + "/"
            + (date.getMonth() + 1) + "/" + date.getDate() + "?pli=1"
    }
    function actionsFor(kind) {
        let actions = []
        if (kind === "workspaces") {
            const monitorName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
            const workspaces = Hyprland.workspaces.values.filter(workspace => workspace.id > 0
                && workspace.monitor && workspace.monitor.name === monitorName).sort((left, right) => left.id - right.id)
            for (let index = 0; index < workspaces.length; index++)
                actions.push({ label: "Workspace " + workspaces[index].name, detail: workspaces[index].active ? "Current" : "Switch", icon: "󰮯", type: "workspace", object: workspaces[index] })
        } else if (kind === "calendar") {
            actions = [panelAction("calendar"),
                { label: "Open this week", detail: "Google Calendar", icon: "󰃭", type: "url", value: calendarUrl(0) },
                { label: "Open next week", detail: "Google Calendar", icon: "󰃭", type: "url", value: calendarUrl(7) }]
        } else if (kind === "tray") {
            const items = SystemTray.items.values.slice().sort((left, right) => (left.title || left.id).localeCompare(right.title || right.id))
            for (let index = 0; index < items.length; index++)
                actions.push({ label: items[index].title || items[index].id, detail: "Activate tray application", icon: "󰀻", type: "tray", object: items[index] })
        } else if (kind === "codex") {
            actions = [panelAction("codex"), { label: "Refresh usage", detail: codexSummary || "Codex limits", icon: "󰑓", type: "refresh" }]
        } else if (kind === "voxtype") {
            actions = [panelAction("voxtype"), { label: "Toggle recording", detail: "Start or stop dictation", icon: "󰍬", type: "command", command: ["voxtype", "record", "toggle"] }]
            for (let index = 0; index < voxtypeEntries.length; index++) {
                const text = voxtypeEntries[index].text
                actions.push({ label: text, detail: "Copy transcription", icon: "󰆏", type: "copy", value: text })
            }
        } else if (kind === "media") {
            actions = [panelAction("media"),
                { label: "Previous track", detail: player ? player.trackArtist || "Media" : "No player", icon: "󰒮", type: "player", value: "previous", enabled: player && player.canGoPrevious },
                { label: player && player.playbackState === MprisPlaybackState.Playing ? "Pause" : "Play", detail: player ? player.trackTitle || "Current player" : "No player", icon: "󰐊", type: "player", value: "toggle", enabled: player && player.canTogglePlaying },
                { label: "Next track", detail: player ? player.trackArtist || "Media" : "No player", icon: "󰒭", type: "player", value: "next", enabled: player && player.canGoNext }]
        } else if (kind === "network") {
            actions = [panelAction("network"),
                { label: wifiState === "enabled" ? "Turn Wi-Fi off" : "Turn Wi-Fi on", detail: networkInfo.ssid || networkInfo.connection || "Wireless radio", icon: "󰖩", type: "command", command: ["nmcli", "radio", "wifi", wifiState === "enabled" ? "off" : "on"] },
                { label: "Copy IP address", detail: networkInfo.ip || "No active address", icon: "󰆏", type: "copy", value: networkInfo.ip || "", enabled: !!networkInfo.ip },
                { label: "DNS: Automatic", detail: "Use DHCP-provided DNS", icon: "󰇖", type: "command", command: [networkBinary, "dns", "DHCP"] },
                { label: "DNS: Cloudflare", detail: "1.1.1.1", icon: "󰇖", type: "command", command: [networkBinary, "dns", "Cloudflare"] },
                { label: "DNS: Google", detail: "8.8.8.8", icon: "󰇖", type: "command", command: [networkBinary, "dns", "Google"] },
                { label: "DNS: Custom…", detail: "Enter one or more servers", icon: "󰇖", type: "customDns" },
                { label: "Wi-Fi band: Auto", detail: "Let NetworkManager choose", icon: "󰤨", type: "command", command: [networkBinary, "band", "auto"] },
                { label: "Wi-Fi band: 5 GHz", detail: "Prefer 5 GHz", icon: "󰤨", type: "command", command: [networkBinary, "band", "5"] }]
        } else if (kind === "theme") {
            actions = [panelAction("theme"),
                { label: "Current theme", detail: currentTheme || "Reading theme…", icon: "󰏘", type: "none" },
                { label: "Next wallpaper", detail: "Cycle this theme's backgrounds", icon: "󰆊", type: "command", command: [themeBinary, "background", "next"] },
                { label: "Reapply current theme", detail: "Regenerate all application adapters", icon: "󰑓", type: "command", command: [themeBinary, "refresh"] }]
        } else if (kind === "power") {
            actions = [
                { label: "Balanced", detail: powerProfile === "balanced" ? "Current" : "General use", icon: "󰾅", type: "command", command: ["powerprofilesctl", "set", "balanced"] },
                { label: "Performance", detail: powerProfile === "performance" ? "Current" : "Maximum speed", icon: "󰓅", type: "command", command: ["powerprofilesctl", "set", "performance"] },
                { label: "Power saver", detail: powerProfile === "power-saver" ? "Current" : "Longer battery life", icon: "󰌪", type: "command", command: ["powerprofilesctl", "set", "power-saver"] }]
        } else if (kind === "battery") {
            actions = [panelAction("battery"), { label: "Battery status", detail: batterySummary || "Reading battery…", icon: "", type: "none" }]
        } else if (kind === "display") {
            actions = [panelAction("display"),
                { label: "Brightness −5%", detail: "Main display", icon: "󰃞", type: "command", command: [displayBinary, "brightness", "main", "-5"] },
                { label: "Brightness +5%", detail: "Main display", icon: "󰃠", type: "command", command: [displayBinary, "brightness", "main", "+5"] },
                { label: "Extend displays", detail: "Arrange horizontally", icon: "󰍺", type: "command", command: [displayBinary, "extend"] }]
            const monitors = (displayInfo.monitors || []).filter(monitor => monitor.enabled)
            for (let index = 0; index < monitors.length; index++) {
                const monitor = monitors[index]
                const scale = Number(monitor.scale || 1)
                actions.push({ label: monitor.name + " scale −", detail: Math.round(scale * 100) + "% → " + Math.round(Math.max(0.5, scale - 0.25) * 100) + "%", icon: "󰍹", type: "command", command: [displayBinary, "scale", monitor.name, Math.max(0.5, scale - 0.25).toFixed(2)], enabled: scale > 0.5 })
                actions.push({ label: monitor.name + " scale +", detail: Math.round(scale * 100) + "% → " + Math.round(Math.min(3, scale + 0.25) * 100) + "%", icon: "󰍹", type: "command", command: [displayBinary, "scale", monitor.name, Math.min(3, scale + 0.25).toFixed(2)], enabled: scale < 3 })
            }
        } else if (kind === "audio") {
            actions = [panelAction("audio"),
                { label: "Volume −5%", detail: "Default output", icon: "󰝞", type: "command", command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"] },
                { label: "Volume +5%", detail: "Default output", icon: "󰕾", type: "command", command: ["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", "5%+"] },
                { label: "Toggle output mute", detail: "Default output", icon: "󰖁", type: "command", command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] },
                { label: "Toggle microphone mute", detail: "Default source", icon: "󰍭", type: "command", command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"] }]
            for (let index = 0; index < sinks.length; index++)
                actions.push({ label: nodeLabel(sinks[index], "Audio output"), detail: "Use as audio output", icon: "󰓃", type: "sink", object: sinks[index] })
            for (let index = 0; index < sources.length; index++)
                actions.push({ label: nodeLabel(sources[index], "Microphone"), detail: "Use as microphone", icon: "󰍬", type: "source", object: sources[index] })
        }
        if (actions.length === 0) actions.push({ label: "Nothing available", detail: "No items are currently registered", icon: "󰅖", type: "none", enabled: false })
        return actions
    }

    function shortcutFor(index) {
        if (index >= 0 && index < 9) return String(index + 1)
        if (index === 9) return "0"
        if (index === 10) return "−"
        return ""
    }
    function buildFilteredResults(term) {
        const query = (term || "").trim().toLowerCase()
        const results = []
        for (let category = 0; category < categories.length; category++) {
            const metadata = categories[category]
            if (!query || metadata.label.toLowerCase().indexOf(query) >= 0) {
                results.push({
                    label: metadata.label,
                    detail: "Open module · Ctrl+" + shortcutFor(category),
                    icon: metadata.icon,
                    resultType: "category",
                    categoryIndex: category
                })
            }
            if (!query) continue
            const actions = actionsFor(metadata.kind)
            for (let actionIndex = 0; actionIndex < actions.length; actionIndex++) {
                const action = actions[actionIndex]
                const haystack = ((action.label || "") + " " + (action.detail || "") + " " + metadata.label).toLowerCase()
                if (haystack.indexOf(query) < 0) continue
                results.push({
                    label: action.label,
                    detail: metadata.label + (action.detail ? " · " + action.detail : ""),
                    icon: action.icon || metadata.icon,
                    resultType: "action",
                    categoryIndex: category,
                    action: action
                })
                if (results.length >= 60) return results
            }
        }
        return results
    }

    function quickNavigate(index) {
        if (index < 0 || index >= categories.length) return
        filtering = false
        filterTerm = ""
        editing = false
        categoryIndex = index
        pane = 1
        actionIndex = 0
        Qt.callLater(function() {
            keyCatcher.forceActiveFocus()
            categoryList.positionViewAtIndex(categoryIndex, ListView.Contain)
            actionList.positionViewAtBeginning()
        })
    }
    function handleQuickNavigation(event) {
        if (!(event.modifiers & Qt.ControlModifier)) return false
        let target = -1
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) target = event.key - Qt.Key_1
        else if (event.key === Qt.Key_0) target = 9
        else if (event.key === Qt.Key_Minus) target = 10
        if (target < 0) return false
        quickNavigate(target)
        event.accepted = true
        return true
    }
    function startFilter() {
        filtering = true
        filterTerm = ""
        filterIndex = 0
        Qt.callLater(function() { filterInput.forceActiveFocus() })
    }
    function cancelFilter() {
        filtering = false
        filterTerm = ""
        keyCatcher.forceActiveFocus()
    }
    function moveFilter(delta) {
        const count = filteredResults.length
        if (count === 0) return
        filterIndex = (filterIndex + delta + count) % count
        filterList.positionViewAtIndex(filterIndex, ListView.Contain)
    }
    function executeFiltered(result) {
        if (!result) return
        if (result.resultType === "category") {
            quickNavigate(result.categoryIndex)
            return
        }
        const action = result.action
        const target = result.categoryIndex
        filtering = false
        filterTerm = ""
        categoryIndex = target
        pane = 1
        const actions = currentActions
        actionIndex = 0
        for (let index = 0; index < actions.length; index++) {
            if (actions[index].label === action.label && actions[index].type === action.type) {
                actionIndex = index
                break
            }
        }
        keyCatcher.forceActiveFocus()
        executeAction(action)
    }

    function setFeedback(message) {
        feedback = message
        feedbackTimer.restart()
    }
    function executeAction(action) {
        if (!action || action.enabled === false || action.type === "none") return
        if (action.type === "panel") {
            const name = targetScreen ? targetScreen.name : ""
            closeMenu()
            panelRequested(action.value, name)
        } else if (action.type === "command") {
            Quickshell.execDetached(action.command)
            setFeedback("Applied: " + action.label)
            refreshTimer.restart()
        } else if (action.type === "copy") {
            if (!action.value) return
            Quickshell.execDetached(["wl-copy", action.value])
            setFeedback("Copied")
        } else if (action.type === "url") {
            Quickshell.execDetached(["xdg-open", action.value])
            closeMenu()
        } else if (action.type === "workspace") {
            action.object.activate()
            closeMenu()
        } else if (action.type === "tray") {
            const item = action.object
            const identity = (item.id || item.title || "").toLowerCase()
            if (identity.indexOf("spotify") >= 0) Quickshell.execDetached([trayToggleBinary, item.id || item.title])
            else item.activate()
            closeMenu()
        } else if (action.type === "player" && player) {
            if (action.value === "previous") player.previous()
            else if (action.value === "next") player.next()
            else player.togglePlaying()
            setFeedback(action.label)
        } else if (action.type === "sink") {
            Pipewire.preferredDefaultAudioSink = action.object
            setFeedback("Output: " + action.label)
        } else if (action.type === "source") {
            Pipewire.preferredDefaultAudioSource = action.object
            setFeedback("Microphone: " + action.label)
        } else if (action.type === "customDns") {
            editing = true
            dnsInput.text = ""
            Qt.callLater(function() { dnsInput.forceActiveFocus() })
        } else if (action.type === "refresh") {
            refreshData()
            setFeedback("Usage refreshed")
        }
    }
    function submitDns() {
        const value = dnsInput.text.trim()
        if (!value) return
        Quickshell.execDetached([networkBinary, "dns", "Custom", value])
        editing = false
        keyCatcher.forceActiveFocus()
        setFeedback("Applied custom DNS")
        refreshTimer.restart()
    }
    function cancelEditor() {
        editing = false
        keyCatcher.forceActiveFocus()
    }
    function moveSelection(delta) {
        if (pane === 0) {
            categoryIndex = (categoryIndex + delta + categories.length) % categories.length
            actionIndex = 0
            categoryList.positionViewAtIndex(categoryIndex, ListView.Contain)
        } else {
            const count = currentActions.length
            if (count === 0) return
            actionIndex = (actionIndex + delta + count) % count
            actionList.positionViewAtIndex(actionIndex, ListView.Contain)
        }
    }
    function enterPane() {
        if (pane === 0) {
            pane = 1
            actionIndex = 0
            actionList.positionViewAtBeginning()
        } else executeAction(currentActions[actionIndex])
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.72)
        MouseArea { anchors.fill: parent; onClicked: root.closeMenu() }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (root.editing) return
            if (root.handleQuickNavigation(event)) return
            if (event.key === Qt.Key_Slash && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) root.startFilter()
            else if (event.key === Qt.Key_Escape) root.closeMenu()
            else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) root.moveSelection(-1)
            else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) root.moveSelection(1)
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.enterPane()
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_Backspace) {
                if (root.pane === 1) root.pane = 0
                else root.closeMenu()
            } else if (event.key === Qt.Key_Tab) root.pane = root.pane === 0 ? 1 : 0
            else if (event.key === Qt.Key_Home) {
                if (root.pane === 0) root.categoryIndex = 0
                else root.actionIndex = 0
            } else if (event.key === Qt.Key_End) {
                if (root.pane === 0) root.categoryIndex = root.categories.length - 1
                else root.actionIndex = Math.max(0, root.currentActions.length - 1)
            } else return
            event.accepted = true
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: Math.min(800, keyCatcher.width - 48)
            height: Math.min(570, keyCatcher.height - 72)
            radius: 18
            color: Theme.surface
            border.width: 1
            border.color: "#424b57"
            clip: true
            MouseArea { anchors.fill: parent; onClicked: {} }

            Column {
                visible: !root.filtering
                anchors.fill: parent

                Rectangle {
                    width: parent.width
                    height: 64
                    color: Theme.elevated
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        spacing: 12
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "󰘳"; color: Theme.primary; font.family: Theme.iconFont; font.pixelSize: 22 }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text { text: "Bar Command Center"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Text { text: "Choose a module, then operate it entirely from the keyboard"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10 }
                        }
                        Item { width: parent.width - 520; height: 1 }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 62; height: 28; radius: 7; color: "#343d48"
                            Text { anchors.centerIn: parent; text: "Alt + ;"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 10; font.weight: Font.DemiBold }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: parent.height - 104

                    Rectangle {
                        width: 250
                        height: parent.height
                        color: "#23282f"
                        ListView {
                            id: categoryList
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 3
                            clip: true
                            model: root.categories
                            delegate: Rectangle {
                                id: categoryRow
                                required property var modelData
                                required property int index
                                width: categoryList.width
                                height: 40
                                radius: 9
                                color: index === root.categoryIndex ? (root.pane === 0 ? Theme.primary : "#364554") : categoryMouse.containsMouse ? "#303842" : "transparent"
                                Row {
                                    anchors.fill: parent; anchors.leftMargin: 11; anchors.rightMargin: 10; spacing: 10
                                    Text { width: 22; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignHCenter; text: categoryRow.modelData.icon; color: index === root.categoryIndex && root.pane === 0 ? Theme.bg : Theme.primary; font.family: Theme.iconFont; font.pixelSize: 17 }
                                    Text { width: parent.width - 94; anchors.verticalCenter: parent.verticalCenter; text: categoryRow.modelData.label; color: index === root.categoryIndex && root.pane === 0 ? Theme.bg : Theme.fg; font.family: Theme.font; font.pixelSize: 12; font.weight: index === root.categoryIndex ? Font.DemiBold : Font.Normal }
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 31; height: 20; radius: 5
                                        color: index === root.categoryIndex && root.pane === 0 ? Qt.rgba(0.12, 0.16, 0.20, 0.18) : "#323a44"
                                        Text { anchors.centerIn: parent; text: "⌃" + root.shortcutFor(categoryRow.index); color: index === root.categoryIndex && root.pane === 0 ? Theme.bg : Theme.muted; font.family: Theme.font; font.pixelSize: 8; font.weight: Font.DemiBold }
                                    }
                                    Text { width: 8; anchors.verticalCenter: parent.verticalCenter; text: index === root.categoryIndex ? "›" : ""; color: index === root.categoryIndex && root.pane === 0 ? Theme.bg : Theme.muted; font.pixelSize: 17 }
                                }
                                MouseArea { id: categoryMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.categoryIndex = categoryRow.index; root.actionIndex = 0; root.pane = 1 } }
                            }
                        }
                    }

                    Rectangle { width: 1; height: parent.height; color: "#3a424d" }

                    Item {
                        width: parent.width - 251
                        height: parent.height
                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 8
                            Row {
                                width: parent.width; height: 32; spacing: 9
                                Text { anchors.verticalCenter: parent.verticalCenter; text: root.selectedCategory.icon; color: Theme.primary; font.family: Theme.iconFont; font.pixelSize: 19 }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: root.selectedCategory.label; color: Theme.fg; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold }
                                Item { width: parent.width - 230; height: 1 }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: root.currentActions.length + " controls"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 9 }
                            }
                            ListView {
                                id: actionList
                                width: parent.width
                                height: parent.height - 40
                                spacing: 5
                                clip: true
                                model: root.currentActions
                                delegate: Rectangle {
                                    id: actionRow
                                    required property var modelData
                                    required property int index
                                    width: actionList.width
                                    height: 49
                                    radius: 9
                                    color: index === root.actionIndex ? (root.pane === 1 ? "#344b60" : "#303a45") : actionMouse.containsMouse ? "#303842" : Theme.elevated
                                    border.width: index === root.actionIndex && root.pane === 1 ? 1 : 0
                                    border.color: Theme.primary
                                    opacity: actionRow.modelData.enabled === false ? 0.42 : 1
                                    Row {
                                        anchors.fill: parent; anchors.leftMargin: 11; anchors.rightMargin: 11; spacing: 10
                                        Text { width: 23; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignHCenter; text: actionRow.modelData.icon || "󰐕"; color: Theme.primary; font.family: Theme.iconFont; font.pixelSize: 17 }
                                        Column {
                                            width: parent.width - 66; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                            Text { width: parent.width; text: actionRow.modelData.label; elide: Text.ElideRight; color: Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold }
                                            Text { width: parent.width; text: actionRow.modelData.detail || ""; elide: Text.ElideRight; color: Theme.muted; font.family: Theme.font; font.pixelSize: 9 }
                                        }
                                        Text { anchors.verticalCenter: parent.verticalCenter; text: index === root.actionIndex && root.pane === 1 ? "↵" : ""; color: Theme.primary; font.pixelSize: 13 }
                                    }
                                    MouseArea { id: actionMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.actionIndex = actionRow.index; root.pane = 1; root.executeAction(actionRow.modelData) } }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 40
                    color: Theme.elevated
                    Row {
                        anchors.centerIn: parent
                        spacing: 20
                        Text { text: "↑↓ / j k  Navigate"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 9 }
                        Text { text: "→ / Enter  Select"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 9 }
                        Text { text: "← / Backspace  Back"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 9 }
                        Text { text: "/  Filter"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 9 }
                        Text { text: "Esc  Close"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 9 }
                        Text { visible: root.feedback !== ""; text: root.feedback; color: Theme.green; font.family: Theme.font; font.pixelSize: 9; font.weight: Font.DemiBold }
                    }
                }
            }

            Rectangle {
                visible: root.filtering
                anchors.fill: parent
                color: Theme.surface
                z: 4

                Column {
                    anchors.fill: parent

                    Rectangle {
                        width: parent.width
                        height: 68
                        color: Theme.elevated
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 18
                            anchors.rightMargin: 18
                            spacing: 10
                            Text { anchors.verticalCenter: parent.verticalCenter; text: "/"; color: Theme.primary; font.family: Theme.font; font.pixelSize: 24; font.weight: Font.DemiBold }
                            TextInput {
                                id: filterInput
                                width: parent.width - 50
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.filterTerm
                                onTextChanged: { root.filterTerm = text; root.filterIndex = 0 }
                                color: Theme.fg
                                selectionColor: Theme.primary
                                font.family: Theme.font
                                font.pixelSize: 17
                                clip: true
                                Keys.onPressed: event => {
                                    if (root.handleQuickNavigation(event)) return
                                    if (event.key === Qt.Key_Escape || (event.key === Qt.Key_Backspace && text.length === 0)) {
                                        root.cancelFilter()
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Up) {
                                        root.moveFilter(-1)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Down) {
                                        root.moveFilter(1)
                                        event.accepted = true
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        root.executeFiltered(root.filteredResults[root.filterIndex])
                                        event.accepted = true
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: parent.height - 108
                        ListView {
                            id: filterList
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 5
                            clip: true
                            model: root.filteredResults
                            delegate: Rectangle {
                                id: filterRow
                                required property var modelData
                                required property int index
                                width: filterList.width
                                height: 50
                                radius: 9
                                color: index === root.filterIndex ? "#344b60" : filterMouse.containsMouse ? "#303842" : Theme.elevated
                                border.width: index === root.filterIndex ? 1 : 0
                                border.color: Theme.primary
                                Row {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 11
                                    Text { width: 24; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignHCenter; text: filterRow.modelData.icon || "󰇖"; color: Theme.primary; font.family: Theme.iconFont; font.pixelSize: 17 }
                                    Column {
                                        width: parent.width - 74; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                        Text { width: parent.width; text: filterRow.modelData.label; elide: Text.ElideRight; color: Theme.fg; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.DemiBold }
                                        Text { width: parent.width; text: filterRow.modelData.detail || ""; elide: Text.ElideRight; color: Theme.muted; font.family: Theme.font; font.pixelSize: 9 }
                                    }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: index === root.filterIndex ? "↵" : ""; color: Theme.primary; font.pixelSize: 13 }
                                }
                                MouseArea { id: filterMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.filterIndex = filterRow.index; root.executeFiltered(filterRow.modelData) } }
                            }
                        }
                        Column {
                            visible: root.filteredResults.length === 0
                            anchors.centerIn: parent
                            spacing: 8
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰅖"; color: Theme.muted; font.family: Theme.iconFont; font.pixelSize: 30 }
                            Text { text: "No controls match /" + root.filterTerm; color: Theme.muted; font.family: Theme.font; font.pixelSize: 12 }
                        }
                    }

                    Rectangle {
                        width: parent.width; height: 40; color: Theme.elevated
                        Row {
                            anchors.centerIn: parent; spacing: 22
                            Text { text: "Type to filter all modules and controls"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 9 }
                            Text { text: "↑↓ Navigate"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 9 }
                            Text { text: "Enter Run"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 9 }
                            Text { text: "Esc Clear"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 9 }
                        }
                    }
                }
            }

            Rectangle {
                visible: root.editing
                anchors.fill: parent
                color: Qt.rgba(0.10, 0.12, 0.15, 0.94)
                z: 5
                Column {
                    anchors.centerIn: parent
                    width: Math.min(480, parent.width - 60)
                    spacing: 12
                    Text { text: "Custom DNS servers"; color: Theme.fg; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Text { text: "Separate multiple IPv4 or IPv6 addresses with spaces"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 10 }
                    Rectangle {
                        width: parent.width; height: 46; radius: 9; color: Theme.elevated; border.width: dnsInput.activeFocus ? 1 : 0; border.color: Theme.primary
                        TextInput {
                            id: dnsInput
                            anchors.fill: parent; anchors.margins: 12
                            color: Theme.fg; selectionColor: Theme.primary; font.family: Theme.font; font.pixelSize: 12
                            clip: true
                            Keys.onReturnPressed: root.submitDns()
                            Keys.onEnterPressed: root.submitDns()
                            Keys.onEscapePressed: root.cancelEditor()
                        }
                    }
                    Text { text: "Enter to apply  ·  Escape to cancel"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 9 }
                }
            }
        }
    }
}
