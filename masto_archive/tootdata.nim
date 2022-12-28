import std/htmlparser
import std/options
import std/xmltree

type
  AttachmentData* = object
    `type`*: string
    mediaType*: string
    url*: string
    name*: string

  TootObjectData* = object
    id*: string
    content*: string
    inReplyTo*: Option[string]
    summary*: Option[string]
    attachment*: seq[AttachmentData]

  TootData* = object
    published*: string
    `type`*: string

type
  TootKind* = enum tkToot, tkBoost
  TootObject* = ref object
    case kind*: TootKind
    of tkToot: toot*: TootObjectData
    of tkBoost: boostedUrl*: string

  Toot* = object
    published*: string
    obj*: TootObject

proc toText*(toot: Toot): string =
  let obj = toot.obj
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
  result.add("at: " & toot.published)
