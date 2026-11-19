import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string statePath: {
        const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR");
        if (runtimeDir && runtimeDir.length > 0)
            return runtimeDir + "/voxtype/state";

        const uid = Quickshell.env("UID");
        return "/run/user/" + (uid && uid.length > 0 ? uid : "1000")
            + "/voxtype/state";
    }
    property string state: "idle"

    property FileView stateFile: FileView {
        path: root.statePath
        watchChanges: true
        printErrors: false

        onLoaded: root.state = (text() || "idle").trim()
        onLoadFailed: root.state = "idle"
        onFileChanged: reload()
    }
}
