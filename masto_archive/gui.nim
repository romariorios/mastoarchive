import std/re
import std/strutils

import nigui

type
  MastoArchiveWindowPolicy* = object
    randomTootIdx*: proc(): int
    tootText*: proc(i: int): string

proc mastoArchiveWindow*(policy: MastoArchiveWindowPolicy): Window =
  result = newWindow("Mastoarchive!")

  result.width = 600.scaleToDpi
  result.height = 400.scaleToDpi

  var container = newLayoutContainer(Layout_Vertical)
  result.add(container)

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

  var getTootButton = newButton("Get toot")
  tootContainer.add(getTootButton)

  proc tootIdxValid(): bool =
    tootIdx.text.contains(re"^[0-9]+$")

  # number-only filtering fails on windows
  when not defined windows:
    tootIdx.onTextChange = proc(e: TextChangeEvent) =
      tootIdx.text = tootIdx.text.replace(re"[^0-9]+") # only allow numbers
  else: # disable button on invalid input instead
    getTootButton.enabled = false
    tootIdx.onTextChange = proc(e: TextChangeEvent) =
      getTootButton.enabled = tootIdxValid()

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
    textArea.addLine(policy.tootText(idx))
    textArea.addLine("======")
    textArea.scrollToBottom()

  randButton.onClick = proc(event: ClickEvent) =
    showToot(policy.randomTootIdx())

  var showSelectedToot = proc() =
    if tootIdx.text.isEmptyOrWhitespace():
      return

    let idx = tootIdx.text.parseInt()
    showToot(idx)

    tootIdx.text = ""

  getTootButton.onClick = proc(event: ClickEvent) = showSelectedToot()
  tootIdx.onKeyDown = proc(event: KeyboardEvent) =
    if tootIdxValid() and event.key == Key_Return:
      showSelectedToot()
