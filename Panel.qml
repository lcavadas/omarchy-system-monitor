import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "lcavadas.system-monitor"
  ipcTarget: "lcavadas.system-monitor"

  // Live system snapshot, refreshed by the poll timer.
  property real cpuPercent: 0
  property int memPercent: 0
  property int diskPercent: 0
  property real netRate: 0
  property real netDown: 0
  property real netUp: 0
  property string memoryLabel: ""
  property string diskLabel: ""
  property string loadAvg: ""
  property int gpuPercent: 0
  property int gpuMemPercent: 0
  property string gpuName: ""
  property string gpuMemLabel: ""
  property bool gpuAvailable: false
  property bool hasData: false

  // Bar metric visibility. Persisted to shell.json via the host shell, so
  // these survive a restart and are editable with `omarchy bar set`.
  property bool showCpu: true
  property bool showRam: true
  property bool showGpu: true
  property bool showVram: true
  property bool showNet: true

  // Rolling history for the sparklines. Every sample is appended to a fresh
  // array (never mutated in place) so QML change signals fire and every
  // Canvas repaints on the next sample.
  property int historyLength: 60
  property var cpuHistory: []
  property var memHistory: []
  property var diskHistory: []
  property var netDownHistory: []
  property var netUpHistory: []
  property var gpuHistory: []
  property var gpuMemHistory: []

  // Defensive color/typography resolvers so content renders correctly even
  // before the bar binding lands (mirrors how the power panel reads these).
  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property color fgDim: Qt.darker(root.fg, 1.4)
  readonly property string fontFam: root.bar ? root.bar.fontFamily : Style.font.family

  // Bar content follows the bar's dynamic foreground so it adapts when the
  // bar is transparent: Omarchy swaps `barForeground` to a contrast colour
  // (e.g. black) so the other bar icons change too. The popup surface is
  // opaque, so popup content keeps the static light foreground below.
  readonly property color barFg: root.bar ? root.bar.barForeground : Color.foreground
  readonly property color barFgDim: Qt.darker(root.barFg, 1.4)

  implicitWidth: barRow.implicitWidth
  implicitHeight: root.bar ? root.bar.barSize : Style.bar.sizeHorizontal

  function refresh() {
    if (!statsProc.running) statsProc.running = true
  }

  function pushSample(history, value) {
    var next = (history || []).concat([value])
    if (next.length > historyLength) next = next.slice(next.length - historyLength)
    return next
  }

  function loadBarVisibility() {
    showCpu = setting("showCpu", true)
    showRam = setting("showRam", true)
    showGpu = setting("showGpu", true)
    showVram = setting("showVram", true)
    showNet = setting("showNet", true)
  }

  function setBarMetric(key, value) {
    if (key === "showCpu") showCpu = value
    else if (key === "showRam") showRam = value
    else if (key === "showGpu") showGpu = value
    else if (key === "showVram") showVram = value
    else if (key === "showNet") showNet = value
    persistBarVisibility()
  }

  function persistBarVisibility() {
    if (!root.bar || !root.bar.shell || typeof root.bar.shell.updateEntryInline !== "function") return
    var next = {}
    var s = root.settings || {}
    for (var k in s) if (Object.prototype.hasOwnProperty.call(s, k)) next[k] = s[k]
    next.showCpu = showCpu
    next.showRam = showRam
    next.showGpu = showGpu
    next.showVram = showVram
    next.showNet = showNet
    root.bar.shell.updateEntryInline(root.moduleName, next)
  }

  Component.onCompleted: loadBarVisibility()
  onSettingsChanged: loadBarVisibility()

  function updateStats(raw) {
    var next = Model.parseKeyValue(raw)
    if (Object.keys(next).length === 0) return
    cpuPercent = Model.parsePercent(next.cpu)
    memPercent = Model.parsePercent(next.memPercent)
    diskPercent = Model.parsePercent(next.diskPercent)
    netRate = Model.parsePercent(next.networkRate)
    netDown = Model.parsePercent(next.networkDown)
    netUp = Model.parsePercent(next.networkUp)
    memoryLabel = next.memory || ""
    diskLabel = next.disk || ""
    loadAvg = next.load || ""
    gpuAvailable = next.gpuAvailable === "1"
    gpuPercent = Model.parsePercent(next.gpuPercent)
    gpuMemPercent = Model.parsePercent(next.gpuMemPercent)
    gpuName = next.gpuName || ""
    gpuMemLabel = next.gpuMemLabel || ""
    cpuHistory = pushSample(cpuHistory, cpuPercent)
    memHistory = pushSample(memHistory, memPercent)
    diskHistory = pushSample(diskHistory, diskPercent)
    netDownHistory = pushSample(netDownHistory, netDown)
    netUpHistory = pushSample(netUpHistory, netUp)
    gpuHistory = pushSample(gpuHistory, gpuPercent)
    gpuMemHistory = pushSample(gpuMemHistory, gpuMemPercent)
    hasData = true
  }

  readonly property color cpuBarColor: {
    if (cpuPercent >= 85) return Color.urgent
    if (cpuPercent >= 60) return Color.accent
    return Color.foreground
  }
  readonly property color memBarColor: {
    if (memPercent >= 85) return Color.urgent
    if (memPercent >= 60) return Color.accent
    return Color.foreground
  }
  readonly property color diskBarColor: Color.foreground
  readonly property color gpuBarColor: {
    if (gpuPercent >= 85) return Color.urgent
    if (gpuPercent >= 60) return Color.accent
    return Color.foreground
  }
  readonly property color vramBarColor: {
    if (gpuMemPercent >= 85) return Color.urgent
    if (gpuMemPercent >= 60) return Color.accent
    return Color.foreground
  }

  // Bar-only graph/readout colours: default to the dynamic bar foreground so
  // the bar widget matches the other icons when the bar is transparent.
  readonly property color barCpuColor: {
    if (cpuPercent >= 85) return Color.urgent
    if (cpuPercent >= 60) return Color.accent
    return root.barFg
  }
  readonly property color barMemColor: {
    if (memPercent >= 85) return Color.urgent
    if (memPercent >= 60) return Color.accent
    return root.barFg
  }
  readonly property color barNetColor: root.barFg
  readonly property color barDiskColor: root.barFg
  readonly property color barGpuColor: {
    if (gpuPercent >= 85) return Color.urgent
    if (gpuPercent >= 60) return Color.accent
    return root.barFg
  }
  readonly property color barVramColor: {
    if (gpuMemPercent >= 85) return Color.urgent
    if (gpuMemPercent >= 60) return Color.accent
    return root.barFg
  }

  Process {
    id: statsProc
    command: ["bash", "-c", Model.statsScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateStats(text)
    }
  }

  // Continuous poll keeps the bar mini-graphs and popup live. 2s interval;
  // each poll is a ~1ms /proc/stat delta.
  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onOpenedChanged: if (root.opened) root.refresh()

  // ---- Bar button: tiny labels + live mini-graphs + values for CPU / memory
  //      / network / disk. Network's graph auto-scales to its recent peak;
  //      disk has no graph. Custom MouseArea (no hover tooltip).
  Item {
    id: button
    anchors.fill: parent

    Row {
      id: barRow
      anchors.centerIn: parent
      spacing: Style.space(8)

      BarMetric {
        label: "CPU"
        value: Math.round(root.cpuPercent) + "%"
        samples: root.cpuHistory
        accent: root.barCpuColor
        maxPoints: 24
        visible: root.showCpu
      }
      BarMetric {
        label: "RAM"
        value: Math.round(root.memPercent) + "%"
        samples: root.memHistory
        accent: root.barMemColor
        maxPoints: 24
        visible: root.showRam
      }
      BarMetric {
        label: "GPU"
        value: root.gpuAvailable ? Math.round(root.gpuPercent) + "%" : ""
        samples: root.gpuHistory
        accent: root.barGpuColor
        maxPoints: 24
        visible: root.showGpu && root.gpuAvailable
      }
      BarMetric {
        label: "VRAM"
        value: root.gpuAvailable ? Math.round(root.gpuMemPercent) + "%" : ""
        samples: root.gpuMemHistory
        accent: root.barVramColor
        maxPoints: 24
        showGraph: false
        visible: root.showVram && root.gpuAvailable
      }
      BarMetric {
        label: "NET"
        samples: root.netDownHistory
        samples2: root.netUpHistory
        accent: Color.accent
        accent2: Color.urgent
        maxPoints: 24
        autoScale: true
        showGraph: false
        valueLeft: root.hasData ? "\u2193 " + Model.formatRateShort(root.netDown) : "\u2193"
        valueRight: root.hasData ? "\u2191 " + Model.formatRateShort(root.netUp) : "\u2191"
        leftColor: root.barFg
        rightColor: root.barFg
        valueWidth: Style.space(50)
        visible: root.showNet
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) root.refresh()
        else root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") root.refresh() }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        MetricCard {
          title: "CPU"
          percent: root.cpuPercent
          samples: root.cpuHistory
          accent: root.cpuBarColor
          showGraph: true
          detail: root.hasData ? Model.cpuLabel(root.cpuPercent).toUpperCase() : "—"
          subDetail: root.hasData ? "LOAD " + root.loadAvg : ""
        }

        PanelSeparator { foreground: root.fg }

        MetricCard {
          title: "Memory"
          percent: root.memPercent
          samples: root.memHistory
          accent: root.memBarColor
          showGraph: true
          detail: root.hasData ? root.memoryLabel : "—"
          subDetail: ""
        }

        // GPU card + its separator are wrapped so both hide together on
        // machines with no supported GPU (no dangling divider in the popup).
        Column {
          visible: root.gpuAvailable
          width: parent.width
          spacing: Style.space(14)
          PanelSeparator { foreground: root.fg }
          MetricCard {
            title: "GPU"
            percent: root.gpuPercent
            samples: root.gpuHistory
            accent: root.gpuBarColor
            showGraph: true
            detail: root.gpuName || "GPU"
            subDetail: ""
          }
          PanelSeparator { foreground: root.fg }
          MetricCard {
            title: "VRAM"
            percent: root.gpuMemPercent
            samples: root.gpuMemHistory
            accent: root.vramBarColor
            showGraph: true
            detail: root.gpuMemLabel
            subDetail: ""
          }
        }

        PanelSeparator { foreground: root.fg }

        MetricCard {
          title: "Network"
          percent: root.netRate
          samples: root.netDownHistory
          samples2: root.netUpHistory
          accent: Color.accent
          accent2: Color.urgent
          showGraph: true
          autoScale: true
          chartType: "bar"
          valueText: ""
          valueLeft: root.hasData ? "\u2193 " + Model.formatRate(root.netDown) : "\u2193"
          valueRight: root.hasData ? "\u2191 " + Model.formatRate(root.netUp) : "\u2191"
          leftColor: Color.accent
          rightColor: Color.urgent
          detail: ""
          subDetail: ""
        }

        PanelSeparator { foreground: root.fg }

        MetricCard {
          title: "Disk"
          percent: root.diskPercent
          samples: root.diskHistory
          accent: root.fg
          showGraph: false
          detail: root.hasData ? root.diskLabel : "—"
          subDetail: ""
        }

        PanelSeparator { foreground: root.fg }

        PanelSectionHeader {
          text: "BAR"
          foreground: root.fg
          fontFamily: root.fontFam
        }

        Toggle {
          width: parent.width
          label: "CPU"
          checked: root.showCpu
          foreground: root.fg
          fontFamily: root.fontFam
          onClicked: root.setBarMetric("showCpu", !root.showCpu)
        }
        Toggle {
          width: parent.width
          label: "RAM"
          checked: root.showRam
          foreground: root.fg
          fontFamily: root.fontFam
          onClicked: root.setBarMetric("showRam", !root.showRam)
        }
        Toggle {
          width: parent.width
          label: "GPU"
          checked: root.showGpu
          foreground: root.fg
          fontFamily: root.fontFam
          onClicked: root.setBarMetric("showGpu", !root.showGpu)
        }
        Toggle {
          width: parent.width
          label: "VRAM"
          checked: root.showVram
          foreground: root.fg
          fontFamily: root.fontFam
          onClicked: root.setBarMetric("showVram", !root.showVram)
        }
        Toggle {
          width: parent.width
          label: "NET"
          checked: root.showNet
          foreground: root.fg
          fontFamily: root.fontFam
          onClicked: root.setBarMetric("showNet", !root.showNet)
        }
      }
    }
  }

  // ---- Bar mini metric: tiny label + optional live graph + value. ----
  component BarMetric: Row {
    id: bm
    required property string label
    property string value: ""
    required property var samples
    property var samples2: null
    property color accent: root.fg
    property color accent2: root.barFgDim
    property int maxPoints: 24
    property bool autoScale: false
    property bool showGraph: true
    // Optional two-colour value (e.g. network ?/?). When valueLeft is set it
    // renders two coloured Texts instead of the single `value`.
    property string valueLeft: ""
    property string valueRight: ""
    property color leftColor: bm.accent
    property color rightColor: bm.accent2
    // Fixed width for the value text(s) so the bar doesn't reflow as the
    // numbers/units change. 0 = auto (naturally sized).
    property real valueWidth: 0

    spacing: Style.space(4)
    // Keep every metric the same height (graph metrics) so a graph-less metric
    // like NET lines up vertically with the rest instead of top-aligning.
    height: Style.space(16)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: bm.label
      color: root.barFgDim
      font.family: root.fontFam
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 0.8
    }

    SparkGraph {
      visible: bm.showGraph
      width: Style.space(26)
      height: Style.space(16)
      samples: bm.samples
      samples2: bm.samples2
      accent: bm.accent
      accent2: bm.accent2
      maxPoints: bm.maxPoints
      fillAlpha: 0.72
      autoScale: bm.autoScale
    }

    Row {
      visible: bm.valueLeft !== ""
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: bm.valueLeft
        color: bm.leftColor
        font.family: root.fontFam
        font.pixelSize: Style.font.caption
        font.bold: true
        width: bm.valueWidth > 0 ? bm.valueWidth : implicitWidth
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideNone
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: bm.valueRight
        color: bm.rightColor
        font.family: root.fontFam
        font.pixelSize: Style.font.caption
        font.bold: true
        width: bm.valueWidth > 0 ? bm.valueWidth : implicitWidth
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideNone
      }
    }

    Text {
      visible: bm.valueLeft === ""
      anchors.verticalCenter: parent.verticalCenter
      text: bm.value
      color: bm.accent
      font.family: root.fontFam
      font.pixelSize: Style.font.caption
      font.bold: true
      width: bm.valueWidth > 0 ? bm.valueWidth : implicitWidth
      horizontalAlignment: Text.AlignHCenter
    }
  }

  // ---- Popup metric card: header + optional live graph + detail. ----
  component MetricCard: Column {
    id: card
    required property string title
    required property real percent
    required property var samples
    property var samples2: null
    property string detail: ""
    property string subDetail: ""
    property string valueText: ""
    property string valueLeft: ""
    property string valueRight: ""
    property color leftColor: card.accent
    property color rightColor: card.accent2
    property color accent: root.fg
    property color accent2: root.fgDim
    property bool showGraph: true
    property bool autoScale: false
    property string chartType: "area"

    width: parent.width
    spacing: Style.space(6)

    // Header: Omarchy section label left, live value right (iStat-style).
    Item {
      width: parent.width
      implicitHeight: Math.max(titleText.implicitHeight, percentText.implicitHeight)

      PanelSectionHeader {
        id: titleText
        text: card.title.toUpperCase()
        foreground: root.fg
        fontFamily: root.fontFam
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Row {
        visible: card.valueLeft !== ""
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)
        Text {
          text: card.valueLeft
          color: card.leftColor
          font.family: root.fontFam
          font.pixelSize: Style.font.title
          font.bold: true
        }
        Text {
          text: card.valueRight
          color: card.rightColor
          font.family: root.fontFam
          font.pixelSize: Style.font.title
          font.bold: true
        }
      }

      Text {
        id: percentText
        visible: card.valueLeft === ""
        text: card.valueText !== "" ? card.valueText : Math.round(card.percent) + "%"
        color: card.accent
        font.family: root.fontFam
        font.pixelSize: Style.font.title
        font.bold: true
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    // Live history graph; hidden for metrics that don't need one (disk).
    SparkGraph {
      width: parent.width
      height: Style.space(44)
      samples: card.samples
      samples2: card.samples2
      accent: card.accent
      accent2: card.accent2
      maxPoints: 60
      visible: card.showGraph && card.chartType === "area"
      autoScale: card.autoScale
    }

    NetworkBarChart {
      width: parent.width
      height: Style.space(44)
      downSamples: card.samples
      upSamples: card.samples2
      downColor: card.accent
      upColor: card.accent2
      maxPoints: 60
      visible: card.showGraph && card.chartType === "bar"
    }

    // Detail row: primary label left, secondary value right.
    Row {
      width: parent.width
      spacing: Style.space(8)

      Text {
        id: detailText
        text: card.detail
        color: root.fg
        opacity: 0.6
        font.family: root.fontFam
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        width: card.subDetail !== ""
          ? parent.width - subDetailText.implicitWidth - parent.spacing
          : parent.width
      }

      Text {
        id: subDetailText
        text: card.subDetail
        color: root.fgDim
        font.family: root.fontFam
        font.pixelSize: Style.font.bodySmall
        visible: card.subDetail !== ""
      }
    }
  }

  // ---- Reusable area-fill sparkline. Auto-scales to its recent peak when
  //      `autoScale` is set (used for network throughput). ----
  // ---- Reusable area-fill sparkline. Auto-scales to its recent peak when
  //      `autoScale` is set (used for network throughput). Optionally draws a
  //      second series (`samples2`, e.g. upload) as a line-only series so
  //      download and upload can be compared in one graph. ----
  component SparkGraph: Canvas {
    id: sg
    required property var samples
    property var samples2: null
    property color accent: root.fg
    property color accent2: Qt.darker(root.fg, 1.4)
    property int maxPoints: 60
    property bool autoScale: false
    // Area fill opacity under the line. Bar mini-graphs use a strong fill;
    // the popup preview uses a lighter one.
    property real fillAlpha: 0.32
    antialiasing: true

    onSamplesChanged: requestPaint()
    onSamples2Changed: requestPaint()
    onAccentChanged: requestPaint()
    onAccent2Changed: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onAutoScaleChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)

      var a = sg.samples || []
      var b = sg.samples2 || []
      if (a.length > sg.maxPoints) a = a.slice(a.length - sg.maxPoints)
      if (b.length > sg.maxPoints) b = b.slice(b.length - sg.maxPoints)
      if (a.length < 2) return

      var w = width
      var h = height
      var pad = 1

      var max = 100
      if (sg.autoScale) {
        max = 0
        for (var i = 0; i < a.length; i++) if (a[i] > max) max = a[i]
        for (var j = 0; j < b.length; j++) if (b[j] > max) max = b[j]
        if (max <= 0) max = 1
      }

      function yAt(data, value) {
        var t = value < 0 ? 0 : value
        var pct = sg.autoScale ? (t / max) * 100 : (t > 100 ? 100 : t)
        return h - pad - (pct / 100) * (h - pad * 2)
      }

      function strokeSeries(data, color, doFill, n) {
        if (n < 2) return
        ctx.beginPath()
        for (var i = 0; i < n; i++) {
          var x = (i / (n - 1)) * w
          var y = yAt(data, data[i])
          if (i === 0) ctx.moveTo(x, y)
          else ctx.lineTo(x, y)
        }
        ctx.strokeStyle = color
        ctx.lineWidth = 1.5
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.stroke()
        if (doFill) {
          ctx.lineTo(w, h - pad)
          ctx.lineTo(0, h - pad)
          ctx.closePath()
          ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, sg.fillAlpha)
          ctx.fill()
        }
      }

      strokeSeries(a, sg.accent, true, a.length)
      strokeSeries(b, sg.accent2, false, b.length)
    }
  }

  // ---- Combined mirror bar chart (iStat-style) for network: download bars
  //      rise from the centre line, upload bars mirror downward; auto-scaled. ----
  component NetworkBarChart: Canvas {
    id: nb
    required property var downSamples
    required property var upSamples
    property color downColor: Color.accent
    property color upColor: Color.urgent
    property int maxPoints: 60
    antialiasing: true

    onDownSamplesChanged: requestPaint()
    onUpSamplesChanged: requestPaint()
    onDownColorChanged: requestPaint()
    onUpColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)

      var d = nb.downSamples || []
      var u = nb.upSamples || []
      if (d.length > nb.maxPoints) d = d.slice(d.length - nb.maxPoints)
      if (u.length > nb.maxPoints) u = u.slice(u.length - nb.maxPoints)

      var n = Math.max(d.length, u.length)
      var w = width
      var h = height
      var mid = h / 2
      var max = 0
      for (var i = 0; i < d.length; i++) if (d[i] > max) max = d[i]
      for (var j = 0; j < u.length; j++) if (u[j] > max) max = u[j]
      if (max <= 0) max = 1

      var slot = n > 0 ? w / n : w
      var barW = Math.max(1, slot * 0.62)
      var half = mid - 1

      for (var i = 0; i < n; i++) {
        var cx = i * slot + slot / 2
        if (i < d.length) {
          var up = (d[i] / max) * half
          if (up >= 0.5) {
            ctx.fillStyle = nb.downColor
            ctx.fillRect(cx - barW / 2, mid - up, barW, up)
          }
        }
        if (i < u.length) {
          var down = (u[i] / max) * half
          if (down >= 0.5) {
            ctx.fillStyle = nb.upColor
            ctx.fillRect(cx - barW / 2, mid, barW, down)
          }
        }
      }

      ctx.fillStyle = Qt.rgba(nb.downColor.r, nb.downColor.g, nb.downColor.b, 0.4)
      ctx.fillRect(0, mid - 0.5, w, 1)
    }
  }
}