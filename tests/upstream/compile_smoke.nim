include common

import yyjson

const SmokeJson = """{"str":"Harry","fp":0.5,"arr":[42,-42,null]}"""

suite "upstream yyjson compile smoke":
  test "public read and write API":
    var doc = readJson(SmokeJson)
    defer:
      doc.close()

    let root = doc.root()
    check root["str"].isString
    check root["str"].equalsStr("Harry")
    check root["fp"].isReal
    check root["fp"].float() == 0.5

    let arr = root["arr"]
    check arr.isArray
    check arr.len == 3
    check arr[0].int() == 42
    check arr[1].int() == -42
    check arr[2].isNull

    check doc.writeJson() == SmokeJson

  test "public mutable build API":
    var doc = newJsonMutDoc()
    defer:
      doc.close()

    let root = doc.newObject()
    root.add("str", doc.newString("Harry"))
    root.add("fp", doc.newFloat(0.5))

    let arr = doc.newArray()
    arr.add(doc.newInt(42))
    arr.add(doc.newInt(-42))
    arr.add(doc.newNull())
    root.add("arr", arr)
    doc.setRoot(root)

    check doc.writeJson() == SmokeJson
