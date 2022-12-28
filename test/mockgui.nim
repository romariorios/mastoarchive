import ../masto_archive/gui

import nigui

proc count(): proc(): int =
  var i = 0
  return proc(): int =
             result = i
             i += 1

app.init()

let policy = MastoArchiveWindowPolicy(
  randomTootIdx: count(),
  tootText: proc(i: int): string = "toot number " & $i
)

let win = mastoArchiveWindow(policy)

win.show()

app.run
