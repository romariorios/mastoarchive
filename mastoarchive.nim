# std imports
import os
import std/json
import std/options
import std/random
import std/strutils

# external libs
import nigui

# own imports
import masto_archive/gui
import masto_archive/parseargs
import masto_archive/tootdata

proc assertInit(success: bool, errMsg: string) =
  if not success:
    echo errMsg
    quit QuitFailure

type
  Outbox = object
    totalToots: int
    toots: JsonNode

proc summary(outboxJson: JsonNode): Outbox =
  Outbox(
    totalToots: outboxJson["totalItems"].num.int,
    toots: outboxJson["orderedItems"])

proc at(toots: JsonNode, idx: int): Toot =
  let node = toots[idx]
  let data = node.to(TootData)
  let objNode = node["object"]
  let t = data.`type`

  let obj =
    case t:
      of "Create": TootObject(kind: tkToot, toot: objNode.to(TootObjectData))
      of "Announce": TootObject(kind: tkBoost, boostedUrl: objNode.str)
      else: raise newException(ValueError, "toot type unknown: " & t)

  Toot(published: data.published, obj: obj)

let
  usageText = "usage: " & paramStr(0) &
    " [rand|loop|toot <tootNum>|tootrange <from>-<to>|gui] " &
    "<path to archive dir>"

# ===

randomize()

let progArgs = parseArgs(paramStr, paramCount())
assertInit(progArgs.isSome(), usageText)

let archiveDir = progArgs.get().archiveDir
assertInit(dirExists(archiveDir),
  "error: \"" & archiveDir & "\" is not a directory")

let outbox = readFile(archiveDir & "/outbox.json").parseJson.summary
let openMode = progArgs.get().openMode

case openMode.kind:
  of omRand:
    let tootIdx = rand(outbox.totalToots - 1)
    echo "Reading toot number ", tootIdx

    echo outbox.toots.at(tootIdx).toText
  of omLoop:
    while true:
      echo "Which toot do you want to see? "
      let tootIdx = stdin.readLine.parseInt
      echo outbox.toots.at(tootIdx).toText
      echo "======"
  of omToot:
    echo outbox.toots.at(openMode.tootIdx).toText
  of omTootRange:
    for idx in openMode.tootIdxFrom..openMode.tootIdxTo:
      echo outbox.toots.at(idx).toText
      echo "======"
  of omGui:
    app.init()

    let policy = MastoArchiveWindowPolicy(
      randomTootIdx: proc(): int = rand(outbox.totalToots - 1),
      tootText: proc(i: int): string = outbox.toots.at(i).toText
    )
    var window = mastoArchiveWindow(policy)
    window.show()

    app.run()
