import std/[os]
import yyjson

proc main() =
  if paramCount() != 1:
    quit "Usage: harbor <vulnerabilities.json>", 2

  var doc = readJsonFile(paramStr(1))
  defer:
    doc.close()

  for _, report in doc.root().pairs:
    let vulns = report["vulnerabilities"]
    for v in vulns.items:
      echo v.getStr("id"), "\t", v.getStr("package"), "\t", v.getStr("version"), "\t", v.getStr("fix_version"), "\t", v.getStr("severity")

when isMainModule:
  main()
