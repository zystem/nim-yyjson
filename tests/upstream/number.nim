include common

suite "upstream yyjson number":
  test "number upstream boundary matrix":
    block:
      var doc = readJson("0")
      defer:
        doc.close()
      let v = doc.root()
      check v.isUInt
      check v.isInt
      check not v.isReal
      check v.typeDesc() == "uint"
      check v.uint64() == 0'u64
      check v.int64() == 0'i64
      check v.num() == 0.0

    block:
      var doc = readJson("-0")
      defer:
        doc.close()
      let v = doc.root()
      check v.isSInt
      check v.isInt
      check not v.isReal
      check v.typeDesc() == "sint"
      check v.int64() == 0'i64
      check v.num() == 0.0

    block:
      var doc = readJson("18446744073709551615")
      defer:
        doc.close()
      let v = doc.root()
      check v.isUInt
      check not v.isSInt
      check v.uint64() == high(uint64)
      check v.num() == 18446744073709551615.0

    block:
      var doc = readJson("-9223372036854775808")
      defer:
        doc.close()
      let v = doc.root()
      check v.isSInt
      check not v.isUInt
      check v.int64() == low(int64)
      check v.num() == -9223372036854775808.0

    block:
      var doc = readJson("18446744073709551616")
      defer:
        doc.close()
      let v = doc.root()
      check v.isReal
      check not v.isInt
      check v.float() == 18446744073709551616.0

    block:
      var doc = readJson("1.7976931348623157e308")
      defer:
        doc.close()
      let v = doc.root()
      check v.isReal
      check v.float() == 1.7976931348623157e308

    expectReadError("1e400", YYJSON_READ_ERROR_INVALID_NUMBER, 0)
    block:
      var doc = readJson("1e400", YYJSON_READ_BIGNUM_AS_RAW)
      defer:
        doc.close()
      let v = doc.root()
      check v.isRaw
      check v.raw() == "1e400"

    for input in ["0", "-0", "123", "-123", "1.5", "1e400"]:
      var doc = readJson(input, YYJSON_READ_NUMBER_AS_RAW)
      defer:
        doc.close()
      let v = doc.root()
      check v.isRaw
      check v.raw() == input
      check v.rawLen() == input.len

    expectReadError("Infinity", YYJSON_READ_ERROR_UNEXPECTED_CHARACTER, 0)
    block:
      var doc = readJson("Infinity", YYJSON_READ_ALLOW_INF_AND_NAN)
      defer:
        doc.close()
      let v = doc.root()
      check v.isReal
      check v.float() == Inf

    block:
      var doc = readJson("-Infinity", YYJSON_READ_ALLOW_INF_AND_NAN)
      defer:
        doc.close()
      let v = doc.root()
      check v.isReal
      check v.float() == NegInf

    block:
      var doc = readJson("NaN", YYJSON_READ_ALLOW_INF_AND_NAN)
      defer:
        doc.close()
      let v = doc.root()
      check v.isReal
      check v.float().classify == fcNan

    block:
      var doc = readJson("0x10", YYJSON_READ_ALLOW_EXT_NUMBER)
      defer:
        doc.close()
      let v = doc.root()
      check v.isUInt
      check v.uint64() == 16'u64

    block:
      var doc = readJson("-0x10", YYJSON_READ_ALLOW_EXT_NUMBER)
      defer:
        doc.close()
      let v = doc.root()
      check v.isSInt
      check v.int64() == -16'i64

    block:
      var doc = readJson("0xFFFFFFFFFFFFFFFF", YYJSON_READ_ALLOW_EXT_NUMBER)
      defer:
        doc.close()
      let v = doc.root()
      check v.isUInt
      check v.uint64() == high(uint64)

    block:
      var doc = readJson("0x10000000000000000",
                         YYJSON_READ_ALLOW_EXT_NUMBER or YYJSON_READ_BIGNUM_AS_RAW)
      defer:
        doc.close()
      let v = doc.root()
      check v.isRaw
      check v.raw() == "0x10000000000000000"

    block:
      var doc = newJsonMutDoc()
      defer:
        doc.close()
      doc.setRoot(doc.newUInt64(high(uint64)))
      check doc.root().isUInt
      check doc.root().uint64() == high(uint64)
      check doc.writeJson() == "18446744073709551615"

    block:
      var doc = newJsonMutDoc()
      defer:
        doc.close()
      doc.setRoot(doc.newInt(low(int64)))
      check doc.root().isSInt
      check doc.root().int64() == low(int64)
      check doc.writeJson() == "-9223372036854775808"

    block:
      var doc = newJsonMutDoc()
      defer:
        doc.close()
      doc.setRoot(doc.newFloat(1.5))
      check doc.root().isReal
      check doc.root().float() == 1.5
      check doc.writeJson() == "1.5"

  test "special real read write matrix":
    for item in [("Infinity", Inf), ("-Infinity", NegInf)]:
      var doc = readJson(item[0], YYJSON_READ_ALLOW_INF_AND_NAN)
      defer:
        doc.close()
      check doc.root().isReal
      check doc.root().float() == item[1]
      check doc.writeJson(YYJSON_WRITE_ALLOW_INF_AND_NAN) == item[0]
      check doc.writeJson(YYJSON_WRITE_INF_AND_NAN_AS_NULL) == "null"

      var mutDoc = readJsonMut(item[0], YYJSON_READ_ALLOW_INF_AND_NAN)
      defer:
        mutDoc.close()
      check mutDoc.root().isReal
      check mutDoc.root().float() == item[1]
      check mutDoc.writeJson(YYJSON_WRITE_ALLOW_INF_AND_NAN) == item[0]
      check mutDoc.writeJson(YYJSON_WRITE_INF_AND_NAN_AS_NULL) == "null"

    block:
      var doc = readJson("NaN", YYJSON_READ_ALLOW_INF_AND_NAN)
      defer:
        doc.close()
      check doc.root().isReal
      check doc.root().float().classify == fcNan
      check doc.writeJson(YYJSON_WRITE_ALLOW_INF_AND_NAN) == "NaN"
      check doc.writeJson(YYJSON_WRITE_INF_AND_NAN_AS_NULL) == "null"

    for value in [Inf, NegInf, NaN]:
      var doc = newJsonMutDoc()
      defer:
        doc.close()
      doc.setRoot(doc.newFloat(value))
      expectWriteError(YYJSON_WRITE_ERROR_NAN_OR_INF, proc () =
        discard doc.writeJson()
      )

  test "number write formatting through public API":
    for item in [
      ("0", "0"),
      ("-0", "0"),
      ("1.0", "1.0"),
      ("1e6", "1000000.0"),
      ("1.25e-3", "0.00125"),
      ("9007199254740991", "9007199254740991"),
      ("18446744073709551615", "18446744073709551615")
    ]:
      var doc = readJson(item[0])
      defer:
        doc.close()
      let written = doc.writeJson()
      check written == item[1]
      var roundtrip = readJson(written)
      defer:
        roundtrip.close()
      check doc.root().equals(roundtrip.root())
