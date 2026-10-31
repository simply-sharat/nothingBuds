import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "nothingBuds"

    component Section: StyledText {
        width: parent ? parent.width : 0
        topPadding: Theme.spacingXL
        bottomPadding: Theme.spacingXS
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    component Divider: StyledRect {
        width: parent ? parent.width : 0
        height: 1
        color: Theme.outlineVariant
    }

    component Note: StyledText {
        width: parent ? parent.width : 0
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Section {
        text: "Device"
    }

    StringSetting {
        settingKey: "address"
        label: "Bluetooth address"
        description: "Leave empty to pick the first connected device whose name looks like Nothing / CMF / Ear."
        placeholder: "2C:BE:EE:70:F0:0B"
        defaultValue: ""
    }

    ToggleSetting {
        settingKey: "showBattery"
        label: "Show battery in the bar"
        description: "Displays the current charge next to the headphone icon."
        defaultValue: true
    }

    Divider {}

    Section {
        text: "Backend"
    }

    StringSetting {
        settingKey: "binary"
        label: "nothingctl path"
        description: "Leave empty to use ~/.local/bin/nothingctl."
        placeholder: "~/.local/bin/nothingctl"
        defaultValue: ""
    }

    Note {
        text: "This plugin needs nothingctl ≥ 0.2.0. Install it with:\n\n    cargo install --git https://github.com/FormalSnake/nothingctl --tag v0.2.0 --locked\n\nor run install.sh from the plugin folder. The device must be paired and connected over Bluetooth; nothingctl finds the RFCOMM channel itself."
    }

    Divider {}

    Section {
        text: "Troubleshooting"
    }

    Note {
        text: "• \"UUID already registered\" means another nothingctl instance is running. Close it and press refresh in the popout.\n• Only one control link can exist per device, so do not run nothingctl watch in a terminal while the widget is active.\n• If the pill stays grey after connecting, open the popout and press refresh.\n• Older Nothing models speak an older protocol; check `nothingctl list` and `nothingctl status --json` in a terminal first."
    }
}
