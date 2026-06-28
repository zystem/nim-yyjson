include common

suite "upstream yyjson data fixtures":
  test "JSONTestSuite parsing":
    checkSummary("test_parsing", runParsingSuite())

  test "JSON_checker":
    checkSummary("test_checker", runCheckerSuite())

  test "JSONTestSuite transform":
    checkSummary("test_transform", runTransformSuite())

  test "encoding":
    checkSummary("test_encoding", runEncodingSuite())

  test "roundtrip":
    checkSummary("test_roundtrip", runRoundtripSuite())

  test "number data":
    checkSummary("test_number_data", runNumberSuite())

  test "yyjson fixtures":
    checkSummary("test_yyjson", runYyjsonSuite())
