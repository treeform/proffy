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
    names*: seq[string]
    namesBack*: Table[string, uint16]
    traces*: seq[Trace]
    traceStack*: seq[uint16]

var
  profiles*: seq[Profile]
  profileIdx* {.threadvar.}: int

proc intern(profile: Profile, s: string): uint16 =
  if s in profile.namesBack:
    result = profile.namesBack[s]
  else:
    result = profile.names.len.uint16
    profile.names.add(s)
    profile.namesBack[s] = result
    assert profile.names.len < high(uint16).int

proc newProfile*(threadName: string): Profile =
  result = Profile()
  result.threadName = threadName
  discard result.intern("")

proc pushTraceWithSideEffects(kind: TraceKind, name: string) =
  when defined(proffy):
    let profile = profiles[profileIdx]
    var trace = Trace()
    trace.kind = kind
    trace.nameKey = profile.intern(name)
    trace.timeStart = getMonoTime().ticks
    trace.level = profile.traceStack.len.uint16
    profile.traceStack.add(profile.traces.len.uint16)
    assert profile.traceStack.len < high(uint16).int
    when not defined(release):
      var stackTrace = ""
      for e in getStackTraceEntries()[0 ..^ 2]:
        stackTrace.add(&"  {e.procname} line: {e.line} {e.filename}\n")
      trace.stackTraceKey = profile.intern(stackTrace)
    profile.traces.add(trace)

func pushTrace*(kind: TraceKind, name: string) =
  cast[proc (kind: TraceKind, name: string) {.nimcall, noSideEffect.}](
    pushTraceWithSideEffects
  )(kind, name)

proc popTraceWithSideEffects() =
  when defined(proffy):
    if profileIdx == 0:
      let
        profile = profiles[profileIdx]
        traceIdx = profile.traceStack.pop()
      profile.traces[traceIdx].timeEnd = getMonoTime().ticks

func popTrace*() =
  cast[proc () {.nimcall, noSideEffect.}](popTraceWithSideEffects)()

proc profDump*() =
  when defined(proffy):
    discard existsOrCreateDir(getHomeDir() / ".proffy")
    for profile in profiles:
      profile.namesBack.clear()
      var data = profile.toFlatty()
      data = compress(data)
      echo "writing profile ... ", data.len, " bytes"
      writeFile(getHomeDir() / ".proffy" / profile.threadName & ".proffy", data)

proc profLoad*(): seq[Profile] =
  for fileName in walkFiles(getHomeDir() / ".proffy/*.proffy"):
    var data = readFile(fileName)
    echo "reading profile ... ", data.len, " bytes"
    data = uncompress(data)
    result.add(data.fromFlatty(Profile))
