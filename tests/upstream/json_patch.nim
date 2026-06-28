include common

import yyjson/private

type
  PatchCase = object
    src: string
    patch: string
    expected: string
    errCode: YyJsonPatchCode
    errIdx: csize_t
    ptrCode: YyJsonPtrCode

proc writeMutVal(val: ptr YyJsonMutVal): string =
  var len: csize_t
  var err: YyJsonWriteErr
  let p = yyjson_mut_val_write_opts(val, YYJSON_WRITE_NOFLAG, nil, addr len, addr err)
  check not p.isNil
  result = newString(system.int(len))
  if len > 0:
    copyMem(addr result[0], p, system.int(len))
  c_free(p)

proc checkMutValEq(val: ptr YyJsonMutVal; expected: string; ok: bool) =
  if not ok:
    check val.isNil
  else:
    check not val.isNil
    check writeMutVal(val) == expected

proc checkPatchErr(err: YyJsonPatchErr; data: PatchCase) =
  check err.code == data.errCode
  check err.idx == data.errIdx
  check err.ptrErr.code == data.ptrCode
  if err.code == YYJSON_PATCH_SUCCESS:
    check err.msg.isNil
  else:
    check not err.msg.isNil

  if err.code == YYJSON_PATCH_ERROR_POINTER:
    check err.ptrErr.code != YYJSON_PTR_ERR_NONE
    check not err.ptrErr.msg.isNil
  else:
    check err.ptrErr.code == YYJSON_PTR_ERR_NONE
    check err.ptrErr.msg.isNil

proc testPatch(data: PatchCase) =
  let doc = yyjson_mut_doc_new(nil)
  let srcDoc = yyjson_read(data.src.cstring, data.src.len.csize_t, YYJSON_READ_NOFLAG)
  let patchDoc = yyjson_read(data.patch.cstring, data.patch.len.csize_t, YYJSON_READ_NOFLAG)
  let src = yyjson_doc_get_root(srcDoc)
  let patch = yyjson_doc_get_root(patchDoc)
  let mutSrc = yyjson_val_mut_copy(doc, src)
  let mutPatch = yyjson_val_mut_copy(doc, patch)
  let ok = data.errCode == YYJSON_PATCH_SUCCESS

  check not doc.isNil

  var ret = yyjson_patch(doc, src, patch, nil)
  checkMutValEq(ret, data.expected, ok)

  var err: YyJsonPatchErr
  ret = yyjson_patch(doc, src, patch, addr err)
  checkMutValEq(ret, data.expected, ok)
  checkPatchErr(err, data)

  ret = yyjson_mut_patch(doc, mutSrc, mutPatch, nil)
  checkMutValEq(ret, data.expected, ok)

  err = YyJsonPatchErr()
  ret = yyjson_mut_patch(doc, mutSrc, mutPatch, addr err)
  checkMutValEq(ret, data.expected, ok)
  checkPatchErr(err, data)

  yyjson_mut_doc_free(doc)
  yyjson_doc_free(srcDoc)
  yyjson_doc_free(patchDoc)

proc okCase(src, patch, expected: string): PatchCase =
  PatchCase(src: src, patch: patch, expected: expected)

proc errCase(src, patch: string; code: YyJsonPatchCode;
             idx: csize_t = 0; ptrCode: YyJsonPtrCode = YYJSON_PTR_ERR_NONE): PatchCase =
  PatchCase(src: src, patch: patch, errCode: code, errIdx: idx, ptrCode: ptrCode)

suite "upstream yyjson patch":
  test "RFC 6902 JSON Patch cases":
    for data in [
      okCase("""{"foo":"bar"}""",
             """[{"op":"add","path":"/baz","value":"qux"}]""",
             """{"foo":"bar","baz":"qux"}"""),
      okCase("""{"foo":["bar","baz"]}""",
             """[{"op":"add","path":"/foo/1","value":"qux"}]""",
             """{"foo":["bar","qux","baz"]}"""),
      okCase("""{"foo":"bar","baz":"qux"}""",
             """[{"op":"remove","path":"/baz"}]""",
             """{"foo":"bar"}"""),
      okCase("""{"foo":["bar","qux","baz"]}""",
             """[{"op":"remove","path":"/foo/1"}]""",
             """{"foo":["bar","baz"]}"""),
      okCase("""{"foo":"bar","baz":"qux"}""",
             """[{"op":"replace","path":"/baz","value":"boo"}]""",
             """{"foo":"bar","baz":"boo"}"""),
      okCase("""{"foo":{"bar":"baz","waldo":"fred"},"qux":{"corge":"grault"}}""",
             """[{"op":"move","from":"/foo/waldo","path":"/qux/thud"}]""",
             """{"foo":{"bar":"baz"},"qux":{"corge":"grault","thud":"fred"}}"""),
      okCase("""{"foo":["all","grass","cows","eat"]}""",
             """[{"op":"move","from":"/foo/1","path":"/foo/3"}]""",
             """{"foo":["all","cows","eat","grass"]}"""),
      okCase("""{"baz":"qux","foo":["a",2,"c"]}""",
             """[{"op":"test","path":"/baz","value":"qux"},{"op":"test","path":"/foo/1","value":2}]""",
             """{"baz":"qux","foo":["a",2,"c"]}"""),
      errCase("""{"baz":"qux"}""",
              """[{"op":"test","path":"/baz","value":"bar"}]""",
              YYJSON_PATCH_ERROR_EQUAL),
      okCase("""{"foo":"bar"}""",
             """[{"op":"add","path":"/child","value":{"grandchild":{}}}]""",
             """{"foo":"bar","child":{"grandchild":{}}}"""),
      okCase("""{"foo":"bar"}""",
             """[{"op":"add","path":"/baz","value":"qux","xyz":123}]""",
             """{"foo":"bar","baz":"qux"}"""),
      errCase("""{"foo":"bar"}""",
              """[{"op":"add","path":"/baz/bat","value":"qux"}]""",
              YYJSON_PATCH_ERROR_POINTER, ptrCode = YYJSON_PTR_ERR_RESOLVE),
      okCase("""{"foo":"bar"}""",
             """[{"op":"add","path":"/baz","value":"qux","op":"remove"}]""",
             """{"foo":"bar","baz":"qux"}"""),
      okCase("""{"/":9,"~1":10}""",
             """[{"op":"test","path":"/~01","value":10}]""",
             """{"/":9,"~1":10}"""),
      errCase("""{"/":9,"~1":10}""",
              """[{"op":"test","path":"/~01","value":"10"}]""",
              YYJSON_PATCH_ERROR_EQUAL),
      okCase("""{"foo":["bar"]}""",
             """[{"op":"add","path":"/foo/-","value":["abc","def"]}]""",
             """{"foo":["bar",["abc","def"]]}""")
    ]:
      testPatch(data)

  test "JSON Patch error and operation matrix":
    for data in [
      errCase("", "[]", YYJSON_PATCH_ERROR_INVALID_PARAMETER),
      errCase("[]", "", YYJSON_PATCH_ERROR_INVALID_PARAMETER),
      errCase("", "", YYJSON_PATCH_ERROR_INVALID_PARAMETER),
      errCase("[]", "{}", YYJSON_PATCH_ERROR_INVALID_PARAMETER),
      errCase("[]", """[{"op":"add","path":"/-","value":0},{"op":"add","path":"/-","value":1},123]""",
              YYJSON_PATCH_ERROR_INVALID_OPERATION, idx = 2),
      errCase("[]", """[{"op":"add","path":"/-","value":0},{"op":"add","path":"/-","value":1},{"op":"err","path":"/-","value":1}]""",
              YYJSON_PATCH_ERROR_INVALID_MEMBER, idx = 2),
      errCase("[]", """[{"op":"add","path":"/-","value":0},{"op":"add","path":"/-","value":1},{"path":"/-","value":1}]""",
              YYJSON_PATCH_ERROR_MISSING_KEY, idx = 2),
      errCase("[]", """[{"op":"add","path":"/-","value":0},{"op":"add","path":"/-","value":1},{"op":"add","value":2}]""",
              YYJSON_PATCH_ERROR_MISSING_KEY, idx = 2),
      errCase("[]", """[{"op":"add","path":"/-","value":0},{"op":"add","path":"/-","value":1},{"op":"add","path":null,"value":2}]""",
              YYJSON_PATCH_ERROR_INVALID_MEMBER, idx = 2),
      errCase("[1]", """[{"op":0,"path":"/0","value":0}]""", YYJSON_PATCH_ERROR_INVALID_MEMBER),
      errCase("[1]", """[{"op":"","path":"/0","value":0}]""", YYJSON_PATCH_ERROR_INVALID_MEMBER),
      errCase("[1]", """[{"op":"unknown","path":"/0","value":0}]""", YYJSON_PATCH_ERROR_INVALID_MEMBER),
      errCase("[1]", """[{"op":"add","value":0}]""", YYJSON_PATCH_ERROR_MISSING_KEY),
      errCase("[0]", """[{"op":"add","path":"/1"}]""", YYJSON_PATCH_ERROR_MISSING_KEY),
      okCase("[0]", """[{"op":"add","path":"/1","value":1}]""", "[0,1]"),
      errCase("[0]", """[{"op":"add","path":"/2","value":1}]""",
              YYJSON_PATCH_ERROR_POINTER, ptrCode = YYJSON_PTR_ERR_RESOLVE),
      errCase("[0]", """[{"op":"add","path":"/~2","value":1}]""",
              YYJSON_PATCH_ERROR_POINTER, ptrCode = YYJSON_PTR_ERR_SYNTAX),
      okCase("[0]", """[{"op":"add","path":"","value":1}]""", "1"),
      errCase("[1]", """[{"op":"remove"}]""", YYJSON_PATCH_ERROR_MISSING_KEY),
      errCase("[1]", """[{"op":"remove","path":0}]""", YYJSON_PATCH_ERROR_INVALID_MEMBER),
      errCase("[1]", """[{"op":"remove","path":""}]""",
              YYJSON_PATCH_ERROR_POINTER, ptrCode = YYJSON_PTR_ERR_SET_ROOT),
      errCase("[1]", """[{"op":"remove","path":"/-"}]""",
              YYJSON_PATCH_ERROR_POINTER, ptrCode = YYJSON_PTR_ERR_RESOLVE),
      okCase("[1]", """[{"op":"remove","path":"/0"}]""", "[]"),
      errCase("[1]", """[{"op":"replace","value":0}]""", YYJSON_PATCH_ERROR_MISSING_KEY),
      errCase("[0]", """[{"op":"replace","path":"/1"}]""", YYJSON_PATCH_ERROR_MISSING_KEY),
      okCase("[0]", """[{"op":"replace","path":"/0","value":1}]""", "[1]"),
      errCase("[0]", """[{"op":"replace","path":"/1","value":1}]""",
              YYJSON_PATCH_ERROR_POINTER, ptrCode = YYJSON_PTR_ERR_RESOLVE),
      okCase("[0]", """[{"op":"replace","path":"","value":1}]""", "1"),
      errCase("[[1,2],[3,4]]", """[{"op":"move","from":"/0/0"}]""",
              YYJSON_PATCH_ERROR_MISSING_KEY),
      errCase("[[1,2],[3,4]]", """[{"op":"move","path":"/1/0"}]""",
              YYJSON_PATCH_ERROR_MISSING_KEY),
      okCase("[[1,2],[3,4]]", """[{"op":"move","from":"/0/0","path":"/1/0"}]""",
             "[[2],[1,3,4]]"),
      errCase("[[1,2],[3,4]]", """[{"op":"move","from":0,"path":"/1/0"}]""",
              YYJSON_PATCH_ERROR_INVALID_MEMBER),
      errCase("[[1,2],[3,4]]", """[{"op":"move","from":"/0/a","path":"/1/0"}]""",
              YYJSON_PATCH_ERROR_POINTER, ptrCode = YYJSON_PTR_ERR_RESOLVE),
      errCase("[[1,2],[3,4]]", """[{"op":"move","from":"/0/~","path":"/1/0"}]""",
              YYJSON_PATCH_ERROR_POINTER, ptrCode = YYJSON_PTR_ERR_SYNTAX),
      okCase("[[1,2],[3,4]]", """[{"op":"move","from":"","path":""}]""",
             "[[1,2],[3,4]]"),
      okCase("[[1,2],[3,4]]", """[{"op":"move","from":"/0/0","path":""}]""", "1"),
      errCase("[[1,2],[3,4]]", """[{"op":"copy","from":"/0/0"}]""",
              YYJSON_PATCH_ERROR_MISSING_KEY),
      errCase("[[1,2],[3,4]]", """[{"op":"copy","path":"/1/0"}]""",
              YYJSON_PATCH_ERROR_MISSING_KEY),
      okCase("[[1,2],[3,4]]", """[{"op":"copy","from":"/0/0","path":"/1/0"}]""",
             "[[1,2],[1,3,4]]"),
      errCase("[[1,2],[3,4]]", """[{"op":"copy","from":0,"path":"/1/0"}]""",
              YYJSON_PATCH_ERROR_INVALID_MEMBER),
      errCase("[[1,2],[3,4]]", """[{"op":"copy","from":"/0/a","path":"/1/0"}]""",
              YYJSON_PATCH_ERROR_POINTER, ptrCode = YYJSON_PTR_ERR_RESOLVE),
      errCase("[[1,2],[3,4]]", """[{"op":"copy","from":"/0/~","path":"/1/0"}]""",
              YYJSON_PATCH_ERROR_POINTER, ptrCode = YYJSON_PTR_ERR_SYNTAX),
      okCase("[[1,2],[3,4]]", """[{"op":"copy","from":"","path":""}]""",
             "[[1,2],[3,4]]"),
      okCase("[[1,2],[3,4]]", """[{"op":"copy","from":"/0/0","path":""}]""", "1"),
      errCase("[1]", """[{"op":"test","value":1}]""", YYJSON_PATCH_ERROR_MISSING_KEY),
      errCase("[1]", """[{"op":"test","path":"/0"}]""", YYJSON_PATCH_ERROR_MISSING_KEY),
      okCase("[1]", """[{"op":"test","path":"/0","value":1}]""", "[1]"),
      errCase("[1]", """[{"op":"test","path":"/1","value":1}]""",
              YYJSON_PATCH_ERROR_POINTER, ptrCode = YYJSON_PTR_ERR_RESOLVE),
      errCase("[1]", """[{"op":"test","path":"/~2","value":1}]""",
              YYJSON_PATCH_ERROR_POINTER, ptrCode = YYJSON_PTR_ERR_SYNTAX),
      errCase("[1]", """[{"op":"test","path":"","value":2}]""", YYJSON_PATCH_ERROR_EQUAL),
      okCase("[1,2,3]",
             """[{"op":"add","path":"/3","value":4},{"op":"remove","path":"/1"},{"op":"replace","path":"/0","value":{"a":0}},{"op":"move","from":"/0/a","path":"/1"},{"op":"copy","from":"/3","path":"/0/b"},{"op":"test","path":"/0","value":{"b":4}}]""",
             """[{"b":4},0,3,4]""")
    ]:
      testPatch(data)
