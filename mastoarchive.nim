import os
import std/json
import std/htmlparser
import std/options
import std/random
import std/strutils
import std/xmltree

proc assertInit(success: bool, errMsg: string) =
  if not success:
    echo errMsg
    quit QuitFailure

type
  OpenMode = enum
    rand, loop, toot

type
  TootObjectData = object
    id: string
    content: string
    inReplyTo: Option[string]
    summary: Option[string]

  TootData = object
    published: string
    `type`: string

type
  TootKind = enum tkToot, tkBoost
  TootObject = ref object
    case kind: TootKind
    of tkToot: toot: TootObjectData
    of tkBoost: boostedUrl: string

  Toot = object
    published: string
    obj: TootObject

type
  Outbox = object
    totalToots: int
    toots: JsonNode

proc summary(outboxJson: JsonNode): Outbox =
  let o = Outbox(
    totalToots: outboxJson["totalItems"].num.int,
    toots: outboxJson["orderedItems"])

  echo "This archive has ", o.totalToots, " toots"
  o

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

proc show(toot: Toot) =
  let obj = toot.obj

  echo "======"
  case obj.kind:
    of tkToot:
      let data = obj.toot
      let contentHtml = data.content.parseHtml

      echo "id: ", data.id
      data.summary.map(proc(cw: string) = echo "cw: ", cw)
      for para in contentHtml:
        echo para.innerText
      data.inReplyTo.map(proc(r: string) = echo "in reply to: ", r)
    of tkBoost:
      echo "boosted: ", obj.boostedUrl
  echo "at: ", toot.published
  echo "======"

# ===

randomize()

assertInit(paramCount() == 2 or paramCount() == 3,
  "usage: " & paramStr(0) & " [rand|loop|toot <tootNum>] <path to archive dir>")

let openModeStr = paramStr(1)
let openMode =
  case toLowerAscii(openModeStr):
    of "rand": rand
    of "loop": loop
    of "toot": toot
    else: raise newException(ValueError, "invalid mode " & openModeStr)

let archiveDir = paramStr(
  case openMode:
    of toot: 3
    else: 2
)

assertInit(dirExists(archiveDir),
  "error: \"" & archiveDir & "\" is not a directory")

echo "Loading outbox..."
let outbox = readFile(archiveDir & "/outbox.json").parseJson.summary

case openMode:
  of rand:
    let tootIdx = rand(outbox.totalToots - 1)
    echo "Reading toot number ", tootIdx

    outbox.toots.at(tootIdx).show
  of loop:
    while true:
      echo "Which toot do you want to see? "
      let tootIdx = stdin.readLine.parseInt
      outbox.toots.at(tootIdx).show
  of toot:
    let tootIdx = paramStr(2).parseInt
    outbox.toots.at(tootIdx).show