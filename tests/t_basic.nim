import std/unittest
import yyjson

suite "yyjson":
  test "parse and access":
    var doc = readJson("""{"name":"redis","tags":["7.4","latest"],"n":3}""")
    defer: doc.close()

    let root = doc.root()
    check root["name"].str() == "redis"
    check root["n"].int64() == 3

    var tags: seq[string] = @[]
    for tag in root["tags"].items:
      tags.add(tag.str())

    check tags == @["7.4", "latest"]

  test "object pairs":
    var doc = readJson("""{"a":1,"b":2}""")
    defer: doc.close()

    var count = 0
    for k, v in doc.root().pairs:
      check ($k) in ["a", "b"]
      check v.isNumber
      inc count

    check count == 2
