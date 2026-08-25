// System Monitor plugin data helpers.
// The stats command is a single bash pipeline that emits tab-separated
// key/value lines: cpu, memory, disk, networkDown, networkUp, load.
//
// CPU is computed from two /proc/stat snapshots 200ms apart instead of
// shelling out to `top`, which scans the whole process table (~200ms of CPU
// work per poll). A /proc/stat delta is a couple of small file reads, so the
// poll costs well under a millisecond of actual CPU.
//
// Network is also a /proc/net/dev delta over the same 200ms window: rx bytes
// (download) and tx bytes (upload) across non-loopback interfaces, scaled to
// bytes/second.

var statsScript = [
  "snap() { awk '/^cpu / { for (i=2;i<=NF;i++) t += $i; idle = $5 + $6; printf \"%d %d\\n\", t, idle }' /proc/stat; }",
  "netsnap() { awk 'NR>2 && $1!=\"lo:\" && $1 ~ /:$/ {r+=$2; t+=$10} END {printf \"%d %d\", r, t}' /proc/net/dev; }",
  "a=$(snap)",
  "na=$(netsnap)",
  "sleep 0.2",
  "b=$(snap)",
  "nb=$(netsnap)",
  "ta=${a%% *}; ia=${a##* }",
  "tb=${b%% *}; ib=${b##* }",
  "dtotal=$((tb - ta)); didle=$((ib - ia))",
  "if [ \"$dtotal\" -gt 0 ]; then cpu=$(((dtotal - didle) * 100 / dtotal)); else cpu=0; fi",
  "mem=$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END { u=t-a; printf \"%.1fGB / %.0fGB\", u/1024/1024, t/1024/1024 }' /proc/meminfo)",
  "memPct=$(awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END { if (t>0) printf \"%d\", (t-a)*100/t; else printf \"0\" }' /proc/meminfo)",
  "disk=$(df -h / | awk 'NR==2 { printf \"%s / %s\", $3, $2 }')",
  "diskPct=$(df -P / | awk 'NR==2 { gsub(/%/,\"\",$5); print ($5==\"\" ? \"0\" : $5) }')",
  "load=$(awk '{print $1}' /proc/loadavg)",
  "na_rx=${na%% *}; na_tx=${na##* }",
  "nb_rx=${nb%% *}; nb_tx=${nb##* }",
  "downDelta=$((nb_rx - na_rx)); upDelta=$((nb_tx - na_tx))",
  "if [ \"$downDelta\" -lt 0 ]; then downDelta=0; fi",
  "if [ \"$upDelta\" -lt 0 ]; then upDelta=0; fi",
  "netDown=$((downDelta * 5))",
  "netUp=$((upDelta * 5))",
  "netRate=$((netDown + netUp))",
  "printf \"cpu\\t%d%%\\n\" \"$cpu\"",
  "printf \"memory\\t%s\\n\" \"$mem\"",
  "printf \"disk\\t%s\\n\" \"$disk\"",
  "printf \"load\\t%s\\n\" \"$load\"",
  "printf \"memPercent\\t%s\\n\" \"$memPct\"",
  "printf \"diskPercent\\t%s\\n\" \"$diskPct\"",
  "printf \"networkDown\\t%d\\n\" \"$netDown\"",
  "printf \"networkUp\\t%d\\n\" \"$netUp\"",
  "printf \"networkRate\\t%d\\n\" \"$netRate\""
].join("\n")

function parseKeyValue(raw) {
  var next = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var idx = lines[i].indexOf("\t")
    if (idx <= 0) continue
    next[lines[i].substring(0, idx)] = lines[i].substring(idx + 1).trim()
  }
  return next
}

function parsePercent(value) {
  var n = Number(String(value || "").replace("%", ""))
  return isFinite(n) ? n : 0
}

function cpuLabel(percent) {
  var p = Math.round(percent)
  if (p >= 90) return "Critical"
  if (p >= 70) return "Heavy load"
  if (p >= 40) return "Moderate"
  if (p >= 10) return "Steady"
  return "Idle"
}

function formatRate(bps) {
  var n = Number(bps)
  if (!isFinite(n) || n < 0) n = 0
  if (n >= 1048576) return (n / 1048576).toFixed(1) + " MB/s"
  if (n >= 1024) return Math.round(n / 1024) + " KB/s"
  return Math.round(n) + " B/s"
}

function formatRateShort(bps) {
  var n = Number(bps)
  if (!isFinite(n) || n < 0) n = 0
  if (n >= 1048576) return (n / 1048576).toFixed(1) + "M"
  if (n >= 1024) return Math.round(n / 1024) + "K"
  return Math.round(n) + "B"
}

if (typeof module !== "undefined") {
  module.exports = {
    statsScript: statsScript,
    parseKeyValue: parseKeyValue,
    parsePercent: parsePercent,
    cpuLabel: cpuLabel,
    formatRate: formatRate,
    formatRateShort: formatRateShort
  }
}
