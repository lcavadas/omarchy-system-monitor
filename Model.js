// System Monitor plugin data helpers.
// The stats command emits a small, tab-separated, finite schema. It is run with
// a cleared environment and only invokes explicitly named system binaries.

var statsScript = [
  "set -u",
  "AWK=/usr/bin/awk; SLEEP=/usr/bin/sleep; DF=/usr/bin/df; HEAD=/usr/bin/head",
  "NVIDIA_SMI=/usr/bin/nvidia-smi; [ -x \"$NVIDIA_SMI\" ] || NVIDIA_SMI=/bin/false",
  "snap() { \"$AWK\" '/^cpu / { for (i=2;i<=NF;i++) t += $i; idle = $5 + $6; printf \"%d %d\\n\", t, idle }' /proc/stat; }",
  "netsnap() { \"$AWK\" 'NR>2 && $1!=\"lo:\" && $1 ~ /:$/ {r+=$2; t+=$10} END {printf \"%d %d\", r, t}' /proc/net/dev; }",
  "a=$(snap); na=$(netsnap); \"$SLEEP\" 0.2; b=$(snap); nb=$(netsnap)",
  "ta=${a%% *}; ia=${a##* }; tb=${b%% *}; ib=${b##* }",
  "dtotal=$((tb - ta)); didle=$((ib - ia))",
  "if [ \"$dtotal\" -gt 0 ]; then cpu=$(((dtotal - didle) * 100 / dtotal)); else cpu=0; fi",
  "mem=$(\"$AWK\" '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END { u=t-a; printf \"%.1fGB / %.0fGB\", u/1024/1024, t/1024/1024 }' /proc/meminfo)",
  "memPct=$(\"$AWK\" '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END { if (t>0) printf \"%d\", (t-a)*100/t; else printf \"0\" }' /proc/meminfo)",
  "disk=$(\"$DF\" -h / | \"$AWK\" 'NR==2 { printf \"%.60s / %.60s\", $3, $2 }')",
  "diskPct=$(\"$DF\" -P / | \"$AWK\" 'NR==2 { gsub(/%/,\"\",$5); print ($5==\"\" ? \"0\" : $5) }')",
  "load=$(\"$AWK\" '{print $1}' /proc/loadavg)",
  "na_rx=${na%% *}; na_tx=${na##* }; nb_rx=${nb%% *}; nb_tx=${nb##* }",
  "downDelta=$((nb_rx - na_rx)); upDelta=$((nb_tx - na_tx))",
  "if [ \"$downDelta\" -lt 0 ]; then downDelta=0; fi; if [ \"$upDelta\" -lt 0 ]; then upDelta=0; fi",
  "netDown=$((downDelta * 5)); netUp=$((upDelta * 5)); netRate=$((netDown + netUp))",
  "gpuAvailable=0; gpuPercent=0; gpuName=\"\"; gpuMemLabel=\"\"; gpuMemPercent=0",
  "if [ -x \"$NVIDIA_SMI\" ]; then",
  "  gpuLine=$(\"$NVIDIA_SMI\" --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | \"$HEAD\" -c 512)",
  "  IFS=, read -r gpuName gpuPercent gpuMemUsed gpuMemTotal _ <<EOF",
  "${gpuLine}",
  "EOF",
  "  gpuName=$(printf '%s' \"$gpuName\" | \"$AWK\" '{$1=$1; print}')",
  "  gpuPercent=$(printf '%s' \"$gpuPercent\" | \"$AWK\" '{$1=$1; print}')",
  "  gpuMemUsed=$(printf '%s' \"$gpuMemUsed\" | \"$AWK\" '{$1=$1; print}')",
  "  gpuMemTotal=$(printf '%s' \"$gpuMemTotal\" | \"$AWK\" '{$1=$1; print}')",
  "  if [[ \"$gpuName\" =~ ^[[:print:]]{1,128}$ && \"$gpuPercent\" =~ ^[0-9]+$ && \"$gpuMemUsed\" =~ ^[0-9]+$ && \"$gpuMemTotal\" =~ ^[1-9][0-9]*$ ]]; then",
  "    gpuMemLabel=$(\"$AWK\" -v u=\"$gpuMemUsed\" -v t=\"$gpuMemTotal\" 'BEGIN { printf \"%.1f GiB / %.1f GiB\", u/1024, t/1024 }')",
  "    gpuMemPercent=$(( gpuMemUsed * 100 / gpuMemTotal )); gpuAvailable=1",
  "  fi",
  "fi",
  "if [ \"$gpuAvailable\" -eq 0 ]; then",
  "  best=\"\"; bestMem=0",
  "  for _d in /sys/class/drm/card*/device; do",
  "    [ -f \"$_d/gpu_busy_percent\" ] || continue; mt=0; read -r mt < \"$_d/mem_info_vram_total\" || mt=0",
  "    [[ \"$mt\" =~ ^[0-9]+$ ]] || continue; if [ \"$mt\" -gt \"$bestMem\" ]; then bestMem=$mt; best=\"$_d\"; fi",
  "  done",
  "  if [ -n \"$best\" ]; then",
  "    gpuPercent=0; gpuMemUsed=0; gpuMemTotal=0; read -r gpuPercent < \"$best/gpu_busy_percent\" || true; read -r gpuMemUsed < \"$best/mem_info_vram_used\" || true; read -r gpuMemTotal < \"$best/mem_info_vram_total\" || true",
  "    if [[ \"$gpuPercent\" =~ ^[0-9]+$ && \"$gpuMemUsed\" =~ ^[0-9]+$ && \"$gpuMemTotal\" =~ ^[1-9][0-9]*$ ]]; then",
  "      gpuName=\"AMD GPU\"; gpuMemLabel=$(\"$AWK\" -v u=\"$gpuMemUsed\" -v t=\"$gpuMemTotal\" 'BEGIN { printf \"%.1f GiB / %.1f GiB\", u/1073741824, t/1073741824 }'); gpuMemPercent=$(( gpuMemUsed * 100 / gpuMemTotal )); gpuAvailable=1",
  "    fi",
  "  fi",
  "fi",
  "printf \"gpuAvailable\\t%d\\n\" \"$gpuAvailable\"; printf \"gpuPercent\\t%d\\n\" \"$gpuPercent\"; printf \"gpuName\\t%s\\n\" \"$gpuName\"; printf \"gpuMemLabel\\t%s\\n\" \"$gpuMemLabel\"; printf \"gpuMemPercent\\t%d\\n\" \"$gpuMemPercent\"",
  "printf \"cpu\\t%d%%\\n\" \"$cpu\"; printf \"memory\\t%s\\n\" \"$mem\"; printf \"disk\\t%s\\n\" \"$disk\"; printf \"load\\t%s\\n\" \"$load\"; printf \"memPercent\\t%s\\n\" \"$memPct\"; printf \"diskPercent\\t%s\\n\" \"$diskPct\"; printf \"networkDown\\t%d\\n\" \"$netDown\"; printf \"networkUp\\t%d\\n\" \"$netUp\"; printf \"networkRate\\t%d\\n\" \"$netRate\""
].join("\n")

var statsKeys = ["gpuAvailable", "gpuPercent", "gpuName", "gpuMemLabel", "gpuMemPercent", "cpu", "memory", "disk", "load", "memPercent", "diskPercent", "networkDown", "networkUp", "networkRate"]

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

function isUnsigned(value, max) {
  return /^\d{1,15}$/.test(value) && Number(value) <= max
}

function isPercent(value) {
  return isUnsigned(value, 100)
}

function isValidStats(raw) {
  raw = String(raw || "")
  if (raw.length === 0 || raw.length > 4096) return false
  var lines = raw.split("\n")
  var seen = {}
  for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
    if (lines[lineIndex] === "" && lineIndex === lines.length - 1) continue
    var tabIndex = lines[lineIndex].indexOf("\t")
    if (tabIndex <= 0) return false
    var key = lines[lineIndex].substring(0, tabIndex)
    if (seen[key]) return false
    seen[key] = true
  }
  var next = parseKeyValue(raw)
  if (Object.keys(next).length !== statsKeys.length) return false
  for (var i = 0; i < statsKeys.length; i++) if (!Object.prototype.hasOwnProperty.call(next, statsKeys[i])) return false
  return /^(0|1)$/.test(next.gpuAvailable)
    && isPercent(next.gpuPercent) && isPercent(next.gpuMemPercent) && isPercent(next.memPercent)
    && isPercent(next.diskPercent) && /^\d{1,3}%$/.test(next.cpu)
    && isUnsigned(next.networkDown, 999999999999999) && isUnsigned(next.networkUp, 999999999999999)
    && isUnsigned(next.networkRate, 999999999999999) && /^\d+(\.\d+)?$/.test(next.load)
    && /^[\d.]+GB \/ [\d.]+GB$/.test(next.memory) && next.disk.length <= 128
    && /^[\x20-\x7e]{0,128}$/.test(next.gpuName) && /^[\x20-\x7e]{0,64}$/.test(next.gpuMemLabel)
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

function gpuLabel(percent) { return cpuLabel(percent) }

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
  module.exports = { statsScript: statsScript, parseKeyValue: parseKeyValue, isValidStats: isValidStats, parsePercent: parsePercent, cpuLabel: cpuLabel, gpuLabel: gpuLabel, formatRate: formatRate, formatRateShort: formatRateShort }
}
