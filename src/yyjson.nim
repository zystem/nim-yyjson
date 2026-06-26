## Thin high-level yyjson wrapper.
##
## This module does not convert values to std/json JsonNode.
## String access is zero-copy unless you explicitly request a Nim string.

import std/[os, strutils]
import yyjson/private

export private.YyJsonReadFlag

type
  JsonKind* = enum
    jkNone, jkRaw, jkNull, jkBool, jkNumber, jkString, jkArray, jkObject

  JsonError* = object of CatchableError

  JsonDoc* = object
    p: ptr YyJsonDoc

  JsonVal* = object
    p: ptr YyJsonVal

proc `=copy`*(dest: var JsonDoc, src: JsonDoc) {.error: "JsonDoc is move-only; use close() exactly once".}

proc isNil*(v: JsonVal): bool {.inline.} =
  v.p.isNil

proc isNil*(d: JsonDoc): bool {.inline.} =
  d.p.isNil

proc close*(d: var JsonDoc) =
  if not d.p.isNil:
    yyjson_doc_free(d.p)
    d.p = nil

proc readJson*(s: string; flags: YyJsonReadFlag = 0'u32): JsonDoc =
  let p = yyjson_read(s.cstring, s.len.csize_t, flags)
  if p.isNil:
    raise newException(JsonError, "yyjson failed to parse JSON string")
  result = JsonDoc(p: p)

proc readJsonFile*(path: string; flags: YyJsonReadFlag = 0'u32): JsonDoc =
  let p = yyjson_read_file(path.cstring, flags, nil, nil)
  if p.isNil:
    raise newException(JsonError, "yyjson failed to parse JSON file: " & path)
  result = JsonDoc(p: p)

proc root*(d: JsonDoc): JsonVal =
  if d.p.isNil:
    raise newException(JsonError, "JsonDoc is closed")
  result = JsonVal(p: yyjson_doc_get_root(d.p))

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

proc isBool*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_bool(v.p)

proc isNumber*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_num(v.p)

proc isString*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_str(v.p)

proc isArray*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_arr(v.p)

proc isObject*(v: JsonVal): bool {.inline.} =
  (not v.p.isNil) and yyjson_is_obj(v.p)

proc len*(v: JsonVal): int =
  if v.p.isNil:
    return 0
  int(yyjson_get_len(v.p))

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

proc uint64*(v: JsonVal; default: uint64 = 0): uint64 =
  if v.isNumber:
    yyjson_get_uint(v.p)
  else:
    default

proc float*(v: JsonVal; default = 0.0): float =
  if v.isNumber:
    float(yyjson_get_real(v.p))
  else:
    default

proc cstr*(v: JsonVal; default: cstring = ""): cstring =
  if v.isString:
    let p = yyjson_get_str(v.p)
    if p.isNil: default else: p
  else:
    default

proc str*(v: JsonVal; default = ""): string =
  if v.isString:
    $v.cstr()
  else:
    default

proc `[]`*(v: JsonVal; key: string): JsonVal =
  if v.isObject:
    JsonVal(p: yyjson_obj_get(v.p, key.cstring))
  else:
    JsonVal(p: nil)

proc getCStr*(v: JsonVal; key: string; default: cstring = ""): cstring =
  v[key].cstr(default)

proc getStr*(v: JsonVal; key: string; default = ""): string =
  v[key].str(default)

proc getBool*(v: JsonVal; key: string; default = false): bool =
  v[key].bool(default)

proc getInt64*(v: JsonVal; key: string; default: int64 = 0): int64 =
  v[key].int64(default)

proc getFloat*(v: JsonVal; key: string; default = 0.0): float =
  v[key].float(default)

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

proc pointer*(v: JsonVal; path: string): JsonVal =
  if v.p.isNil:
    return JsonVal(p: nil)
  JsonVal(p: yyjson_ptr_get(v.p, path.cstring, path.len.csize_t))

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
