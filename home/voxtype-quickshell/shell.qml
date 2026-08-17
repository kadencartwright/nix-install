import QtQuick
import Quickshell
import "voxtype-shared" as VT

ShellRoot {
    VT.StateReader {
        id: stateReader
    }

    VT.AudioBridge {
        id: audio
        bridgeBinary: {
            const configured = Quickshell.env("VOXTYPE_AUDIO_BRIDGE_BINARY");
            return configured && configured.length > 0
                ? configured
                : "voxtype-audio-bridge";
        }
    }

    RecordingOverlay {
        daemonState: stateReader.state
        audio: audio
    }
}
