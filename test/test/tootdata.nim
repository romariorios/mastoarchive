import ../../masto_archive/tootdata

import std/options

block:
  let toot = Toot(
    published: "2022-12-27",
    obj: TootObject(
      kind: tkToot,
      toot: TootObjectData(
        id: "12345",
        content: "<p>hello world</p>",
        inReplyTo: some("original post"),
        summary: some("warning: graphics")
      )
    )
  )

  let tootText = toot.toText()
  assert tootText ==
    "id: 12345\ncw: warning: graphics\nhello world\n" &
      "in reply to: original post\nat: 2022-12-27"

block:
  let boost = Toot(
    published: "2020-11-11",
    obj: TootObject(
      kind: tkBoost,
      boostedUrl: "boosted-url.com"
    )
  )

  let tootText = boost.toText()
  assert tootText == "boost: boosted-url.com\nat: 2020-11-11"
