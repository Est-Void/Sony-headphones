# Sony Pods for Noctalia

Battery monitor and noise control (ANC / Ambient Sound) for Sony Bluetooth
headphones in [Noctalia](https://noctalia.dev) v5+.

Modeled after
[`osp54/oppo-pods`](https://noctalia.dev/plugins/community/oppo-pods):
bar widget (`sony-pods`) + floating panel (`panel`) + background service
(`service`), with a `python3`-only backend speaking Sony's reverse-engineered
**MDR V2** binary protocol over Bluetooth RFCOMM (same protocol as the
official Sound Connect app). No phone, no account, no extra dependencies.

Tested on **WH-1000XM5**. Should also work on other V2 devices
(WH-1000XM6, WF-1000XM5/XM4, LinkBuds series, WH-CH720N, ULT WEAR, …) —
please report.

## Requirements

- `python3` on `PATH` (standard library only)
- BlueZ Bluetooth stack with RFCOMM support (`bluetoothctl`, `sdptool`)
- Paired and connected Sony headphones

## Usage

Add the `sony-pods` widget to your bar via **Settings → Bar → Widgets**.

- **Left-click** the bar icon to toggle the control panel.
- **Right-click** the bar icon to cycle noise modes
  (`Noise Cancelling` → `Ambient Sound` → `Off`).

Toggle the panel from IPC / keybind:

```sh
noctalia msg panel-toggle estvoid/sony-pods:panel
```

## Settings

| Setting                 | Type   | Default | Description                                                        |
| ----------------------- | ------ | ------- | ------------------------------------------------------------------ |
| `device_mac`            | string | `""`    | Bluetooth MAC of the headphones. Blank = auto-detect.              |
| `hide_when_disconnected`| bool   | `true`  | Hide the bar widget when the headphones are not connected.         |

## IPC

```sh
noctalia msg plugin estvoid/sony-pods:service all cycle-noise
noctalia msg plugin estvoid/sony-pods:service all set-noise anc
noctalia msg plugin estvoid/sony-pods:service all set-noise transparency
noctalia msg plugin estvoid/sony-pods:service all set-noise off
noctalia msg plugin estvoid/sony-pods:service all set-ambient 12
noctalia msg plugin estvoid/sony-pods:service all refresh
```

The backend CLI works standalone too:

```sh
python3 scripts/sony_ctl.py status [--mac XX:XX:XX:XX:XX:XX]
python3 scripts/sony_ctl.py set-anc anc|transparency|off
python3 scripts/sony_ctl.py set-ambient 0..20
python3 scripts/sony_ctl.py cycle-anc
python3 scripts/sony_ctl.py cached
```

## Notes

- Control channel is the Sony `Serial HPC` service
  (`956c7b26-…`, usually RFCOMM channel 9), resolved via `sdptool`.
- Over-ear models (WH-1000X) report a single battery level; BlueZ
  `Battery Percentage` is used as fallback when RFCOMM is busy.
- The XM5 does not echo the ambient level back, so the panel shows the
  last-set level (persisted in `$XDG_RUNTIME_DIR/sony_pods_state.json`).
- v0.1 covers battery + noise modes + ambient level. EQ / DSEE /
  Speak-to-Chat are planned for v0.2.
