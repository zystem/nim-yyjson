include common
import yyjson/private

suite "upstream yyjson reader writer":
  test "writer flags and files":
    var doc = readJson("""{"a":[1,2],"text":"é /","ok":true}""")
    defer:
      doc.close()

    check doc.writeJson() == """{"a":[1,2],"text":"é /","ok":true}"""
    check doc.root()["a"].writeJson() == "[1,2]"
    check doc.writeJson(YYJSON_WRITE_ESCAPE_UNICODE).contains("\\u00E9")
    check doc.writeJson(YYJSON_WRITE_ESCAPE_UNICODE or YYJSON_WRITE_LOWERCASE_HEX).contains("\\u00e9")
    check doc.writeJson(YYJSON_WRITE_ESCAPE_SLASHES).contains("\\/")
    check doc.writeJson(YYJSON_WRITE_NEWLINE_AT_END).endsWith("\n")

    check doc.writeJson(YYJSON_WRITE_PRETTY) ==
      "{\n" &
      "    \"a\": [\n" &
      "        1,\n" &
      "        2\n" &
      "    ],\n" &
      "    \"text\": \"é /\",\n" &
      "    \"ok\": true\n" &
      "}"
    check doc.writeJson(YYJSON_WRITE_PRETTY_TWO_SPACES) ==
      "{\n" &
      "  \"a\": [\n" &
      "    1,\n" &
      "    2\n" &
      "  ],\n" &
      "  \"text\": \"é /\",\n" &
      "  \"ok\": true\n" &
      "}"

    let path = getTempDir() / "nim_yyjson_writer_flags.json"
    if fileExists(path):
      removeFile(path)
    writeJsonFile(path, doc, YYJSON_WRITE_PRETTY_TWO_SPACES or YYJSON_WRITE_NEWLINE_AT_END)
    check readFile(path) == doc.writeJson(YYJSON_WRITE_PRETTY_TWO_SPACES or YYJSON_WRITE_NEWLINE_AT_END)
    removeFile(path)

    var mutDoc = readJsonMut("""{"a":[1,2],"text":"é /","ok":true}""")
    defer:
      mutDoc.close()

    check mutDoc.writeJson() == doc.writeJson()
    check mutDoc.root()["a"].writeJson() == "[1,2]"
    writeJsonFile(path, mutDoc, YYJSON_WRITE_PRETTY)
    check readFile(path) == mutDoc.writeJson(YYJSON_WRITE_PRETTY)
    removeFile(path)

  test "writer public API edge cases":
    block:
      var doc = readJson("[123]")
      defer:
        doc.close()
      var mutDoc = readJsonMut("[123]")
      defer:
        mutDoc.close()

      check doc.writeJson(YYJSON_WRITE_PRETTY_TWO_SPACES) ==
        "[\n" &
        "  123\n" &
        "]"
      check mutDoc.writeJson(YYJSON_WRITE_PRETTY_TWO_SPACES) ==
        doc.writeJson(YYJSON_WRITE_PRETTY_TWO_SPACES)

      check doc.writeJson(YYJSON_WRITE_NEWLINE_AT_END) == "[123]\n"
      check doc.root().writeJson(YYJSON_WRITE_NEWLINE_AT_END) == "[123]\n"
      check mutDoc.writeJson(YYJSON_WRITE_NEWLINE_AT_END) == "[123]\n"
      check mutDoc.root().writeJson(YYJSON_WRITE_NEWLINE_AT_END) == "[123]\n"

      check doc.writeJson(YYJSON_WRITE_PRETTY or YYJSON_WRITE_NEWLINE_AT_END) ==
        "[\n" &
        "    123\n" &
        "]\n"
      check mutDoc.writeJson(YYJSON_WRITE_PRETTY or YYJSON_WRITE_NEWLINE_AT_END) ==
        doc.writeJson(YYJSON_WRITE_PRETTY or YYJSON_WRITE_NEWLINE_AT_END)

    block:
      var doc = readJson("""{"slash":"/","accent":"é","nested":[{"ok":true}]}""")
      defer:
        doc.close()
      let flags = YYJSON_WRITE_ESCAPE_SLASHES or
                  YYJSON_WRITE_ESCAPE_UNICODE or
                  YYJSON_WRITE_LOWERCASE_HEX
      check doc.writeJson(flags) ==
        """{"slash":"\/","accent":"\u00e9","nested":[{"ok":true}]}"""
      check doc.root()["nested"].writeJson(YYJSON_WRITE_PRETTY_TWO_SPACES) ==
        "[\n" &
        "  {\n" &
        "    \"ok\": true\n" &
        "  }\n" &
        "]"

    block:
      var doc = newJsonMutDoc()
      defer:
        doc.close()
      let root = doc.newArray()
      let obj = doc.newObject()
      obj.add("message", doc.newString("hello"))
      obj.add("n", doc.newInt(42))
      root.add(obj)
      root.add(doc.newBool(false))
      doc.setRoot(root)

      let compact = """[{"message":"hello","n":42},false]"""
      check doc.writeJson() == compact
      check doc.root().writeJson() == compact

  test "writer errors":
    var infDoc = newJsonMutDoc()
    defer:
      infDoc.close()
    infDoc.setRoot(infDoc.newFloat(Inf))

    expectWriteError(YYJSON_WRITE_ERROR_NAN_OR_INF, proc () =
      discard infDoc.writeJson()
    )
    expectWriteError(YYJSON_WRITE_ERROR_NAN_OR_INF, proc () =
      discard infDoc.root().writeJson()
    )
    check infDoc.writeJson(YYJSON_WRITE_ALLOW_INF_AND_NAN) == "Infinity"
    check infDoc.writeJson(YYJSON_WRITE_INF_AND_NAN_AS_NULL) == "null"

    var invalidDoc = newJsonMutDoc()
    defer:
      invalidDoc.close()
    invalidDoc.setRoot(invalidDoc.newString("\x80"))

    expectWriteError(YYJSON_WRITE_ERROR_INVALID_STRING, proc () =
      discard invalidDoc.writeJson()
    )
    expectWriteError(YYJSON_WRITE_ERROR_INVALID_STRING, proc () =
      discard invalidDoc.root().writeJson()
    )
    check invalidDoc.writeJson(YYJSON_WRITE_ALLOW_INVALID_UNICODE).len > 0

  test "writer special real values":
    proc expectSpecial(value: float; allowed, nullified: string) =
      var doc = newJsonMutDoc()
      defer:
        doc.close()
      doc.setRoot(doc.newFloat(value))

      expectWriteError(YYJSON_WRITE_ERROR_NAN_OR_INF, proc () =
        discard doc.writeJson()
      )
      expectWriteError(YYJSON_WRITE_ERROR_NAN_OR_INF, proc () =
        discard doc.root().writeJson()
      )
      check doc.writeJson(YYJSON_WRITE_ALLOW_INF_AND_NAN) == allowed
      check doc.root().writeJson(YYJSON_WRITE_ALLOW_INF_AND_NAN) == allowed
      check doc.writeJson(YYJSON_WRITE_INF_AND_NAN_AS_NULL) == nullified
      check doc.root().writeJson(YYJSON_WRITE_INF_AND_NAN_AS_NULL) == nullified

    expectSpecial(Inf, "Infinity", "null")
    expectSpecial(NegInf, "-Infinity", "null")

    var nanDoc = newJsonMutDoc()
    defer:
      nanDoc.close()
    nanDoc.setRoot(nanDoc.newFloat(NaN))
    expectWriteError(YYJSON_WRITE_ERROR_NAN_OR_INF, proc () =
      discard nanDoc.writeJson()
    )
    check nanDoc.writeJson(YYJSON_WRITE_ALLOW_INF_AND_NAN) == "NaN"
    check nanDoc.writeJson(YYJSON_WRITE_INF_AND_NAN_AS_NULL) == "null"

  test "reader errors":
    expectReadError("", YYJSON_READ_ERROR_INVALID_PARAMETER, 0)
    expectReadError(" ", YYJSON_READ_ERROR_EMPTY_CONTENT, 0)
    expectReadError("\n\n\r\n", YYJSON_READ_ERROR_EMPTY_CONTENT, 0)

    expectReadError("[1]abc", YYJSON_READ_ERROR_UNEXPECTED_CONTENT, 3)
    expectReadError("[1],", YYJSON_READ_ERROR_UNEXPECTED_CONTENT, 3)
    expectReadError("[abc]", YYJSON_READ_ERROR_UNEXPECTED_CHARACTER, 1)
    expectReadError("inf", YYJSON_READ_ERROR_UNEXPECTED_CHARACTER, 0)
    expectReadError("[1,]", YYJSON_READ_ERROR_JSON_STRUCTURE, 2)
    expectReadError("""{"array":[1,],"integer":35}""", YYJSON_READ_ERROR_JSON_STRUCTURE, 11)

    let truncatedSingleValues = ["-", "-1.", "123.", "123e", "123e-", "123.1e", "123.1e-",
                                 "t", "tr", "tru", "f", "fa", "fal", "fals", "n", "nu", "nul"]
    for input in truncatedSingleValues:
      expectReadError(input, YYJSON_READ_ERROR_UNEXPECTED_END, input.len)
      if input[0].isAlphaAscii:
        expectReadError(input & " ", YYJSON_READ_ERROR_LITERAL, 0)
      else:
        expectReadError(input & " ", YYJSON_READ_ERROR_INVALID_NUMBER, input.len)

    for input in ["na", "-na", "in", "-in", "In", "-In", "infi", "-infi",
                  "Infi", "-Infi", "Infinit", "-Infinit"]:
      expectReadErrorNot(input, YYJSON_READ_ERROR_UNEXPECTED_END)
      expectReadError(input, YYJSON_READ_ERROR_UNEXPECTED_END, input.len,
                      YYJSON_READ_ALLOW_INF_AND_NAN)

    for input in ["[0]", "[\n  0\n]", "[123e4]", "[-123.4e-56]",
                  "\"Check\\u2705\\u00A9\\t2020\"",
                  "[[[{}]]]",
                  "{\"name\":\"Harry\",\"id\":123,\"star\":[1,2,3]}"]:
      for last in 1 ..< input.len:
        expectReadError(input[0 ..< last], YYJSON_READ_ERROR_UNEXPECTED_END, last)
      expectReadOk(input)

    expectReadError("-Infini", YYJSON_READ_ERROR_UNEXPECTED_END, "-Infini".len,
                    YYJSON_READ_ALLOW_INF_AND_NAN)

    expectReadError("123.e12", YYJSON_READ_ERROR_INVALID_NUMBER, 4)
    expectReadError("000", YYJSON_READ_ERROR_INVALID_NUMBER, 0)
    expectReadError("[01", YYJSON_READ_ERROR_INVALID_NUMBER, 1)
    expectReadError("[123.]", YYJSON_READ_ERROR_INVALID_NUMBER, 5)

    expectReadError("\"\\uD800\"", YYJSON_READ_ERROR_INVALID_STRING, 1)
    for input in ["\"\x01abcdefgh\"", "\"\xA0abcdefgh\"", "\"\xFFabcdefgh\""]:
      for last in 2 ..< 10:
        expectReadError(input[0 ..< last], YYJSON_READ_ERROR_INVALID_STRING, 1)

    expectReadError("\xEF\xBB\xBFabcde", YYJSON_READ_ERROR_UNEXPECTED_CHARACTER, 0)
    expectReadError("\xEF\xBB\xBFabcde", YYJSON_READ_ERROR_UNEXPECTED_CHARACTER, 3,
                    YYJSON_READ_ALLOW_BOM)

    expectReadError("[truu]", YYJSON_READ_ERROR_LITERAL, 1)
    expectReadError("truu", YYJSON_READ_ERROR_LITERAL, 0)
    expectReadError("nan", YYJSON_READ_ERROR_LITERAL, 0)

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

    try:
      discard readJsonFile(jsonDataRoot / "test_yyjson" / "comment_multiline_empty(fail).json")
      fail()
    except JsonReadError as e:
      check e.code == YYJSON_READ_ERROR_UNEXPECTED_CHARACTER
      check e.pos == 0
      check e.reason.len > 0

  test "locate pos":
    expectLocateFail("abc", -1)
    expectLocateFail("abc", 4)
    expectLocateFail("", 1)

    expectLocate("", 0, 1, 1, 0)
    expectLocate("\n", 0, 1, 1, 0)
    expectLocate("\n", 1, 2, 1, 1)
    expectLocate("\n\n", 1, 2, 1, 1)
    expectLocate("\n\n", 2, 3, 1, 2)

    let oneLine = "abc"
    for pos in 0 .. oneLine.len:
      expectLocate(oneLine, pos, 1, pos + 1, pos)

    let twoLines = "abc\ndef"
    for pos in 0 .. twoLines.len:
      if pos <= 3:
        expectLocate(twoLines, pos, 1, pos + 1, pos)
      else:
        expectLocate(twoLines, pos, 2, pos - 4 + 1, pos)

    let threeLines = "abc\ndef\nghijklmn"
    for pos in 0 .. threeLines.len:
      if pos <= 3:
        expectLocate(threeLines, pos, 1, pos + 1, pos)
      elif pos <= 7:
        expectLocate(threeLines, pos, 2, pos - 4 + 1, pos)
      else:
        expectLocate(threeLines, pos, 3, pos - 8 + 1, pos)

    let unicode = "abcé果😀"
    for pos in 0 .. unicode.len:
      var posUni = pos
      if pos >= 4 and pos <= 5:
        posUni = 4
      if pos >= 6 and pos <= 8:
        posUni = 5
      if pos >= 9 and pos <= 12:
        posUni = 6
      expectLocate(unicode, pos, 1, posUni + 1, posUni)

    let invalidUtf8 = "a\x80\xF8def"
    for pos in 0 .. invalidUtf8.len:
      expectLocate(invalidUtf8, pos, 1, pos + 1, pos)

    let withBom = "\xEF\xBB\xBFdef"
    for pos in 0 .. withBom.len:
      if pos < 3:
        expectLocate(withBom, pos, 1, (if pos == 0: 1 else: 2), (if pos == 0: 0 else: 1))
      else:
        let posUni = pos - 3
        expectLocate(withBom, pos, 1, posUni + 1, posUni)

  test "reader flags":
    expectReadError("[1,]", YYJSON_READ_ERROR_JSON_STRUCTURE, 2)
    expectReadOk("[1,]", YYJSON_READ_ALLOW_TRAILING_COMMAS)

    expectReadError("[1] trailing", YYJSON_READ_ERROR_UNEXPECTED_CONTENT, 4)
    expectReadOk("[1] trailing", YYJSON_READ_STOP_WHEN_DONE)

    expectReadError("[1]/*", YYJSON_READ_ERROR_UNEXPECTED_CONTENT, 3)
    expectReadError("[1]/*", YYJSON_READ_ERROR_UNEXPECTED_END, 5, YYJSON_READ_ALLOW_COMMENTS)
    expectReadOk("[1/* comment */]", YYJSON_READ_ALLOW_COMMENTS)

    expectReadError("\xEF\xBB\xBF[1]", YYJSON_READ_ERROR_UNEXPECTED_CHARACTER, 0)
    expectReadOk("\xEF\xBB\xBF[1]", YYJSON_READ_ALLOW_BOM)
    expectReadOk("\xEF\xBB\xBF[1]", YYJSON_READ_ALLOW_EXT_WHITESPACE)

    expectReadError("Infinity", YYJSON_READ_ERROR_UNEXPECTED_CHARACTER, 0)
    expectReadOk("Infinity", YYJSON_READ_ALLOW_INF_AND_NAN)
    expectReadOk("NaN", YYJSON_READ_ALLOW_INF_AND_NAN)
    expectReadOk("0x10", YYJSON_READ_ALLOW_EXT_NUMBER)
    expectReadOk("'abc'", YYJSON_READ_ALLOW_SINGLE_QUOTED_STR)
    expectReadOk("{abc:1}", YYJSON_READ_ALLOW_UNQUOTED_KEY)
    expectReadOk("{abc:'x', list:[0x10, Infinity,],}", YYJSON_READ_JSON5)

  test "doc metadata":
    var err: YyJsonReadErr
    let input = """{"name":"Harry","id":123,"star":[1,2,3]}"""
    let doc = yyjson_read_opts(input.cstring, input.len.csize_t, YYJSON_READ_NOFLAG,
                               nil, addr err)
    check not doc.isNil
    check err.code == YYJSON_READ_SUCCESS
    check yyjson_doc_get_read_size(doc) == input.len.csize_t
    check yyjson_doc_get_val_count(doc) > 0
    yyjson_doc_free(doc)

    err = YyJsonReadErr()
    let bad = "[1,]"
    let badDoc = yyjson_read_opts(bad.cstring, bad.len.csize_t, YYJSON_READ_NOFLAG,
                                  nil, addr err)
    check badDoc.isNil
    check err.code == YYJSON_READ_ERROR_JSON_STRUCTURE
    check yyjson_doc_get_read_size(badDoc) == 0.csize_t
    check yyjson_doc_get_val_count(badDoc) == 0.csize_t

  test "incremental reader":
    proc expectIncremental(input: string; flags: YyJsonReadFlag = YYJSON_READ_NOFLAG) =
      var err: YyJsonReadErr
      check yyjson_incr_read(nil, 1, addr err).isNil

      var invalidBuf = newSeq[char](input.len + 64)
      for i, ch in input:
        invalidBuf[i] = ch
      let incrFlags = flags or YYJSON_READ_INSITU
      let invalidState = yyjson_incr_new(cast[cstring](addr invalidBuf[0]),
                                         input.len.csize_t, incrFlags, nil)
      check not invalidState.isNil
      check yyjson_incr_read(invalidState, 0, addr err).isNil
      check yyjson_incr_read(invalidState, input.len.csize_t + 1, addr err).isNil
      yyjson_incr_free(invalidState)

      var buf = newSeq[char](input.len + 64)
      let state = yyjson_incr_new(cast[cstring](addr buf[0]), input.len.csize_t,
                                  incrFlags, nil)
      check not state.isNil

      var doc: ptr YyJsonDoc
      for readLen in 1 .. input.len:
        for i in 0 ..< readLen:
          buf[i] = input[i]
        err = YyJsonReadErr()
        doc = yyjson_incr_read(state, readLen.csize_t, addr err)
        if readLen < input.len:
          check doc.isNil
          check err.code == YYJSON_READ_ERROR_MORE
        else:
          check not doc.isNil
          check err.code == YYJSON_READ_SUCCESS
          check yyjson_doc_get_read_size(doc) == input.len.csize_t
          check yyjson_doc_get_val_count(doc) > 0
          let written = yyjson_write_opts(doc, YYJSON_WRITE_NOFLAG, nil, nil, nil)
          check not written.isNil
          c_free(written)

      yyjson_doc_free(doc)
      yyjson_incr_free(state)

    expectIncremental("""{"name":"Harry","id":123,"star":[1,2,3]}""")
    expectIncremental("[true,false,null,{\"x\":\"y\"}]")
    expectIncremental("[1,2,3]")

    var err: YyJsonReadErr
    let bad = "[1,]"
    let state = yyjson_incr_new(bad.cstring, bad.len.csize_t, YYJSON_READ_NOFLAG, nil)
    check not state.isNil
    let doc = yyjson_incr_read(state, bad.len.csize_t, addr err)
    check doc.isNil
    check err.code == YYJSON_READ_ERROR_JSON_STRUCTURE
    yyjson_incr_free(state)
