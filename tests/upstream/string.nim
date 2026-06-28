include common

suite "upstream yyjson string":
  test "string read write upstream matrix":
    type StringCase = object
      raw: string
      escNon: string
      escSlash: string
      escUnicode: string
      escAll: string

    let cases = [
      StringCase(raw: "", escNon: "", escSlash: "", escUnicode: "", escAll: ""),
      StringCase(raw: "a", escNon: "a", escSlash: "a", escUnicode: "a", escAll: "a"),
      StringCase(raw: "abc", escNon: "abc", escSlash: "abc", escUnicode: "abc", escAll: "abc"),
      StringCase(raw: "\0", escNon: "\\u0000", escSlash: "\\u0000",
                 escUnicode: "\\u0000", escAll: "\\u0000"),
      StringCase(raw: "abc\0", escNon: "abc\\u0000", escSlash: "abc\\u0000",
                 escUnicode: "abc\\u0000", escAll: "abc\\u0000"),
      StringCase(raw: "\0abc", escNon: "\\u0000abc", escSlash: "\\u0000abc",
                 escUnicode: "\\u0000abc", escAll: "\\u0000abc"),
      StringCase(raw: "abc\0def", escNon: "abc\\u0000def", escSlash: "abc\\u0000def",
                 escUnicode: "abc\\u0000def", escAll: "abc\\u0000def"),
      StringCase(raw: "a\\b", escNon: "a\\\\b", escSlash: "a\\\\b",
                 escUnicode: "a\\\\b", escAll: "a\\\\b"),
      StringCase(raw: "a/b", escNon: "a/b", escSlash: "a\\/b",
                 escUnicode: "a/b", escAll: "a\\/b"),
      StringCase(raw: "\"\\/\b\f\n\r\t", escNon: "\\\"\\\\/\\b\\f\\n\\r\\t",
                 escSlash: "\\\"\\\\\\/\\b\\f\\n\\r\\t",
                 escUnicode: "\\\"\\\\/\\b\\f\\n\\r\\t",
                 escAll: "\\\"\\\\\\/\\b\\f\\n\\r\\t"),
      StringCase(raw: "Alizée", escNon: "Alizée", escSlash: "Alizée",
                 escUnicode: "Aliz\\u00E9e", escAll: "Aliz\\u00E9e"),
      StringCase(raw: "Hello世界", escNon: "Hello世界", escSlash: "Hello世界",
                 escUnicode: "Hello\\u4E16\\u754C", escAll: "Hello\\u4E16\\u754C"),
      StringCase(raw: "Emoji😊", escNon: "Emoji😊", escSlash: "Emoji😊",
                 escUnicode: "Emoji\\uD83D\\uDE0A", escAll: "Emoji\\uD83D\\uDE0A"),
      StringCase(raw: "🐱\t🐶", escNon: "🐱\\t🐶", escSlash: "🐱\\t🐶",
                 escUnicode: "\\uD83D\\uDC31\\t\\uD83D\\uDC36",
                 escAll: "\\uD83D\\uDC31\\t\\uD83D\\uDC36"),
      StringCase(raw: "Check✅©\t2020®яблоко////แอปเปิ้ล\\\\リンゴ|تفاحة|蘋果|사과|",
                 escNon: "Check✅©\\t2020®яблоко////แอปเปิ้ล\\\\\\\\リンゴ|تفاحة|蘋果|사과|",
                 escSlash: "Check✅©\\t2020®яблоко\\/\\/\\/\\/แอปเปิ้ล\\\\\\\\リンゴ|تفاحة|蘋果|사과|",
                 escUnicode: "Check\\u2705\\u00A9\\t2020\\u00AE\\u044F\\u0431\\u043B\\u043E\\u043A\\u043E////\\u0E41\\u0E2D\\u0E1B\\u0E40\\u0E1B\\u0E34\\u0E49\\u0E25\\\\\\\\\\u30EA\\u30F3\\u30B4|\\u062A\\u0641\\u0627\\u062D\\u0629|\\u860B\\u679C|\\uC0AC\\uACFC|\\uF8FF",
                 escAll: "Check\\u2705\\u00A9\\t2020\\u00AE\\u044F\\u0431\\u043B\\u043E\\u043A\\u043E\\/\\/\\/\\/\\u0E41\\u0E2D\\u0E1B\\u0E40\\u0E1B\\u0E34\\u0E49\\u0E25\\\\\\\\\\u30EA\\u30F3\\u30B4|\\u062A\\u0641\\u0627\\u062D\\u0629|\\u860B\\u679C|\\uC0AC\\uACFC|\\uF8FF")
    ]

    for item in cases:
      for body in [item.escNon, item.escSlash, item.escUnicode, item.escAll]:
        expectStringRead(body, item.raw)
        expectStringRead(body, item.raw, YYJSON_READ_ALLOW_INVALID_UNICODE)

      expectStringWrite(item.raw, item.escNon)
      expectStringWrite(item.raw, item.escSlash, YYJSON_WRITE_ESCAPE_SLASHES)
      expectStringWrite(item.raw, item.escUnicode, YYJSON_WRITE_ESCAPE_UNICODE)
      expectStringWrite(item.raw, item.escAll,
                        YYJSON_WRITE_ESCAPE_UNICODE or YYJSON_WRITE_ESCAPE_SLASHES)

    expectStringRead("Hello\\u4e16\\u754c", "Hello世界")

    var randStr = ""
    for i in 0 ..< 64:
      randStr.add(char(ord('a') + (i mod 26)))
    for len in 1 .. 64:
      let s = randStr[0 ..< len]
      expectStringRoundtrip(s, s)

    for len in 0 .. 64:
      let suffix = randStr[0 ..< len]
      expectStringRoundtrip("\t" & suffix, "\\t" & suffix)

  test "string invalid and extended escapes":
    for body in ["\\T", "\\U00E9", "\\a", "\\e", "\\v", "\\'", "\\?",
                 "\\000", "\\101", "\\x00", "\\x41", "\\U1234", "\\u123Z",
                 "\\x1234", "\\uDE0A", "\\uDE0A\\u0000", "\\uD83D",
                 "\\uD83D\\", "\\uD83D\\u", "\\uD83DAAAA",
                 "\\uD83D\\u0000", "\\uD83D\\uD83D"]:
      expectStringRejected(body)

    let truncated = "\\u0024\\u0024"
    for len in 1 ..< 12:
      if len != 6:
        expectStringRejected(truncated[0 ..< len])

    expectStringRead("ab\\\"xy", "ab\"xy")
    expectStringRejected("ab\\'xy")
    expectStringRead("ab\\'xy", "ab'xy", YYJSON_READ_ALLOW_EXT_ESCAPE)
    expectStringRejected("ab\\")
    expectStringRejected("ab\\", YYJSON_READ_ALLOW_EXT_ESCAPE)

    expectStringRejected("ab\\axy")
    expectStringRead("ab\\axy", "ab\x07xy", YYJSON_READ_ALLOW_EXT_ESCAPE)
    expectStringRejected("ab\\exy")
    expectStringRead("ab\\exy", "ab\x1Bxy", YYJSON_READ_ALLOW_EXT_ESCAPE)
    expectStringRejected("ab\\vxy")
    expectStringRead("ab\\vxy", "ab\vxy", YYJSON_READ_ALLOW_EXT_ESCAPE)
    expectStringRejected("ab\\?xy")
    expectStringRead("ab\\?xy", "ab?xy", YYJSON_READ_ALLOW_EXT_ESCAPE)
    expectStringRejected("ab\\0xy")
    expectStringRead("ab\\0xy", "ab\0xy", YYJSON_READ_ALLOW_EXT_ESCAPE)
    expectStringRejected("ab\\012xy", YYJSON_READ_ALLOW_EXT_ESCAPE)

    expectStringRejected("ab\\x00xy")
    expectStringRead("ab\\x00xy", "ab\0xy", YYJSON_READ_ALLOW_EXT_ESCAPE)
    expectStringRejected("ab\\x7Fxy")
    expectStringRead("ab\\x7Fxy", "ab\x7Fxy", YYJSON_READ_ALLOW_EXT_ESCAPE)
    expectStringRejected("ab\\x80xy")
    expectStringRead("ab\\x80xy", "ab\xC2\x80xy", YYJSON_READ_ALLOW_EXT_ESCAPE)
    expectStringRejected("ab\\xFFxy")
    expectStringRead("ab\\xFFxy", "abÿxy", YYJSON_READ_ALLOW_EXT_ESCAPE)
    expectStringRejected("ab\\xPPxy", YYJSON_READ_ALLOW_EXT_ESCAPE)
    expectStringRead("ab\\X7Fxy", "abX7Fxy", YYJSON_READ_ALLOW_EXT_ESCAPE)

    expectStringRead("ab\\\"xy", "ab\"xy", YYJSON_READ_ALLOW_SINGLE_QUOTED_STR, '\'')
    expectStringRead("ab\\'xy", "ab'xy", YYJSON_READ_ALLOW_SINGLE_QUOTED_STR, '\'')
    expectStringRead("ab\\axy", "ab\x07xy",
                     YYJSON_READ_ALLOW_SINGLE_QUOTED_STR or YYJSON_READ_ALLOW_EXT_ESCAPE,
                     '\'')
