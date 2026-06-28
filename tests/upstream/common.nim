import std/[algorithm, math, os, strformat, strutils, unittest]
import yyjson

const
  upstreamDataRoot = currentSourcePath().parentDir().parentDir() / "data" / "yyjson"
  jsonDataRoot = upstreamDataRoot / "json"
  numDataRoot = upstreamDataRoot / "num"

type
  Summary = object
    passed: int
    failed: int
    skipped: int

proc jsonFiles(dir: string): seq[string] =
  for path in walkDirRec(dir):
    if path.endsWith(".json"):
      result.add(path)
  result.sort()

proc txtFiles(dir: string): seq[string] =
  for path in walkDirRec(dir):
    if path.endsWith(".txt"):
      result.add(path)
  result.sort()

proc rel(path: string): string =
  relativePath(path, upstreamDataRoot)

proc dataLines(path: string): seq[string] =
  for line in lines(path):
    let s = line.strip()
    if s.len > 0 and not s.startsWith("#"):
      result.add(s)

proc tryParseFile(path: string; flags: YyJsonReadFlag = YYJSON_READ_NOFLAG): bool =
  try:
    var doc = readJsonFile(path, flags)
    doc.close()
    true
  except JsonError:
    false

proc expectParse(path: string; shouldPass: bool; summary: var Summary;
                 flags: YyJsonReadFlag = YYJSON_READ_NOFLAG) =
  let ok = tryParseFile(path, flags)
  if ok == shouldPass:
    inc summary.passed
  else:
    inc summary.failed
    checkpoint(&"{rel(path)}: expected parse={shouldPass}, got parse={ok}, flags={flags}")

proc expectReadOk(input: string; flags: YyJsonReadFlag = YYJSON_READ_NOFLAG) =
  try:
    var doc = readJson(input, flags)
    doc.close()
  except JsonError as e:
    checkpoint(&"expected read success, got {e.name}: {e.msg}, flags={flags}, input={input}")
    fail()

proc expectReadError(input: string; code: YyJsonReadCode; pos: int;
                     flags: YyJsonReadFlag = YYJSON_READ_NOFLAG) =
  try:
    var doc = readJson(input, flags)
    doc.close()
    checkpoint(&"expected read error code={code}, pos={pos}, flags={flags}, input={input}")
    fail()
  except JsonReadError as e:
    check e.code == code
    check e.pos == pos
    check e.reason.len > 0
  except JsonError as e:
    checkpoint(&"expected JsonReadError, got {e.name}: {e.msg}, input={input}")
    fail()

proc expectReadErrorNot(input: string; code: YyJsonReadCode;
                        flags: YyJsonReadFlag = YYJSON_READ_NOFLAG) =
  try:
    var doc = readJson(input, flags)
    doc.close()
    checkpoint(&"expected read error not code={code}, flags={flags}, input={input}")
    fail()
  except JsonReadError as e:
    check e.code != code
    check e.reason.len > 0
  except JsonError as e:
    checkpoint(&"expected JsonReadError, got {e.name}: {e.msg}, input={input}")
    fail()

proc expectLocate(input: string; pos, line, col, chr: int) =
  var loc: JsonLocation
  check input.locatePos(pos, loc)
  check loc.line == line
  check loc.col == col
  check loc.chr == chr

proc expectLocateFail(input: string; pos: int) =
  var loc = JsonLocation(line: -1, col: -1, chr: -1)
  check not input.locatePos(pos, loc)
  check loc.line == 0
  check loc.col == 0
  check loc.chr == 0

proc quoteJsonStringBody(body: string; quote = '"'): string =
  result = newString(body.len + 2)
  result[0] = quote
  if body.len > 0:
    copyMem(addr result[1], unsafeAddr body[0], body.len)
  result[result.high] = quote

proc expectStringRead(body, expected: string;
                      flags: YyJsonReadFlag = YYJSON_READ_NOFLAG;
                      quote = '"') =
  var doc = readJson(quoteJsonStringBody(body, quote), flags)
  defer:
    doc.close()
  let root = doc.root()
  check root.isString
  check root.strLen == expected.len
  check root.str() == expected
  check root.equalsStr(expected)

proc expectStringRejected(body: string;
                          flags: YyJsonReadFlag = YYJSON_READ_NOFLAG) =
  try:
    var doc = readJson(quoteJsonStringBody(body), flags)
    doc.close()
    checkpoint(&"expected string read failure, flags={flags}, body={body}")
    fail()
  except JsonReadError as e:
    check e.reason.len > 0
  except JsonError as e:
    checkpoint(&"expected JsonReadError, got {e.name}: {e.msg}, body={body}")
    fail()

proc expectStringWrite(raw, expectedBody: string;
                       flags: YyJsonWriteFlag = YYJSON_WRITE_NOFLAG) =
  let expected = quoteJsonStringBody(expectedBody)

  var doc = newJsonMutDoc()
  defer:
    doc.close()
  doc.setRoot(doc.newString(raw))
  check doc.writeJson(flags) == expected

  var readDoc = readJson(expected, YYJSON_READ_ALLOW_INVALID_UNICODE)
  defer:
    readDoc.close()
  check readDoc.writeJson(flags) == expected

  var arrDoc = newJsonMutDoc()
  defer:
    arrDoc.close()
  let arr = arrDoc.newArray()
  arr.add(arrDoc.newString(raw))
  arrDoc.setRoot(arr)

  let expectedArray = "[" & expected & "]"
  check arrDoc.writeJson(flags) == expectedArray

  var readArrayDoc = readJson(expectedArray, YYJSON_READ_ALLOW_INVALID_UNICODE)
  defer:
    readArrayDoc.close()
  check readArrayDoc.writeJson(flags) == expectedArray

  let expectedPrettyArray = "[\n    " & expected & "\n]"
  check arrDoc.writeJson(flags or YYJSON_WRITE_PRETTY) == expectedPrettyArray

  var readPrettyArrayDoc = readJson(expectedPrettyArray, YYJSON_READ_ALLOW_INVALID_UNICODE)
  defer:
    readPrettyArrayDoc.close()
  check readPrettyArrayDoc.writeJson(flags or YYJSON_WRITE_PRETTY) == expectedPrettyArray

proc expectStringRoundtrip(raw, escapedBody: string;
                           readFlags: YyJsonReadFlag = YYJSON_READ_NOFLAG;
                           writeFlags: YyJsonWriteFlag = YYJSON_WRITE_NOFLAG) =
  expectStringRead(escapedBody, raw, readFlags)
  expectStringWrite(raw, escapedBody, writeFlags)

proc expectWriteError(code: YyJsonWriteCode; action: proc ()) =
  try:
    action()
    checkpoint(&"expected write error code={code}")
    fail()
  except JsonWriteError as e:
    check e.code == code
    check e.reason.len > 0
  except JsonError as e:
    checkpoint(&"expected JsonWriteError, got {e.name}: {e.msg}")
    fail()

proc expectPointerError(code: YyJsonPtrCode; pos: int; action: proc ()) =
  try:
    action()
    checkpoint(&"expected pointer error code={code}, pos={pos}")
    fail()
  except JsonPointerError as e:
    check e.code == code
    check e.pos == pos
    check e.reason.len > 0
  except JsonError as e:
    checkpoint(&"expected JsonPointerError, got {e.name}: {e.msg}")
    fail()

proc skip(summary: var Summary) =
  inc summary.skipped

proc runParsingSuite(): Summary =
  for path in jsonFiles(jsonDataRoot / "test_parsing"):
    let name = splitFile(path).name
    if name.startsWith("y_"):
      expectParse(path, true, result)
    elif name.startsWith("n_"):
      expectParse(path, false, result)
    else:
      skip(result)

proc runCheckerSuite(): Summary =
  for path in jsonFiles(jsonDataRoot / "test_checker"):
    let name = splitFile(path).name
    if "EXCLUDE" in name:
      skip(result)
    elif name.startsWith("pass"):
      expectParse(path, true, result)
    elif name.startsWith("fail"):
      expectParse(path, false, result)
    else:
      skip(result)

proc runTransformSuite(): Summary =
  for path in jsonFiles(jsonDataRoot / "test_transform"):
    expectParse(path, "invalid" notin splitFile(path).name, result)

proc runEncodingSuite(): Summary =
  for path in jsonFiles(jsonDataRoot / "test_encoding"):
    let name = splitFile(path).name
    expectParse(path, name == "utf8", result)
    if name == "utf8":
      expectParse(path, true, result, YYJSON_READ_ALLOW_BOM)
      expectParse(path, true, result, YYJSON_READ_ALLOW_EXT_WHITESPACE)
    elif name == "utf8bom":
      expectParse(path, true, result, YYJSON_READ_ALLOW_BOM)
      expectParse(path, true, result, YYJSON_READ_ALLOW_EXT_WHITESPACE)
    else:
      expectParse(path, false, result, YYJSON_READ_ALLOW_BOM)
      expectParse(path, false, result, YYJSON_READ_ALLOW_EXT_WHITESPACE)

proc runRoundtripSuite(): Summary =
  for path in jsonFiles(jsonDataRoot / "test_roundtrip"):
    try:
      var doc = readJsonFile(path)
      let outJson = doc.writeJson()
      doc.close()

      var doc2 = readJson(outJson)
      doc2.close()
      inc result.passed
    except JsonError:
      inc result.failed
      checkpoint(&"{rel(path)}: parse/write/parse failed")

proc yyjsonRelaxedFlags(name: string): YyJsonReadFlag =
  if "(garbage)" in name:
    result = result or YYJSON_READ_STOP_WHEN_DONE
  if "(bignum)" in name or "(bighex)" in name:
    result = result or YYJSON_READ_BIGNUM_AS_RAW
  if "(comma)" in name:
    result = result or YYJSON_READ_ALLOW_TRAILING_COMMAS
  if "(comment)" in name or "(endcomment)" in name:
    result = result or YYJSON_READ_ALLOW_COMMENTS
  if "(inf)" in name or "(nan)" in name:
    result = result or YYJSON_READ_ALLOW_INF_AND_NAN
  if "(str_err)" in name:
    result = result or YYJSON_READ_ALLOW_INVALID_UNICODE
  if "(bom)" in name:
    result = result or YYJSON_READ_ALLOW_BOM
  if "(ext_num)" in name:
    result = result or YYJSON_READ_ALLOW_EXT_NUMBER
  if "(ext_esc)" in name:
    result = result or YYJSON_READ_ALLOW_EXT_ESCAPE
  if "(ext_ws)" in name:
    result = result or YYJSON_READ_ALLOW_EXT_WHITESPACE
  if "(str_sq)" in name:
    result = result or YYJSON_READ_ALLOW_SINGLE_QUOTED_STR
  if "(str_uq)" in name:
    result = result or YYJSON_READ_ALLOW_UNQUOTED_KEY

proc runYyjsonSuite(): Summary =
  for path in jsonFiles(jsonDataRoot / "test_yyjson"):
    let name = splitFile(path).name
    let strictPass = "(" notin name
    expectParse(path, strictPass, result)

    let flags = yyjsonRelaxedFlags(name)
    let relaxedPass = "(fail)" notin name
    if flags != YYJSON_READ_NOFLAG:
      expectParse(path, relaxedPass, result, flags)

proc canParseNumber(s: string; flags: YyJsonReadFlag): bool =
  try:
    var doc = readJson(s, flags)
    let root = doc.root()
    result = root.isNumber or root.isRaw
    doc.close()
  except JsonError:
    result = false

proc expectNumberParse(path, num: string; shouldPass: bool; summary: var Summary;
                       flags: YyJsonReadFlag) =
  let ok = canParseNumber(num, flags)
  if ok == shouldPass:
    inc summary.passed
  else:
    inc summary.failed
    checkpoint(&"{rel(path)}: expected number parse={shouldPass}, got parse={ok}, num={num}, flags={flags}")

proc flagsForNumberFile(name: string): YyJsonReadFlag =
  if "(ext)" in name:
    result = result or YYJSON_READ_ALLOW_EXT_NUMBER
  if "(inf)" in name or name.startsWith("literal"):
    result = result or YYJSON_READ_ALLOW_INF_AND_NAN

proc runNumberSuite(): Summary =
  for path in txtFiles(numDataRoot):
    let name = splitFile(path).name
    let shouldCheckStrict = not name.startsWith("real_")
    let shouldPassStrict = "(fail)" notin name and "(ext)" notin name and
                           "(inf)" notin name and not name.startsWith("literal")
    let relaxedFlags =
      if "(ext)" in name:
        YYJSON_READ_NOFLAG
      else:
        flagsForNumberFile(name)
    let shouldPassRelaxed = "(fail)" notin name and
                            not (name.startsWith("hex") and "(big)" in name)
    for num in dataLines(path):
      if shouldCheckStrict:
        expectNumberParse(path, num, shouldPassStrict, result, YYJSON_READ_NOFLAG)
      if relaxedFlags != YYJSON_READ_NOFLAG:
        expectNumberParse(path, num, shouldPassRelaxed, result, relaxedFlags)
      if "(fail)" notin name:
        expectNumberParse(path, num, true, result,
                          flagsForNumberFile(name) or
                          YYJSON_READ_NUMBER_AS_RAW or YYJSON_READ_BIGNUM_AS_RAW)

proc checkSummary(name: string; summary: Summary) =
  echo &"{name}: passed={summary.passed} failed={summary.failed} skipped={summary.skipped}"
  checkpoint(&"{name}: passed={summary.passed} skipped={summary.skipped}")
  check summary.failed == 0
  check summary.passed > 0
