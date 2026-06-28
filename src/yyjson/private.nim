# Low-level yyjson FFI.
#
# This module intentionally exposes only the subset needed by the high-level wrapper.
# More bindings can be added without breaking the high-level API.

import std/os

{.passC: "-std=c99".}

const
  privateDir = currentSourcePath().parentDir()
  moduleVendorDir = privateDir / "vendor"
  sourceVendorDir = privateDir.parentDir().parentDir() / "vendor"
  installedVendorDir = privateDir.parentDir() / "vendor"

when fileExists(moduleVendorDir / "yyjson.c"):
  const yyjsonVendorDir = moduleVendorDir
  const yyjsonCompilePath = "vendor/yyjson.c"
elif fileExists(sourceVendorDir / "yyjson.c"):
  const yyjsonVendorDir = sourceVendorDir
  const yyjsonCompilePath = "../../vendor/yyjson.c"
elif fileExists(installedVendorDir / "yyjson.c"):
  const yyjsonVendorDir = installedVendorDir
  const yyjsonCompilePath = "../vendor/yyjson.c"
else:
  {.error: "vendored yyjson not found: expected vendor/yyjson.c and vendor/yyjson.h".}

{.passC: "-I" & yyjsonVendorDir.}

type
  YyJsonDoc* {.importc: "yyjson_doc", header: "yyjson.h", incompleteStruct.} = object
  YyJsonVal* {.importc: "yyjson_val", header: "yyjson.h", incompleteStruct.} = object
  YyJsonMutDoc* {.importc: "yyjson_mut_doc", header: "yyjson.h", incompleteStruct.} = object
  YyJsonMutVal* {.importc: "yyjson_mut_val", header: "yyjson.h", incompleteStruct.} = object
  YyJsonIncrState* {.importc: "yyjson_incr_state", header: "yyjson.h", incompleteStruct.} = object

  YyJsonReadFlag* = uint32
  YyJsonReadCode* = uint32
  YyJsonWriteFlag* = uint32
  YyJsonWriteCode* = uint32
  YyJsonPtrCode* = uint32
  YyJsonPatchCode* = uint32
  YyJsonType* = uint8
  YyJsonAlcMalloc* = proc(ctx: pointer, size: csize_t): pointer {.cdecl.}
  YyJsonAlcRealloc* = proc(ctx: pointer, p: pointer, oldSize: csize_t,
                           size: csize_t): pointer {.cdecl.}
  YyJsonAlcFree* = proc(ctx: pointer, p: pointer) {.cdecl.}

  YyJsonAlc* {.importc: "yyjson_alc", header: "yyjson.h", bycopy.} = object
    malloc*: YyJsonAlcMalloc
    realloc*: YyJsonAlcRealloc
    free*: YyJsonAlcFree
    ctx*: pointer

  YyJsonReadErr* {.importc: "yyjson_read_err", header: "yyjson.h", bycopy.} = object
    code*: YyJsonReadCode
    msg*: cstring
    pos*: csize_t

  YyJsonWriteErr* {.importc: "yyjson_write_err", header: "yyjson.h", bycopy.} = object
    code*: YyJsonWriteCode
    msg*: cstring

  YyJsonPtrErr* {.importc: "yyjson_ptr_err", header: "yyjson.h", bycopy.} = object
    code*: YyJsonPtrCode
    msg*: cstring
    pos*: csize_t

  YyJsonPatchErr* {.importc: "yyjson_patch_err", header: "yyjson.h", bycopy.} = object
    code*: YyJsonPatchCode
    idx*: csize_t
    msg*: cstring
    ptrErr* {.importc: "ptr".}: YyJsonPtrErr

  YyJsonPtrCtx* {.importc: "yyjson_ptr_ctx", header: "yyjson.h", bycopy.} = object
    ctn*: ptr YyJsonMutVal
    pre*: ptr YyJsonMutVal
    old*: ptr YyJsonMutVal

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

  YyJsonMutObjIter* {.importc: "yyjson_mut_obj_iter", header: "yyjson.h", bycopy.} = object
    idx*: csize_t
    max*: csize_t
    cur*: ptr YyJsonMutVal
    pre*: ptr YyJsonMutVal
    obj*: ptr YyJsonMutVal

  YyJsonMutArrIter* {.importc: "yyjson_mut_arr_iter", header: "yyjson.h", bycopy.} = object
    idx*: csize_t
    max*: csize_t
    cur*: ptr YyJsonMutVal
    pre*: ptr YyJsonMutVal
    arr*: ptr YyJsonMutVal

const
  YYJSON_READ_NOFLAG* = 0'u32
  YYJSON_READ_INSITU* = 1'u32 shl 0
  YYJSON_READ_STOP_WHEN_DONE* = 1'u32 shl 1
  YYJSON_READ_ALLOW_TRAILING_COMMAS* = 1'u32 shl 2
  YYJSON_READ_ALLOW_COMMENTS* = 1'u32 shl 3
  YYJSON_READ_ALLOW_INF_AND_NAN* = 1'u32 shl 4
  YYJSON_READ_NUMBER_AS_RAW* = 1'u32 shl 5
  YYJSON_READ_ALLOW_INVALID_UNICODE* = 1'u32 shl 6
  YYJSON_READ_BIGNUM_AS_RAW* = 1'u32 shl 7
  YYJSON_READ_ALLOW_BOM* = 1'u32 shl 8
  YYJSON_READ_ALLOW_EXT_NUMBER* = 1'u32 shl 9
  YYJSON_READ_ALLOW_EXT_ESCAPE* = 1'u32 shl 10
  YYJSON_READ_ALLOW_EXT_WHITESPACE* = 1'u32 shl 11
  YYJSON_READ_ALLOW_SINGLE_QUOTED_STR* = 1'u32 shl 12
  YYJSON_READ_ALLOW_UNQUOTED_KEY* = 1'u32 shl 13
  YYJSON_READ_JSON5* =
    YYJSON_READ_ALLOW_TRAILING_COMMAS or
    YYJSON_READ_ALLOW_COMMENTS or
    YYJSON_READ_ALLOW_INF_AND_NAN or
    YYJSON_READ_ALLOW_EXT_NUMBER or
    YYJSON_READ_ALLOW_EXT_ESCAPE or
    YYJSON_READ_ALLOW_EXT_WHITESPACE or
    YYJSON_READ_ALLOW_SINGLE_QUOTED_STR or
    YYJSON_READ_ALLOW_UNQUOTED_KEY

  YYJSON_READ_SUCCESS* = 0'u32
  YYJSON_READ_ERROR_INVALID_PARAMETER* = 1'u32
  YYJSON_READ_ERROR_MEMORY_ALLOCATION* = 2'u32
  YYJSON_READ_ERROR_EMPTY_CONTENT* = 3'u32
  YYJSON_READ_ERROR_UNEXPECTED_CONTENT* = 4'u32
  YYJSON_READ_ERROR_UNEXPECTED_END* = 5'u32
  YYJSON_READ_ERROR_UNEXPECTED_CHARACTER* = 6'u32
  YYJSON_READ_ERROR_JSON_STRUCTURE* = 7'u32
  YYJSON_READ_ERROR_INVALID_COMMENT* = 8'u32
  YYJSON_READ_ERROR_INVALID_NUMBER* = 9'u32
  YYJSON_READ_ERROR_INVALID_STRING* = 10'u32
  YYJSON_READ_ERROR_LITERAL* = 11'u32
  YYJSON_READ_ERROR_FILE_OPEN* = 12'u32
  YYJSON_READ_ERROR_FILE_READ* = 13'u32
  YYJSON_READ_ERROR_MORE* = 14'u32
  YYJSON_READ_ERROR_DEPTH* = 15'u32

  YYJSON_TYPE_NONE* = 0'u8
  YYJSON_TYPE_RAW* = 1'u8
  YYJSON_TYPE_NULL* = 2'u8
  YYJSON_TYPE_BOOL* = 3'u8
  YYJSON_TYPE_NUM* = 4'u8
  YYJSON_TYPE_STR* = 5'u8
  YYJSON_TYPE_ARR* = 6'u8
  YYJSON_TYPE_OBJ* = 7'u8

  YYJSON_WRITE_NOFLAG* = 0'u32
  YYJSON_WRITE_PRETTY* = 1'u32 shl 0
  YYJSON_WRITE_ESCAPE_UNICODE* = 1'u32 shl 1
  YYJSON_WRITE_ESCAPE_SLASHES* = 1'u32 shl 2
  YYJSON_WRITE_ALLOW_INF_AND_NAN* = 1'u32 shl 3
  YYJSON_WRITE_INF_AND_NAN_AS_NULL* = 1'u32 shl 4
  YYJSON_WRITE_ALLOW_INVALID_UNICODE* = 1'u32 shl 5
  YYJSON_WRITE_PRETTY_TWO_SPACES* = 1'u32 shl 6
  YYJSON_WRITE_NEWLINE_AT_END* = 1'u32 shl 7
  YYJSON_WRITE_LOWERCASE_HEX* = 1'u32 shl 8

  YYJSON_WRITE_SUCCESS* = 0'u32
  YYJSON_WRITE_ERROR_INVALID_PARAMETER* = 1'u32
  YYJSON_WRITE_ERROR_MEMORY_ALLOCATION* = 2'u32
  YYJSON_WRITE_ERROR_INVALID_VALUE_TYPE* = 3'u32
  YYJSON_WRITE_ERROR_NAN_OR_INF* = 4'u32
  YYJSON_WRITE_ERROR_FILE_OPEN* = 5'u32
  YYJSON_WRITE_ERROR_FILE_WRITE* = 6'u32
  YYJSON_WRITE_ERROR_INVALID_STRING* = 7'u32

  YYJSON_PTR_ERR_NONE* = 0'u32
  YYJSON_PTR_ERR_PARAMETER* = 1'u32
  YYJSON_PTR_ERR_SYNTAX* = 2'u32
  YYJSON_PTR_ERR_RESOLVE* = 3'u32
  YYJSON_PTR_ERR_NULL_ROOT* = 4'u32
  YYJSON_PTR_ERR_SET_ROOT* = 5'u32
  YYJSON_PTR_ERR_MEMORY_ALLOCATION* = 6'u32

  YYJSON_PATCH_SUCCESS* = 0'u32
  YYJSON_PATCH_ERROR_INVALID_PARAMETER* = 1'u32
  YYJSON_PATCH_ERROR_MEMORY_ALLOCATION* = 2'u32
  YYJSON_PATCH_ERROR_INVALID_OPERATION* = 3'u32
  YYJSON_PATCH_ERROR_MISSING_KEY* = 4'u32
  YYJSON_PATCH_ERROR_INVALID_MEMBER* = 5'u32
  YYJSON_PATCH_ERROR_EQUAL* = 6'u32
  YYJSON_PATCH_ERROR_POINTER* = 7'u32

# Compile vendored yyjson.c automatically.
{.compile: yyjsonCompilePath.}

proc yyjson_read*(dat: cstring, len: csize_t, flg: YyJsonReadFlag): ptr YyJsonDoc
  {.importc, header: "yyjson.h".}

proc yyjson_read_opts*(dat: cstring, len: csize_t, flg: YyJsonReadFlag,
                       alc: pointer, err: ptr YyJsonReadErr): ptr YyJsonDoc
  {.importc, header: "yyjson.h".}

proc yyjson_incr_new*(buf: cstring, bufLen: csize_t, flg: YyJsonReadFlag,
                      alc: pointer): ptr YyJsonIncrState
  {.importc, header: "yyjson.h".}

proc yyjson_incr_read*(state: ptr YyJsonIncrState, len: csize_t,
                       err: ptr YyJsonReadErr): ptr YyJsonDoc
  {.importc, header: "yyjson.h".}

proc yyjson_incr_free*(state: ptr YyJsonIncrState)
  {.importc, header: "yyjson.h".}

proc yyjson_read_max_memory_usage*(len: csize_t,
                                   flg: YyJsonReadFlag): csize_t
  {.importc, header: "yyjson.h".}

proc yyjson_alc_pool_init*(alc: ptr YyJsonAlc, buf: pointer,
                           size: csize_t): bool
  {.importc, header: "yyjson.h".}

proc yyjson_alc_dyn_new*(): ptr YyJsonAlc
  {.importc, header: "yyjson.h".}

proc yyjson_alc_dyn_free*(alc: ptr YyJsonAlc)
  {.importc, header: "yyjson.h".}

proc yyjson_read_file*(path: cstring, flg: YyJsonReadFlag, alc: pointer,
                       err: ptr YyJsonReadErr): ptr YyJsonDoc
  {.importc, header: "yyjson.h".}

proc yyjson_locate_pos*(str: cstring, len: csize_t, pos: csize_t,
                        line: ptr csize_t, col: ptr csize_t,
                        chr: ptr csize_t): bool
  {.importc, header: "yyjson.h".}

proc yyjson_doc_free*(doc: ptr YyJsonDoc)
  {.importc, header: "yyjson.h".}

proc yyjson_doc_get_root*(doc: ptr YyJsonDoc): ptr YyJsonVal
  {.importc, header: "yyjson.h".}

proc yyjson_doc_get_read_size*(doc: ptr YyJsonDoc): csize_t
  {.importc, header: "yyjson.h".}

proc yyjson_doc_get_val_count*(doc: ptr YyJsonDoc): csize_t
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_new*(alc: pointer): ptr YyJsonMutDoc
  {.importc, header: "yyjson.h".}

proc yyjson_doc_mut_copy*(doc: ptr YyJsonDoc, alc: pointer): ptr YyJsonMutDoc
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_mut_copy*(doc: ptr YyJsonMutDoc,
                              alc: pointer): ptr YyJsonMutDoc
  {.importc, header: "yyjson.h".}

proc yyjson_val_mut_copy*(doc: ptr YyJsonMutDoc,
                          val: ptr YyJsonVal): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_val_mut_copy*(doc: ptr YyJsonMutDoc,
                              val: ptr YyJsonMutVal): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_free*(doc: ptr YyJsonMutDoc)
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_get_root*(doc: ptr YyJsonMutDoc): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_set_root*(doc: ptr YyJsonMutDoc, root: ptr YyJsonMutVal)
  {.importc, header: "yyjson.h".}

proc yyjson_mut_write_opts*(doc: ptr YyJsonMutDoc, flg: YyJsonWriteFlag,
                            alc: pointer, len: ptr csize_t,
                            err: ptr YyJsonWriteErr): cstring
  {.importc, header: "yyjson.h".}

proc yyjson_mut_write_file*(path: cstring, doc: ptr YyJsonMutDoc, flg: YyJsonWriteFlag,
                            alc: pointer, err: ptr YyJsonWriteErr): bool
  {.importc, header: "yyjson.h".}

proc yyjson_write_opts*(doc: ptr YyJsonDoc, flg: YyJsonWriteFlag, alc: pointer,
                        len: ptr csize_t, err: ptr YyJsonWriteErr): cstring
  {.importc, header: "yyjson.h".}

proc yyjson_write_file*(path: cstring, doc: ptr YyJsonDoc, flg: YyJsonWriteFlag,
                        alc: pointer, err: ptr YyJsonWriteErr): bool
  {.importc, header: "yyjson.h".}

proc yyjson_get_type*(val: ptr YyJsonVal): YyJsonType
  {.importc, header: "yyjson.h".}

proc yyjson_is_null*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_raw*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_bool*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_true*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_false*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_num*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_uint*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_sint*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_int*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_real*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_str*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_arr*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_obj*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_is_ctn*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_get_bool*(val: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_get_type_desc*(val: ptr YyJsonVal): cstring
  {.importc, header: "yyjson.h".}

proc yyjson_get_raw*(val: ptr YyJsonVal): cstring
  {.importc, header: "yyjson.h".}

proc yyjson_get_sint*(val: ptr YyJsonVal): int64
  {.importc, header: "yyjson.h".}

proc yyjson_get_uint*(val: ptr YyJsonVal): uint64
  {.importc, header: "yyjson.h".}

proc yyjson_get_real*(val: ptr YyJsonVal): cdouble
  {.importc, header: "yyjson.h".}

proc yyjson_get_num*(val: ptr YyJsonVal): cdouble
  {.importc, header: "yyjson.h".}

proc yyjson_get_str*(val: ptr YyJsonVal): cstring
  {.importc, header: "yyjson.h".}

proc yyjson_get_len*(val: ptr YyJsonVal): csize_t
  {.importc, header: "yyjson.h".}

proc yyjson_equals*(lhs: ptr YyJsonVal, rhs: ptr YyJsonVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_equals_str*(val: ptr YyJsonVal, str: cstring): bool
  {.importc, header: "yyjson.h".}

proc yyjson_equals_strn*(val: ptr YyJsonVal, str: cstring, len: csize_t): bool
  {.importc, header: "yyjson.h".}

proc yyjson_merge_patch*(doc: ptr YyJsonMutDoc, orig: ptr YyJsonVal,
                         patch: ptr YyJsonVal): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_patch*(doc: ptr YyJsonMutDoc, orig: ptr YyJsonVal,
                   patch: ptr YyJsonVal,
                   err: ptr YyJsonPatchErr): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_obj_get*(obj: ptr YyJsonVal, key: cstring): ptr YyJsonVal
  {.importc, header: "yyjson.h".}

proc yyjson_arr_get*(arr: ptr YyJsonVal, idx: csize_t): ptr YyJsonVal
  {.importc, header: "yyjson.h".}

proc yyjson_arr_get_first*(arr: ptr YyJsonVal): ptr YyJsonVal
  {.importc, header: "yyjson.h".}

proc yyjson_arr_get_last*(arr: ptr YyJsonVal): ptr YyJsonVal
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

proc yyjson_ptr_get*(val: ptr YyJsonVal, ptrStr: cstring): ptr YyJsonVal
  {.importc, header: "yyjson.h".}

proc yyjson_ptr_getn*(val: ptr YyJsonVal, ptrStr: cstring, ptrLen: csize_t): ptr YyJsonVal
  {.importc, header: "yyjson.h".}

proc yyjson_ptr_getx*(val: ptr YyJsonVal, ptrStr: cstring, ptrLen: csize_t,
                      err: ptr YyJsonPtrErr): ptr YyJsonVal
  {.importc, header: "yyjson.h".}

proc yyjson_ptr_get_bool*(val: ptr YyJsonVal, ptrStr: cstring,
                          value: ptr bool): bool
  {.importc, header: "yyjson.h".}

proc yyjson_ptr_get_uint*(val: ptr YyJsonVal, ptrStr: cstring,
                          value: ptr uint64): bool
  {.importc, header: "yyjson.h".}

proc yyjson_ptr_get_sint*(val: ptr YyJsonVal, ptrStr: cstring,
                          value: ptr int64): bool
  {.importc, header: "yyjson.h".}

proc yyjson_ptr_get_real*(val: ptr YyJsonVal, ptrStr: cstring,
                          value: ptr cdouble): bool
  {.importc, header: "yyjson.h".}

proc yyjson_ptr_get_num*(val: ptr YyJsonVal, ptrStr: cstring,
                         value: ptr cdouble): bool
  {.importc, header: "yyjson.h".}

proc yyjson_ptr_get_str*(val: ptr YyJsonVal, ptrStr: cstring,
                         value: ptr cstring): bool
  {.importc, header: "yyjson.h".}

proc yyjson_doc_ptr_getn*(doc: ptr YyJsonDoc, ptrStr: cstring,
                          ptrLen: csize_t): ptr YyJsonVal
  {.importc, header: "yyjson.h".}

proc yyjson_doc_ptr_getx*(doc: ptr YyJsonDoc, ptrStr: cstring,
                          ptrLen: csize_t,
                          err: ptr YyJsonPtrErr): ptr YyJsonVal
  {.importc, header: "yyjson.h".}

proc yyjson_doc_ptr_get*(doc: ptr YyJsonDoc, ptrStr: cstring): ptr YyJsonVal
  {.importc, header: "yyjson.h".}

proc yyjson_val_write_opts*(val: ptr YyJsonVal, flg: YyJsonWriteFlag, alc: pointer,
                            len: ptr csize_t, err: ptr YyJsonWriteErr): cstring
  {.importc, header: "yyjson.h".}

proc yyjson_val_write_file*(path: cstring, val: ptr YyJsonVal, flg: YyJsonWriteFlag,
                            alc: pointer, err: ptr YyJsonWriteErr): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_null*(doc: ptr YyJsonMutDoc): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_true*(doc: ptr YyJsonMutDoc): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_false*(doc: ptr YyJsonMutDoc): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_bool*(doc: ptr YyJsonMutDoc, val: bool): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_uint*(doc: ptr YyJsonMutDoc, num: uint64): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_sint*(doc: ptr YyJsonMutDoc, num: int64): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_real*(doc: ptr YyJsonMutDoc, num: cdouble): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_raw*(doc: ptr YyJsonMutDoc, str: cstring): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_rawn*(doc: ptr YyJsonMutDoc, str: cstring,
                      len: csize_t): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_rawcpy*(doc: ptr YyJsonMutDoc, str: cstring): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_rawncpy*(doc: ptr YyJsonMutDoc, str: cstring,
                         len: csize_t): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_str*(doc: ptr YyJsonMutDoc, str: cstring): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_strn*(doc: ptr YyJsonMutDoc, str: cstring,
                      len: csize_t): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_str_copy_n*(doc: ptr YyJsonMutDoc, str: cstring,
                            len: csize_t): ptr YyJsonMutVal
  {.importc: "yyjson_mut_strncpy", header: "yyjson.h".}

proc yyjson_mut_get_type*(val: ptr YyJsonMutVal): YyJsonType
  {.importc, header: "yyjson.h".}

proc yyjson_mut_is_null*(val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_is_raw*(val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_is_bool*(val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_is_true*(val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_is_false*(val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_is_num*(val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_is_uint*(val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_is_sint*(val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_is_int*(val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_is_real*(val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_is_str*(val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_is_arr*(val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_is_obj*(val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_is_ctn*(val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_get_bool*(val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_get_type_desc*(val: ptr YyJsonMutVal): cstring
  {.importc, header: "yyjson.h".}

proc yyjson_mut_get_raw*(val: ptr YyJsonMutVal): cstring
  {.importc, header: "yyjson.h".}

proc yyjson_mut_get_sint*(val: ptr YyJsonMutVal): int64
  {.importc, header: "yyjson.h".}

proc yyjson_mut_get_uint*(val: ptr YyJsonMutVal): uint64
  {.importc, header: "yyjson.h".}

proc yyjson_mut_get_real*(val: ptr YyJsonMutVal): cdouble
  {.importc, header: "yyjson.h".}

proc yyjson_mut_get_num*(val: ptr YyJsonMutVal): cdouble
  {.importc, header: "yyjson.h".}

proc yyjson_mut_get_str*(val: ptr YyJsonMutVal): cstring
  {.importc, header: "yyjson.h".}

proc yyjson_mut_get_len*(val: ptr YyJsonMutVal): csize_t
  {.importc, header: "yyjson.h".}

proc yyjson_mut_equals*(lhs: ptr YyJsonMutVal, rhs: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_equals_str*(val: ptr YyJsonMutVal, str: cstring): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_equals_strn*(val: ptr YyJsonMutVal, str: cstring,
                             len: csize_t): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_merge_patch*(doc: ptr YyJsonMutDoc, orig: ptr YyJsonMutVal,
                             patch: ptr YyJsonMutVal): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_patch*(doc: ptr YyJsonMutDoc, orig: ptr YyJsonMutVal,
                       patch: ptr YyJsonMutVal,
                       err: ptr YyJsonPatchErr): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr*(doc: ptr YyJsonMutDoc): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj*(doc: ptr YyJsonMutDoc): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_add_val*(arr: ptr YyJsonMutVal, val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_add_null*(doc: ptr YyJsonMutDoc, arr: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_add_true*(doc: ptr YyJsonMutDoc, arr: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_add_false*(doc: ptr YyJsonMutDoc, arr: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_add_bool*(doc: ptr YyJsonMutDoc, arr: ptr YyJsonMutVal,
                              val: bool): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_add_uint*(doc: ptr YyJsonMutDoc, arr: ptr YyJsonMutVal,
                              num: uint64): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_add_sint*(doc: ptr YyJsonMutDoc, arr: ptr YyJsonMutVal,
                              num: int64): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_add_int*(doc: ptr YyJsonMutDoc, arr: ptr YyJsonMutVal,
                             num: int64): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_add_real*(doc: ptr YyJsonMutDoc, arr: ptr YyJsonMutVal,
                              num: cdouble): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_add_str*(doc: ptr YyJsonMutDoc, arr: ptr YyJsonMutVal,
                             str: cstring): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_add_strn*(doc: ptr YyJsonMutDoc, arr: ptr YyJsonMutVal,
                              str: cstring, len: csize_t): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_add_arr*(doc: ptr YyJsonMutDoc,
                             arr: ptr YyJsonMutVal): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_add_obj*(doc: ptr YyJsonMutDoc,
                             arr: ptr YyJsonMutVal): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_get*(arr: ptr YyJsonMutVal, idx: csize_t): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_get_first*(arr: ptr YyJsonMutVal): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_get_last*(arr: ptr YyJsonMutVal): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_replace*(arr: ptr YyJsonMutVal, idx: csize_t,
                             val: ptr YyJsonMutVal): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_remove*(arr: ptr YyJsonMutVal, idx: csize_t): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_clear*(arr: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_iter_init*(arr: ptr YyJsonMutVal, iter: ptr YyJsonMutArrIter): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_arr_iter_next*(iter: ptr YyJsonMutArrIter): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_add*(obj: ptr YyJsonMutVal, key: ptr YyJsonMutVal,
                         val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_getn*(obj: ptr YyJsonMutVal, key: cstring,
                          keyLen: csize_t): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_remove_keyn*(obj: ptr YyJsonMutVal, key: cstring,
                                 keyLen: csize_t): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_replace*(obj: ptr YyJsonMutVal, key: ptr YyJsonMutVal,
                             val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_clear*(obj: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_iter_init*(obj: ptr YyJsonMutVal, iter: ptr YyJsonMutObjIter): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_iter_next*(iter: ptr YyJsonMutObjIter): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_iter_get_val*(key: ptr YyJsonMutVal): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_iter_get*(iter: ptr YyJsonMutObjIter,
                              key: cstring): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_iter_remove*(iter: ptr YyJsonMutObjIter): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_add_val*(doc: ptr YyJsonMutDoc, obj: ptr YyJsonMutVal,
                             key: cstring, val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_add_null*(doc: ptr YyJsonMutDoc, obj: ptr YyJsonMutVal,
                              key: cstring): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_add_bool*(doc: ptr YyJsonMutDoc, obj: ptr YyJsonMutVal,
                              key: cstring, val: bool): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_add_int*(doc: ptr YyJsonMutDoc, obj: ptr YyJsonMutVal,
                             key: cstring, num: int64): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_add_real*(doc: ptr YyJsonMutDoc, obj: ptr YyJsonMutVal,
                              key: cstring, num: cdouble): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_add_str*(doc: ptr YyJsonMutDoc, obj: ptr YyJsonMutVal,
                             key: cstring, val: cstring): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_add_strn*(doc: ptr YyJsonMutDoc, obj: ptr YyJsonMutVal,
                              key: cstring, val: cstring, len: csize_t): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_add_arr*(doc: ptr YyJsonMutDoc, obj: ptr YyJsonMutVal,
                             key: cstring): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_add_obj*(doc: ptr YyJsonMutDoc, obj: ptr YyJsonMutVal,
                             key: cstring): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_obj_rename_key*(doc: ptr YyJsonMutDoc, obj: ptr YyJsonMutVal,
                                key: cstring, newKey: cstring): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_ptr_get*(val: ptr YyJsonMutVal,
                         ptrStr: cstring): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_ptr_getn*(val: ptr YyJsonMutVal, ptrStr: cstring,
                          ptrLen: csize_t): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_ptr_getx*(val: ptr YyJsonMutVal, ptrStr: cstring,
                          ptrLen: csize_t, ctx: ptr YyJsonPtrCtx,
                          err: ptr YyJsonPtrErr): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_ptr_getn*(doc: ptr YyJsonMutDoc, ptrStr: cstring,
                              ptrLen: csize_t): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_ptr_getx*(doc: ptr YyJsonMutDoc, ptrStr: cstring,
                              ptrLen: csize_t, ctx: ptr YyJsonPtrCtx,
                              err: ptr YyJsonPtrErr): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_ptr_get*(doc: ptr YyJsonMutDoc,
                             ptrStr: cstring): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_ptr_add*(doc: ptr YyJsonMutDoc, ptrStr: cstring,
                             newVal: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_ptr_addn*(doc: ptr YyJsonMutDoc, ptrStr: cstring,
                              ptrLen: csize_t, newVal: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_ptr_addx*(doc: ptr YyJsonMutDoc, ptrStr: cstring,
                              ptrLen: csize_t, newVal: ptr YyJsonMutVal,
                              createParent: bool, ctx: ptr YyJsonPtrCtx,
                              err: ptr YyJsonPtrErr): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_ptr_set*(doc: ptr YyJsonMutDoc, ptrStr: cstring,
                             newVal: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_ptr_setn*(doc: ptr YyJsonMutDoc, ptrStr: cstring,
                              ptrLen: csize_t, newVal: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_ptr_setx*(doc: ptr YyJsonMutDoc, ptrStr: cstring,
                              ptrLen: csize_t, newVal: ptr YyJsonMutVal,
                              createParent: bool, ctx: ptr YyJsonPtrCtx,
                              err: ptr YyJsonPtrErr): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_ptr_replace*(doc: ptr YyJsonMutDoc, ptrStr: cstring,
                                 newVal: ptr YyJsonMutVal): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_ptr_replacen*(doc: ptr YyJsonMutDoc, ptrStr: cstring,
                                  ptrLen: csize_t,
                                  newVal: ptr YyJsonMutVal): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_ptr_replacex*(doc: ptr YyJsonMutDoc, ptrStr: cstring,
                                  ptrLen: csize_t, newVal: ptr YyJsonMutVal,
                                  ctx: ptr YyJsonPtrCtx,
                                  err: ptr YyJsonPtrErr): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_ptr_remove*(doc: ptr YyJsonMutDoc,
                                ptrStr: cstring): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_ptr_removen*(doc: ptr YyJsonMutDoc, ptrStr: cstring,
                                 ptrLen: csize_t): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_doc_ptr_removex*(doc: ptr YyJsonMutDoc, ptrStr: cstring,
                                 ptrLen: csize_t, ctx: ptr YyJsonPtrCtx,
                                 err: ptr YyJsonPtrErr): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_ptr_add*(val: ptr YyJsonMutVal, ptrStr: cstring,
                         newVal: ptr YyJsonMutVal,
                         doc: ptr YyJsonMutDoc): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_ptr_addn*(val: ptr YyJsonMutVal, ptrStr: cstring,
                          ptrLen: csize_t, newVal: ptr YyJsonMutVal,
                          doc: ptr YyJsonMutDoc): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_ptr_addx*(val: ptr YyJsonMutVal, ptrStr: cstring,
                          ptrLen: csize_t, newVal: ptr YyJsonMutVal,
                          doc: ptr YyJsonMutDoc, createParent: bool,
                          ctx: ptr YyJsonPtrCtx,
                          err: ptr YyJsonPtrErr): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_ptr_set*(val: ptr YyJsonMutVal, ptrStr: cstring,
                         newVal: ptr YyJsonMutVal,
                         doc: ptr YyJsonMutDoc): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_ptr_setn*(val: ptr YyJsonMutVal, ptrStr: cstring,
                          ptrLen: csize_t, newVal: ptr YyJsonMutVal,
                          doc: ptr YyJsonMutDoc): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_ptr_setx*(val: ptr YyJsonMutVal, ptrStr: cstring,
                          ptrLen: csize_t, newVal: ptr YyJsonMutVal,
                          doc: ptr YyJsonMutDoc, createParent: bool,
                          ctx: ptr YyJsonPtrCtx,
                          err: ptr YyJsonPtrErr): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_ptr_replace*(val: ptr YyJsonMutVal, ptrStr: cstring,
                             newVal: ptr YyJsonMutVal): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_ptr_replacen*(val: ptr YyJsonMutVal, ptrStr: cstring,
                              ptrLen: csize_t,
                              newVal: ptr YyJsonMutVal): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_ptr_replacex*(val: ptr YyJsonMutVal, ptrStr: cstring,
                              ptrLen: csize_t, newVal: ptr YyJsonMutVal,
                              ctx: ptr YyJsonPtrCtx,
                              err: ptr YyJsonPtrErr): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_ptr_remove*(val: ptr YyJsonMutVal,
                            ptrStr: cstring): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_ptr_removen*(val: ptr YyJsonMutVal, ptrStr: cstring,
                             ptrLen: csize_t): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_mut_ptr_removex*(val: ptr YyJsonMutVal, ptrStr: cstring,
                             ptrLen: csize_t, ctx: ptr YyJsonPtrCtx,
                             err: ptr YyJsonPtrErr): ptr YyJsonMutVal
  {.importc, header: "yyjson.h".}

proc yyjson_ptr_ctx_append*(ctx: ptr YyJsonPtrCtx, key: ptr YyJsonMutVal,
                            val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_ptr_ctx_replace*(ctx: ptr YyJsonPtrCtx,
                             val: ptr YyJsonMutVal): bool
  {.importc, header: "yyjson.h".}

proc yyjson_ptr_ctx_remove*(ctx: ptr YyJsonPtrCtx): bool
  {.importc, header: "yyjson.h".}

proc yyjson_mut_val_write_opts*(val: ptr YyJsonMutVal, flg: YyJsonWriteFlag,
                                alc: pointer, len: ptr csize_t,
                                err: ptr YyJsonWriteErr): cstring
  {.importc, header: "yyjson.h".}

proc c_free*(p: pointer)
  {.importc: "free", header: "stdlib.h".}
