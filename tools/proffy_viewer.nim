
import fidget, proffy, tables, chroma, vmath, strformat, hashes

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

profLoad()

loadFont("IBMPlex", "fonts/IBMPlexSans-Regular.ttf")
setTitle("Proffy Viewer 2000")

var
  zoom = 1e-6
  offset: int64 = 0
  anchor: Vec2

  selTraceId: int = -1

proc drawMain() =
  frame "textAlignFixed":
    box 0, 0, root.box.w, root.box.h
    fill NIMBG

    group "header":
      box 0, 0, root.box.w, 40
      fill DARK1

    group "traces":
      box 0, 60, root.box.w, 200
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
            if selTraceId == traceId:
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

            if w > 10:
              clipContent true
              text "label":
                box 2, 0, 1000, 20
                fill BLACK
                font "IBMPlex", 16, 400, 20, hLeft, vCenter
                characters name

    if selTraceId != -1:
      let trace = profile.traces[selTraceId]
      group "info":
        box 0, root.box.h-300, root.box.w, 300
        fill DARK1
        text "label":
          box 10, 0, 1000, 100
          fill WHITE1
          font "IBMPlex", 16, 400, 20, hLeft, vTop
          var text = &"""
{profile.names[trace.nameKey]}
{trace.timeEnd - trace.timeStart}ns
{(trace.timeEnd - trace.timeStart).float * 1e-6:<9.2f}ms
"""
          for e in trace.stackTrace:
            text.add &"{profile.names[e.procNameKey]} line: {e.line} {profile.names[e.fileNameKey]}\n"

          characters text
    onClick:
      anchor = mouse.pos

    onMouseDown:
      var d = anchor - mouse.pos
      anchor = mouse.pos
      offset += (mouse.pos.x / zoom).int
      if d.y > 0:
        zoom *= 1.05
      if d.y < 0:
        zoom *= 0.95
      zoom = clamp(zoom, 0.0000001, 10)
      offset += (d.x / zoom).int
      offset -= (mouse.pos.x / zoom).int



startFidget(drawMain, w = 1000, h = 600)
