const assert = require("assert")
const fs = require("fs")
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

console.log("Model schema tests passed")
