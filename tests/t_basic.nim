import std/[os, strutils, unittest]
import yyjson

suite "yyjson":
  test "parse and access":
    var doc = readJson("""{"name":"redis","tags":["7.4","latest"],"n":3,"enabled":true}""")
    defer:
      doc.close()

    let root = doc.root()
    check root["name"].str() == "redis"
    check root["n"].int64() == 3
    check root["n"].int() == 3
    check root["n"].isInt
    check root["n"].isUInt
    check not root["n"].isReal
    check root["enabled"].bool() == true
    check root["enabled"].typeDesc() == "true"
    check root.hasKey("name")
    check "name" in root
    check not root.hasKey("missing")
    check root["name"].strLen() == 5
    check root["name"].equalsStr("redis")
    check root["tags"][0].str() == "7.4"
    check root["tags"][1].str() == "latest"
    check root["tags"][2].isNil
    check root["tags"][-1].isNil
    check root["tags"].first().str() == "7.4"
    check root["tags"].last().str() == "latest"
    check root["tags"].hasIndex(0)
    check not root["tags"].hasIndex(2)
    check root["tags"].getStr(1) == "latest"
    check root["tags"].getStr(2, "missing") == "missing"

    var tags: seq[string] = @[]
    for tag in root["tags"].items:
      tags.add(tag.str())

    check tags == @["7.4", "latest"]

  test "object pairs":
    var doc = readJson("""{"a":1,"b":2}""")
    defer:
      doc.close()

    var count = 0
    for k, v in doc.root().pairs:
      check ($k) in ["a", "b"]
      check v.isNumber
      inc count

    check count == 2

  test "raw and equality helpers":
    var rawDoc = readJson("""{"n":12345}""", YYJSON_READ_NUMBER_AS_RAW)
    defer:
      rawDoc.close()

    let n = rawDoc.root()["n"]
    check n.isRaw
    check n.raw() == "12345"
    check n.rawLen() == 5

    var lhs = readJson("""{"a":1,"b":[true,null],"c":{"x":"y"}}""")
    defer:
      lhs.close()

    var rhs = readJson("""{"c":{"x":"y"},"b":[true,null],"a":1}""")
    defer:
      rhs.close()

    var different = readJson("""{"a":1,"b":[true,false],"c":{"x":"y"}}""")
    defer:
      different.close()

    check lhs.root().equals(rhs.root())
    check lhs.root() == rhs.root()
    check not lhs.root().equals(different.root())
    check lhs.root()["missing"] != rhs.root()["missing"]

  test "mutable dom build and write":
    var mutDoc = newJsonMutDoc()
    defer:
      mutDoc.close()

    let root = mutDoc.newObject()
    let tags = mutDoc.newArray()
    tags.add(mutDoc.newString("7.4"))
    tags.add(mutDoc.newString("latest"))

    root.add("name", mutDoc.newString("redis"))
    root.add("withNull", mutDoc.newString("a\0b"))
    root.add("n", mutDoc.newInt(3))
    root.add("enabled", mutDoc.newBool(true))
    root.add("tags", tags)
    root.add("optional", mutDoc.newNull())
    mutDoc.setRoot(root)

    let json = mutDoc.writeJson()
    var doc = readJson(json)
    defer:
      doc.close()

    check doc.root()["name"].str() == "redis"
    check doc.root()["withNull"].str() == "a\0b"
    check doc.root()["withNull"].strLen() == 3
    check doc.root()["n"].int() == 3
    check doc.root()["enabled"].bool() == true
    check doc.root()["tags"][0].str() == "7.4"
    check doc.root()["tags"][1].str() == "latest"
    check doc.root()["optional"].isNull

  test "mutable dom read navigate and mutate":
    var mutDoc = readJsonMut("""{"name":"redis","tags":["7.4","latest"],"n":3,"enabled":true,"drop":1}""")
    defer:
      mutDoc.close()

    let root = mutDoc.root()
    check root.isObject
    check root.len == 5
    check root["name"].str() == "redis"
    check root["tags"].isArray
    check root["tags"].first().str() == "7.4"
    check root["tags"].last().str() == "latest"
    check root.pointer("/tags/1").str() == "latest"
    check root.getInt("n") == 3
    check root.getBool("enabled") == true

    let oldTag = root["tags"].replace(0, mutDoc.newString("8.0"))
    check oldTag.str() == "7.4"
    check root["tags"].remove(1).str() == "latest"
    check root["tags"].len == 1
    check root.replace("n", mutDoc.newInt(4))
    check root.remove("drop").int() == 1
    root.add("withNull", mutDoc.newString("a\0b"))

    var keys: seq[string] = @[]
    for k, v in root.pairs:
      keys.add($k)
      check not v.isNil
    check "name" in keys
    check "drop" notin keys

    var values: seq[string] = @[]
    for tag in root["tags"].items:
      values.add(tag.str())
    check values == @["8.0"]

    let json = mutDoc.writeJson()
    var doc = readJson(json)
    defer:
      doc.close()

    check doc.root()["tags"].len == 1
    check doc.root()["tags"][0].str() == "8.0"
    check doc.root()["n"].int() == 4
    check not doc.root().hasKey("drop")
    check doc.root()["withNull"].str() == "a\0b"

  test "json pointer":
    var doc = readJson("""{"metadata":{"name":"redis"}}""")
    defer:
      doc.close()

    check doc.root().pointer("/metadata/name").str() == "redis"
    check doc.root().pointer("/metadata/missing").isNil

  test "read error details":
    try:
      discard readJson("""{"name":]""")
      fail()
    except JsonReadError as e:
      check e.code != YYJSON_READ_SUCCESS
      check e.pos > 0
      check e.reason.len > 0
      check e.msg.contains("yyjson failed to parse JSON string")

  test "read file error details":
    let path = getTempDir() / "nim_yyjson_missing_file.json"
    if fileExists(path):
      removeFile(path)

    try:
      discard readJsonFile(path)
      fail()
    except JsonReadError as e:
      check e.code == YYJSON_READ_ERROR_FILE_OPEN
      check e.reason.len > 0
      check e.msg.contains(path)

  test "write json":
    var doc = readJson("""{"name":"redis","tags":["7.4","latest"],"n":3}""")
    defer:
      doc.close()

    check doc.writeJson() == """{"name":"redis","tags":["7.4","latest"],"n":3}"""
    check doc.root()["tags"].writeJson() == """["7.4","latest"]"""

    let pretty = doc.writeJson(YYJSON_WRITE_PRETTY_TWO_SPACES)
    check pretty.contains("\n")
    check pretty.contains("  \"name\"")

  test "write json file":
    var doc = readJson("""{"metadata":{"name":"redis"}}""")
    defer:
      doc.close()

    let path = getTempDir() / "nim_yyjson_write_test.json"
    if fileExists(path):
      removeFile(path)
    defer:
      if fileExists(path):
        removeFile(path)

    writeJsonFile(path, doc.root())

    var written = readJsonFile(path)
    defer:
      written.close()

    check written.root().pointer("/metadata/name").str() == "redis"
