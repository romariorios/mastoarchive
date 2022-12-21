import std/options
import std/sequtils
import std/strutils

type
  OpenModeKind* = enum omRand, omLoop, omToot, omTootRange, omGui
  OpenMode* = ref object
    case kind*: OpenModeKind
    of omRand: rand*: void
    of omLoop: loop*: void
    of omToot: tootIdx*: int
    of omTootRange:
      tootIdxfrom*, tootIdxTo*: int
    of omGui: gui*: void

  ProgArgs* = object
    openMode*: OpenMode
    archiveDir*: string

proc parseArgs*(paramAt: proc(i: int): string; paramC: int): Option[ProgArgs] =
  if paramC < 1 or paramC > 3:
    return none(ProgArgs)

  var archiveDir: string
  let openMode =
    if paramC == 1:
      archiveDir = paramAt(1)
      some(omGui)
    else:
      case paramAt(1):
        of "rand":
          archiveDir = paramAt(2)
          some(omRand)
        of "loop":
          archiveDir = paramAt(2)
          some(omLoop)
        of "toot":
          archiveDir = paramAt(3)
          some(omToot)
        of "tootrange":
          archiveDir = paramAt(3)
          some(omTootRange)
        of "gui":
          archiveDir = paramAt(2)
          some(omGui)
        else: none(OpenModeKind)

  if openMode.isNone:
    return none(ProgArgs)

  case openMode.get():
    of omToot:
      let idx = paramAt(2).parseInt
      some(ProgArgs(openMode: OpenMode(kind: omToot, tootIdx: idx),
                    archiveDir: archiveDir))
    of omTootRange:
      let tRange = paramAt(2).split('-').map(parseInt)
      if tRange.len() != 2:
        return none(ProgArgs)

      some(ProgArgs(
        openMode: OpenMode(kind: omTootRange, tootIdxFrom: tRange[0],
                           tootIdxTo: tRange[1]),
        archiveDir: archiveDir))
    else:
      some(ProgArgs(openMode: OpenMode(kind: openMode.get()),
                    archiveDir: archiveDir))
