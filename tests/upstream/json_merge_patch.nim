include common

import yyjson/private

proc writeMutVal(val: ptr YyJsonMutVal): string =
  var len: csize_t
  var err: YyJsonWriteErr
  let p = yyjson_mut_val_write_opts(val, YYJSON_WRITE_NOFLAG, nil, addr len, addr err)
  check not p.isNil
  result = newString(system.int(len))
  if len > 0:
    copyMem(addr result[0], p, system.int(len))
  c_free(p)

proc testMergePatchOne(origJson, patchJson, expectedJson: string) =
  let origDoc = yyjson_read(origJson.cstring, origJson.len.csize_t, YYJSON_READ_NOFLAG)
  let patchDoc = yyjson_read(patchJson.cstring, patchJson.len.csize_t, YYJSON_READ_NOFLAG)
  let expectedDoc = yyjson_read(expectedJson.cstring, expectedJson.len.csize_t,
                                YYJSON_READ_NOFLAG)
  check not origDoc.isNil
  check not patchDoc.isNil
  check not expectedDoc.isNil

  let mutOrigDoc = yyjson_doc_mut_copy(origDoc, nil)
  let mutPatchDoc = yyjson_doc_mut_copy(patchDoc, nil)
  let mutExpectedDoc = yyjson_doc_mut_copy(expectedDoc, nil)
  check not mutOrigDoc.isNil
  check not mutPatchDoc.isNil
  check not mutExpectedDoc.isNil

  let doc = yyjson_mut_doc_new(nil)
  check not doc.isNil

  let ret1 = yyjson_merge_patch(doc, yyjson_doc_get_root(origDoc),
                                yyjson_doc_get_root(patchDoc))
  let ret2 = yyjson_mut_merge_patch(doc, yyjson_mut_doc_get_root(mutOrigDoc),
                                    yyjson_mut_doc_get_root(mutPatchDoc))
  check not ret1.isNil
  check not ret2.isNil
  check writeMutVal(ret1) == expectedJson
  check writeMutVal(ret2) == expectedJson
  check yyjson_mut_equals(yyjson_mut_doc_get_root(mutExpectedDoc), ret1)
  check yyjson_mut_equals(yyjson_mut_doc_get_root(mutExpectedDoc), ret2)

  check yyjson_merge_patch(nil, nil, nil).isNil
  check yyjson_merge_patch(nil, yyjson_doc_get_root(origDoc), nil).isNil
  check yyjson_merge_patch(nil, nil, yyjson_doc_get_root(patchDoc)).isNil
  check yyjson_merge_patch(nil, yyjson_doc_get_root(origDoc),
                           yyjson_doc_get_root(patchDoc)).isNil
  check yyjson_merge_patch(doc, yyjson_doc_get_root(origDoc), nil).isNil
  check not yyjson_merge_patch(doc, nil, yyjson_doc_get_root(patchDoc)).isNil

  check yyjson_mut_merge_patch(nil, nil, nil).isNil
  check yyjson_mut_merge_patch(nil, yyjson_mut_doc_get_root(mutOrigDoc), nil).isNil
  check yyjson_mut_merge_patch(nil, nil, yyjson_mut_doc_get_root(mutPatchDoc)).isNil
  check yyjson_mut_merge_patch(nil, yyjson_mut_doc_get_root(mutOrigDoc),
                               yyjson_mut_doc_get_root(mutPatchDoc)).isNil
  check yyjson_mut_merge_patch(doc, yyjson_mut_doc_get_root(mutOrigDoc), nil).isNil
  check not yyjson_mut_merge_patch(doc, nil, yyjson_mut_doc_get_root(mutPatchDoc)).isNil

  yyjson_mut_doc_free(doc)
  yyjson_mut_doc_free(mutExpectedDoc)
  yyjson_mut_doc_free(mutPatchDoc)
  yyjson_mut_doc_free(mutOrigDoc)
  yyjson_doc_free(expectedDoc)
  yyjson_doc_free(patchDoc)
  yyjson_doc_free(origDoc)

suite "upstream yyjson merge patch":
  test "RFC 7386 merge patch cases":
    testMergePatchOne("""{"a":"b"}""", """{"a":"c"}""", """{"a":"c"}""")
    testMergePatchOne("""{"a":"b"}""", """{"b":"c"}""", """{"a":"b","b":"c"}""")
    testMergePatchOne("""{"a":"b"}""", """{"a":null }""", "{}")
    testMergePatchOne("""{"a":"b"}""", """{"a":null }""", "{}")
    testMergePatchOne("""{"a":"b", "b":"c"}""", """{"a":null }""", """{"b":"c"}""")
    testMergePatchOne("""{"a":["b"] }""", """{"a":"c"}""", """{"a":"c"}""")
    testMergePatchOne("""{"a":"c"}""", """{"a":["b"]}""", """{"a":["b"]}""")
    testMergePatchOne("""{"a":{"b":"c"}}""", """{"a":{"b":"d","c":null}}""",
                      """{"a":{"b":"d"}}""")
    testMergePatchOne("""{"a":{"b":"c"}}""", """{"a":[1]}""", """{"a":[1]}""")
    testMergePatchOne("""["a","b"]""", """["c","d"]""", """["c","d"]""")
    testMergePatchOne("""{"a":"b"}""", """["c"]""", """["c"]""")
    testMergePatchOne("""{"a":"foo"}""", "null", "null")
    testMergePatchOne("""{"a":"foo"}""", "\"bar\"", "\"bar\"")
    testMergePatchOne("""{"e":null}""", """{"a":1}""", """{"e":null,"a":1}""")
    testMergePatchOne("""[1,2]""", """{"a":"b","c":null}""", """{"a":"b"}""")
    testMergePatchOne("{}", """{"a":{"bb":{"ccc":null}}}""", """{"a":{"bb":{}}}""")
