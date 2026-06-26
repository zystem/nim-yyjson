import std/[os]
import yyjson

if paramCount() != 1:
  quit "Usage: harbor <vulnerabilities.json>", 2

let doc = readJsonFile(paramStr(1))
defer:
  var d = doc
  d.close()

for _, report in doc.root().pairs:
  let vulns = report["vulnerabilities"]
  for v in vulns.items:
    echo v.getStr("id"), "\t", v.getStr("package"), "\t", v.getStr("version"), "\t", v.getStr("fix_version"), "\t", v.getStr("severity")
