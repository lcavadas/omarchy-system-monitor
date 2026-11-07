const assert = require("assert")
const { execFileSync } = require("child_process")
const fs = require("fs")
const os = require("os")
const path = require("path")
const Model = require("./Model.js")

const panel = fs.readFileSync("./Panel.qml", "utf8")
assert.strictEqual(panel.includes('"--foreground"'), false)
assert.strictEqual(panel.includes('"--kill-after=0.25s"'), true)

const valid = [
  "gpuAvailable\t1",
  "gpuPercent\t12",
  "gpuName\tExample GPU",
  "gpuMemLabel\t1.0 GiB / 8.0 GiB",
  "gpuMemPercent\t13",
  "cpu\t42%",
  "memory\t4.0GB / 16GB",
  "disk\t20G / 100G",
  "load\t0.25",
  "memPercent\t25",
  "diskPercent\t20",
  "networkDown\t1024",
  "networkUp\t512",
  "networkRate\t1536"
].join("\n") + "\n"

assert.strictEqual(Model.isValidStats(valid), true)
assert.strictEqual(Model.isValidStats(valid.replace("cpu\t42%", "cpu\tnan")), false)
assert.strictEqual(Model.isValidStats(valid + "unknown\tvalue\n"), false)
assert.strictEqual(Model.isValidStats("x".repeat(4097)), false)
assert.strictEqual(Model.isValidStats(valid.replace("gpuName\tExample GPU", "gpuName\tbad\nname")), false)

// Run the real collector against a stubbed nvidia-smi and amdgpu sysfs tree.
function collect(nvidiaLine, amd) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "system-monitor-test-"))
  try {
    const smi = path.join(root, "nvidia-smi")
    if (nvidiaLine) fs.writeFileSync(smi, `#!/bin/bash\necho '${nvidiaLine}'\n`, { mode: 0o755 })
    if (amd) {
      const device = path.join(root, "drm", "card2", "device")
      fs.mkdirSync(device, { recursive: true })
      fs.writeFileSync(path.join(device, "gpu_busy_percent"), `${amd.busy}\n`)
      fs.writeFileSync(path.join(device, "mem_info_vram_used"), `${amd.used}\n`)
      fs.writeFileSync(path.join(device, "mem_info_vram_total"), `${amd.total}\n`)
    }
    const script = Model.statsScript
      .replace("NVIDIA_SMI=/usr/bin/nvidia-smi", `NVIDIA_SMI=${smi}`)
      .replace("/sys/class/drm/card*/device", path.join(root, "drm", "card*", "device"))
    const stdout = execFileSync("/bin/bash", ["-c", script], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] })
    assert.strictEqual(Model.isValidStats(stdout), true)
    return Model.parseKeyValue(stdout)
  } finally {
    fs.rmSync(root, { recursive: true, force: true })
  }
}

const dgpuIdle = "Test NVIDIA, 0, 5, 4096"
const dgpuBusy = "Test NVIDIA, 90, 2048, 4096"
const igpu = { busy: 5, used: 268435456, total: 536870912 }

// The bug: an idle dGPU must not hide the iGPU that is drawing the desktop.
let stats = collect(dgpuIdle, igpu)
assert.strictEqual(stats.gpuName, "AMD GPU")
assert.strictEqual(stats.gpuPercent, "5")
assert.strictEqual(stats.gpuMemPercent, "50")

stats = collect(dgpuBusy, igpu)
assert.strictEqual(stats.gpuName, "Test NVIDIA")
assert.strictEqual(stats.gpuPercent, "90")
assert.strictEqual(stats.gpuMemPercent, "50")

// Both idle stays on the iGPU, so the panel doesn't flip between them.
assert.strictEqual(collect(dgpuIdle, { ...igpu, busy: 0 }).gpuName, "AMD GPU")

assert.strictEqual(collect(null, igpu).gpuName, "AMD GPU")
assert.strictEqual(collect(dgpuIdle, null).gpuName, "Test NVIDIA")
assert.strictEqual(collect(null, null).gpuAvailable, "0")

console.log("Model schema tests passed")
