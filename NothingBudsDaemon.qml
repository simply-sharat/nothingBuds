import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.Common
import qs.Services

// Single owner of the nothingctl link. DMS spawns one daemon per plugin, so
// the RFCOMM socket is never opened twice no matter how many bar/popout
// instances exist. State is published in PluginService.globalVars and the
// widget sends commands back through send().
Item {
    id: root

    property var pluginService: null
    property string pluginId: "nothingBuds"

    readonly property string home: Quickshell.env("HOME") || ""

    // Settings are re-read whenever pluginDataChanged fires.
    property int settingsRevision: 0
    readonly property var settingsData: {
        root.settingsRevision;
        return SettingsData.getPluginSettingsForPlugin(root.pluginId) || ({});
    }
    readonly property string configuredBinary: String(root.settingsData.binary || "").trim()
    readonly property string binary: root.configuredBinary !== ""
        ? root.configuredBinary
        : root.home + "/.local/bin/nothingctl"
    readonly property string pinnedAddress: String(root.settingsData.address || "").trim().toUpperCase()
    readonly property bool showBattery: root.settingsData.showBattery !== false

    // Live snapshot from `nothingctl watch`.
    property var state: null
    // idle | connecting | live | disconnected | unsupported | error
    property string phase: "idle"
    property string message: ""
    property bool busy: false
    property string stderrTail: ""
    property int retries: 0

    // ---------------------------------------------------------------- device
    readonly property var devices: BluetoothService.adapter?.devices?.values ?? []
    readonly property var device: {
        const all = root.devices;
        if (root.pinnedAddress !== "") {
            return all.find(d => String(d.address || "").toUpperCase() === root.pinnedAddress) || null;
        }
        const looksLikeOurs = d => /nothing|cmf|ear/i.test(String(d.name || ""));
        return all.find(d => d.connected && looksLikeOurs(d))
            || all.find(d => looksLikeOurs(d))
            || null;
    }
    readonly property bool connected: root.device ? root.device.connected === true : false
    readonly property string address: root.device ? String(root.device.address || "") : root.pinnedAddress
    readonly property string deviceName: root.device
        ? String(root.device.name || "")
        : String(root.state?.name || "")

    // ---------------------------------------------------------------- output
    function publish() {
        PluginService.setGlobalVar(root.pluginId, "snapshot", {
            state: root.state,
            phase: root.phase,
            message: root.message,
            busy: root.busy,
            connected: root.connected,
            address: root.address,
            name: root.deviceName,
            showBattery: root.showBattery,
            binary: root.binary
        });
    }

    // ---------------------------------------------------------------- link
    Process {
        id: watchProc
        running: false
        stdinEnabled: true
        command: {
            const args = [root.binary, "watch"];
            if (root.address !== "")
                args.push("-d", root.address);
            return args;
        }
        stdout: SplitParser {
            onRead: line => root.onLine(String(line || "").trim())
        }
        stderr: SplitParser {
            onRead: line => {
                const text = String(line || "").trim();
                if (text !== "")
                    root.stderrTail = text.slice(0, 240);
            }
        }
        onExited: exitCode => root.onExit(exitCode)
    }

    // Give BlueZ a moment to release the old RFCOMM socket before reopening.
    Timer {
        id: restartTimer
        interval: 700
        repeat: false
        onTriggered: root.startWatch()
    }

    Timer {
        id: retryTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (root.connected && !watchProc.running && root.retries < 4) {
                root.retries += 1;
                root.startWatch();
            }
        }
    }

    function startWatch() {
        if (watchProc.running || !root.connected)
            return;
        root.stderrTail = "";
        root.message = "";
        root.phase = "connecting";
        root.publish();
        watchProc.running = true;
    }

    function stopWatch() {
        retryTimer.stop();
        restartTimer.stop();
        if (watchProc.running)
            watchProc.running = false;
    }

    function syncLink() {
        if (root.connected) {
            if (!watchProc.running)
                root.startWatch();
        } else {
            root.stopWatch();
            root.state = null;
            root.busy = false;
            if (root.phase === "live" || root.phase === "connecting" || root.phase === "idle")
                root.phase = "disconnected";
            root.publish();
        }
    }

    function onLine(line) {
        if (line === "")
            return;
        let msg = null;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (!msg || typeof msg !== "object")
            return;

        if (msg.type === "state") {
            root.state = msg;
            root.phase = "live";
            root.message = "";
            root.busy = false;
            root.retries = 0;
            root.publish();
            return;
        }
        if (msg.type === "ack") {
            root.busy = false;
            root.publish();
            return;
        }
        if (msg.type === "error") {
            root.busy = false;
            root.message = String(msg.message || "The device refused the command");
            if (msg.code === "unsupported-model")
                root.phase = "unsupported";
            root.publish();
            return;
        }
        if (msg.type === "disconnected") {
            root.state = null;
            root.busy = false;
            root.phase = "disconnected";
            root.publish();
        }
    }

    function onExit(exitCode) {
        root.busy = false;
        if (exitCode === 3) {
            root.phase = "unsupported";
            root.message = "This model is not supported by nothingctl yet.";
        } else if (root.connected) {
            root.phase = "error";
            root.message = root.stderrTail !== ""
                ? root.stderrTail
                : "nothingctl exited (" + exitCode + ")";
            retryTimer.restart();
        } else {
            root.state = null;
            root.phase = "disconnected";
        }
        root.publish();
    }

    // ---------------------------------------------------------------- commands
    // Called by the widget: send("anc high"), send("eq rock"), ...
    function send(command) {
        const line = String(command || "").trim();
        if (line === "")
            return false;
        if (!watchProc.running) {
            root.message = root.connected ? "Link is starting, try again" : "Device is not connected";
            root.publish();
            if (root.connected)
                root.startWatch();
            return false;
        }
        watchProc.write(line + "\n");
        root.busy = true;
        root.message = "";
        root.publish();
        return true;
    }

    function setConnected(want) {
        if (!root.device)
            return false;
        if (want) {
            root.phase = "connecting";
            root.message = "";
            root.device.connect();
        } else {
            root.device.disconnect();
        }
        root.publish();
        return true;
    }

    function refresh() {
        root.stopWatch();
        root.state = null;
        root.retries = 0;
        root.phase = root.connected ? "connecting" : "disconnected";
        root.publish();
        if (root.connected)
            restartTimer.restart();
    }

    // ---------------------------------------------------------------- wiring
    onDeviceChanged: root.syncLink()
    onConnectedChanged: root.syncLink()
    onPinnedAddressChanged: root.refresh()

    Connections {
        target: root.device
        enabled: root.device !== null
        function onConnectedChanged() {
            root.syncLink();
        }
    }

    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null
        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId !== root.pluginId)
                return;
            root.settingsRevision += 1;
            root.publish();
        }
    }

    Component.onCompleted: {
        root.publish();
        root.syncLink();
    }

    Component.onDestruction: root.stopWatch()
}
