
import fidget, proffy, tables, chroma, vmath, strformat, hashes, sequtils, algorithm, strutils

const
  TURQUOISE1 = "#1ABC9C".parseHtmlColor
  TURQUOISE2 = "#16A085".parseHtmlColor
  GREEN1 = "#2ECC71".parseHtmlColor
  GREEN2 = "#27AE60".parseHtmlColor
  BLUE1 = "#3498DB".parseHtmlColor
  BLUE2 = "#2980B9".parseHtmlColor
  PURPLE1 = "#9B59B6".parseHtmlColor
  PURPLE2 = "#8E44AD".parseHtmlColor
  DARK1 = "#34495E".parseHtmlColor
  DARK2 = "#2C3E50".parseHtmlColor
  YELLOW1 = "#F1C40F".parseHtmlColor
  YELLOW2 = "#F39C12".parseHtmlColor
  ORANGE1 = "#E67E22".parseHtmlColor
  ORANGE2 = "#D35400".parseHtmlColor
  RED1 = "#E74C3C".parseHtmlColor
  RED2 = "#C0392B".parseHtmlColor
  WHITE1 = "#ECF0F1".parseHtmlColor
  WHITE2 = "#BDC3C7".parseHtmlColor
  GRAY1 = "#95A5A6".parseHtmlColor
  GRAY2 = "#7F8C8D".parseHtmlColor

  WHITE = "#FFFFFF".parseHtmlColor
  BLACK = "#000000".parseHtmlColor
  NIMBG = "#171921".parseHtmlColor

  colors = [
    TURQUOISE1,
    BLUE1,
    PURPLE1,
    YELLOW1,
    ORANGE1,
    RED1,
  ]

proc hasPrefix(a, b: string): bool =
  a.len >= b.len and a[0 ..< b.len] == b


type
  ViewKind = enum
    TimelineView
    TreeView

  Stats = ref object
    num: int
    avg: float
    avgSelf: float
    min: int64
    max: int64
    total: int64
    totalSelf: int64

var
  statistics: Table[int, Stats]
  statisticsTree: Table[string, Stats]
proc computeStats() =
  # Compute Statistics
  for profile in profiles:
    for traceId, trace in profile.traces:
      let time = trace.timeEnd - trace.timeStart
      if trace.nameKey notin statistics:
        statistics[trace.nameKey] = Stats()
        statistics[trace.nameKey].min = time
      var s = statistics[trace.nameKey]
      s.total += time
      inc s.num
      s.min = min(s.min, time)
      s.max = max(s.max, time)
  for i, s in statistics:
    s.avg = s.total.float / s.num.float

  for profile in profiles:
    for traceId, trace in profile.traces:
      var key = profile.names[trace.nameKey]
      var parent = trace.parent
      while parent != 0:
        let parentTrace = profile.traces[parent]
        key = profile.names[parentTrace.nameKey] & "/" & key
        parent = parentTrace.parent

      if key notin statisticsTree:
        statisticsTree[key] = Stats()
      var s = statisticsTree[key]
      let time = trace.timeEnd - trace.timeStart
      s.total += time
      inc s.num
      s.min = min(s.min, time)
      s.max = max(s.max, time)

  var ks = toSeq(statisticsTree.keys())
  ks.sort()
  for i, k in ks:
    let s = statisticsTree[k]
    echo k, " ", s.total, " ", s.num
    s.avg = s.total.float64 / s.num.float64

    s.totalSelf = s.total
    var j = i + 1
    echo "for ", k
    while j < ks.len:
      if not ks[j].hasPrefix(k):
        break
      if ks[j].count("/") != k.count("/") + 1:
        echo "   skip ", ks[j]
        inc j
        continue
      echo "  count ", ks[j]
      s.totalSelf -= statisticsTree[ks[j]].total
      inc j

    s.avgSelf = s.totalSelf.float64 / s.num.float64


loadFont("IBMPlex", "fonts/IBMPlexSans-Regular.ttf")
loadFont("Inconsolata", "fonts/Inconsolata-Regular.ttf")
setTitle("Proffy Viewer 2000")


profLoad()
computeStats()

var
  zoom = 1e-6
  offset: int64 = 0
  anchor: Vec2

  view: ViewKind

  selThreadId: int = -1
  selTraceId: int = -1

proc drawTimelineView() =
  for threadId, profile in profiles:
    group "thread":
      box 0, threadId*300 + 60, root.box.w, 200
      if profile.traces.len > 0:
        let
          timeStart = profile.traces[0].timeStart
          timeEnd = profile.traces[^1].timeEnd
        offset = clamp(offset, timeStart, timeEnd)

        for traceId, trace in profile.traces:
          let x = (trace.timeStart - offset).float64 * zoom
          let w = (trace.timeEnd - offset).float64 * zoom - x

          if x > root.box.w or x + w < 0:
            continue
          if w < 0.1:
            continue

          group "trace":
            let name = profile.names[trace.nameKey]
            box x, trace.level * 20, max(w, 1), 20
            if selTraceId == traceId and selThreadId == threadId:
              fill GREEN1
              onHover:
                fill GREEN2
            else:
              let h = (abs(hash(name)) mod 360_000).float32 / 1000.0
              fill hsv(h, 100.0, 100.0).color
              onHover:
                fill RED2
            onClick:
              selTraceId = traceId
              selThreadId = threadId
            if w > 10:
              clipContent true
              text "label":
                box 2, 0, 1000, 20
                fill BLACK
                font "IBMPlex", 16, 400, 20, hLeft, vCenter
                characters name

  if selTraceId != -1 and selThreadId != -1:
    let profile = profiles[selThreadId]
    let trace = profile.traces[selTraceId]
    group "info":
      box 0, root.box.h-500, root.box.w, 500
      fill DARK1
      text "name":
        box 10, 10, 1000, 100
        fill WHITE1
        font "IBMPlex", 20, 400, 30, hLeft, vTop
        characters profile.names[trace.nameKey]

      text "info":
        box 10, 40, 1000, 100
        fill WHITE1
        font "Inconsolata", 16, 400, 20, hLeft, vTop
        let s = statistics[trace.nameKey]
        var text = &"""
this:  {(trace.timeEnd - trace.timeStart).float * 1e-6:>20.6f} ms
avg:   {(s.avg).float * 1e-6:>20.6f} ms
total: {(s.total).float * 1e-6:>20.6f} ms
max:   {(s.max).float * 1e-6:>20.6f} ms
min:   {(s.min).float * 1e-6:>20.6f} ms
num:   {s.num:>20} calls

Stack Trace:
{profile.names[trace.stackTraceKey]}
"""
        characters text

  onClick:
    anchor = mouse.pos

  onMouseDown:
    var d = anchor - mouse.pos
    anchor = mouse.pos
    offset += (mouse.pos.x / zoom).int
    zoom *= 1.0 + 0.025 * d.y
    zoom = clamp(zoom, 0.0000001, 10)
    offset += (d.x / zoom).int
    offset -= (mouse.pos.x / zoom).int

proc drawTreeView() =

  group "treeView":
    box 0, 60, root.box.w, root.box.h - 60
    layout lmVertical
    counterAxisSizingMode csFixed
    itemSpacing 1
    var offset = 300
    var prevName: seq[string]

    var ks = toSeq(statisticsTree.keys())
    ks.sort()
    ks.reverse()
    for k in ks:
      let s = statisticsTree[k]
      #echo k, " ", s.total, " ", s.num

      group "trace":
        box 0, 0, root.box.w, 20

        onHover:
          fill WHITE1, 0.1

        # if selTraceId == traceId and selThreadId == threadId:
        #   fill GREEN1
        #   onHover:
        #     fill GREEN2
        # else:
        #   let h = (abs(hash(name)) mod 360_000).float32 / 1000.0
        #   fill hsv(h, 100.0, 100.0).color
        #   onHover:
        #     fill RED2
        # onClick:
        #   selTraceId = traceId
        #   selThreadId = threadId

        var nameParts = k.split('/')

        text "label":
          box nameParts.len * 10, 0, 1000, 20
          fill WHITE
          font "IBMPlex", 14, 400, 20, hLeft, vCenter
          characters nameParts[^1]

        text "avg":
          box offset, 0, 200, 20
          fill WHITE
          font "IBMPlex", 14, 400, 20, hRight, vCenter
          characters &"{(s.avg).float * 1e-6:>20.3f}"

        text "avgSelf":
          box offset+200, 0, 200, 20
          fill WHITE
          font "IBMPlex", 14, 400, 20, hRight, vCenter
          characters &"{(s.avgSelf).float * 1e-6:>20.3f}"

        text "total":
          box offset+400, 0, 200, 20
          fill WHITE
          font "IBMPlex", 14, 400, 20, hRight, vCenter
          characters &"{(s.total).float * 1e-6:>20.3f}"

        text "totalSelf":
          box offset+600, 0, 200, 20
          fill WHITE
          font "IBMPlex", 14, 400, 20, hRight, vCenter
          characters &"{(s.totalSelf).float * 1e-6:>20.3f}"

        text "num":
          box offset+800, 0, 200, 20
          fill WHITE
          font "IBMPlex", 14, 400, 20, hRight, vCenter
          characters &"{s.num:>20}"

    group "header":
      box 0, 0, root.box.w, 20
      text "avg":
        box offset, 0, 200, 20
        fill WHITE
        font "IBMPlex", 16, 400, 20, hRight, vCenter
        characters "avg ms"

      text "total":
        box offset+200, 0, 200, 20
        fill WHITE
        font "IBMPlex", 16, 400, 20, hRight, vCenter
        characters "avg self ms"

      text "total":
        box offset+400, 0, 200, 20
        fill WHITE
        font "IBMPlex", 16, 400, 20, hRight, vCenter
        characters "total ms"

      text "total":
        box offset+600, 0, 200, 20
        fill WHITE
        font "IBMPlex", 16, 400, 20, hRight, vCenter
        characters "total self ms"

      text "num":
        box offset+800, 0, 200, 20
        fill WHITE
        font "IBMPlex", 16, 400, 20, hRight, vCenter
        characters "num calls"


proc headerTabButton(viewKind: ViewKind) =
  component "MenuButton":
    fill BLUE1, 0.5
    cornerRadius 2
    layout lmVertical
    counterAxisSizingMode csAuto
    horizontalPadding 5
    verticalPadding 1
    itemSpacing 10
    text "headerTabButton":
      box 5, 1, 60, 18
      fill WHITE
      font "IBMPlex", 14, 500, 18, hLeft, vTop
      characters $viewKind
      textAutoResize tsWidth_and_height
      layoutAlign laCenter

    if view == viewKind:
      fill BLUE1
    onClick:
      view = viewKind

proc drawHeader() =
  group "header":
    box 0, 0, root.box.w, 40
    fill DARK1
    frame "tabs":
      box 5, 5, 250, 30
      layout lmHorizontal
      counterAxisSizingMode csAuto
      horizontalPadding 5
      verticalPadding 5
      itemSpacing 4

      headerTabButton(TreeView)
      headerTabButton(TimelineView)

proc drawMain() =
  frame "main":
    box 0, 0, root.box.w, root.box.h
    fill NIMBG

    drawHeader()

    case view:
    of TimelineView:
      drawTimelineView()
    of TreeView:
      drawTreeView()


startFidget(drawMain, w = 1200, h = 1200)
