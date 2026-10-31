import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Modules.Plugins
import qs.DCommon.Widgets

// Bar pill + popout for Nothing / CMF audio devices. All Bluetooth and
// protocol work happens in NothingBudsDaemon.qml; this surface only renders
// the published snapshot and forwards `set` commands to the daemon.
PluginComponent {
    id: root

    readonly property var snap: PluginService.globalVars[root.pluginId]?.snapshot ?? null
    readonly property var st: root.snap?.state ?? null
    readonly property bool connected: root.snap?.connected === true
    readonly property bool live: root.connected && root.snap?.phase === "live"
    readonly property bool busy: root.snap?.busy === true
    readonly property string phase: String(root.snap?.phase || "idle")
    readonly property string message: String(root.snap?.message || "")
    readonly property string deviceName: String(root.snap?.name || "Nothing / CMF")
    readonly property string modelName: String(root.st?.model?.name || "")
    readonly property string firmware: String(root.st?.firmware || "")
    readonly property bool showBattery: root.snap?.showBattery !== false

    readonly property string ancMode: String(root.st?.anc?.mode || "")
    readonly property var ancChoices: root.st?.anc?.available ?? []
    readonly property var eqChoices: root.st?.eq?.available ?? []
    readonly property string eqPreset: String(root.st?.eq?.preset || "")
    readonly property var spatialChoices: root.st?.spatial?.available ?? []
    readonly property string spatialMode: String(root.st?.spatial?.mode || "")

    readonly property var batteries: root.st?.battery ?? []
    readonly property var singleBattery: {
        const list = root.batteries;
        return list.find(b => b.id === "single") || null;
    }
    readonly property int batteryLevel: {
        const list = root.batteries;
        if (!list || list.length === 0)
            return -1;
        const single = list.find(b => b.id === "single");
        if (single && typeof single.level === "number")
            return single.level;
        const buds = list.filter(b => b.id === "left" || b.id === "right");
        if (buds.length === 0)
            return -1;
        return Math.min.apply(null, buds.map(b => Number(b.level)));
    }
    readonly property bool charging: {
        const list = root.batteries;
        return list.some(b => b.charging === true);
    }
    readonly property color modeColor: {
        const m = root.ancMode;
        if (!root.connected)
            return Theme.surfaceVariantText;
        if (m === "transparency")
            return Theme.tertiary;
        if (m === "off" || m === "")
            return Theme.surfaceVariantText;
        return Theme.primary;
    }

    // ------------------------------------------------------------- helpers
    function daemon() {
        const map = PluginService.pluginDaemonInstances;
        if (!map)
            return null;
        return map[root.pluginId] || null;
    }

    function send(command) {
        const d = root.daemon();
        if (d && typeof d.send === "function")
            d.send(command);
    }

    function setConnected(want) {
        const d = root.daemon();
        if (d && typeof d.setConnected === "function")
            d.setConnected(want);
    }

    function refresh() {
        const d = root.daemon();
        if (d && typeof d.refresh === "function")
            d.refresh();
    }

    function ancLabel(mode) {
        const labels = {
            "off": "Off",
            "transparency": "Transparency",
            "low": "ANC low",
            "mid": "ANC mid",
            "high": "ANC high",
            "adaptive": "Adaptive",
            "nc": "ANC"
        };
        return labels[mode] || mode;
    }

    function presetLabel(name) {
        return String(name || "").charAt(0).toUpperCase() + String(name || "").slice(1);
    }

    function spatialLabel(name) {
        const labels = { "off": "Off", "fixed": "Fixed", "concert": "Concert", "theatre": "Theatre", "head_tracking": "Head tracking" };
        return labels[name] || presetLabel(name);
    }

    function batteryOf(id) {
        return root.batteries.find(b => b.id === id) || null;
    }

    function budText() {
        if (!root.live)
            return "";
        const parts = [];
        const left = root.batteryOf("left");
        const right = root.batteryOf("right");
        const caseBattery = root.batteryOf("case");
        if (left)
            parts.push("L " + left.level + "%");
        if (right)
            parts.push("R " + right.level + "%");
        if (caseBattery)
            parts.push("Case " + caseBattery.level + "%");
        return parts.join("  ·  ");
    }

    // ------------------------------------------------------------------ bar
    horizontalBarPill: Component {
        Item {
            implicitWidth: pillRow.implicitWidth + Theme.spacingXS * 2
            implicitHeight: Math.max(pillRow.implicitHeight, root.iconSize)

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DIcon {
                    name: "headphones"
                    size: root.iconSize
                    color: root.live ? Theme.primary : Theme.surfaceVariantText
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    visible: root.snap !== null
                    width: Math.max(5, Math.round(root.iconSize * 0.22))
                    height: width
                    radius: width / 2
                    color: root.modeColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    visible: root.showBattery && root.live && root.batteryLevel >= 0
                    text: root.batteryLevel + "%"
                    font.pixelSize: root.textSize
                    color: root.charging ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: Math.max(root.iconSize, Theme.spacingM)
            implicitHeight: verticalRow.implicitHeight + Theme.spacingXS * 2

            Column {
                id: verticalRow
                anchors.centerIn: parent
                spacing: 3

                DIcon {
                    name: "headphones"
                    size: root.iconSize
                    color: root.live ? Theme.primary : Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    visible: root.snap !== null
                    width: Math.max(5, Math.round(root.iconSize * 0.22))
                    height: width
                    radius: width / 2
                    color: root.modeColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    // --------------------------------------------------------------- popout
    popoutWidth: 380
    popoutHeight: 480

    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            height: root.popoutHeight - Theme.spacingS * 2

            Item {
                width: parent.width
                height: root.popoutHeight - Theme.spacingS * 2

                Column {
                    id: content
                    x: Theme.spacingM
                    y: Theme.spacingS
                    width: parent.width - Theme.spacingM * 2
                    spacing: Theme.spacingM

                    // ------------------------------------------------ header
                    Item {
                        width: parent.width
                        height: 44

                        DIcon {
                            id: headerIcon
                            name: "headphones"
                            size: 30
                            color: root.live ? Theme.primary : Theme.surfaceVariantText
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.left: headerIcon.right
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: headerActions.left
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            StyledText {
                                width: parent.width
                                text: root.deviceName
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                            }

                            StyledText {
                                width: parent.width
                                text: {
                                    if (!root.live)
                                        return root.phase === "connecting" ? "Connecting…" : "Disconnected";
                                    const bits = [];
                                    if (root.modelName !== "")
                                        bits.push(root.modelName);
                                    if (root.firmware !== "")
                                        bits.push("fw " + root.firmware);
                                    bits.push(root.ancMode === "" ? "ready" : root.ancLabel(root.ancMode));
                                    return bits.join(" · ");
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                            }
                        }

                        Row {
                            id: headerActions
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            DActionButton {
                                buttonSize: 34
                                iconName: root.connected ? "link_off" : "link"
                                iconColor: Theme.surfaceText
                                tooltipText: root.connected ? "Disconnect" : "Connect"
                                onClicked: root.setConnected(!root.connected)
                            }

                            DActionButton {
                                buttonSize: 34
                                iconName: "refresh"
                                iconColor: Theme.surfaceText
                                tooltipText: "Read the device again"
                                onClicked: root.refresh()
                            }
                        }
                    }

                    // ----------------------------------------------- battery
                    StyledRect {
                        width: parent.width
                        height: 62
                        radius: Theme.cornerRadiusM
                        color: Theme.surfaceContainerHigh
                        visible: root.live

                        DIcon {
                            id: batteryIcon
                            name: root.charging ? "battery_charging_full" : "battery_full"
                            size: 26
                            color: root.batteryLevel >= 0 && root.batteryLevel < 20 ? Theme.error : Theme.primary
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Column {
                            anchors.left: batteryIcon.right
                            anchors.leftMargin: Theme.spacingM
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            StyledText {
                                text: root.batteryLevel >= 0 ? root.batteryLevel + "%" : "Battery unknown"
                                font.pixelSize: Theme.fontSizeLarge + 2
                                font.weight: Font.Medium
                                color: Theme.surfaceText
                            }

                            StyledText {
                                text: {
                                    if (root.charging)
                                        return "Charging";
                                    const buds = root.budText();
                                    return buds !== "" ? buds : "On battery";
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }

                    // --------------------------------------------------- anc
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: root.live && root.ancChoices.length > 0

                        StyledText {
                            text: "Noise control"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                        }

                        Flow {
                            width: parent.width
                            spacing: Theme.spacingXS

                            Repeater {
                                model: root.ancChoices

                                Chip {
                                    label: root.ancLabel(modelData)
                                    selected: root.ancMode === modelData
                                    onChosen: root.send("anc " + modelData)
                                }
                            }
                        }
                    }

                    // ---------------------------------------------------- eq
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: root.live && root.eqChoices.length > 0

                        StyledText {
                            text: "Equalizer"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                        }

                        Flow {
                            width: parent.width
                            spacing: Theme.spacingXS

                            Repeater {
                                model: root.eqChoices

                                Chip {
                                    label: root.presetLabel(modelData)
                                    selected: root.eqPreset === modelData
                                    onChosen: root.send("eq " + modelData)
                                }
                            }
                        }
                    }

                    // ------------------------------------------------ spatial
                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: root.live && root.spatialChoices.length > 0

                        StyledText {
                            text: "Spatial audio"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                        }

                        Flow {
                            width: parent.width
                            spacing: Theme.spacingXS

                            Repeater {
                                model: root.spatialChoices

                                Chip {
                                    label: root.spatialLabel(modelData)
                                    selected: root.spatialMode === modelData
                                    onChosen: root.send("spatial " + modelData)
                                }
                            }
                        }
                    }

                    // ------------------------------------------------ toggles
                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: root.live

                        ToggleRow {
                            label: "Low latency"
                            description: "Shorter audio delay for games and video"
                            value: root.st?.lowLatency === true
                            available: root.st?.lowLatency !== null && root.st?.lowLatency !== undefined
                            onChanged: v => root.send("low-latency " + (v ? "on" : "off"))
                        }

                        ToggleRow {
                            label: "Personal sound"
                            description: "Hearing-profile based tuning"
                            value: root.st?.personalSound === true
                            available: root.st?.personalSound !== null && root.st?.personalSound !== undefined
                            onChanged: v => root.send("personal-sound " + (v ? "on" : "off"))
                        }

                        ToggleRow {
                            label: "In-ear detection"
                            description: "Pause when a bud is removed"
                            value: root.st?.inEar === true
                            available: root.st?.inEar !== null && root.st?.inEar !== undefined
                            onChanged: v => root.send("in-ear " + (v ? "on" : "off"))
                        }

                        ToggleRow {
                            label: "Super mic"
                            description: "Use the case as a call microphone"
                            value: root.st?.superMic === true
                            available: root.st?.superMic !== null && root.st?.superMic !== undefined
                            onChanged: v => root.send("super-mic " + (v ? "on" : "off"))
                        }
                    }

                    // ----------------------------------------------- messages
                    StyledText {
                        width: parent.width
                        visible: text !== ""
                        text: {
                            if (root.message !== "")
                                return root.message;
                            if (root.busy)
                                return "Applying…";
                            if (root.connected && root.phase === "connecting")
                                return "Opening the control link…";
                            if (!root.connected)
                                return "Connect the device to control noise, EQ and spatial audio.";
                            return "";
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.message !== "" ? Theme.error : Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }

                    // ---------------------------------------------- disconnect
                    StyledText {
                        width: parent.width
                        visible: !root.connected
                        text: "nothingctl not found? Set its path in this plugin's settings."
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------- inline types
    component Chip: StyledRect {
        id: chip

        property string label: ""
        property bool selected: false

        signal chosen

        implicitWidth: chipText.implicitWidth + Theme.spacingM * 2
        implicitHeight: 30
        width: implicitWidth
        height: implicitHeight
        radius: height / 2
        color: selected ? Theme.primary : "transparent"
        border.width: selected ? 0 : 1
        border.color: Theme.outlineVariant

        StyledText {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            font.pixelSize: Theme.fontSizeSmall
            color: chip.selected ? Theme.onPrimary : Theme.surfaceVariantText
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.chosen()
        }
    }

    component ToggleRow: Item {
        id: row

        property string label: ""
        property string description: ""
        property bool value: false
        property bool available: true

        signal changed(bool value)

        width: parent ? parent.width : 0
        height: available ? 40 : 0
        visible: available

        StyledText {
            anchors.left: parent.left
            anchors.right: toggle.left
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceText
            elide: Text.ElideRight
        }

        DToggle {
            id: toggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: row.value
            onToggled: checked => row.changed(checked)
        }
    }
}
