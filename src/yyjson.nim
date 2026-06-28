## Thin high-level yyjson wrapper.
##
## This module does not convert values to std/json JsonNode.
## String access is zero-copy unless you explicitly request a Nim string.

import yyjson/private

export private.YyJsonReadFlag
export private.YyJsonReadCode
export private.YYJSON_READ_NOFLAG
export private.YYJSON_READ_INSITU
export private.YYJSON_READ_STOP_WHEN_DONE
export private.YYJSON_READ_ALLOW_TRAILING_COMMAS
export private.YYJSON_READ_ALLOW_COMMENTS
export private.YYJSON_READ_ALLOW_INF_AND_NAN
export private.YYJSON_READ_NUMBER_AS_RAW
export private.YYJSON_READ_ALLOW_INVALID_UNICODE
export private.YYJSON_READ_BIGNUM_AS_RAW
export private.YYJSON_READ_ALLOW_BOM
export private.YYJSON_READ_ALLOW_EXT_NUMBER
export private.YYJSON_READ_ALLOW_EXT_ESCAPE
export private.YYJSON_READ_ALLOW_EXT_WHITESPACE
export private.YYJSON_READ_ALLOW_SINGLE_QUOTED_STR
export private.YYJSON_READ_ALLOW_UNQUOTED_KEY
export private.YYJSON_READ_JSON5
export private.YYJSON_READ_SUCCESS
export private.YYJSON_READ_ERROR_INVALID_PARAMETER
export private.YYJSON_READ_ERROR_MEMORY_ALLOCATION
export private.YYJSON_READ_ERROR_EMPTY_CONTENT
export private.YYJSON_READ_ERROR_UNEXPECTED_CONTENT
export private.YYJSON_READ_ERROR_UNEXPECTED_END
export private.YYJSON_READ_ERROR_UNEXPECTED_CHARACTER
export private.YYJSON_READ_ERROR_JSON_STRUCTURE
export private.YYJSON_READ_ERROR_INVALID_COMMENT
export private.YYJSON_READ_ERROR_INVALID_NUMBER
export private.YYJSON_READ_ERROR_INVALID_STRING
export private.YYJSON_READ_ERROR_LITERAL
export private.YYJSON_READ_ERROR_FILE_OPEN
export private.YYJSON_READ_ERROR_FILE_READ
export private.YYJSON_READ_ERROR_MORE
export private.YYJSON_READ_ERROR_DEPTH
export private.YyJsonWriteFlag
export private.YyJsonWriteCode
export private.YyJsonPtrCode
export private.YYJSON_WRITE_NOFLAG
export private.YYJSON_WRITE_PRETTY
export private.YYJSON_WRITE_ESCAPE_UNICODE
export private.YYJSON_WRITE_ESCAPE_SLASHES
export private.YYJSON_WRITE_ALLOW_INF_AND_NAN
export private.YYJSON_WRITE_INF_AND_NAN_AS_NULL
export private.YYJSON_WRITE_ALLOW_INVALID_UNICODE
export private.YYJSON_WRITE_PRETTY_TWO_SPACES
export private.YYJSON_WRITE_NEWLINE_AT_END
export private.YYJSON_WRITE_LOWERCASE_HEX
export private.YYJSON_WRITE_SUCCESS
export private.YYJSON_WRITE_ERROR_INVALID_PARAMETER
export private.YYJSON_WRITE_ERROR_MEMORY_ALLOCATION
export private.YYJSON_WRITE_ERROR_INVALID_VALUE_TYPE
export private.YYJSON_WRITE_ERROR_NAN_OR_INF
export private.YYJSON_WRITE_ERROR_FILE_OPEN
export private.YYJSON_WRITE_ERROR_FILE_WRITE
export private.YYJSON_WRITE_ERROR_INVALID_STRING
export private.YYJSON_PTR_ERR_NONE
export private.YYJSON_PTR_ERR_PARAMETER
export private.YYJSON_PTR_ERR_SYNTAX
export private.YYJSON_PTR_ERR_RESOLVE
export private.YYJSON_PTR_ERR_NULL_ROOT
export private.YYJSON_PTR_ERR_SET_ROOT
export private.YYJSON_PTR_ERR_MEMORY_ALLOCATION

type
  JsonKind* = enum
    jkNone, jkRaw, jkNull, jkBool, jkNumber, jkString, jkArray, jkObject

  JsonError* = object of CatchableError

  JsonReadError* = object of JsonError
    code*: YyJsonReadCode
    pos*: int
    reason*: string

  JsonWriteError* = object of JsonError
    code*: YyJsonWriteCode
    reason*: string

  JsonPointerError* = object of JsonError
    code*: YyJsonPtrCode
    pos*: int
    reason*: string

  JsonLocation* = object
    line*: int
    col*: int
    chr*: int

  JsonDoc* = object
    p: ptr YyJsonDoc

  JsonVal* = object
    p: ptr YyJsonVal

  JsonMutDoc* = object
    p: ptr YyJsonMutDoc

  JsonMutVal* = object
    p: ptr YyJsonMutVal
    d: ptr YyJsonMutDoc

  JsonPointerContext* = object
    raw: YyJsonPtrCtx
    d: ptr YyJsonMutDoc

proc `=copy`*(dest: var JsonDoc, src: JsonDoc) {.error: "JsonDoc is move-only; use close() exactly once".}
proc `=copy`*(dest: var JsonMutDoc, src: JsonMutDoc) {.error: "JsonMutDoc is move-only; use close() exactly once".}

proc isNil*(v: JsonVal): bool {.inline.} =
  v.p.isNil

proc isNil*(d: JsonDoc): bool {.inline.} =
  d.p.isNil

proc isNil*(v: JsonMutVal): bool {.inline.} =
  v.p.isNil

proc isNil*(d: JsonMutDoc): bool {.inline.} =
  d.p.isNil

proc close*(d: var JsonDoc) =
  if not d.p.isNil:
    yyjson_doc_free(d.p)
    d.p = nil

proc close*(d: var JsonMutDoc) =
  if not d.p.isNil:
    yyjson_mut_doc_free(d.p)
    d.p = nil

proc raiseReadError(context: string; err: YyJsonReadErr) {.noReturn.} =
  let msg = if err.msg.isNil: "unknown yyjson read error" else: $err.msg
  let detail = context & ": " & msg
  var e = newException(JsonReadError, detail)
  e.code = err.code
  e.pos = system.int(err.pos)
  e.reason = msg
  raise e

proc raiseWriteError(context: string; err: YyJsonWriteErr) {.noReturn.} =
  let msg = if err.msg.isNil: "unknown yyjson write error" else: $err.msg
  let detail = context & ": " & msg
  var e = newException(JsonWriteError, detail)
  e.code = err.code
  e.reason = msg
  raise e

proc raisePointerError(context: string; err: YyJsonPtrErr) {.noReturn.} =
  let msg = if err.msg.isNil: "unknown yyjson pointer error" else: $err.msg
  let detail = context & ": " & msg
  var e = newException(JsonPointerError, detail)
  e.code = err.code
  e.pos = system.int(err.pos)
  e.reason = msg
  raise e

proc readJson*(s: string; flags: YyJsonReadFlag = YYJSON_READ_NOFLAG): JsonDoc =
  var err: YyJsonReadErr
  let p = yyjson_read_opts(s.cstring, s.len.csize_t, flags, nil, addr err)
  if p.isNil:
    raiseReadError("yyjson failed to parse JSON string", err)
  result = JsonDoc(p: p)

proc readJsonFile*(path: string; flags: YyJsonReadFlag = YYJSON_READ_NOFLAG): JsonDoc =
  var err: YyJsonReadErr
  let p = yyjson_read_file(path.cstring, flags, nil, addr err)
  if p.isNil:
    raiseReadError("yyjson failed to parse JSON file: " & path, err)
  result = JsonDoc(p: p)

proc readJsonMut*(s: string; flags: YyJsonReadFlag = YYJSON_READ_NOFLAG): JsonMutDoc =
  var err: YyJsonReadErr
  let doc = yyjson_read_opts(s.cstring, s.len.csize_t, flags, nil, addr err)
  if doc.isNil:
    raiseReadError("yyjson failed to parse JSON string", err)
  let mutDoc = yyjson_doc_mut_copy(doc, nil)
  yyjson_doc_free(doc)
  if mutDoc.isNil:
    raise newException(JsonError, "yyjson failed to copy JSON string into mutable document")
  JsonMutDoc(p: mutDoc)

proc readJsonMutFile*(path: string; flags: YyJsonReadFlag = YYJSON_READ_NOFLAG): JsonMutDoc =
  var err: YyJsonReadErr
  let doc = yyjson_read_file(path.cstring, flags, nil, addr err)
  if doc.isNil:
    raiseReadError("yyjson failed to parse JSON file: " & path, err)
  let mutDoc = yyjson_doc_mut_copy(doc, nil)
  yyjson_doc_free(doc)
  if mutDoc.isNil:
    raise newException(JsonError, "yyjson failed to copy JSON file into mutable document: " & path)
  JsonMutDoc(p: mutDoc)

proc locatePos*(s: string; pos: int; loc: var JsonLocation): bool =
  if pos < 0 or pos > s.len:
    loc = JsonLocation()
    return false

  var line, col, chr: csize_t
  result = yyjson_locate_pos(s.cstring, s.len.csize_t, pos.csize_t,
                             addr line, addr col, addr chr)
  loc = JsonLocation(line: int(line), col: int(col), chr: int(chr))

proc locatePos*(s: string; pos: int; line, col, chr: var int): bool =
  var loc: JsonLocation
  result = locatePos(s, pos, loc)
  line = loc.line
  col = loc.col
  chr = loc.chr

proc newJsonMutDoc*(): JsonMutDoc =
  let p = yyjson_mut_doc_new(nil)
  if p.isNil:
    raise newException(JsonError, "yyjson failed to create mutable JSON document")
  JsonMutDoc(p: p)

proc wrapMutVal(d: ptr YyJsonMutDoc; p: ptr YyJsonMutVal; context: string): JsonMutVal =
  if p.isNil:
    raise newException(JsonError, context)
  JsonMutVal(p: p, d: d)

proc clone*(d: JsonMutDoc): JsonMutDoc =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  let p = yyjson_mut_doc_mut_copy(d.p, nil)
  if p.isNil:
    raise newException(JsonError, "yyjson failed to clone mutable JSON document")
  JsonMutDoc(p: p)

proc clone*(d: JsonMutDoc; v: JsonVal): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  wrapMutVal(d.p, yyjson_val_mut_copy(d.p, v.p),
             "yyjson failed to clone JSON value into mutable document")

proc clone*(d: JsonMutDoc; v: JsonMutVal): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  wrapMutVal(d.p, yyjson_mut_val_mut_copy(d.p, v.p),
             "yyjson failed to clone mutable JSON value into mutable document")

proc takeJsonString(p: cstring; len: csize_t; err: YyJsonWriteErr): string =
  if p.isNil:
    raiseWriteError("yyjson failed to write JSON", err)

  let n = system.int(len)
  result = newString(n)
  if n > 0:
    copyMem(addr result[0], p, n)
  c_free(p)

proc writeJson*(d: JsonDoc; flags: YyJsonWriteFlag = YYJSON_WRITE_NOFLAG): string =
  if d.p.isNil:
    raise newException(JsonError, "JsonDoc is closed")

  var len: csize_t
  var err: YyJsonWriteErr
  takeJsonString(yyjson_write_opts(d.p, flags, nil, addr len, addr err), len, err)

proc writeJson*(v: JsonVal; flags: YyJsonWriteFlag = YYJSON_WRITE_NOFLAG): string =
  if v.p.isNil:
    raise newException(JsonError, "JsonVal is nil")

  var len: csize_t
  var err: YyJsonWriteErr
  takeJsonString(yyjson_val_write_opts(v.p, flags, nil, addr len, addr err), len, err)

proc writeJsonFile*(path: string; d: JsonDoc; flags: YyJsonWriteFlag = YYJSON_WRITE_NOFLAG) =
  if d.p.isNil:
    raise newException(JsonError, "JsonDoc is closed")
  var err: YyJsonWriteErr
  if not yyjson_write_file(path.cstring, d.p, flags, nil, addr err):
    raiseWriteError("yyjson failed to write JSON file: " & path, err)

proc writeJsonFile*(path: string; v: JsonVal; flags: YyJsonWriteFlag = YYJSON_WRITE_NOFLAG) =
  if v.p.isNil:
    raise newException(JsonError, "JsonVal is nil")
  var err: YyJsonWriteErr
  if not yyjson_val_write_file(path.cstring, v.p, flags, nil, addr err):
    raiseWriteError("yyjson failed to write JSON file: " & path, err)

proc writeJson*(d: JsonMutDoc; flags: YyJsonWriteFlag = YYJSON_WRITE_NOFLAG): string =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")

  var len: csize_t
  var err: YyJsonWriteErr
  takeJsonString(yyjson_mut_write_opts(d.p, flags, nil, addr len, addr err), len, err)

proc writeJson*(v: JsonMutVal; flags: YyJsonWriteFlag = YYJSON_WRITE_NOFLAG): string =
  if v.p.isNil:
    raise newException(JsonError, "JsonMutVal is nil")

  var len: csize_t
  var err: YyJsonWriteErr
  takeJsonString(yyjson_mut_val_write_opts(v.p, flags, nil, addr len, addr err), len, err)

proc writeJsonFile*(path: string; d: JsonMutDoc; flags: YyJsonWriteFlag = YYJSON_WRITE_NOFLAG) =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  var err: YyJsonWriteErr
  if not yyjson_mut_write_file(path.cstring, d.p, flags, nil, addr err):
    raiseWriteError("yyjson failed to write mutable JSON file: " & path, err)

proc root*(d: JsonDoc): JsonVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonDoc is closed")
  JsonVal(p: yyjson_doc_get_root(d.p))

proc root*(d: JsonMutDoc): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  JsonMutVal(p: yyjson_mut_doc_get_root(d.p), d: d.p)

proc setRoot*(d: JsonMutDoc; v: JsonMutVal) =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  yyjson_mut_doc_set_root(d.p, v.p)

proc newNull*(d: JsonMutDoc): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  wrapMutVal(d.p, yyjson_mut_null(d.p), "yyjson failed to create mutable null")

proc newBool*(d: JsonMutDoc; val: bool): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  wrapMutVal(d.p, yyjson_mut_bool(d.p, val), "yyjson failed to create mutable bool")

proc newUInt64*(d: JsonMutDoc; val: uint64): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  wrapMutVal(d.p, yyjson_mut_uint(d.p, val), "yyjson failed to create mutable uint")

proc newInt*(d: JsonMutDoc; val: int64): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  wrapMutVal(d.p, yyjson_mut_sint(d.p, val), "yyjson failed to create mutable int")

proc newFloat*(d: JsonMutDoc; val: float): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  wrapMutVal(d.p, yyjson_mut_real(d.p, cdouble(val)), "yyjson failed to create mutable real")

proc newString*(d: JsonMutDoc; val: string): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  wrapMutVal(d.p, yyjson_mut_str_copy_n(d.p, val.cstring, csize_t(val.len)),
             "yyjson failed to create mutable string")

proc newArray*(d: JsonMutDoc): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  wrapMutVal(d.p, yyjson_mut_arr(d.p), "yyjson failed to create mutable array")

proc newObject*(d: JsonMutDoc): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  wrapMutVal(d.p, yyjson_mut_obj(d.p), "yyjson failed to create mutable object")

proc add*(arr: JsonMutVal; val: JsonMutVal) =
  if not yyjson_mut_arr_add_val(arr.p, val.p):
    raise newException(JsonError, "yyjson failed to append mutable array value")

proc add*(obj: JsonMutVal; key: string; val: JsonMutVal) =
  if obj.d.isNil:
    raise newException(JsonError, "JsonMutVal has no owning document")
  let keyVal = yyjson_mut_str_copy_n(obj.d, key.cstring, csize_t(key.len))
  if keyVal.isNil or not yyjson_mut_obj_add(obj.p, keyVal, val.p):
    raise newException(JsonError, "yyjson failed to add mutable object value: " & key)

proc kind*(v: JsonMutVal): JsonKind =
  if v.p.isNil:
    return jkNone

  case yyjson_mut_get_type(v.p)
  of YYJSON_TYPE_RAW: jkRaw
  of YYJSON_TYPE_NULL: jkNull
  of YYJSON_TYPE_BOOL: jkBool
  of YYJSON_TYPE_NUM: jkNumber
  of YYJSON_TYPE_STR: jkString
  of YYJSON_TYPE_ARR: jkArray
  of YYJSON_TYPE_OBJ: jkObject
  else: jkNone

proc kind*(v: JsonVal): JsonKind =
  if v.p.isNil:
    return jkNone

  case yyjson_get_type(v.p)
  of YYJSON_TYPE_RAW: jkRaw
  of YYJSON_TYPE_NULL: jkNull
  of YYJSON_TYPE_BOOL: jkBool
  of YYJSON_TYPE_NUM: jkNumber
  of YYJSON_TYPE_STR: jkString
  of YYJSON_TYPE_ARR: jkArray
  of YYJSON_TYPE_OBJ: jkObject
  else: jkNone

proc isNull*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_null(v.p)

proc isRaw*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_raw(v.p)

proc isBool*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_bool(v.p)

proc isTrue*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_true(v.p)

proc isFalse*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_false(v.p)

proc isNumber*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_num(v.p)

proc isUInt*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_uint(v.p)

proc isSInt*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_sint(v.p)

proc isInt*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_int(v.p)

proc isReal*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_real(v.p)

proc isString*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_str(v.p)

proc isArray*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_arr(v.p)

proc isObject*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_obj(v.p)

proc isContainer*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_ctn(v.p)

proc len*(v: JsonVal): int =
  if v.p.isNil:
    return 0
  system.int(yyjson_get_len(v.p))

proc strLen*(v: JsonVal): int =
  if v.isString:
    v.len
  else:
    0

proc rawLen*(v: JsonVal): int =
  if v.isRaw:
    v.len
  else:
    0

proc typeDesc*(v: JsonVal): string =
  let p = yyjson_get_type_desc(v.p)
  if p.isNil: "unknown" else: $p

proc bool*(v: JsonVal; default = false): bool =
  if v.isBool:
    yyjson_get_bool(v.p)
  else:
    default

proc int64*(v: JsonVal; default: int64 = 0): int64 =
  if v.isNumber:
    yyjson_get_sint(v.p)
  else:
    default

proc int*(v: JsonVal; default = 0): int =
  system.int(v.int64(system.int64(default)))

proc uint64*(v: JsonVal; default: uint64 = 0): uint64 =
  if v.isNumber:
    yyjson_get_uint(v.p)
  else:
    default

proc float*(v: JsonVal; default = 0.0): float =
  if v.isNumber:
    system.float(yyjson_get_real(v.p))
  else:
    default

proc num*(v: JsonVal; default = 0.0): float =
  if v.isNumber:
    system.float(yyjson_get_num(v.p))
  else:
    default

proc cstr*(v: JsonVal; default: cstring = ""): cstring =
  if v.isString:
    let p = yyjson_get_str(v.p)
    if p.isNil: default else: p
  else:
    default

proc copyJsonBytes(p: cstring; len: int): string =
  result = newString(len)
  if len > 0:
    copyMem(addr result[0], p, len)

proc isNull*(v: JsonMutVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_mut_is_null(v.p)

proc isRaw*(v: JsonMutVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_mut_is_raw(v.p)

proc isBool*(v: JsonMutVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_mut_is_bool(v.p)

proc isNumber*(v: JsonMutVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_mut_is_num(v.p)

proc isUInt*(v: JsonMutVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_mut_is_uint(v.p)

proc isSInt*(v: JsonMutVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_mut_is_sint(v.p)

proc isInt*(v: JsonMutVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_mut_is_int(v.p)

proc isReal*(v: JsonMutVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_mut_is_real(v.p)

proc isString*(v: JsonMutVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_mut_is_str(v.p)

proc isArray*(v: JsonMutVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_mut_is_arr(v.p)

proc isObject*(v: JsonMutVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_mut_is_obj(v.p)

proc len*(v: JsonMutVal): int =
  if v.p.isNil:
    return 0
  system.int(yyjson_mut_get_len(v.p))

proc strLen*(v: JsonMutVal): int =
  if v.isString:
    v.len
  else:
    0

proc rawLen*(v: JsonMutVal): int =
  if v.isRaw:
    v.len
  else:
    0

proc typeDesc*(v: JsonMutVal): string =
  let p = yyjson_mut_get_type_desc(v.p)
  if p.isNil: "unknown" else: $p

proc bool*(v: JsonMutVal; default = false): bool =
  if v.isBool:
    yyjson_mut_get_bool(v.p)
  else:
    default

proc int64*(v: JsonMutVal; default: int64 = 0): int64 =
  if v.isNumber:
    yyjson_mut_get_sint(v.p)
  else:
    default

proc int*(v: JsonMutVal; default = 0): int =
  system.int(v.int64(system.int64(default)))

proc uint64*(v: JsonMutVal; default: uint64 = 0): uint64 =
  if v.isNumber:
    yyjson_mut_get_uint(v.p)
  else:
    default

proc float*(v: JsonMutVal; default = 0.0): float =
  if v.isNumber:
    system.float(yyjson_mut_get_real(v.p))
  else:
    default

proc cstr*(v: JsonMutVal; default: cstring = ""): cstring =
  if v.isString:
    let p = yyjson_mut_get_str(v.p)
    if p.isNil: default else: p
  else:
    default

proc craw*(v: JsonMutVal; default: cstring = ""): cstring =
  if v.isRaw:
    let p = yyjson_mut_get_raw(v.p)
    if p.isNil: default else: p
  else:
    default

proc str*(v: JsonMutVal; default = ""): string =
  if v.isString:
    let p = yyjson_mut_get_str(v.p)
    if p.isNil: default else: copyJsonBytes(p, v.strLen)
  else:
    default

proc raw*(v: JsonMutVal; default = ""): string =
  if v.isRaw:
    let p = yyjson_mut_get_raw(v.p)
    if p.isNil: default else: copyJsonBytes(p, v.rawLen)
  else:
    default

proc craw*(v: JsonVal; default: cstring = ""): cstring =
  if v.isRaw:
    let p = yyjson_get_raw(v.p)
    if p.isNil: default else: p
  else:
    default

proc str*(v: JsonVal; default = ""): string =
  if v.isString:
    let p = yyjson_get_str(v.p)
    if p.isNil: default else: copyJsonBytes(p, v.strLen)
  else:
    default

proc raw*(v: JsonVal; default = ""): string =
  if v.isRaw:
    let p = yyjson_get_raw(v.p)
    if p.isNil: default else: copyJsonBytes(p, v.rawLen)
  else:
    default

proc equalsStr*(v: JsonVal; s: string): bool =
  (not v.p.isNil) and yyjson_equals_strn(v.p, s.cstring, csize_t(s.len))

proc equalsStrLen*(v: JsonVal; s: string; len: int): bool =
  if v.p.isNil or len < 0 or len > s.len:
    return false
  yyjson_equals_strn(v.p, s.cstring, len.csize_t)

proc equals*(a, b: JsonVal): bool =
  (not a.p.isNil) and (not b.p.isNil) and yyjson_equals(a.p, b.p)

proc `==`*(a, b: JsonVal): bool =
  a.equals(b)

proc `[]`*(v: JsonVal; key: string): JsonVal =
  if v.isObject:
    JsonVal(p: yyjson_obj_get(v.p, key.cstring))
  else:
    JsonVal(p: nil)

proc `[]`*(v: JsonVal; index: int): JsonVal =
  if v.isArray and index >= 0:
    JsonVal(p: yyjson_arr_get(v.p, csize_t(index)))
  else:
    JsonVal(p: nil)

proc `[]`*(v: JsonMutVal; key: string): JsonMutVal =
  if v.isObject:
    JsonMutVal(p: yyjson_mut_obj_getn(v.p, key.cstring, key.len.csize_t), d: v.d)
  else:
    JsonMutVal(p: nil, d: v.d)

proc `[]`*(v: JsonMutVal; index: int): JsonMutVal =
  if v.isArray and index >= 0:
    JsonMutVal(p: yyjson_mut_arr_get(v.p, csize_t(index)), d: v.d)
  else:
    JsonMutVal(p: nil, d: v.d)

proc first*(v: JsonVal): JsonVal =
  if v.isArray:
    JsonVal(p: yyjson_arr_get_first(v.p))
  else:
    JsonVal(p: nil)

proc last*(v: JsonVal): JsonVal =
  if v.isArray:
    JsonVal(p: yyjson_arr_get_last(v.p))
  else:
    JsonVal(p: nil)

proc first*(v: JsonMutVal): JsonMutVal =
  if v.isArray:
    JsonMutVal(p: yyjson_mut_arr_get_first(v.p), d: v.d)
  else:
    JsonMutVal(p: nil, d: v.d)

proc last*(v: JsonMutVal): JsonMutVal =
  if v.isArray:
    JsonMutVal(p: yyjson_mut_arr_get_last(v.p), d: v.d)
  else:
    JsonMutVal(p: nil, d: v.d)

proc hasKey*(v: JsonVal; key: string): bool =
  not v[key].isNil

proc hasIndex*(v: JsonVal; index: int): bool =
  not v[index].isNil

proc contains*(v: JsonVal; key: string): bool =
  v.hasKey(key)

proc contains*(key: string; v: JsonVal): bool =
  v.hasKey(key)

proc contains*(v: JsonVal; index: int): bool =
  v.hasIndex(index)

proc hasKey*(v: JsonMutVal; key: string): bool =
  not v[key].isNil

proc hasIndex*(v: JsonMutVal; index: int): bool =
  not v[index].isNil

proc contains*(v: JsonMutVal; key: string): bool =
  v.hasKey(key)

proc contains*(key: string; v: JsonMutVal): bool =
  v.hasKey(key)

proc contains*(v: JsonMutVal; index: int): bool =
  v.hasIndex(index)

proc getCStr*(v: JsonVal; key: string; default: cstring = ""): cstring =
  v[key].cstr(default)

proc getStr*(v: JsonVal; key: string; default = ""): string =
  v[key].str(default)

proc getBool*(v: JsonVal; key: string; default = false): bool =
  v[key].bool(default)

proc getInt64*(v: JsonVal; key: string; default: int64 = 0): int64 =
  v[key].int64(default)

proc getInt*(v: JsonVal; key: string; default = 0): int =
  v[key].int(default)

proc getUInt64*(v: JsonVal; key: string; default: uint64 = 0): uint64 =
  v[key].uint64(default)

proc getFloat*(v: JsonVal; key: string; default = 0.0): float =
  v[key].float(default)

proc getCStr*(v: JsonVal; index: int; default: cstring = ""): cstring =
  v[index].cstr(default)

proc getStr*(v: JsonVal; index: int; default = ""): string =
  v[index].str(default)

proc getBool*(v: JsonVal; index: int; default = false): bool =
  v[index].bool(default)

proc getInt64*(v: JsonVal; index: int; default: int64 = 0): int64 =
  v[index].int64(default)

proc getInt*(v: JsonVal; index: int; default = 0): int =
  v[index].int(default)

proc getUInt64*(v: JsonVal; index: int; default: uint64 = 0): uint64 =
  v[index].uint64(default)

proc getFloat*(v: JsonVal; index: int; default = 0.0): float =
  v[index].float(default)

proc getCStr*(v: JsonMutVal; key: string; default: cstring = ""): cstring =
  v[key].cstr(default)

proc getStr*(v: JsonMutVal; key: string; default = ""): string =
  v[key].str(default)

proc getBool*(v: JsonMutVal; key: string; default = false): bool =
  v[key].bool(default)

proc getInt64*(v: JsonMutVal; key: string; default: int64 = 0): int64 =
  v[key].int64(default)

proc getInt*(v: JsonMutVal; key: string; default = 0): int =
  v[key].int(default)

proc getUInt64*(v: JsonMutVal; key: string; default: uint64 = 0): uint64 =
  v[key].uint64(default)

proc getFloat*(v: JsonMutVal; key: string; default = 0.0): float =
  v[key].float(default)

proc getCStr*(v: JsonMutVal; index: int; default: cstring = ""): cstring =
  v[index].cstr(default)

proc getStr*(v: JsonMutVal; index: int; default = ""): string =
  v[index].str(default)

proc getBool*(v: JsonMutVal; index: int; default = false): bool =
  v[index].bool(default)

proc getInt64*(v: JsonMutVal; index: int; default: int64 = 0): int64 =
  v[index].int64(default)

proc getInt*(v: JsonMutVal; index: int; default = 0): int =
  v[index].int(default)

proc getUInt64*(v: JsonMutVal; index: int; default: uint64 = 0): uint64 =
  v[index].uint64(default)

proc getFloat*(v: JsonMutVal; index: int; default = 0.0): float =
  v[index].float(default)

proc replace*(arr: JsonMutVal; index: int; val: JsonMutVal): JsonMutVal =
  if arr.isArray and index >= 0:
    JsonMutVal(p: yyjson_mut_arr_replace(arr.p, csize_t(index), val.p), d: arr.d)
  else:
    JsonMutVal(p: nil, d: arr.d)

proc remove*(arr: JsonMutVal; index: int): JsonMutVal =
  if arr.isArray and index >= 0:
    JsonMutVal(p: yyjson_mut_arr_remove(arr.p, csize_t(index)), d: arr.d)
  else:
    JsonMutVal(p: nil, d: arr.d)

proc replace*(obj: JsonMutVal; key: string; val: JsonMutVal): bool =
  if obj.d.isNil:
    raise newException(JsonError, "JsonMutVal has no owning document")
  let keyVal = yyjson_mut_str_copy_n(obj.d, key.cstring, csize_t(key.len))
  (not keyVal.isNil) and yyjson_mut_obj_replace(obj.p, keyVal, val.p)

proc remove*(obj: JsonMutVal; key: string): JsonMutVal =
  if obj.isObject:
    JsonMutVal(p: yyjson_mut_obj_remove_keyn(obj.p, key.cstring, key.len.csize_t), d: obj.d)
  else:
    JsonMutVal(p: nil, d: obj.d)

proc clear*(v: JsonMutVal): bool =
  if v.isArray:
    yyjson_mut_arr_clear(v.p)
  elif v.isObject:
    yyjson_mut_obj_clear(v.p)
  else:
    false

iterator items*(v: JsonVal): JsonVal =
  if v.isArray:
    var it: YyJsonArrIter
    if yyjson_arr_iter_init(v.p, addr it):
      while true:
        let x = yyjson_arr_iter_next(addr it)
        if x.isNil:
          break
        yield JsonVal(p: x)

iterator pairs*(v: JsonVal): tuple[key: cstring, value: JsonVal] =
  if v.isObject:
    var it: YyJsonObjIter
    if yyjson_obj_iter_init(v.p, addr it):
      while true:
        let keyVal = yyjson_obj_iter_next(addr it)
        if keyVal.isNil:
          break
        let val = yyjson_obj_iter_get_val(keyVal)
        yield (yyjson_get_str(keyVal), JsonVal(p: val))

iterator items*(v: JsonMutVal): JsonMutVal =
  if v.isArray:
    var it: YyJsonMutArrIter
    if yyjson_mut_arr_iter_init(v.p, addr it):
      while true:
        let x = yyjson_mut_arr_iter_next(addr it)
        if x.isNil:
          break
        yield JsonMutVal(p: x, d: v.d)

iterator pairs*(v: JsonMutVal): tuple[key: cstring, value: JsonMutVal] =
  if v.isObject:
    var it: YyJsonMutObjIter
    if yyjson_mut_obj_iter_init(v.p, addr it):
      while true:
        let keyVal = yyjson_mut_obj_iter_next(addr it)
        if keyVal.isNil:
          break
        let val = yyjson_mut_obj_iter_get_val(keyVal)
        yield (yyjson_mut_get_str(keyVal), JsonMutVal(p: val, d: v.d))

proc pointer*(v: JsonVal; path: string): JsonVal =
  if v.p.isNil:
    return JsonVal(p: nil)
  JsonVal(p: yyjson_ptr_getn(v.p, path.cstring, path.len.csize_t))

proc pointerCString*(v: JsonVal; path: cstring): JsonVal =
  if v.p.isNil:
    return JsonVal(p: nil)
  JsonVal(p: yyjson_ptr_get(v.p, path))

proc pointerLen*(v: JsonVal; path: string; pathLen: int): JsonVal =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  if v.p.isNil:
    return JsonVal(p: nil)
  JsonVal(p: yyjson_ptr_getn(v.p, path.cstring, pathLen.csize_t))

proc pointerStrict*(v: JsonVal; path: string): JsonVal =
  var err: YyJsonPtrErr
  let p = yyjson_ptr_getx(v.p, path.cstring, path.len.csize_t, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to resolve JSON pointer", err)
  JsonVal(p: p)

proc pointerStrictLen*(v: JsonVal; path: string; pathLen: int): JsonVal =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  var err: YyJsonPtrErr
  let p = yyjson_ptr_getx(v.p, path.cstring, pathLen.csize_t, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to resolve JSON pointer", err)
  JsonVal(p: p)

proc pointerGetBool*(v: JsonVal; path: string; value: var bool): bool =
  if v.p.isNil:
    return false
  yyjson_ptr_get_bool(v.p, path.cstring, addr value)

proc pointerGetUInt64*(v: JsonVal; path: string; value: var uint64): bool =
  if v.p.isNil:
    return false
  yyjson_ptr_get_uint(v.p, path.cstring, addr value)

proc pointerGetInt64*(v: JsonVal; path: string; value: var int64): bool =
  if v.p.isNil:
    return false
  yyjson_ptr_get_sint(v.p, path.cstring, addr value)

proc pointerGetReal*(v: JsonVal; path: string; value: var float): bool =
  if v.p.isNil:
    return false
  var raw: cdouble
  result = yyjson_ptr_get_real(v.p, path.cstring, addr raw)
  if result:
    value = system.float(raw)

proc pointerGetNum*(v: JsonVal; path: string; value: var float): bool =
  if v.p.isNil:
    return false
  var raw: cdouble
  result = yyjson_ptr_get_num(v.p, path.cstring, addr raw)
  if result:
    value = system.float(raw)

proc pointerGetStr*(v: JsonVal; path: string; value: var string): bool =
  if v.p.isNil:
    return false
  var raw: cstring
  result = yyjson_ptr_get_str(v.p, path.cstring, addr raw)
  if result:
    value = $raw

proc pointer*(d: JsonDoc; path: string): JsonVal =
  if d.p.isNil:
    return JsonVal(p: nil)
  JsonVal(p: yyjson_doc_ptr_getn(d.p, path.cstring, path.len.csize_t))

proc pointerCString*(d: JsonDoc; path: cstring): JsonVal =
  if d.p.isNil:
    return JsonVal(p: nil)
  JsonVal(p: yyjson_doc_ptr_get(d.p, path))

proc pointerLen*(d: JsonDoc; path: string; pathLen: int): JsonVal =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  if d.p.isNil:
    return JsonVal(p: nil)
  JsonVal(p: yyjson_doc_ptr_getn(d.p, path.cstring, pathLen.csize_t))

proc pointerStrict*(d: JsonDoc; path: string): JsonVal =
  var err: YyJsonPtrErr
  let p = yyjson_doc_ptr_getx(d.p, path.cstring, path.len.csize_t, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to resolve JSON pointer", err)
  JsonVal(p: p)

proc pointerStrictLen*(d: JsonDoc; path: string; pathLen: int): JsonVal =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  var err: YyJsonPtrErr
  let p = yyjson_doc_ptr_getx(d.p, path.cstring, pathLen.csize_t, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to resolve JSON pointer", err)
  JsonVal(p: p)

proc pointer*(v: JsonMutVal; path: string): JsonMutVal =
  if v.p.isNil:
    return JsonMutVal(p: nil, d: v.d)
  JsonMutVal(p: yyjson_mut_ptr_getn(v.p, path.cstring, path.len.csize_t), d: v.d)

proc pointerCString*(v: JsonMutVal; path: cstring): JsonMutVal =
  if v.p.isNil:
    return JsonMutVal(p: nil, d: v.d)
  JsonMutVal(p: yyjson_mut_ptr_get(v.p, path), d: v.d)

proc pointerLen*(v: JsonMutVal; path: string; pathLen: int): JsonMutVal =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  if v.p.isNil:
    return JsonMutVal(p: nil, d: v.d)
  JsonMutVal(p: yyjson_mut_ptr_getn(v.p, path.cstring, pathLen.csize_t), d: v.d)

proc pointerStrict*(v: JsonMutVal; path: string): JsonMutVal =
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  let p = yyjson_mut_ptr_getx(v.p, path.cstring, path.len.csize_t,
                              addr ctx, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to resolve mutable JSON pointer", err)
  JsonMutVal(p: p, d: v.d)

proc pointer*(v: JsonMutVal; path: string;
              ctx: var JsonPointerContext): JsonMutVal =
  var err: YyJsonPtrErr
  ctx = JsonPointerContext(d: v.d)
  let p = yyjson_mut_ptr_getx(v.p, path.cstring, path.len.csize_t,
                              addr ctx.raw, addr err)
  JsonMutVal(p: p, d: v.d)

proc pointerStrictLen*(v: JsonMutVal; path: string; pathLen: int): JsonMutVal =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  let p = yyjson_mut_ptr_getx(v.p, path.cstring, pathLen.csize_t,
                              addr ctx, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to resolve mutable JSON pointer", err)
  JsonMutVal(p: p, d: v.d)

proc pointerStrict*(v: JsonMutVal; path: string;
                    ctx: var JsonPointerContext): JsonMutVal =
  var err: YyJsonPtrErr
  ctx = JsonPointerContext(d: v.d)
  let p = yyjson_mut_ptr_getx(v.p, path.cstring, path.len.csize_t,
                              addr ctx.raw, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to resolve mutable JSON pointer", err)
  JsonMutVal(p: p, d: v.d)

proc pointer*(d: JsonMutDoc; path: string): JsonMutVal =
  if d.p.isNil:
    return JsonMutVal(p: nil, d: nil)
  JsonMutVal(p: yyjson_mut_doc_ptr_getn(d.p, path.cstring, path.len.csize_t),
             d: d.p)

proc pointerCString*(d: JsonMutDoc; path: cstring): JsonMutVal =
  if d.p.isNil:
    return JsonMutVal(p: nil, d: nil)
  JsonMutVal(p: yyjson_mut_doc_ptr_get(d.p, path), d: d.p)

proc pointerLen*(d: JsonMutDoc; path: string; pathLen: int): JsonMutVal =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  if d.p.isNil:
    return JsonMutVal(p: nil, d: nil)
  JsonMutVal(p: yyjson_mut_doc_ptr_getn(d.p, path.cstring, pathLen.csize_t),
             d: d.p)

proc pointerStrict*(d: JsonMutDoc; path: string): JsonMutVal =
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  let p = yyjson_mut_doc_ptr_getx(d.p, path.cstring, path.len.csize_t,
                                  addr ctx, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to resolve mutable JSON pointer", err)
  JsonMutVal(p: p, d: d.p)

proc pointer*(d: JsonMutDoc; path: string;
              ctx: var JsonPointerContext): JsonMutVal =
  var err: YyJsonPtrErr
  ctx = JsonPointerContext(d: d.p)
  let p = yyjson_mut_doc_ptr_getx(d.p, path.cstring, path.len.csize_t,
                                  addr ctx.raw, addr err)
  JsonMutVal(p: p, d: d.p)

proc pointerStrictLen*(d: JsonMutDoc; path: string; pathLen: int): JsonMutVal =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  let p = yyjson_mut_doc_ptr_getx(d.p, path.cstring, pathLen.csize_t,
                                  addr ctx, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to resolve mutable JSON pointer", err)
  JsonMutVal(p: p, d: d.p)

proc pointerStrict*(d: JsonMutDoc; path: string;
                    ctx: var JsonPointerContext): JsonMutVal =
  var err: YyJsonPtrErr
  ctx = JsonPointerContext(d: d.p)
  let p = yyjson_mut_doc_ptr_getx(d.p, path.cstring, path.len.csize_t,
                                  addr ctx.raw, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to resolve mutable JSON pointer", err)
  JsonMutVal(p: p, d: d.p)

proc container*(ctx: JsonPointerContext): JsonMutVal =
  JsonMutVal(p: ctx.raw.ctn, d: ctx.d)

proc previous*(ctx: JsonPointerContext): JsonMutVal =
  JsonMutVal(p: ctx.raw.pre, d: ctx.d)

proc old*(ctx: JsonPointerContext): JsonMutVal =
  JsonMutVal(p: ctx.raw.old, d: ctx.d)

proc append*(ctx: var JsonPointerContext; val: JsonMutVal): bool =
  yyjson_ptr_ctx_append(addr ctx.raw, nil, val.p)

proc append*(ctx: var JsonPointerContext; key: JsonMutVal;
             val: JsonMutVal): bool =
  yyjson_ptr_ctx_append(addr ctx.raw, key.p, val.p)

proc append*(ctx: var JsonPointerContext; key: string;
             val: JsonMutVal): bool =
  if ctx.d.isNil:
    return false
  let keyVal = yyjson_mut_str_copy_n(ctx.d, key.cstring, key.len.csize_t)
  (not keyVal.isNil) and yyjson_ptr_ctx_append(addr ctx.raw, keyVal, val.p)

proc replace*(ctx: var JsonPointerContext; val: JsonMutVal): JsonMutVal =
  if yyjson_ptr_ctx_replace(addr ctx.raw, val.p):
    JsonMutVal(p: ctx.raw.old, d: ctx.d)
  else:
    JsonMutVal(p: nil, d: ctx.d)

proc remove*(ctx: var JsonPointerContext): JsonMutVal =
  if yyjson_ptr_ctx_remove(addr ctx.raw):
    JsonMutVal(p: ctx.raw.old, d: ctx.d)
  else:
    JsonMutVal(p: nil, d: ctx.d)

proc pointerAdd*(d: JsonMutDoc; path: string; val: JsonMutVal): bool =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  yyjson_mut_doc_ptr_addn(d.p, path.cstring, path.len.csize_t, val.p)

proc pointerAddCString*(d: JsonMutDoc; path: cstring; val: JsonMutVal): bool =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  yyjson_mut_doc_ptr_add(d.p, path, val.p)

proc pointerAddStrict*(d: JsonMutDoc; path: string; val: JsonMutVal;
                       createParent = true) =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  if not yyjson_mut_doc_ptr_addx(d.p, path.cstring, path.len.csize_t, val.p,
                                 createParent, addr ctx, addr err):
    raisePointerError("yyjson failed to add by JSON pointer", err)

proc pointerAddStrictLen*(d: JsonMutDoc; path: string; pathLen: int;
                          val: JsonMutVal; createParent = true) =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  if not yyjson_mut_doc_ptr_addx(d.p, path.cstring, pathLen.csize_t, val.p,
                                 createParent, addr ctx, addr err):
    raisePointerError("yyjson failed to add by JSON pointer", err)

proc pointerSet*(d: JsonMutDoc; path: string; val: JsonMutVal): bool =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  yyjson_mut_doc_ptr_setn(d.p, path.cstring, path.len.csize_t, val.p)

proc pointerSetCString*(d: JsonMutDoc; path: cstring; val: JsonMutVal): bool =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  yyjson_mut_doc_ptr_set(d.p, path, val.p)

proc pointerSetStrict*(d: JsonMutDoc; path: string; val: JsonMutVal;
                       createParent = true) =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  if not yyjson_mut_doc_ptr_setx(d.p, path.cstring, path.len.csize_t, val.p,
                                 createParent, addr ctx, addr err):
    raisePointerError("yyjson failed to set by JSON pointer", err)

proc pointerSetStrictLen*(d: JsonMutDoc; path: string; pathLen: int;
                          val: JsonMutVal; createParent = true) =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  if not yyjson_mut_doc_ptr_setx(d.p, path.cstring, pathLen.csize_t, val.p,
                                 createParent, addr ctx, addr err):
    raisePointerError("yyjson failed to set by JSON pointer", err)

proc pointerReplace*(d: JsonMutDoc; path: string; val: JsonMutVal): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  JsonMutVal(p: yyjson_mut_doc_ptr_replacen(d.p, path.cstring,
                                            path.len.csize_t, val.p),
             d: d.p)

proc pointerReplaceCString*(d: JsonMutDoc; path: cstring;
                            val: JsonMutVal): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  JsonMutVal(p: yyjson_mut_doc_ptr_replace(d.p, path, val.p), d: d.p)

proc pointerReplaceStrict*(d: JsonMutDoc; path: string; val: JsonMutVal): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  let p = yyjson_mut_doc_ptr_replacex(d.p, path.cstring, path.len.csize_t,
                                      val.p, addr ctx, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to replace by JSON pointer", err)
  JsonMutVal(p: p, d: d.p)

proc pointerReplaceStrictLen*(d: JsonMutDoc; path: string; pathLen: int;
                              val: JsonMutVal): JsonMutVal =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  let p = yyjson_mut_doc_ptr_replacex(d.p, path.cstring, pathLen.csize_t,
                                      val.p, addr ctx, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to replace by JSON pointer", err)
  JsonMutVal(p: p, d: d.p)

proc pointerRemove*(d: JsonMutDoc; path: string): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  JsonMutVal(p: yyjson_mut_doc_ptr_removen(d.p, path.cstring,
                                           path.len.csize_t),
             d: d.p)

proc pointerRemoveCString*(d: JsonMutDoc; path: cstring): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  JsonMutVal(p: yyjson_mut_doc_ptr_remove(d.p, path), d: d.p)

proc pointerRemoveStrict*(d: JsonMutDoc; path: string): JsonMutVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  let p = yyjson_mut_doc_ptr_removex(d.p, path.cstring, path.len.csize_t,
                                     addr ctx, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to remove by JSON pointer", err)
  JsonMutVal(p: p, d: d.p)

proc pointerRemoveStrictLen*(d: JsonMutDoc; path: string; pathLen: int): JsonMutVal =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  if d.p.isNil:
    raise newException(JsonError, "JsonMutDoc is closed")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  let p = yyjson_mut_doc_ptr_removex(d.p, path.cstring, pathLen.csize_t,
                                     addr ctx, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to remove by JSON pointer", err)
  JsonMutVal(p: p, d: d.p)

proc pointerAdd*(v: JsonMutVal; path: string; val: JsonMutVal): bool =
  if v.d.isNil:
    raise newException(JsonError, "JsonMutVal has no owning document")
  yyjson_mut_ptr_addn(v.p, path.cstring, path.len.csize_t, val.p, v.d)

proc pointerAddCString*(v: JsonMutVal; path: cstring; val: JsonMutVal): bool =
  if v.d.isNil:
    raise newException(JsonError, "JsonMutVal has no owning document")
  yyjson_mut_ptr_add(v.p, path, val.p, v.d)

proc pointerAddStrict*(v: JsonMutVal; path: string; val: JsonMutVal;
                       createParent = true) =
  if v.d.isNil:
    raise newException(JsonError, "JsonMutVal has no owning document")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  if not yyjson_mut_ptr_addx(v.p, path.cstring, path.len.csize_t, val.p, v.d,
                             createParent, addr ctx, addr err):
    raisePointerError("yyjson failed to add by mutable JSON pointer", err)

proc pointerAddStrictLen*(v: JsonMutVal; path: string; pathLen: int;
                          val: JsonMutVal; createParent = true) =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  if v.d.isNil:
    raise newException(JsonError, "JsonMutVal has no owning document")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  if not yyjson_mut_ptr_addx(v.p, path.cstring, pathLen.csize_t, val.p, v.d,
                             createParent, addr ctx, addr err):
    raisePointerError("yyjson failed to add by mutable JSON pointer", err)

proc pointerSet*(v: JsonMutVal; path: string; val: JsonMutVal): bool =
  if v.d.isNil:
    raise newException(JsonError, "JsonMutVal has no owning document")
  yyjson_mut_ptr_setn(v.p, path.cstring, path.len.csize_t, val.p, v.d)

proc pointerSetCString*(v: JsonMutVal; path: cstring; val: JsonMutVal): bool =
  if v.d.isNil:
    raise newException(JsonError, "JsonMutVal has no owning document")
  yyjson_mut_ptr_set(v.p, path, val.p, v.d)

proc pointerSetStrict*(v: JsonMutVal; path: string; val: JsonMutVal;
                       createParent = true) =
  if v.d.isNil:
    raise newException(JsonError, "JsonMutVal has no owning document")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  if not yyjson_mut_ptr_setx(v.p, path.cstring, path.len.csize_t, val.p, v.d,
                             createParent, addr ctx, addr err):
    raisePointerError("yyjson failed to set by mutable JSON pointer", err)

proc pointerSetStrictLen*(v: JsonMutVal; path: string; pathLen: int;
                          val: JsonMutVal; createParent = true) =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  if v.d.isNil:
    raise newException(JsonError, "JsonMutVal has no owning document")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  if not yyjson_mut_ptr_setx(v.p, path.cstring, pathLen.csize_t, val.p, v.d,
                             createParent, addr ctx, addr err):
    raisePointerError("yyjson failed to set by mutable JSON pointer", err)

proc pointerReplace*(v: JsonMutVal; path: string; val: JsonMutVal): JsonMutVal =
  JsonMutVal(p: yyjson_mut_ptr_replacen(v.p, path.cstring,
                                        path.len.csize_t, val.p),
             d: v.d)

proc pointerReplaceCString*(v: JsonMutVal; path: cstring;
                            val: JsonMutVal): JsonMutVal =
  JsonMutVal(p: yyjson_mut_ptr_replace(v.p, path, val.p), d: v.d)

proc pointerReplaceStrict*(v: JsonMutVal; path: string; val: JsonMutVal): JsonMutVal =
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  let p = yyjson_mut_ptr_replacex(v.p, path.cstring, path.len.csize_t,
                                  val.p, addr ctx, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to replace by mutable JSON pointer", err)
  JsonMutVal(p: p, d: v.d)

proc pointerReplaceStrictLen*(v: JsonMutVal; path: string; pathLen: int;
                              val: JsonMutVal): JsonMutVal =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  let p = yyjson_mut_ptr_replacex(v.p, path.cstring, pathLen.csize_t,
                                  val.p, addr ctx, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to replace by mutable JSON pointer", err)
  JsonMutVal(p: p, d: v.d)

proc pointerRemove*(v: JsonMutVal; path: string): JsonMutVal =
  JsonMutVal(p: yyjson_mut_ptr_removen(v.p, path.cstring, path.len.csize_t),
             d: v.d)

proc pointerRemoveCString*(v: JsonMutVal; path: cstring): JsonMutVal =
  JsonMutVal(p: yyjson_mut_ptr_remove(v.p, path), d: v.d)

proc pointerRemoveStrict*(v: JsonMutVal; path: string): JsonMutVal =
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  let p = yyjson_mut_ptr_removex(v.p, path.cstring, path.len.csize_t,
                                 addr ctx, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to remove by mutable JSON pointer", err)
  JsonMutVal(p: p, d: v.d)

proc pointerRemoveStrictLen*(v: JsonMutVal; path: string; pathLen: int): JsonMutVal =
  if pathLen < 0 or pathLen > path.len:
    raise newException(ValueError, "JSON pointer length is out of bounds")
  var err: YyJsonPtrErr
  var ctx: YyJsonPtrCtx
  let p = yyjson_mut_ptr_removex(v.p, path.cstring, pathLen.csize_t,
                                 addr ctx, addr err)
  if p.isNil:
    raisePointerError("yyjson failed to remove by mutable JSON pointer", err)
  JsonMutVal(p: p, d: v.d)

proc `$`*(v: JsonVal): string =
  case v.kind
  of jkNone: "<nil>"
  of jkNull: "null"
  of jkBool: $v.bool()
  of jkNumber: $v.float()
  of jkString: v.str()
  of jkArray: "<array len=" & $v.len & ">"
  of jkObject: "<object len=" & $v.len & ">"
  of jkRaw: "<raw>"

proc `$`*(v: JsonMutVal): string =
  case v.kind
  of jkNone: "<nil>"
  of jkNull: "null"
  of jkBool: $v.bool()
  of jkNumber: $v.float()
  of jkString: v.str()
  of jkArray: "<array len=" & $v.len & ">"
  of jkObject: "<object len=" & $v.len & ">"
  of jkRaw: "<raw>"
