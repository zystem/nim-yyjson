include common

suite "upstream yyjson pointer":
  test "json pointer get":
    let json =
      "{" &
      "\"foo\":[\"bar\",\"baz\"]," &
      "\"\":0," &
      "\"a/b\":1," &
      "\"c%d\":2," &
      "\"e^f\":3," &
      "\"g|h\":4," &
      "\"i\\\\j\":5," &
      "\"k\\\"l\":6," &
      "\" \":7," &
      "\"m~n\":8," &
      "\"a\\u0000bc\":9" &
      "}"
    var doc = readJson(json)
    defer:
      doc.close()

    check doc.pointer("").isObject
    check doc.root().pointer("").isObject
    check doc.pointer("/foo").len == 2
    check doc.pointer("/foo/0").str() == "bar"
    check doc.pointer("/").int() == 0
    check doc.pointer("/a~1b").int() == 1
    check doc.pointer("/c%d").int() == 2
    check doc.pointer("/e^f").int() == 3
    check doc.pointer("/g|h").int() == 4
    check doc.pointer("/i\\j").int() == 5
    check doc.pointer("/k\"l").int() == 6
    check doc.pointer("/ ").int() == 7
    check doc.pointer("/m~0n").int() == 8
    check doc.pointer("/a\0bc").int() == 9

    check doc.pointer("foo").isNil
    check doc.pointer("/foo/2").isNil
    check doc.pointer("/a~2b").isNil
    check doc.pointer("/missing").isNil

    var mutDoc = readJsonMut(json)
    defer:
      mutDoc.close()

    check mutDoc.pointer("").isObject
    check mutDoc.root().pointer("/foo/1").str() == "baz"
    check mutDoc.pointer("/a~1b").int() == 1
    check mutDoc.pointer("/m~0n").int() == 8
    check mutDoc.pointer("/a\0bc").int() == 9
    check mutDoc.pointer("/missing").isNil

  test "json pointer upstream get matrix":
    proc expectGet(src, path, expected: string) =
      var doc = readJson(src)
      defer:
        doc.close()
      check doc.pointerStrict(path).writeJson() == expected

      var mutDoc = readJsonMut(src)
      defer:
        mutDoc.close()
      check mutDoc.pointerStrict(path).writeJson() == expected

    proc expectGetLen(src, path: string; pathLen: int; expected: string) =
      var doc = readJson(src)
      defer:
        doc.close()
      check doc.pointerStrictLen(path, pathLen).writeJson() == expected
      check doc.root().pointerStrictLen(path, pathLen).writeJson() == expected

      var mutDoc = readJsonMut(src)
      defer:
        mutDoc.close()
      check mutDoc.pointerStrictLen(path, pathLen).writeJson() == expected
      check mutDoc.root().pointerStrictLen(path, pathLen).writeJson() == expected

    proc expectGetError(src, path: string; code: YyJsonPtrCode; pos: int) =
      var doc = readJson(src)
      defer:
        doc.close()
      expectPointerError(code, pos, proc () =
        discard doc.pointerStrict(path)
      )

      var mutDoc = readJsonMut(src)
      defer:
        mutDoc.close()
      expectPointerError(code, pos, proc () =
        discard mutDoc.pointerStrict(path)
      )

    expectGet("1", "", "1")
    expectGetError("1", "/", YYJSON_PTR_ERR_RESOLVE, 1)

    var emptyRoot = newJsonMutDoc()
    defer:
      emptyRoot.close()
    check emptyRoot.pointer("").isNil
    check emptyRoot.pointer("/a").isNil
    expectPointerError(YYJSON_PTR_ERR_NULL_ROOT, 0, proc () =
      discard emptyRoot.pointerStrict("")
    )
    expectPointerError(YYJSON_PTR_ERR_NULL_ROOT, 0, proc () =
      discard emptyRoot.pointerStrict("/a")
    )

    for path in ["a", "~"]:
      expectGetError("""{"a":[1,2,3]}""", path, YYJSON_PTR_ERR_SYNTAX, 0)
    for path in ["/~", "/a/~", "/a/~2", "/a/~/", "/a/~~"]:
      expectGetError("""{"a":[1,2,3]}""", path, YYJSON_PTR_ERR_SYNTAX,
                     if path == "/~": 1 else: 3)

    for path in ["/0", "/1", "/"]:
      expectGetError("[]", path, YYJSON_PTR_ERR_RESOLVE, 1)
    for path in ["/a/00", "/a/01", "/a/-1", "/a/ 1",
                 "/a/18446744073709551615"]:
      expectGetError("""{"a":[1,2,3]}""", path, YYJSON_PTR_ERR_RESOLVE, 3)
    for path in ["/a/0", "/a/-", "/a/1"]:
      expectGetError("""{"a":[]}""", path, YYJSON_PTR_ERR_RESOLVE, 3)

    expectGet("""{"a":[1]}""", "/a/0", "1")
    expectGet("""{"a":[1,2]}""", "/a/0", "1")
    expectGet("""{"a":[1,2]}""", "/a/1", "2")
    for path in ["/a/2", "/a/3", "/a/-"]:
      expectGetError("""{"a":[1,2]}""", path, YYJSON_PTR_ERR_RESOLVE, 3)
    expectGetError("""{"a":[1,[2,3,4]]}""", "/a/-/2",
                   YYJSON_PTR_ERR_RESOLVE, 3)
    expectGet("""{"a":[1,[2,3,4]]}""", "/a/1/2", "4")
    expectGetError("""{"a":[1,[2,3,4]]}""", "/a/0/2",
                   YYJSON_PTR_ERR_RESOLVE, 5)
    for path in ["/a/1/3", "/a/1/b"]:
      expectGetError("""{"a":[1,[2,3,4]]}""", path,
                     YYJSON_PTR_ERR_RESOLVE, 5)

    expectGetError("{}", "/a", YYJSON_PTR_ERR_RESOLVE, 1)
    expectGet("""{"a\u0000bc":1,"b":2}""", "/a\0bc", "1")
    expectGet("""{"a~b":1,"c":2}""", "/a~0b", "1")
    expectGetError("""{"a~b":1,"c":2}""", "/a~1b",
                   YYJSON_PTR_ERR_RESOLVE, 1)
    expectGet("""{"a/b":1,"c":2}""", "/a~1b", "1")
    expectGetError("""{"a/b":1,"c":2}""", "/a~0b",
                   YYJSON_PTR_ERR_RESOLVE, 1)
    expectGet("""{"a":1,"a":2,"b":3}""", "/a", "1")
    expectGet("""{"a":{"b":{"c":1}}}""", "/a/b/c", "1")
    expectGet("""{"a":{"b":{"c":1}}}""", "/a/b", """{"c":1}""")
    expectGetError("""{"a":{"b":{"c":1}}}""", "/a/c",
                   YYJSON_PTR_ERR_RESOLVE, 3)
    expectGetError("""{"a":{"b":{"c":1}}}""", "/a/b/d",
                   YYJSON_PTR_ERR_RESOLVE, 5)
    expectGetError("""{"a":{"b":{"c":1}}}""", "/a/b/c/d",
                   YYJSON_PTR_ERR_RESOLVE, 7)
    expectGetLen("""{"a":{"b":{"c":1}}}""", "/a/b/ignored", 4, """{"c":1}""")

  test "json pointer typed get":
    let json =
      "{" &
      "\"answer\":{\"to\":{\"life\":42}}," &
      "\"true\":true," &
      "\"-1\":-1," &
      "\"1\":1," &
      "\"0\":0," &
      "\"i64_max\":9223372036854775807," &
      "\"i64_max+\":9223372036854775808," &
      "\"zero\":0," &
      "\"pi\":3.14159," &
      "\"pistr\":\"3.14159\"" &
      "}"
    var doc = readJson(json)
    defer:
      doc.close()
    let root = doc.root()
    var boolValue: bool
    var realValue: float
    var sintValue: int64
    var uintValue: uint64
    var stringValue: string

    check root.pointerGetBool("/true", boolValue) and boolValue == true
    check root.pointerGetUInt64("/answer/to/life", uintValue) and uintValue == 42'u64
    check root.pointerGetInt64("/-1", sintValue) and sintValue == -1'i64
    check root.pointerGetInt64("/1", sintValue) and sintValue == 1'i64
    check root.pointerGetUInt64("/1", uintValue) and uintValue == 1'u64
    check root.pointerGetInt64("/0", sintValue) and sintValue == 0'i64
    check root.pointerGetUInt64("/0", uintValue) and uintValue == 0'u64
    check root.pointerGetInt64("/i64_max", sintValue) and sintValue == high(int64)
    check root.pointerGetUInt64("/i64_max", uintValue) and uintValue == system.uint64(high(int64))
    check root.pointerGetUInt64("/i64_max+", uintValue) and uintValue == 9223372036854775808'u64
    check root.pointerGetReal("/pi", realValue) and realValue == 3.14159
    check root.pointerGetNum("/-1", realValue) and realValue == -1.0
    check root.pointerGetNum("/zero", realValue) and realValue == 0.0
    check root.pointerGetNum("/answer/to/life", realValue) and realValue == 42.0
    check root.pointerGetNum("/pi", realValue) and realValue == 3.14159
    check root.pointerGetStr("/pistr", stringValue) and stringValue == "3.14159"

    check not root.pointerGetUInt64("/-1", uintValue)
    check not root.pointerGetInt64("/i64_max+", sintValue)
    check not root.pointerGetNum("/pistr", realValue)
    check not root.pointerGetStr("/answer/to", stringValue)
    check not root.pointerGetUInt64("/nosuch", uintValue)
    check not root.pointerGetInt64("/nosuch", sintValue)
    check not root.pointerGetReal("/nosuch", realValue)

    check not root.pointerGetBool("/pi", boolValue)
    check not root.pointerGetUInt64("/pi", uintValue)
    check not root.pointerGetInt64("/pi", sintValue)
    check not root.pointerGetReal("/zero", realValue)
    check not root.pointerGetNum("/true", realValue)
    check not root.pointerGetStr("/pi", stringValue)

  test "mutable json pointer operations":
    var doc = readJsonMut("""{"foo":["bar"],"obj":{"a":1},"a/b":1,"m~n":8}""")
    defer:
      doc.close()

    check doc.pointerAdd("/foo/1", doc.newString("baz"))
    check doc.pointer("/foo/0").str() == "bar"
    check doc.pointer("/foo/1").str() == "baz"

    check doc.pointerAdd("/created/path", doc.newInt(3))
    check doc.pointer("/created/path").int() == 3

    check doc.pointerSet("/obj/a", doc.newInt(2))
    check doc.pointer("/obj/a").int() == 2

    let old = doc.pointerReplace("/obj/a", doc.newInt(4))
    check old.int() == 2
    check doc.pointer("/obj/a").int() == 4

    check doc.pointerRemove("/a~1b").int() == 1
    check doc.pointer("/a~1b").isNil

    let root = doc.root()
    check root.pointerAdd("/foo/0", doc.newString("first"))
    check root.pointer("/foo/0").str() == "first"
    check root.pointer("/foo/1").str() == "bar"

    check root.pointerSet("/m~0n", doc.newInt(9))
    check root.pointer("/m~0n").int() == 9

    check root.pointerRemove("/created/path").int() == 3
    check root.pointer("/created/path").isNil

    check not doc.pointerAdd("bad/path", doc.newInt(1))
    check doc.pointerReplace("/missing", doc.newInt(1)).isNil
    check doc.pointerRemove("/missing").isNil

    var empty = newJsonMutDoc()
    defer:
      empty.close()
    check empty.pointerSet("", empty.newObject())
    check empty.pointer("").isObject
    check empty.pointerAdd("/answer", empty.newInt(42))
    check empty.pointer("/answer").int() == 42

  test "json pointer strict errors":
    var doc = readJson("""{"foo":["bar"],"obj":{"a":1}}""")
    defer:
      doc.close()

    check doc.pointerStrict("").isObject
    check doc.root().pointerStrict("/foo/0").str() == "bar"
    expectPointerError(YYJSON_PTR_ERR_SYNTAX, 0, proc () =
      discard doc.pointerStrict("foo")
    )
    expectPointerError(YYJSON_PTR_ERR_SYNTAX, 1, proc () =
      discard doc.pointerStrict("/~2")
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      discard doc.pointerStrict("/missing")
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 5, proc () =
      discard doc.pointerStrict("/foo/2")
    )

    var mutDoc = readJsonMut("""{"foo":["bar"],"obj":{"a":1}}""")
    defer:
      mutDoc.close()

    check mutDoc.pointerStrict("").isObject
    check mutDoc.root().pointerStrict("/obj/a").int() == 1
    expectPointerError(YYJSON_PTR_ERR_SYNTAX, 0, proc () =
      discard mutDoc.pointerStrict("foo")
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 5, proc () =
      discard mutDoc.pointerStrict("/foo/2")
    )

  test "mutable json pointer strict operations":
    var doc = readJsonMut("""{"foo":["bar"],"obj":{"a":1}}""")
    defer:
      doc.close()

    doc.pointerAddStrict("/foo/1", doc.newString("baz"))
    check doc.pointerStrict("/foo/0").str() == "bar"
    check doc.pointerStrict("/foo/1").str() == "baz"

    doc.pointerSetStrict("/created/path", doc.newInt(3))
    check doc.pointerStrict("/created/path").int() == 3

    let old = doc.pointerReplaceStrict("/obj/a", doc.newInt(2))
    check old.int() == 1
    check doc.pointerStrict("/obj/a").int() == 2

    check doc.pointerRemoveStrict("/created/path").int() == 3
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 9, proc () =
      discard doc.pointerStrict("/created/path")
    )

    let root = doc.root()
    root.pointerAddStrict("/foo/0", doc.newString("first"))
    check root.pointerStrict("/foo/0").str() == "first"
    check root.pointerStrict("/foo/1").str() == "bar"

    root.pointerSetStrict("/obj/b", doc.newInt(5))
    check root.pointerStrict("/obj/b").int() == 5

    expectPointerError(YYJSON_PTR_ERR_SYNTAX, 0, proc () =
      doc.pointerAddStrict("bad/path", doc.newInt(1))
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      discard doc.pointerReplaceStrict("/missing", doc.newInt(1))
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      discard doc.pointerRemoveStrict("/missing")
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      doc.pointerSetStrict("/no/parent", doc.newInt(1), createParent = false)
    )

  test "mutable json pointer context operations":
    var doc = readJsonMut("""{"a":[0,1,null],"obj":{"x":1}}""")
    defer:
      doc.close()

    var ctx: JsonPointerContext
    check doc.pointerStrict("/a/2", ctx).isNull
    check ctx.container().isArray
    check ctx.remove().isNull
    check doc.pointerStrict("/a").len == 2

    check doc.pointerStrict("/a/1", ctx).int() == 1
    check ctx.replace(doc.newInt(42)).int() == 1
    check doc.pointerStrict("/a/1").int() == 42
    check ctx.old().int() == 1

    check doc.pointerStrict("/a/1", ctx).int() == 42
    check ctx.append(doc.newInt(7))
    check doc.pointerStrict("/a/2").int() == 7

    check doc.pointerStrict("/obj/x", ctx).int() == 1
    check ctx.append("y", doc.newInt(2))
    check doc.pointerStrict("/obj/y").int() == 2

  test "json pointer upstream context matrix":
    proc expectCtxAppend(src, path: string; val: int; dst: string;
                         pre = "") =
      var doc = readJsonMut(src)
      defer:
        doc.close()
      var ctx: JsonPointerContext
      discard doc.pointer(path, ctx)
      check ctx.append(doc.newInt(val))
      check doc.writeJson() == dst
      if pre.len > 0:
        check ctx.previous().writeJson() == pre

    proc expectCtxAppendKey(src, path, key: string; val: int; dst: string;
                            pre = "") =
      var doc = readJsonMut(src)
      defer:
        doc.close()
      var ctx: JsonPointerContext
      discard doc.pointer(path, ctx)
      check ctx.append(key, doc.newInt(val))
      check doc.writeJson() == dst
      if pre.len > 0:
        check ctx.previous().writeJson() == pre

    proc expectCtxAppendFails(src, path: string; val: int; ctn = "") =
      var doc = readJsonMut(src)
      defer:
        doc.close()
      var ctx: JsonPointerContext
      discard doc.pointer(path, ctx)
      check not ctx.append(doc.newInt(val))
      check doc.writeJson() == src
      if ctn.len > 0:
        check ctx.container().writeJson() == ctn

    proc expectCtxReplace(src, path: string; val: int; dst, old: string;
                          pre = "") =
      var doc = readJsonMut(src)
      defer:
        doc.close()
      var ctx: JsonPointerContext
      discard doc.pointer(path, ctx)
      check ctx.replace(doc.newInt(val)).writeJson() == old
      check doc.writeJson() == dst
      if pre.len > 0:
        check ctx.previous().writeJson() == pre
      check ctx.old().writeJson() == old

    proc expectCtxReplaceFails(src, path: string; val: int; ctn = "") =
      var doc = readJsonMut(src)
      defer:
        doc.close()
      var ctx: JsonPointerContext
      discard doc.pointer(path, ctx)
      check ctx.replace(doc.newInt(val)).isNil
      check doc.writeJson() == src
      if ctn.len > 0:
        check ctx.container().writeJson() == ctn

    proc expectCtxRemove(src, path, dst, old: string; ctn = "") =
      var doc = readJsonMut(src)
      defer:
        doc.close()
      var ctx: JsonPointerContext
      discard doc.pointer(path, ctx)
      check ctx.remove().writeJson() == old
      check doc.writeJson() == dst
      check ctx.old().writeJson() == old
      if ctn.len > 0:
        check ctx.container().writeJson() == ctn

    proc expectCtxRemoveFails(src, path: string; ctn = "") =
      var doc = readJsonMut(src)
      defer:
        doc.close()
      var ctx: JsonPointerContext
      discard doc.pointer(path, ctx)
      check ctx.remove().isNil
      check doc.writeJson() == src
      if ctn.len > 0:
        check ctx.container().writeJson() == ctn

    expectCtxAppend("[]", "/0", 1, "[1]", "1")
    expectCtxReplaceFails("[]", "/0", 1, "[]")
    expectCtxRemoveFails("[]", "/0", "[]")

    expectCtxAppend("[1]", "/0", 2, "[1,2]", "1")
    expectCtxReplace("[1]", "/0", 2, "[2]", "1", "2")
    expectCtxRemove("[1]", "/0", "[]", "1", "[]")

    expectCtxAppend("[1]", "/1", 2, "[1,2]", "1")
    expectCtxReplaceFails("[1]", "/1", 2, "[1]")
    expectCtxRemoveFails("[1]", "/1", "[1]")

    expectCtxAppend("[1,2]", "/0", 3, "[1,3,2]", "1")
    expectCtxReplace("[1,2]", "/0", 3, "[3,2]", "1", "2")
    expectCtxRemove("[1,2]", "/0", "[2]", "1", "[2]")

    expectCtxAppend("[1,2]", "/1", 3, "[1,2,3]", "2")
    expectCtxReplace("[1,2]", "/1", 3, "[1,3]", "2", "1")
    expectCtxRemove("[1,2]", "/1", "[1]", "2", "[1]")

    expectCtxAppend("[1,2]", "/2", 3, "[1,2,3]", "2")
    expectCtxReplaceFails("[1,2]", "/2", 3, "[1,2]")
    expectCtxRemoveFails("[1,2]", "/2", "[1,2]")

    expectCtxAppendKey("{}", "/a", "a", 1, """{"a":1}""", "\"a\"")
    expectCtxReplaceFails("{}", "/a", 1, "{}")
    expectCtxRemoveFails("{}", "/a", "{}")

    expectCtxAppendKey("""{"a":1}""", "/a", "b", 2, """{"a":1,"b":2}""",
                       "\"a\"")
    expectCtxReplace("""{"a":1}""", "/a", 2, """{"a":2}""", "1", "\"a\"")
    expectCtxRemove("""{"a":1}""", "/a", "{}", "1", "{}")

    expectCtxAppendKey("""{"a":1}""", "/b", "b", 2, """{"a":1,"b":2}""",
                       "\"a\"")
    expectCtxReplaceFails("""{"a":1}""", "/b", 2, """{"a":1}""")
    expectCtxRemoveFails("""{"a":1}""", "/b", """{"a":1}""")

    expectCtxAppendKey("""{"a":1,"b":2}""", "/a", "c", 3,
                       """{"a":1,"c":3,"b":2}""", "\"a\"")
    expectCtxReplace("""{"a":1,"b":2}""", "/a", 3,
                     """{"a":3,"b":2}""", "1", "\"b\"")
    expectCtxRemove("""{"a":1,"b":2}""", "/a", """{"b":2}""", "1",
                    """{"b":2}""")

    expectCtxAppendKey("""{"a":1,"b":2}""", "/b", "c", 3,
                       """{"a":1,"b":2,"c":3}""", "\"b\"")
    expectCtxReplace("""{"a":1,"b":2}""", "/b", 3,
                     """{"a":1,"b":3}""", "2", "\"a\"")
    expectCtxRemove("""{"a":1,"b":2}""", "/b", """{"a":1}""", "2",
                    """{"a":1}""")

    expectCtxAppendKey("""{"a":1,"b":2}""", "/c", "c", 3,
                       """{"a":1,"b":2,"c":3}""", "\"b\"")
    expectCtxReplaceFails("""{"a":1,"b":2}""", "/c", 3, """{"a":1,"b":2}""")
    expectCtxRemoveFails("""{"a":1,"b":2}""", "/c", """{"a":1,"b":2}""")
    expectCtxAppendFails("""{"a":1}""", "/b", 2, """{"a":1}""")

  test "json pointer upstream put matrix":
    var empty = newJsonMutDoc()
    defer:
      empty.close()

    empty.pointerSetStrict("/a", empty.newInt(1))
    check empty.writeJson() == """{"a":1}"""

    var rootOps = readJsonMut("[1,2]")
    defer:
      rootOps.close()

    expectPointerError(YYJSON_PTR_ERR_SET_ROOT, 0, proc () =
      rootOps.pointerAddStrict("", rootOps.newInt(3))
    )
    rootOps.pointerSetStrict("", rootOps.newInt(3))
    check rootOps.writeJson() == "3"

    var replaceRoot = readJsonMut("[1,2]")
    defer:
      replaceRoot.close()
    check replaceRoot.pointerReplaceStrict("", replaceRoot.newInt(3)).len == 2
    check replaceRoot.writeJson() == "3"

    var removeRoot = readJsonMut("[1,2]")
    defer:
      removeRoot.close()
    check removeRoot.pointerRemoveStrict("").len == 2
    check removeRoot.root().isNil

    var arr0 = readJsonMut("[]")
    defer:
      arr0.close()
    arr0.pointerAddStrict("/0", arr0.newInt(1))
    check arr0.writeJson() == "[1]"

    var arrDash = readJsonMut("[]")
    defer:
      arrDash.close()
    arrDash.pointerAddStrict("/-", arrDash.newInt(1))
    check arrDash.writeJson() == "[1]"

    var arr = readJsonMut("[1,2]")
    defer:
      arr.close()
    arr.pointerAddStrict("/0", arr.newInt(0))
    check arr.writeJson() == "[0,1,2]"
    arr.pointerAddStrict("/3", arr.newInt(3))
    check arr.writeJson() == "[0,1,2,3]"
    arr.pointerAddStrict("/-", arr.newInt(4))
    check arr.writeJson() == "[0,1,2,3,4]"
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      arr.pointerAddStrict("/6", arr.newInt(6))
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      discard arr.pointerReplaceStrict("/5", arr.newInt(5))
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      discard arr.pointerRemoveStrict("/5")
    )

    var created = newJsonMutDoc()
    defer:
      created.close()
    created.pointerAddStrict("/a/0", created.newInt(1))
    check created.writeJson() == """{"a":{"0":1}}"""

    var escaped = readJsonMut("""{"a/b":1,"m~n":2}""")
    defer:
      escaped.close()
    escaped.pointerSetStrict("/a~1b", escaped.newInt(10))
    escaped.pointerSetStrict("/m~0n", escaped.newInt(20))
    check escaped.pointerStrict("/a~1b").int() == 10
    check escaped.pointerStrict("/m~0n").int() == 20

    var ctxDoc = readJsonMut("[1,2]")
    defer:
      ctxDoc.close()
    var ctx: JsonPointerContext
    check ctxDoc.pointerStrict("/0", ctx).int() == 1
    check ctx.append(ctxDoc.newInt(3))
    check ctxDoc.writeJson() == "[1,3,2]"
    check ctxDoc.pointerStrict("/1", ctx).int() == 3
    check ctx.replace(ctxDoc.newInt(4)).int() == 3
    check ctxDoc.writeJson() == "[1,4,2]"
    check ctxDoc.pointerStrict("/1", ctx).int() == 4
    check ctx.remove().int() == 4
    check ctxDoc.writeJson() == "[1,2]"

    var noParent = readJsonMut("{}")
    defer:
      noParent.close()
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      noParent.pointerAddStrict("/a/0", noParent.newInt(1), createParent = false)
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      noParent.pointerSetStrict("/a/0", noParent.newInt(1), createParent = false)
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      discard noParent.pointerReplaceStrict("/a/0", noParent.newInt(1))
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      discard noParent.pointerRemoveStrict("/a/0")
    )

    var deepCreated = readJsonMut("{}")
    defer:
      deepCreated.close()
    deepCreated.pointerAddStrict("/a/0/b", deepCreated.newInt(1))
    check deepCreated.writeJson() == """{"a":{"0":{"b":1}}}"""

    var arrayParent = readJsonMut("[]")
    defer:
      arrayParent.close()
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      arrayParent.pointerAddStrict("/a/0", arrayParent.newInt(1))
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      arrayParent.pointerSetStrict("/a/0", arrayParent.newInt(1))
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      discard arrayParent.pointerReplaceStrict("/a/0", arrayParent.newInt(1))
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      discard arrayParent.pointerRemoveStrict("/a/0")
    )
    expectPointerError(YYJSON_PTR_ERR_SYNTAX, 3, proc () =
      arrayParent.pointerAddStrict("/-/~2", arrayParent.newInt(1))
    )

    var scalarParent = readJsonMut("[1]")
    defer:
      scalarParent.close()
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 3, proc () =
      scalarParent.pointerAddStrict("/0/a", scalarParent.newInt(1))
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 3, proc () =
      scalarParent.pointerSetStrict("/0/a", scalarParent.newInt(1))
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 3, proc () =
      discard scalarParent.pointerReplaceStrict("/0/a", scalarParent.newInt(1))
    )
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 3, proc () =
      discard scalarParent.pointerRemoveStrict("/0/a")
    )

    var lenDoc = readJsonMut("""{"a":1,"b":2}""")
    defer:
      lenDoc.close()
    lenDoc.pointerSetStrictLen("/a/ignored", 2, lenDoc.newInt(10))
    check lenDoc.writeJson() == """{"a":10,"b":2}"""
    lenDoc.pointerAddStrictLen("/c/ignored", 2, lenDoc.newInt(3))
    check lenDoc.writeJson() == """{"a":10,"b":2,"c":3}"""
    check lenDoc.pointerReplaceStrictLen("/b/ignored", 2, lenDoc.newInt(20)).int() == 2
    check lenDoc.writeJson() == """{"a":10,"b":20,"c":3}"""
    check lenDoc.pointerRemoveStrictLen("/c/ignored", 2).int() == 3
    check lenDoc.writeJson() == """{"a":10,"b":20}"""

    var lenRoot = readJsonMut("""{"a":1}""")
    defer:
      lenRoot.close()
    let embeddedPath = "/a" & "\0" & "/ignored"
    check lenRoot.pointerCString(embeddedPath.cstring).int() == 1
    check lenRoot.pointerLen(embeddedPath, embeddedPath.len).isNil
    lenRoot.root().pointerSetStrictLen(embeddedPath, 2, lenRoot.newInt(2))
    check lenRoot.writeJson() == """{"a":2}"""
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      lenRoot.root().pointerSetStrictLen(embeddedPath, embeddedPath.len,
                                        lenRoot.newInt(3), createParent = false)
    )
    expect(ValueError):
      lenRoot.pointerAddStrictLen("/a", 3, lenRoot.newInt(4))

    var plainOps = readJsonMut("""{"a":1}""")
    defer:
      plainOps.close()
    check plainOps.pointerSetCString(embeddedPath.cstring, plainOps.newInt(3))
    check plainOps.writeJson() == """{"a":3}"""
    check plainOps.pointerAddCString(("/b" & "\0" & "/ignored").cstring,
                                     plainOps.newInt(4))
    check plainOps.writeJson() == """{"a":3,"b":4}"""
    check plainOps.root().pointerReplaceCString(("/a" & "\0" & "/ignored").cstring,
                                                plainOps.newInt(5)).int() == 3
    check plainOps.writeJson() == """{"a":5,"b":4}"""
    check plainOps.root().pointerRemoveCString(("/b" & "\0" & "/ignored").cstring).int() == 4
    check plainOps.writeJson() == """{"a":5}"""

    var objCtx = readJsonMut("""{"a":1,"b":2}""")
    defer:
      objCtx.close()
    check objCtx.pointerStrict("/a", ctx).int() == 1
    check ctx.append("c", objCtx.newInt(3))
    check objCtx.writeJson() == """{"a":1,"c":3,"b":2}"""
    check objCtx.pointerStrict("/a", ctx).int() == 1
    check ctx.replace(objCtx.newInt(4)).int() == 1
    check objCtx.writeJson() == """{"a":4,"c":3,"b":2}"""
    check objCtx.pointerStrict("/b", ctx).int() == 2
    check ctx.remove().int() == 2
    check objCtx.writeJson() == """{"a":4,"c":3}"""

    var missingObjCtx = readJsonMut("""{"a":1}""")
    defer:
      missingObjCtx.close()
    expectPointerError(YYJSON_PTR_ERR_RESOLVE, 1, proc () =
      discard missingObjCtx.pointerStrict("/b", ctx)
    )
    check ctx.append("b", missingObjCtx.newInt(2))
    check missingObjCtx.writeJson() == """{"a":1,"b":2}"""
