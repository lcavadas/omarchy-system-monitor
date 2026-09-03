# System Monitor - Omarchy bar widget

A live system-monitor bar widget for Omarchy, inspired by iStat Menus: live
history mini-graphs on the bar and richer detail graphs in the dropdown panel.

## What it shows

**On the bar** (compact, iStat-style, in order)
- `CPU` - live mini history graph + current %
- `RAM` - live mini history graph + current %
- `GPU` - live mini history graph + current % (auto-hidden when no supported
  GPU is detected; defaults to the discrete GPU on hybrid systems)
- `VRAM` - live mini history graph + current % (same auto-hide behaviour)
- `NET` - live download/upload throughput (down / up), colour-coded

**In the dropdown panel** (click the widget)
- `CPU` - history graph, load average, load-level label
- `Memory` - history graph, used / total
- `NET` - combined download/upload **mirror bar chart** (download bars rise,
  upload bars mirror downward)
- `Disk` - used / total
- `GPU` - history graph, utilisation %, and load-level label (like `CPU`); the
  GPU model is shown as the secondary detail. Only shown when a supported GPU
  is detected.
- `VRAM` - video memory history graph, % used, and used / total (like
  `Memory`). Only shown when a supported GPU is detected.

The widget follows the bar foreground, so it darkens correctly on a transparent
bar, and it uses the theme accent/urgent colours on the network graph.

## Install

```bash
omarchy plugin add https://github.com/lcavadas/omarchy-system-monitor.git
```

## Remove

```bash
omarchy plugin remove lcavadas.system-monitor
```

## Add to the bar

Add it under `bar.layout` in `~/.config/omarchy/shell.json` (e.g. the `right`
section):

```json
{ "id": "lcavadas.system-monitor" }
```

or use the bar's drag-and-drop / `omarchy bar` commands to place it. The shell
hot-reloads `shell.json`, so no restart is needed for layout changes.

## Requirements

- Linux (reads `/proc/stat`, `/proc/meminfo`, `/proc/net/dev`, `/proc/loadavg`,
  and `df -h /`)
- Omarchy shell (the bar host)

GPU monitoring is best-effort and auto-hidden when unsupported:

- **NVIDIA** via `nvidia-smi` (ships with the driver; no extra install).
- **AMD** via the `amdgpu` sysfs interface (`gpu_busy_percent`,
  `mem_info_vram_*`).
- On hybrid systems the discrete GPU is reported by default. Systems with no
  supported GPU simply don't show a GPU metric in the bar or popup.

## Bar visibility toggles

Each metric card in the dropdown has a small switch in its header (left of the
title) that toggles that metric's visibility on the bar (`CPU`, `Memory` →
`RAM`, `GPU`, `VRAM`, `Network` → `NET`; `Disk` has none). Choices are saved
to `shell.json` and survive restarts.

The same toggles are just inline widget settings, so they can also be set from
the CLI:

```bash
omarchy bar set lcavadas.system-monitor showCpu false
omarchy bar set lcavadas.system-monitor showNet false
```

Keys: `showCpu`, `showRam`, `showGpu`, `showVram`, `showNet` (all default
`true`). GPU and VRAM still auto-hide when no supported GPU is detected,
regardless of their toggle.

## Tuning

- **Poll interval:** `Panel.qml` - the `Timer` `interval` (default `2000` ms).
- **History length:** `Panel.qml` - `historyLength` (default `60` samples).
- **Bar-network value width:** `Panel.qml` - the `NET` metric's `valueWidth`.

## Notes

- Lightweight: CPU, memory, disk and network come from standard Linux
  proc/filesystem reads plus `bash` (a couple of small file reads per poll).
  The only external binary is `nvidia-smi`, used **only** when an NVIDIA GPU is
  detected, and it ships with the driver.
- The `NET` graph only appears in the popup; the bar keeps a compact
  down/up readout.

## License

MIT - see [LICENSE](LICENSE).
