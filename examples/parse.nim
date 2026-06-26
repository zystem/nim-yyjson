import yyjson

let doc = readJson("""{"name":"redis","tags":["7.4","latest"],"enabled":true}""")
defer:
  var d = doc
  d.close()

let root = doc.root()

echo root["name"].str()
echo root["enabled"].bool()

for tag in root["tags"].items:
  echo tag.str()
