# Low-level yyjson FFI.
#
# This module intentionally exposes only the subset needed by the high-level wrapper.
# More bindings can be added without breaking the high-level API.

{.passC: "-I" & currentSourcePath().parentDir().parentDir().parentDir() / "vendor".}

type
  YyJsonDoc* {.importc: "yyjson_doc", header: "yyjson.h", incompleteStruct.} = object
  YyJsonVal* {.importc: "yyjson_val", header: "yyjson.h", incompleteStruct.} = object

  YyJsonReadFlag* = uint32
  YyJsonType* = uint8

  YyJsonObjIter* {.importc: "yyjson_obj_iter", header: "yyjson.h", bycopy.} = object
    idx*: csize_t
    max*: csize_t
    cur*: ptr YyJsonVal
    obj*: ptr YyJsonVal

  YyJsonArrIter* {.importc: "yyjson_arr_iter", header: "yyjson.h", bycopy.} = object
    idx*: csize_t
    max*: csize_t
    cur*: ptr YyJsonVal
    arr*: ptr YyJsonVal

const
  YYJSON_TYPE_NONE* = 0'u8
  YYJSON_TYPE_RAW* = 1'u8
  YYJSON_TYPE_NULL* = 2'u8
  YYJSON_TYPE_BOOL* = 3'u8
  YYJSON_TYPE_NUM* = 4'u8
  YYJSON_TYPE_STR* = 5'u8
  YYJSON_TYPE_ARR* = 6'u8
  YYJSON_TYPE_OBJ* = 7'u8

# compile vendored yyjson.c automatically.
{.compile: "../../vendor/yyjson.c".}

proc yyjson_read*(dat: cstring, len: csize_t, flg: YyJsonReadFlag): ptr YyJsonDoc
  {.importc, header: "yyjson.h".}

proc yyjson_read_file*(path: cstring, flg: YyJsonReadFlag, alc: pointer, err: pointer): ptr YyJsonDoc
  {.importc, header: "yyjson.h".}

proc yyjson_doc_free*(doc: ptr YyJsonDoc)
  {.importc, header: "yyjson.h".}

proc yyjson_doc_get_root*(doc: ptr YyJsonDoc): ptr YyJsonVal
  {.importc, header: "yyjson.h".}

proc yyjson_get_type*(val: ptr YyJsonVal): YyJsonType
  {.importc, header: "yyjson.h".}

proc yyjson_is_null*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_bool*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_num*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_str*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_arr*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_obj*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_get_bool*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_get_sint*(val: ptr YyJsonVal): int64
  {.importc, header: "yyjson.h".}

proc yyjson_get_uint*(val: ptr YyJsonVal): uint64
  {.importc, header: "yyjson.h".}

proc yyjson_get_real*(val: ptr YyJsonVal): cdouble
  {.importc, header: "yyjson.h".}

proc yyjson_get_str*(val: ptr YyJsonVal): cstring
  {.importc, header: "yyjson.h".}

proc yyjson_get_len*(val: ptr YyJsonVal): csize_t
  {.importc, header: "yyjson.h".}

proc yyjson_obj_get*(obj: ptr YyJsonVal, key: cstring): ptr YyJsonVal
  {.importc, header: "yyjson.h".}

proc yyjson_obj_iter_init*(obj: ptr YyJsonVal, iter: ptr YyJsonObjIter): bool
  {.importc, header: "yyjson.h".}

proc yyjson_obj_iter_next*(iter: ptr YyJsonObjIter): ptr YyJsonVal
  {.importc, header: "yyjson.h".}

proc yyjson_obj_iter_get_val*(key: ptr YyJsonVal): ptr YyJsonVal
  {.importc, header: "yyjson.h".}

proc yyjson_arr_iter_init*(arr: ptr YyJsonVal, iter: ptr YyJsonArrIter): bool
  {.importc, header: "yyjson.h".}

proc yyjson_arr_iter_next*(iter: ptr YyJsonArrIter): ptr YyJsonVal
  {.importc, header: "yyjson.h".}

proc yyjson_ptr_get*(val: ptr YyJsonVal, ptrStr: cstring, ptrLen: csize_t): ptr YyJsonVal
  {.importc, header: "yyjson.h".}
