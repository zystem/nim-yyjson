include common
import yyjson/private

proc writeMut(val: ptr YyJsonMutVal): string =
  var len: csize_t
  var err: YyJsonWriteErr
  let written = yyjson_mut_val_write_opts(val, YYJSON_WRITE_NOFLAG, nil, addr len, addr err)
  check err.code == YYJSON_WRITE_SUCCESS
  check not written.isNil
  result = ($written)[0 ..< cast[int](len)]
  c_free(written)

suite "upstream yyjson mutable values":
  test "mutable scalar constructors":
    let doc = yyjson_mut_doc_new(nil)
    defer:
      yyjson_mut_doc_free(doc)

    check yyjson_mut_null(nil).isNil
    let n = yyjson_mut_null(doc)
    check yyjson_mut_is_null(n)
    check $yyjson_mut_get_type_desc(n) == "null"

    check yyjson_mut_true(nil).isNil
    let t = yyjson_mut_true(doc)
    check yyjson_mut_is_true(t)
    check yyjson_mut_is_bool(t)
    check yyjson_mut_get_bool(t)

    let f = yyjson_mut_false(doc)
    check yyjson_mut_is_false(f)
    check yyjson_mut_is_bool(f)
    check not yyjson_mut_get_bool(f)

    let b = yyjson_mut_bool(doc, true)
    check yyjson_mut_is_true(b)

    let u = yyjson_mut_uint(doc, 123'u64)
    check yyjson_mut_is_uint(u)
    check yyjson_mut_is_int(u)
    check yyjson_mut_get_uint(u) == 123'u64
    check yyjson_mut_get_sint(u) == 123'i64
    check yyjson_mut_get_num(u) == 123.0
    check yyjson_mut_get_bool(u) == false

    let s = yyjson_mut_sint(doc, -123'i64)
    check yyjson_mut_is_sint(s)
    check yyjson_mut_is_int(s)
    check yyjson_mut_get_sint(s) == -123'i64
    check yyjson_mut_get_uint(s) == high(uint64) - 122'u64
    check yyjson_mut_get_num(s) == -123.0

    let r = yyjson_mut_real(doc, 123.25)
    check yyjson_mut_is_real(r)
    check yyjson_mut_is_num(r)
    check yyjson_mut_get_real(r) == 123.25
    check yyjson_mut_get_num(r) == 123.25

    let arr = yyjson_mut_arr(doc)
    check yyjson_mut_is_arr(arr)
    check yyjson_mut_is_ctn(arr)

    let obj = yyjson_mut_obj(doc)
    check yyjson_mut_is_obj(obj)
    check yyjson_mut_is_ctn(obj)

  test "mutable raw and string constructors":
    let doc = yyjson_mut_doc_new(nil)
    defer:
      yyjson_mut_doc_free(doc)

    check yyjson_mut_raw(nil, "abc").isNil
    check yyjson_mut_raw(doc, nil).isNil
    let rawBorrowed = yyjson_mut_raw(doc, "abc")
    check yyjson_mut_is_raw(rawBorrowed)
    check $yyjson_mut_get_raw(rawBorrowed) == "abc"
    check yyjson_mut_get_len(rawBorrowed) == 3.csize_t

    let rawSlice = yyjson_mut_rawn(doc, "abc(garbage)", 3)
    check yyjson_mut_is_raw(rawSlice)
    check ($yyjson_mut_get_raw(rawSlice))[0 ..< cast[int](yyjson_mut_get_len(rawSlice))] == "abc"

    let rawCopied = yyjson_mut_rawncpy(doc, "def(garbage)", 3)
    check yyjson_mut_is_raw(rawCopied)
    check ($yyjson_mut_get_raw(rawCopied))[0 ..< cast[int](yyjson_mut_get_len(rawCopied))] == "def"

    check yyjson_mut_str(nil, "abc").isNil
    check yyjson_mut_str(doc, nil).isNil
    let strBorrowed = yyjson_mut_str(doc, "abc")
    check yyjson_mut_is_str(strBorrowed)
    check yyjson_mut_equals_str(strBorrowed, "abc")
    check yyjson_mut_equals_strn(strBorrowed, "abc", 3)
    check yyjson_mut_get_len(strBorrowed) == 3.csize_t

    let withNul = "abc\0def"
    let strSlice = yyjson_mut_strn(doc, withNul.cstring, withNul.len.csize_t)
    check yyjson_mut_is_str(strSlice)
    check yyjson_mut_get_len(strSlice) == 7.csize_t
    check not yyjson_mut_equals_str(strSlice, "abc")
    check yyjson_mut_equals_strn(strSlice, withNul.cstring, withNul.len.csize_t)

    let strCopied = yyjson_mut_str_copy_n(doc, withNul.cstring, withNul.len.csize_t)
    check yyjson_mut_is_str(strCopied)
    check yyjson_mut_get_len(strCopied) == 7.csize_t

  test "mutable array convenience api":
    let doc = yyjson_mut_doc_new(nil)
    defer:
      yyjson_mut_doc_free(doc)

    let arr = yyjson_mut_arr(doc)
    check not yyjson_mut_arr_add_val(nil, nil)
    check not yyjson_mut_arr_add_val(arr, nil)
    check not yyjson_mut_arr_add_null(nil, arr)
    check not yyjson_mut_arr_add_null(doc, nil)

    check yyjson_mut_arr_add_null(doc, arr)
    check yyjson_mut_arr_add_true(doc, arr)
    check yyjson_mut_arr_add_false(doc, arr)
    check yyjson_mut_arr_add_bool(doc, arr, true)
    check yyjson_mut_arr_add_uint(doc, arr, 12)
    check yyjson_mut_arr_add_sint(doc, arr, -12)
    check yyjson_mut_arr_add_int(doc, arr, -13)
    check yyjson_mut_arr_add_real(doc, arr, 1.5)
    check yyjson_mut_arr_add_str(doc, arr, "abc")

    let withNul = "abc\0def"
    check yyjson_mut_arr_add_strn(doc, arr, withNul.cstring, withNul.len.csize_t)
    check yyjson_mut_arr_add_arr(nil, arr).isNil
    let childArr = yyjson_mut_arr_add_arr(doc, arr)
    check not childArr.isNil
    check yyjson_mut_is_arr(childArr)
    let childObj = yyjson_mut_arr_add_obj(doc, arr)
    check not childObj.isNil
    check yyjson_mut_is_obj(childObj)

    check yyjson_mut_get_len(arr) == 12.csize_t
    check yyjson_mut_is_null(yyjson_mut_arr_get(arr, 0))
    check yyjson_mut_is_true(yyjson_mut_arr_get(arr, 1))
    check yyjson_mut_get_sint(yyjson_mut_arr_get(arr, 6)) == -13
    check yyjson_mut_get_len(yyjson_mut_arr_get(arr, 9)) == 7.csize_t

  test "mutable object convenience api":
    let doc = yyjson_mut_doc_new(nil)
    defer:
      yyjson_mut_doc_free(doc)

    let obj = yyjson_mut_obj(doc)
    check not yyjson_mut_obj_add_null(nil, obj, "a")
    check not yyjson_mut_obj_add_null(doc, nil, "a")
    check not yyjson_mut_obj_add_null(doc, obj, nil)

    check yyjson_mut_obj_add_null(doc, obj, "a")
    check yyjson_mut_obj_add_bool(doc, obj, "b", true)
    check yyjson_mut_obj_add_int(doc, obj, "c", -123)
    check yyjson_mut_obj_add_real(doc, obj, "d", 1.25)
    check yyjson_mut_obj_add_str(doc, obj, "e", "abc")

    let withNul = "abc\0def"
    check yyjson_mut_obj_add_strn(doc, obj, "f", withNul.cstring, withNul.len.csize_t)
    let arr = yyjson_mut_obj_add_arr(doc, obj, "g")
    check not arr.isNil
    let nested = yyjson_mut_obj_add_obj(doc, obj, "h")
    check not nested.isNil
    check yyjson_mut_obj_add_val(doc, obj, "i", yyjson_mut_raw(doc, "123"))

    check yyjson_mut_get_len(obj) == 9.csize_t
    check yyjson_mut_is_null(yyjson_mut_obj_getn(obj, "a", 1))
    check yyjson_mut_get_bool(yyjson_mut_obj_getn(obj, "b", 1))
    check yyjson_mut_get_sint(yyjson_mut_obj_getn(obj, "c", 1)) == -123
    check yyjson_mut_get_len(yyjson_mut_obj_getn(obj, "f", 1)) == 7.csize_t

    check yyjson_mut_obj_rename_key(doc, obj, "e", "renamed")
    check yyjson_mut_obj_getn(obj, "e", 1).isNil
    check yyjson_mut_equals_str(yyjson_mut_obj_getn(obj, "renamed", 7), "abc")

  test "mutable object iterator lookup and remove":
    let doc = yyjson_mut_doc_new(nil)
    defer:
      yyjson_mut_doc_free(doc)

    let obj = yyjson_mut_obj(doc)
    check yyjson_mut_obj_add_int(doc, obj, "a", 10)
    check yyjson_mut_obj_add_int(doc, obj, "b", 11)
    check yyjson_mut_obj_add_int(doc, obj, "c", 12)

    var iter: YyJsonMutObjIter
    check yyjson_mut_obj_iter_init(obj, addr iter)
    check yyjson_mut_get_sint(yyjson_mut_obj_iter_get(addr iter, "a")) == 10
    check yyjson_mut_get_sint(yyjson_mut_obj_iter_get(addr iter, "c")) == 12
    check yyjson_mut_obj_iter_get(addr iter, "x").isNil

    check yyjson_mut_obj_iter_init(obj, addr iter)
    var seen: seq[string] = @[]
    while true:
      let key = yyjson_mut_obj_iter_next(addr iter)
      if key.isNil:
        break
      seen.add(($yyjson_mut_get_str(key))[0 ..< cast[int](yyjson_mut_get_len(key))])
      let val = yyjson_mut_obj_iter_get_val(key)
      if yyjson_mut_equals_str(key, "b"):
        let removed = yyjson_mut_obj_iter_remove(addr iter)
        check removed == val

    check seen == @["a", "b", "c"]
    check yyjson_mut_get_len(obj) == 2.csize_t
    check yyjson_mut_obj_getn(obj, "b", 1).isNil
    check writeMut(obj) == """{"a":10,"c":12}"""
