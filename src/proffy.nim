## Frame based, instrumentation profiler for games.
import tables, print, std/monotimes, os, flatty, supersnappy

type

  StackFrame* = object
    procNameKey*: int
    line*: int
    filenameKey*: int

  TraceKind* = enum
    tkFrame
    tkMark

  Trace* = object
    kind*: TraceKind
    nameKey*: int
    timeStart*: int64
    timeEnd*: int64
    level*: int
    stackTrace*: seq[StackFrame]

  Profile* = ref object
    threadName*: string
    names*: Table[int, string]
    namesBack*: Table[string, int]
    traces*: seq[Trace]
    traceStack*: seq[int]

proc place(profile: Profile, s: string): int =
  if s in profile.namesBack:
    result = profile.namesBack[s]
  else:
    result = profile.names.len
    profile.names[result] = s
    profile.namesBack[s] = result

var
  profile* {.threadvar.}: Profile

proc initProfile*(threadName: string) =
  profile = Profile()
  profile.threadName = threadName

proc pushTrace*(kind: TraceKind, name: string) =
  if profile == nil: return
  var trace = Trace()
  trace.kind = kind
  trace.nameKey = profile.place(name)
  trace.timeStart = getMonoTime().ticks
  trace.level = profile.traceStack.len
  profile.traceStack.add(profile.traces.len)
  for e in getStackTraceEntries():
    var s = StackFrame()
    s.procNameKey = profile.place($e.procname)
    s.line = e.line
    s.filenameKey = profile.place($e.filename)
    trace.stackTrace.add(s)
  profile.traces.add(trace)

proc popTrace*() =
  if profile == nil: return
  let index = profile.traceStack.pop()
  profile.traces[index].timeEnd = getMonoTime().ticks

proc profDump*() =
  if profile == nil: return
  discard existsOrCreateDir(getHomeDir() / ".proffy")

  profile.namesBack.clear()
  var data = profile.toFlatty()
  data = compress(data)
  echo "writing profile ... ", data.len, " bytes"
  writeFile(getHomeDir() / ".proffy" / profile.threadName & ".proffy", data)

proc profLoad*() =
  for fileName in walkFiles(getHomeDir() / ".proffy/*.proffy"):
    var data = readFile(fileName)
    echo "reading profile ... ", data.len, " bytes"
    data = uncompress(data)
    profile = data.fromFlatty(Profile)
    break
