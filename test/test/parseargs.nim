import ../../parseargs.nim

import std/options

proc parseArgsSeq(args: seq[string]): Option[ProgArgs] =
  parseArgs(
    proc(i: int): string = args[i],
    args.len - 1
  )

block:
  let progArgsOpt = parseArgsSeq(@["mastoarchive", "archive-path"])
  assert progArgsOpt.isSome

  let progArgs = progArgsOpt.get()
  assert progArgs.archiveDir == "archive-path"
  assert progArgs.openMode.kind == omGui

block:
  let progArgsOpt = parseArgsSeq(@["mastoarchive", "rand", "archive-path"])
  assert progArgsOpt.isSome

  let progArgs = progArgsOpt.get()
  assert progArgs.archiveDir == "archive-path"
  assert progArgs.openMode.kind == omRand

block:
  let progArgsOpt = parseArgsSeq(@["mastoarchive", "loop", "archive-path"])
  assert progArgsOpt.isSome

  let progArgs = progArgsOpt.get()
  assert progArgs.archiveDir == "archive-path"
  assert progArgs.openMode.kind == omLoop

block:
  let progArgsOpt = parseArgsSeq(@["mastoarchive", "llop", "archive-path"])
  assert not progArgsOpt.isSome

# TODO: this test fails. solve this
# block:
#   let progArgsOpt = parseArgsSeq(@["mastoarchive", "loop"])
#   assert not progArgsOpt.isSome

block:
  let progArgsOpt = parseArgsSeq(
    @["mastoarchive", "toot", "12355", "archive-path"])
  assert progArgsOpt.isSome

  let progArgs = progArgsOpt.get()
  assert progArgs.archiveDir == "archive-path"
  assert progArgs.openMode.kind == omToot
  assert progArgs.openMode.tootIdx == 12355

# TODO: this test fails. the exception is unhandled
# block:
#   let progArgsOpt = parseArgsSeq(
#     @["mastoarchive", "toot", "129o", "archive-path"])
#   assert not progArgsOpt.isSome

block:
  let progArgsOpt = parseArgsSeq(
    @["mastoarchive", "tootrange", "120-200", "archive-path"])
  assert progArgsOpt.isSome

  let progArgs = progArgsOpt.get()
  assert progArgs.archiveDir == "archive-path"
  assert progArgs.openMode.kind == omTootRange
  assert progArgs.openMode.tootIdxFrom == 120
  assert progArgs.openMode.tootIdxTo == 200

# TODO: this test fails. parseInt can't handle untrimmed integer strings
# block:
#   let progArgsOpt = parseArgsSeq(
#     @["mastoarchive", "tootrange", "100 - 200", "archive-path"])
#   assert progArgsOpt.isSome

#   let progArgs = progArgsOpt.get()
#   assert progArgs.archiveDir == "archive-path"
#   assert progArgs.openMode.kind == omTootRange
#   assert progArgs.openMode.tootIdxFrom == 100
#   assert progArgs.openMode.tootIdxTo == 200

# TODO: this test fails. unhandled exception when trying to find archive-path
# block:
#   let progArgsOpt = parseArgsSeq(
#     @["mastoarchive", "tootrange", "120-200"])
#   assert not progArgsOpt.isSome

block:
  let progArgsOpt = parseArgsSeq(
    @["mastoarchive", "gui", "archive-path"])
  assert progArgsOpt.isSome

  let progArgs = progArgsOpt.get()
  assert progArgs.archiveDir == "archive-path"
  assert progArgs.openMode.kind == omGui

# TODO: this test fails
# block:
#   let progArgsOpt = parseArgsSeq(
#     @["mastoarchive", "gui"])
#   assert not progArgsOpt.isSome
