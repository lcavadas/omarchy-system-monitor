# System Monitor - Omarchy bar widget

A live system-monitor bar widget for Omarchy, inspired by iStat Menus: live
history mini-graphs on the bar and richer detail graphs in the dropdown panel.

## What it shows

**On the bar** (compact, iStat-style)
- `CPU` - live mini history graph + current %
- `MEM` - live mini history graph + current %
- `NET` - live download/upload throughput (down / up), colour-coded

**In the dropdown panel** (click the widget)
- `CPU` - history graph, load average, load-level label
- `Memory` - history graph, used / total
- `Network` - combined download/upload **mirror bar chart** (download bars rise,
  upload bars mirror downward)
- `Disk` - used / total

The widget follows the bar foreground, so it darkens correctly on a transparent
bar, and it uses the theme accent/urgent colours on the network graph.

## Install

```bash
omarchy plugin add https://git.mooglest.com/mooglest/omarchy-system-monitor.git
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

## Tuning

- **Poll interval:** `Panel.qml` - the `Timer` `interval` (default `2000` ms).
- **History length:** `Panel.qml` - `historyLength` (default `60` samples).
- **Bar-network value width:** `Panel.qml` - the `NET` metric's `valueWidth`.

## Notes

- No external binaries: all metrics come from standard Linux proc/filesystem
  reads plus `bash`, so the plugin is lightweight (a couple of small file reads
  per poll).
- The `NET` graph only appears in the popup; the bar keeps a compact
  down/up readout.

## License

MIT - see [LICENSE](LICENSE).
