include common

suite "upstream yyjson values":
  test "array access helpers":
    var doc = readJson("""{"items":["alpha",2,true,null]}""")
    defer:
      doc.close()

    let items = doc.root()["items"]
    check items.len == 4
    check items[0].str() == "alpha"
    check items[1].int() == 2
    check items[2].bool() == true
    check items[3].isNull
    check items[4].isNil
    check items[-1].isNil
    check items.first().str() == "alpha"
    check items.last().isNull
    check items.hasIndex(0)
    check not items.hasIndex(4)
    check items.getStr(0) == "alpha"
    check items.getInt(1) == 2
    check items.getBool(2) == true
    check items.getStr(4, "fallback") == "fallback"

  test "json array upstream api matrix":
    proc expectArray(json: string; values: openArray[int]) =
      var doc = readJson(json)
      defer:
        doc.close()

      let arr = doc.root()
      check arr.isArray
      check arr.len == values.len

      if values.len == 0:
        check arr[0].isNil
        check arr.first().isNil
        check arr.last().isNil
      else:
        check arr.first().int() == values[0]
        check arr.last().int() == values[^1]
        for i, expected in values:
          check arr[i].int() == expected
          check arr.hasIndex(i)
        check arr[values.len].isNil
        check not arr.hasIndex(values.len)

      var idx = 0
      for item in arr.items:
        check item.int() == values[idx]
        inc idx
      check idx == values.len

    expectArray("[]", [])
    expectArray("[1]", [1])
    expectArray("[1,2]", [1, 2])
    expectArray("[1,2,3]", [1, 2, 3])

  test "json object upstream api matrix":
    proc expectObject(json: string; values: openArray[tuple[key: string, val: int]]) =
      var doc = readJson(json)
      defer:
        doc.close()

      let obj = doc.root()
      check obj.isObject
      check obj.len == values.len
      check obj["x"].isNil
      check obj[""].isNil
      check not obj.hasKey("x")
      check not obj.hasKey("")
      check obj.getInt("x", -1) == -1

      for item in values:
        check obj.hasKey(item.key)
        check obj[item.key].int() == item.val
        check obj.getInt(item.key) == item.val

      var seen: seq[string] = @[]
      for key, val in obj.pairs:
        let k = $key
        seen.add(k)
        var expected = 0
        var found = false
        for item in values:
          if item.key == k:
            expected = item.val
            found = true
            break
        check found
        check val.int() == expected

      check seen.len == values.len
      for item in values:
        check item.key in seen

    expectObject("{}", [])
    expectObject("""{"a":1}""", [("a", 1)])
    expectObject("""{"a":1,"b":2}""", [("a", 1), ("b", 2)])
    expectObject("""{"a":1,"b":2,"c":3}""", [("a", 1), ("b", 2), ("c", 3)])

  test "value equality and type helpers":
    let nilVal = JsonVal()
    check nilVal.typeDesc() == "unknown"
    check nilVal.len == 0
    check nilVal.int64() == 0
    check nilVal.uint64() == 0
    check nilVal.float() == 0.0
    check nilVal.num() == 0.0
    check nilVal.bool() == false
    check nilVal.str() == ""
    check not nilVal.equalsStr("")
    check not nilVal.equalsStrLen("", 0)

    var scalarDoc = readJson("""{
      "null": null,
      "true": true,
      "false": false,
      "uint": 123,
      "sint": -123,
      "real": 123.0,
      "str": "abc",
      "nulstr": "abc\u0000def",
      "arr": [],
      "obj": {}
    }""")
    defer:
      scalarDoc.close()

    let scalars = scalarDoc.root()
    check scalars["null"].isNull
    check scalars["null"].typeDesc() == "null"
    check scalars["true"].isBool
    check scalars["true"].isTrue
    check not scalars["true"].isFalse
    check scalars["true"].typeDesc() == "true"
    check scalars["true"].bool() == true
    check scalars["false"].isBool
    check scalars["false"].isFalse
    check not scalars["false"].isTrue
    check scalars["false"].typeDesc() == "false"
    check scalars["false"].bool() == false

    check scalars["uint"].isUInt
    check scalars["uint"].isInt
    check not scalars["uint"].isReal
    check scalars["uint"].typeDesc() == "uint"
    check scalars["uint"].uint64() == 123'u64
    check scalars["uint"].int64() == 123'i64
    check scalars["uint"].float() == 0.0
    check scalars["uint"].num() == 123.0

    check scalars["sint"].isSInt
    check scalars["sint"].isInt
    check scalars["sint"].typeDesc() == "sint"
    check scalars["sint"].uint64() == high(uint64) - 122'u64
    check scalars["sint"].int64() == -123'i64
    check scalars["sint"].float() == 0.0
    check scalars["sint"].num() == -123.0

    check scalars["real"].isReal
    check not scalars["real"].isInt
    check scalars["real"].typeDesc() == "real"
    check scalars["real"].uint64() == 0'u64
    check scalars["real"].int64() == 0'i64
    check scalars["real"].float() == 123.0
    check scalars["real"].num() == 123.0

    check scalars["str"].isString
    check scalars["str"].typeDesc() == "string"
    check scalars["str"].str() == "abc"
    check scalars["str"].strLen() == 3
    check scalars["str"].equalsStr("abc")
    check scalars["nulstr"].str() == "abc\0def"
    check scalars["nulstr"].strLen() == 7
    check not scalars["nulstr"].equalsStr("abc")
    check not scalars["nulstr"].equalsStrLen("abc", 3)
    check scalars["nulstr"].equalsStrLen("abc\0def", 7)

    check scalars["arr"].isArray
    check scalars["arr"].isContainer
    check scalars["arr"].typeDesc() == "array"
    check scalars["obj"].isObject
    check scalars["obj"].isContainer
    check scalars["obj"].typeDesc() == "object"

    var rawDoc = readJson("""{"n":12345}""", YYJSON_READ_NUMBER_AS_RAW)
    defer:
      rawDoc.close()

    let rawNum = rawDoc.root()["n"]
    check rawNum.isRaw
    check rawNum.raw() == "12345"
    check rawNum.rawLen() == 5

    var lhs = readJson("""{"a":1,"b":[true,null],"c":{"x":"y"}}""")
    defer:
      lhs.close()

    var rhs = readJson("""{"c":{"x":"y"},"b":[true,null],"a":1}""")
    defer:
      rhs.close()

    var different = readJson("""{"a":1,"b":[true,false],"c":{"x":"y"}}""")
    defer:
      different.close()

    check lhs.root()["a"].isInt
    check lhs.root()["a"].isUInt
    check not lhs.root()["a"].isReal
    check lhs.root()["c"]["x"].strLen() == 1
    check lhs.root()["c"]["x"].equalsStr("y")
    check lhs.root().equals(rhs.root())
    check lhs.root() == rhs.root()
    check not lhs.root().equals(different.root())

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

    var doc = readJson(mutDoc.writeJson())
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

  test "mutable dom clone":
    var src = readJsonMut("""{"a":[1],"obj":{"x":true}}""")
    defer:
      src.close()

    var docCopy = src.clone()
    defer:
      docCopy.close()
    docCopy.pointerSetStrict("/a/0", docCopy.newInt(2))
    check docCopy.writeJson() == """{"a":[2],"obj":{"x":true}}"""
    check src.writeJson() == """{"a":[1],"obj":{"x":true}}"""

    var imut = readJson("""{"obj":{"x":true},"other":1}""")
    defer:
      imut.close()
    var fromImmutable = newJsonMutDoc()
    defer:
      fromImmutable.close()
    fromImmutable.setRoot(fromImmutable.clone(imut.pointerStrict("/obj")))
    fromImmutable.pointerSetStrict("/x", fromImmutable.newBool(false))
    check fromImmutable.writeJson() == """{"x":false}"""
    check imut.writeJson() == """{"obj":{"x":true},"other":1}"""

    var fromMutable = newJsonMutDoc()
    defer:
      fromMutable.close()
    fromMutable.setRoot(fromMutable.clone(src.pointerStrict("/a")))
    fromMutable.root().add(fromMutable.newInt(3))
    check fromMutable.writeJson() == "[1,3]"
    check src.writeJson() == """{"a":[1],"obj":{"x":true}}"""

  test "mutable dom read navigate and mutate":
    var mutDoc = readJsonMut("""{"name":"redis","tags":["7.4","latest"],"n":3,"enabled":true,"drop":1}""")
    defer:
      mutDoc.close()

    let root = mutDoc.root()
    check root.isObject
    check root.len == 5
    check root["name"].str() == "redis"
    check root["tags"][0].str() == "7.4"
    check root["tags"][1].str() == "latest"
    check root["tags"].first().str() == "7.4"
    check root["tags"].last().str() == "latest"
    check root.pointer("/tags/1").str() == "latest"
    check root.getInt("n") == 3
    check root.getBool("enabled") == true

    check root["tags"].replace(0, mutDoc.newString("8.0")).str() == "7.4"
    check root["tags"].remove(1).str() == "latest"
    check root.replace("n", mutDoc.newInt(4))
    check root.remove("drop").int() == 1
    root.add("withNull", mutDoc.newString("a\0b"))

    var keys: seq[string] = @[]
    for k, v in root.pairs:
      keys.add($k)
      check not v.isNil
    check "name" in keys
    check "drop" notin keys

    var tags: seq[string] = @[]
    for tag in root["tags"].items:
      tags.add(tag.str())
    check tags == @["8.0"]

    var doc = readJson(mutDoc.writeJson())
    defer:
      doc.close()

    check doc.root()["tags"].len == 1
    check doc.root()["tags"][0].str() == "8.0"
    check doc.root()["n"].int() == 4
    check not doc.root().hasKey("drop")
    check doc.root()["withNull"].str() == "a\0b"
