# Nothing Buds for DankMaterialShell (DMS)

A bar pill and popout for Nothing / CMF audio devices on CachyOS + niri +
DankMaterialShell 2.0. Shows battery and the current noise-control mode, and
lets you change ANC, EQ, spatial audio, low-latency and personal sound
without leaving the bar.

Ported from the Omarchy "Nothing Buds" Quattro bar widget. The Bluetooth
protocol work is done by
[nothingctl](https://github.com/FormalSnake/nothingctl) instead of `earctl`,
because nothingctl supports newer models (including the CMF Headphone Pro,
B175) and discovers the RFCOMM channel through BlueZ.

## Features

- Bar pill: headphone icon, mode-coloured status dot, battery percentage.
- Popout: battery, noise control (Off/Transparency/Low/Mid/High/Adaptive),
  equalizer presets, spatial audio (Off/Concert/Theatre), low-latency,
  personal sound, in-ear detection and super-mic toggles (only the ones the
  connected model reports).
- Connect / disconnect the device and refresh the control link from the
  popout.
- Device auto-detection or a pinned Bluetooth address.
- Configurable path to `nothingctl`.

## Requirements

- CachyOS / Arch (or any distro with the packages below).
- niri 26.04+ (Wayland) — any Wayland compositor works.
- DankMaterialShell 2.0 (`dux-shell`) with Quickshell 0.3.2+.
- `nothingctl` 0.2.0+.
- Rust toolchain (`cargo`) to build nothingctl.
- A paired and connected Nothing / CMF device.
- Bluetooth stack (BlueZ) with RFCOMM support.

## Installation

### 1. Clone this repository

```sh
git clone https://github.com/<your-user>/nothingBuds.git
cd nothingBuds
```

If you are installing by hand without git, copy the whole folder to:

```sh
~/.config/DankMaterialShell/plugins/nothingBuds/
```

(DankMaterialShell resolves `~/.config/dms` to the same location on this
setup.)

### 2. Install the backend (nothingctl)

```sh
./install.sh
```

The script builds nothingctl v0.2.0 with cargo and installs it to
`~/.local/bin/nothingctl`. To do it manually:

```sh
cargo install --git https://github.com/FormalSnake/nothingctl --tag v0.2.0 --locked
```

Make sure `~/.local/bin` is on your `PATH`:

```sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc   # or fish/zsh
```

Verify:

```sh
nothingctl --version
nothingctl list
```

### 3. Enable the plugin in DMS

```sh
dms ipc call plugin-scan scan
sleep 3
dms ipc call plugins enable nothingBuds
```

Or use the UI: Settings → Plugins → rescan → enable **Nothing Buds**.

### 4. Add the widget to the bar

Either edit `~/.config/DankMaterialShell/settings.json` (back it up first):

```json
{ "id": "nothingBuds", "enabled": true }
```

added to the desired section's widget list (`leftWidgets` / `centerWidgets` /
`rightWidgets`), or use the DMS bar editor.

### 5. (Optional) Pin your device

Open Settings → Plugins → Nothing Buds and set:

- **Bluetooth address** — e.g. `2C:BE:EE:70:F0:0B`. Leave empty to use the
  first connected device whose name contains Nothing, CMF or Ear.
- **Show battery in the bar** — toggle.
- **nothingctl path** — leave empty for `~/.local/bin/nothingctl`.

## Usage

- **Bar pill**: headphone icon, mode-coloured dot, battery percentage.
- **Click** the pill to open the popout.
- **Noise control / Equalizer / Spatial audio**: click a chip to apply.
- **Toggles**: flip low-latency, personal sound, in-ear detection, super-mic.
- **Connect / disconnect**: link icon in the popout header.
- **Refresh**: circular-arrow icon — reopens the control link.
- **Settings**: gear icon in DMS, or `dms ipc call settings open`.

## How it works

- `NothingBudsDaemon.qml` is a singleton that owns the single
  `nothingctl watch` process. It publishes a snapshot through
  `PluginService.globalVars["nothingBuds"]` and exposes `send`,
  `setConnected` and `refresh`.
- `NothingBuds.qml` renders the bar pill and the popout, reads the snapshot
  and forwards commands as stdin lines (`anc high`, `eq rock`,
  `spatial concert`, `low-latency on`, ...).

Only one RFCOMM control link can exist per device. Running
`nothingctl watch` in a terminal while the widget is active fails with
`Bluetooth operation not permitted: UUID already registered`.

## Troubleshooting

- **Pill stays grey after connecting**: open the popout and press refresh.
- **"UUID already registered"**: another nothingctl instance is running.
  Close it, then press refresh in the popout.
- **"no model id on the Fast Pair channel within 5s"**: transient BlueZ
  race after a reconnect. The daemon retries up to 4 times; if it persists,
  disconnect and reconnect the device.
- **"This model is not supported by nothingctl yet."**: the device's model id
  is not in nothingctl's table. Check `nothingctl status --json`.
- **nothingctl not found**: set the full path in the plugin settings.
- **No battery / controls shown**: run `nothingctl status -d <MAC> --json`
  in a terminal and confirm the device reports them.

## Limitations

- nothingctl exposes no codec switching or find-my-device ring.
- Single-battery devices (B175) show one battery entry; the popout still
  handles left/right/case batteries for earbuds.
- Only controls the connected model reports are shown.

## Uninstall

```sh
dms ipc call plugins disable nothingBuds
rm -rf ~/.config/DankMaterialShell/plugins/nothingBuds
```

Optionally remove `~/.local/bin/nothingctl`.

## Credits

- Original Omarchy "Nothing Buds" Quattro bar widget.
- [nothingctl](https://github.com/FormalSnake/nothingctl) by FormalSnake.
- DankMaterialShell by AvengeMedia / DuxLabs.
