# std imports
import os
import std/json
import std/htmlparser
import std/options
import std/random
import std/sequtils
import std/strutils
import std/xmltree

# external libs
import nigui

proc assertInit(success: bool, errMsg: string) =
  if not success:
    echo errMsg
    quit QuitFailure

type
  OpenMode = enum
    rand, loop, toot, tootrange, gui

type
  AttachmentData = object
    `type`: string
    mediaType: string
    url: string
    name: string

  TootObjectData = object
    id: string
    content: string
    inReplyTo: Option[string]
    summary: Option[string]
    attachment: seq[AttachmentData]

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

proc toText(toot: Toot): string =
  let obj = toot.obj
  result.add("======\n")

  case obj.kind:
    of tkToot:
      let data = obj.toot
      let contentHtml = data.content.parseHtml

      result.add("id: " & data.id & "\n")
      if data.summary.isSome:
        result.add("cw: " & data.summary.get() & "\n")

      for para in contentHtml:
        result.add(para.innerText & "\n")

      if data.attachment.len > 0:
        result.add("attachments:\n")
      for att in data.attachment:
        result.add("- description: " & att.name & "; url: " & att.url & "\n")

      if data.inReplyTo.isSome:
        result.add("in reply to: " & data.inReplyTo.get() & "\n")
    of tkBoost:
      result.add("boost: " & obj.boostedUrl & "\n")
  result.add("at: " & toot.published & "\n======\n")

let
  usageText = "usage: " & paramStr(0) &
    " [rand|loop|toot <tootNum>|tootrange <from>-<to>|gui] " &
    "<path to archive dir>"

# ===

randomize()

assertInit(paramCount() == 2 or paramCount() == 3, usageText)

let openModeStr = paramStr(1)
let openMode =
  case toLowerAscii(openModeStr):
    of "rand": some(rand)
    of "loop": some(loop)
    of "toot": some(toot)
    of "tootrange": some(tootrange)
    of "gui": some(gui)
    else: none(OpenMode)

assertInit(
  openMode.isSome,
  "error: invalid mode " & openModeStr & "\n" & usageText)

let archiveDir = paramStr(
  case openMode.get():
    of toot: 3
    of tootrange: 3
    else: 2
)

assertInit(dirExists(archiveDir),
  "error: \"" & archiveDir & "\" is not a directory")

echo "Loading outbox..."
let outbox = readFile(archiveDir & "/outbox.json").parseJson.summary

case openMode.get():
  of rand:
    let tootIdx = rand(outbox.totalToots - 1)
    echo "Reading toot number ", tootIdx

    echo outbox.toots.at(tootIdx).toText
  of loop:
    while true:
      echo "Which toot do you want to see? "
      let tootIdx = stdin.readLine.parseInt
      echo outbox.toots.at(tootIdx).toText
  of toot:
    let tootIdx = paramStr(2).parseInt
    echo outbox.toots.at(tootIdx).toText
  of tootrange:
    let tRange = paramStr(2).split('-').map(parseInt)
    assertInit(tRange.len() == 2,
               "error: range must have exactly two indexes")
    for idx in tRange[0]..tRange[1]:
      echo outbox.toots.at(idx).toText
  of gui:
    app.init()

    var window = newWindow("Mastoarchive!")

    window.width = 600.scaleToDpi
    window.height = 400.scaleToDpi

    var container = newLayoutContainer(Layout_Vertical)
    window.add(container)

    var button = newButton("Random toot")
    container.add(button)

    var textArea = newTextArea()
    container.add(textArea)

    button.onClick = proc(event: ClickEvent) =
      let tootIdx = rand(outbox.totalToots - 1)
      textArea.addLine("Reading toot number " & $tootIdx)
      textArea.addLine(outbox.toots.at(tootIdx).toText)

    window.show()

    app.run()
