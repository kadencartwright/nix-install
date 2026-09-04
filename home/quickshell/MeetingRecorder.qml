pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string binary: {
        const configured = Quickshell.env("MEETING_RECORD_BINARY")
        return configured && configured.length > 0 ? configured : "meeting-record"
    }
    readonly property string runtimeStatePath: {
        const runtime = Quickshell.env("XDG_RUNTIME_DIR")
        return runtime && runtime.length > 0 ? runtime + "/meeting-record/state.json" : ""
    }

    property bool recording: false
    property bool paused: false
    property bool busy: false
    property string error: ""
    property string sessionId: ""
    property string startedAt: ""
    property double startedAtMs: 0
    property double pausedAtMs: 0
    property double pausedDurationSeconds: 0
    property string directory: ""
    property var microphone: ({ description: "Resolving microphone…", nodeName: "" })
    property var output: ({ description: "Resolving output…", nodeName: "" })
    property var availableMicrophones: []
    property var availableOutputs: []
    property string selectedMicrophoneNode: ""
    property string selectedOutputNode: ""
    property var sessions: []
    property var destinations: []
    property var externalRecorders: []
    property var externalFiles: []
    property string externalError: ""
    property double clockNow: Date.now()
    readonly property double currentPauseSeconds: paused && pausedAtMs > 0
        ? Math.max(0, (clockNow - pausedAtMs) / 1000) : 0
    readonly property int elapsedSeconds: recording && startedAtMs > 0
        ? Math.max(0, Math.floor((clockNow - startedAtMs) / 1000 - pausedDurationSeconds - currentPauseSeconds)) : 0

    signal operationFinished(string operation, bool succeeded)

    function parseDate(value) {
        // Go's RFC3339Nano may contain more fractional digits than JS accepts.
        const normalized = String(value || "").replace(/(\.\d{3})\d+(Z|[+-]\d\d:\d\d)$/, "$1$2")
        const milliseconds = Date.parse(normalized)
        return isNaN(milliseconds) ? new Date(0) : new Date(milliseconds)
    }

    function formatElapsed(seconds) {
        const total = Math.max(0, Number(seconds) || 0)
        const hours = Math.floor(total / 3600)
        const minutes = Math.floor((total % 3600) / 60)
        const secs = Math.floor(total % 60)
        const pad = value => value < 10 ? "0" + value : String(value)
        return hours > 0 ? hours + ":" + pad(minutes) + ":" + pad(secs) : pad(minutes) + ":" + pad(secs)
    }

    function cleanError(value) {
        const text = String(value || "").trim()
        return text.replace(/^meeting-record:\s*/, "") || "Command failed"
    }

    function applyState(value) {
        let state
        try {
            state = typeof value === "string" ? JSON.parse(value) : value
        } catch (exception) {
            error = "Recorder state is malformed"
            reconcileStatus()
            return
        }
        const wasRecording = recording
        recording = Boolean(state && state.recording && state.session)
        if (recording) {
            const session = state.session
            paused = Boolean(state.paused)
            sessionId = String(session.id || "")
            startedAt = String(session.startedAt || "")
            startedAtMs = parseDate(startedAt).getTime()
            pausedAtMs = session.pausedAt ? parseDate(session.pausedAt).getTime() : 0
            pausedDurationSeconds = Number(session.pausedDurationSeconds || 0)
            directory = String(session.directory || "")
            microphone = session.microphone || ({ description: "Unknown microphone", nodeName: "" })
            output = session.output || ({ description: "Unknown output", nodeName: "" })
            selectedMicrophoneNode = String(microphone.nodeName || "")
            selectedOutputNode = String(output.nodeName || "")
            clockNow = Date.now()
        } else {
            paused = false
            sessionId = ""
            startedAt = ""
            startedAtMs = 0
            pausedAtMs = 0
            pausedDurationSeconds = 0
            directory = ""
            if (wasRecording) {
                refreshDevices()
                refreshSessions()
            }
        }
    }

    function start() {
        if (busy || recording) return
        busy = true
        error = ""
        const command = [binary, "start", "--detach"]
        if (selectedMicrophoneNode) command.push("--microphone", selectedMicrophoneNode)
        if (selectedOutputNode) command.push("--output", selectedOutputNode)
        startProcess.command = command
        startProcess.running = true
    }

    function stop() {
        if (busy || !recording) return
        busy = true
        error = ""
        stopProcess.running = true
    }

    function pause() {
        if (busy || !recording || paused) return
        runRecordingControl("pause")
    }

    function resume() {
        if (busy || !recording || !paused) return
        runRecordingControl("resume")
    }

    function runRecordingControl(operation) {
        busy = true
        error = ""
        controlProcess.operation = operation
        controlProcess.command = [binary, operation]
        controlProcess.running = true
    }

    function findDevice(devices, nodeName) {
        for (let index = 0; index < devices.length; index++) {
            if (String(devices[index].nodeName || "") === String(nodeName || "")) return devices[index]
        }
        return null
    }

    function selectMicrophone(nodeName) {
        if (recording || busy) return
        const device = findDevice(availableMicrophones, nodeName)
        if (device) {
            selectedMicrophoneNode = String(device.nodeName)
            microphone = device
        }
    }

    function selectOutput(nodeName) {
        if (recording || busy) return
        const device = findDevice(availableOutputs, nodeName)
        if (device) {
            selectedOutputNode = String(device.nodeName)
            output = device
        }
    }

    function toggle() {
        if (recording) stop()
        else start()
    }

    function reconcileStatus() {
        if (!statusProcess.running) statusProcess.running = true
    }

    function refreshDevices() {
        if (!devicesProcess.running) devicesProcess.running = true
    }

    function refreshSessions() {
        if (!listProcess.running) listProcess.running = true
    }

    function refreshDestinations() {
        if (!destinationsProcess.running) destinationsProcess.running = true
    }

    function refreshExternal() {
        if (!externalProcess.running) externalProcess.running = true
    }

    function popupOpened() {
        reconcileStatus()
        refreshDevices()
        refreshSessions()
        refreshDestinations()
    }

    function openSession(id) { runAction([binary, "open", String(id)], "open") }
    function viewNotion(id) { runAction([binary, "notion", String(id)], "open") }
    function playMeeting(id) { runAction([binary, "play", String(id), "meeting"], "play") }
    function playLocal(id) { runAction([binary, "play", String(id), "local"], "play") }
    function playRemote(id) { runAction([binary, "play", String(id), "remote"], "play") }
    function playExternal(id) { runAction([binary, "recorder", "play", String(id)], "play") }
    function viewExternalNotion(id) { runAction([binary, "recorder", "notion", String(id)], "open") }

    function uploadExternal(id, destinationId) {
        if (busy || actionProcess.running) return
        busy = true
        error = ""
        actionProcess.operation = "externalUpload"
        actionProcess.command = [binary, "recorder", "upload", String(id), "--destination", String(destinationId), "--json"]
        actionProcess.running = true
    }

    function uploadSession(id, destinationId) {
        if (busy || actionProcess.running) return
        busy = true
        error = ""
        actionProcess.operation = "upload"
        actionProcess.command = [binary, "upload", String(id), "--destination", String(destinationId), "--json"]
        actionProcess.running = true
    }

    function deleteSession(id) {
        if (busy || actionProcess.running) return
        busy = true
        error = ""
        actionProcess.operation = "delete"
        actionProcess.command = [binary, "delete", String(id)]
        actionProcess.running = true
    }

    function runAction(command, operation) {
        if (actionProcess.running) return
        error = ""
        actionProcess.operation = operation
        actionProcess.command = command
        actionProcess.running = true
    }

    property FileView stateFile: FileView {
        path: root.runtimeStatePath
        watchChanges: true
        printErrors: false
        onLoaded: root.applyState(text())
        onFileChanged: reload()
        onLoadFailed: root.reconcileStatus()
    }

    property Timer elapsedTimer: Timer {
        interval: 1000
        repeat: true
        running: root.recording && !root.paused
        triggeredOnStart: true
        onTriggered: root.clockNow = Date.now()
    }

    // This is only a safety reconciliation while active. Elapsed time is local
    // and no process is spawned each second.
    property Timer reconcileTimer: Timer {
        interval: 30000
        repeat: true
        running: root.recording
        onTriggered: root.reconcileStatus()
    }

    property Process startProcess: Process {
        command: [root.binary, "start", "--detach"]
        stdout: StdioCollector { id: startStdout }
        stderr: StdioCollector { id: startStderr }
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            if (exitCode !== 0) root.error = root.cleanError(startStderr.text)
            root.reconcileStatus()
            root.operationFinished("start", exitCode === 0)
        }
    }

    property Process stopProcess: Process {
        command: [root.binary, "stop"]
        stdout: StdioCollector { id: stopStdout }
        stderr: StdioCollector { id: stopStderr }
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            if (exitCode !== 0) root.error = root.cleanError(stopStderr.text)
            root.reconcileStatus()
            if (exitCode === 0) root.refreshSessions()
            root.operationFinished("stop", exitCode === 0)
        }
    }

    property Process controlProcess: Process {
        property string operation: ""
        stdout: StdioCollector { id: controlStdout }
        stderr: StdioCollector { id: controlStderr }
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            if (exitCode !== 0) root.error = root.cleanError(controlStderr.text)
            root.reconcileStatus()
            root.operationFinished(operation, exitCode === 0)
        }
    }

    property Process statusProcess: Process {
        command: [root.binary, "status", "--json"]
        stdout: StdioCollector { id: statusStdout }
        stderr: StdioCollector { id: statusStderr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) root.applyState(statusStdout.text)
            else root.error = root.cleanError(statusStderr.text)
        }
    }

    property Process devicesProcess: Process {
        command: [root.binary, "devices", "--json"]
        stdout: StdioCollector { id: devicesStdout }
        stderr: StdioCollector { id: devicesStderr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.error = root.cleanError(devicesStderr.text)
                return
            }
            try {
                const devices = JSON.parse(devicesStdout.text)
                root.availableMicrophones = devices.microphones || []
                root.availableOutputs = devices.outputs || []
                if (!root.recording) {
                    let selectedMicrophone = root.findDevice(root.availableMicrophones, root.selectedMicrophoneNode)
                    if (!selectedMicrophone) selectedMicrophone = devices.microphone
                    let selectedOutput = root.findDevice(root.availableOutputs, root.selectedOutputNode)
                    if (!selectedOutput) selectedOutput = devices.output
                    root.microphone = selectedMicrophone || ({ description: "Unknown microphone", nodeName: "" })
                    root.output = selectedOutput || ({ description: "Unknown output", nodeName: "" })
                    root.selectedMicrophoneNode = String(root.microphone.nodeName || "")
                    root.selectedOutputNode = String(root.output.nodeName || "")
                }
            } catch (exception) {
                root.error = "Device information is malformed"
            }
        }
    }

    property Process listProcess: Process {
        command: [root.binary, "list", "--json"]
        stdout: StdioCollector { id: listStdout }
        stderr: StdioCollector { id: listStderr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.error = root.cleanError(listStderr.text)
                return
            }
            try {
                const result = JSON.parse(listStdout.text)
                root.sessions = (result.sessions || []).slice(0, 20)
                if (result.warnings && result.warnings.length > 0)
                    root.error = result.warnings[0]
            } catch (exception) {
                root.error = "Recording history is malformed"
            }
        }
    }

    property Process destinationsProcess: Process {
        command: [root.binary, "destinations", "--json"]
        stdout: StdioCollector { id: destinationsStdout }
        stderr: StdioCollector { id: destinationsStderr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.destinations = []
                root.error = root.cleanError(destinationsStderr.text)
                return
            }
            try {
                const result = JSON.parse(destinationsStdout.text)
                root.destinations = result.destinations || []
            } catch (exception) {
                root.destinations = []
                root.error = "Notion destinations are malformed"
            }
        }
    }

    property Process externalProcess: Process {
        command: [root.binary, "recorder", "list", "--json"]
        stdout: StdioCollector { id: externalStdout }
        stderr: StdioCollector { id: externalStderr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.externalRecorders = []
                root.externalFiles = []
                root.externalError = root.cleanError(externalStderr.text)
                return
            }
            try {
                const result = JSON.parse(externalStdout.text)
                root.externalRecorders = result.recorders || []
                let files = []
                let firstError = ""
                for (let index = 0; index < root.externalRecorders.length; index++) {
                    const recorder = root.externalRecorders[index]
                    files = files.concat(recorder.files || [])
                    if (!firstError && recorder.error) firstError = String(recorder.error)
                }
                root.externalFiles = files
                root.externalError = firstError
            } catch (exception) {
                root.externalRecorders = []
                root.externalFiles = []
                root.externalError = "Voice recorder information is malformed"
            }
        }
    }

    property Process actionProcess: Process {
        property string operation: ""
        stdout: StdioCollector { id: actionStdout }
        stderr: StdioCollector { id: actionStderr }
        onExited: (exitCode, exitStatus) => {
            if (operation === "delete" || operation === "upload" || operation === "externalUpload") root.busy = false
            if (exitCode !== 0) root.error = root.cleanError(actionStderr.text)
            if ((operation === "delete" || operation === "upload") && exitCode === 0)
                root.refreshSessions()
            if (operation === "externalUpload" && exitCode === 0) root.refreshExternal()
            root.operationFinished(operation, exitCode === 0)
        }
    }

    property IpcHandler ipc: IpcHandler {
        target: "meetingRecorder"

        function start(): string {
            root.start()
            return root.recording ? "already recording" : "starting"
        }

        function stop(): string {
            root.stop()
            return root.recording ? "stopping" : "not recording"
        }

        function pause(): string {
            root.pause()
            return root.paused ? "already paused" : "pausing"
        }

        function resume(): string {
            root.resume()
            return root.paused ? "resuming" : "not paused"
        }

        function toggle(): string {
            const action = root.recording ? "stopping" : "starting"
            root.toggle()
            return action
        }

        function status(): string {
            root.reconcileStatus()
            return root.recording ? (root.paused ? "paused " : "recording ") + root.formatElapsed(root.elapsedSeconds) : "idle"
        }

    }

    Component.onCompleted: {
        reconcileStatus()
        refreshDevices()
        refreshDestinations()
    }
}
