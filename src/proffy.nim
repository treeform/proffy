## Frame based, instrumentation profiler for games.
import tables, print, std/monotimes, os, flatty, supersnappy, strformat

type
  TraceKind* = enum
    tkFrame
    tkMark

  Trace* = object
    kind*: TraceKind
    nameKey*: int
    timeStart*: int64
    timeEnd*: int64
    level*: int
    parent*: int
    stackTraceKey*: int

  Profile* = ref object
    threadName*: string
    names*: Table[int, string]
    namesBack*: Table[string, int]
    traces*: seq[Trace]
    traceStack*: seq[int]

proc intern(profile: Profile, s: string): int =
  if s in profile.namesBack:
    result = profile.namesBack[s]
  else:
    result = profile.names.len
    profile.names[result] = s
    profile.namesBack[s] = result

var
  profile* {.threadvar.}: Profile
  profiles*: seq[Profile]

proc initProfile*(threadName: string) =
  profile = Profile()
  profile.threadName = threadName
  discard profile.intern("")

proc pushTrace*(kind: TraceKind, name: string) =
  if profile == nil: return
  var trace = Trace()
  trace.kind = kind
  trace.nameKey = profile.intern(name)
  trace.timeStart = getMonoTime().ticks
  trace.level = profile.traceStack.len
  if profile.traceStack.len > 0:
    trace.parent = profile.traceStack[^1]
  profile.traceStack.add(profile.traces.len)
  when not defined(release):
    var stackTrace = ""
    for e in getStackTraceEntries()[0 ..^ 2]:
      stackTrace.add(&"  {e.procname} line: {e.line} {e.filename}\n")
    trace.stackTraceKey = profile.intern(stackTrace)
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
    profiles.add(profile)
