## Frame based instrumentation profiler for games.

import flatty, os, std/monotimes, strformat, supersnappy, tables

type
  TraceKind* = enum
    tkFrame
    tkMark

  Trace* = object
    kind*: TraceKind
    nameKey*: uint16
    timeStart*: int64
    timeEnd*: int64
    level*: uint16
    stackTraceKey*: uint16

  Profile* = ref object
    threadName*: string
    names*: Table[uint16, string]
    namesBack*: Table[string, uint16]
    traces*: seq[Trace]
    traceStack*: seq[uint16]

var
  profile* {.threadvar.}: Profile
  profiles*: seq[Profile]

proc intern(profile: Profile, s: string): uint16 =
  if s in profile.namesBack:
    result = profile.namesBack[s]
  else:
    result = profile.names.len.uint16
    profile.names[result] = s
    profile.namesBack[s] = result
    assert profile.names.len < high(uint16).int

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
  trace.level = profile.traceStack.len.uint16
  profile.traceStack.add(trace.level)
  assert profile.traceStack.len < high(uint16).int
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
