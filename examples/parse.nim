import yyjson

proc main() =
  var doc = readJson("""{"name":"redis","tags":["7.4","latest"],"enabled":true}""")
  defer:
    doc.close()

  let root = doc.root()

  echo root["name"].str()
  echo root["enabled"].bool()

  for tag in root["tags"].items:
    echo tag.str()

when isMainModule:
  main()
