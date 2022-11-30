# std imports
import os
import std/json
import std/htmlparser
import std/options
import std/random
import std/re
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
  OpenModeKind = enum omRand, omLoop, omToot, omTootRange, omGui
  OpenMode = ref object
    case kind: OpenModeKind
    of omRand: rand: void
    of omLoop: loop: void
    of omToot: tootIdx: int
    of omTootRange:
      tootIdxfrom, tootIdxTo: int
    of omGui: gui: void

  ProgArgs = object
    openMode: OpenMode
    archiveDir: string

proc parseArgs(): Option[ProgArgs] =
  if paramCount() < 1 or paramCount() > 3:
    return none(ProgArgs)

  var archiveDir: string
  let openMode =
    if paramCount() == 1:
      archiveDir = paramStr(1)
      some(omGui)
    else:
      case paramStr(1):
        of "rand":
          archiveDir = paramStr(2)
          some(omRand)
        of "loop":
          archiveDir = paramStr(2)
          some(omLoop)
        of "toot":
          archiveDir = paramStr(3)
          some(omToot)
        of "tootrange":
          archiveDir = paramStr(3)
          some(omTootRange)
        of "gui":
          archiveDir = paramStr(2)
          some(omGui)
        else: none(OpenModeKind)

  if openMode.isNone:
    return none(ProgArgs)

  case openMode.get():
    of omToot:
      let idx = paramStr(2).parseInt
      some(ProgArgs(openMode: OpenMode(kind: omToot, tootIdx: idx),
                    archiveDir: archiveDir))
    of omTootRange:
      let tRange = paramStr(2).split('-').map(parseInt)
      if tRange.len() != 2:
        return none(ProgArgs)

      some(ProgArgs(
        openMode: OpenMode(kind: omTootRange, tootIdxFrom: tRange[0],
                           tootIdxTo: tRange[1]),
        archiveDir: archiveDir))
    else:
      some(ProgArgs(openMode: OpenMode(kind: openMode.get()),
                    archiveDir: archiveDir))

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

let progArgs = parseArgs()
assertInit(progArgs.isSome(), usageText)

let archiveDir = progArgs.get().archiveDir
assertInit(dirExists(archiveDir),
  "error: \"" & archiveDir & "\" is not a directory")

echo "Loading outbox..."
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
  of omToot:
    echo outbox.toots.at(openMode.tootIdx).toText
  of omTootRange:
    for idx in openMode.tootIdxFrom..openMode.tootIdxTo:
      echo outbox.toots.at(idx).toText
  of omGui:
    app.init()

    var window = newWindow("Mastoarchive!")

    window.width = 600.scaleToDpi
    window.height = 400.scaleToDpi

    var container = newLayoutContainer(Layout_Vertical)
    window.add(container)

    var modeCombo = newComboBox(@["Random", "Select toot"])
    container.add(modeCombo)

    var modeContainers: seq[LayoutContainer]

    var randContainer = newLayoutContainer(Layout_Horizontal)
    container.add(randContainer)
    modeContainers.add(randContainer)

    var randButton = newButton("Random toot")
    randContainer.add(randButton)

    var tootContainer = newLayoutContainer(Layout_Horizontal)
    container.add(tootContainer)
    modeContainers.add(tootContainer)

    var tootIdxLabel = newLabel("Toot index:")
    tootContainer.add(tootIdxLabel)

    var tootIdx = newTextBox()
    tootContainer.add(tootIdx)

    tootIdx.onTextChange = proc(e: TextChangeEvent) =
      tootIdx.text = tootIdx.text.replace(re"[^0-9]+") # only allow numbers

    var getTootButton = newButton("Get toot")
    tootContainer.add(getTootButton)

    var showSelectedMode = proc() =
      for child in modeContainers:
        child.hide()

      modeContainers[modeCombo.index].show()

    showSelectedMode()
    modeCombo.onChange = proc(changeEvent: ComboBoxChangeEvent) =
      showSelectedMode()

    var textArea = newTextArea()
    container.add(textArea)

    var showToot = proc(idx: int) =
      textArea.addLine("Reading toot number " & $idx)
      textArea.addLine(outbox.toots.at(idx).toText)
      textArea.scrollToBottom()

    randButton.onClick = proc(event: ClickEvent) =
      let idx = rand(outbox.totalToots - 1)
      showToot(idx)

    var showSelectedToot = proc() =
      if tootIdx.text.isEmptyOrWhitespace():
        return

      let idx = tootIdx.text.parseInt()
      showToot(idx)
      tootIdx.text = ""

    getTootButton.onClick = proc(event: ClickEvent) = showSelectedToot()
    tootIdx.onKeyDown = proc(event: KeyboardEvent) =
      if event.key == Key_Return:
        showSelectedToot()

    window.show()

    app.run()
