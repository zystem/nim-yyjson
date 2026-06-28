include common

import yyjson/private

const
  NumPtr = 16
  BufSize = 1024
  PaddingSize = 4

proc bufPtr(buf: var seq[byte]): system.pointer =
  if buf.len == 0:
    nil
  else:
    cast[system.pointer](addr buf[0])

proc fill(p: system.pointer; size: int; value: byte = 0xFF'u8) =
  if not p.isNil and size > 0:
    zeroMem(p, size)

proc makeArrayJson(n: int; padded = false): string =
  result = newString(1 + n * 2)
  result[0] = '['
  for i in 0..<n:
    result[i * 2 + 1] = '1'
    result[i * 2 + 2] = ','
  result[result.high] = ']'
  if padded:
    result.add("\0\0\0\0")

suite "upstream yyjson allocator":
  test "pool allocator init failures":
    var alc: YyJsonAlc

    check not yyjson_alc_pool_init(nil, nil, 0)

    zeroMem(addr alc, sizeof(alc))
    check not yyjson_alc_pool_init(addr alc, nil, 0)
    check alc.malloc(nil, 1).isNil
    check alc.realloc(nil, nil, 0, 1).isNil
    alc.free(nil, nil)

    zeroMem(addr alc, sizeof(alc))
    check not yyjson_alc_pool_init(addr alc, nil, BufSize.csize_t)
    check alc.malloc(nil, 1).isNil
    check alc.realloc(nil, nil, 0, 1).isNil
    alc.free(nil, nil)

    var small = newSeq[byte](10)
    zeroMem(addr alc, sizeof(alc))
    check not yyjson_alc_pool_init(addr alc, small.bufPtr, small.len.csize_t)
    check alc.malloc(nil, 1).isNil
    check alc.realloc(nil, nil, 0, 1).isNil
    alc.free(nil, nil)

    var tooSmall = newSeq[byte](8 * sizeof(system.pointer) - 1)
    check not yyjson_alc_pool_init(addr alc, tooSmall.bufPtr, tooSmall.len.csize_t)

  test "pool allocator functions":
    var alc: YyJsonAlc
    var buf = newSeq[byte](BufSize)
    check yyjson_alc_pool_init(addr alc, buf.bufPtr, buf.len.csize_t)

    var ptrs: array[NumPtr, system.pointer]

    ptrs[0] = alc.malloc(alc.ctx, BufSize div 2)
    check not ptrs[0].isNil
    fill(ptrs[0], BufSize div 2, 0)
    ptrs[1] = alc.malloc(alc.ctx, BufSize div 2)
    check ptrs[1].isNil
    alc.free(alc.ctx, ptrs[0])

    for i in 0..<NumPtr:
      ptrs[i] = alc.malloc(alc.ctx, 32)
      check not ptrs[i].isNil
      fill(ptrs[i], 32, 0)
    for i in countup(0, NumPtr - 1, 2):
      alc.free(alc.ctx, ptrs[i])
    for i in countup(0, NumPtr - 1, 2):
      ptrs[i] = alc.malloc(alc.ctx, 16)
      check not ptrs[i].isNil
      fill(ptrs[i], 16, 0)
    for i in countdown(NumPtr - 1, 0):
      alc.free(alc.ctx, ptrs[i])

    for i in 0..<(NumPtr div 2):
      ptrs[i] = alc.malloc(alc.ctx, 8)
      check not ptrs[i].isNil
      fill(ptrs[i], 8, 0)
    for i in countup(0, NumPtr div 2 - 1, 2):
      alc.free(alc.ctx, ptrs[i])
    for i in countup(1, NumPtr div 2 - 1, 2):
      ptrs[i] = alc.realloc(alc.ctx, ptrs[i], 8, 32)
      check not ptrs[i].isNil
      fill(ptrs[i], 32, 0)
    for i in countup(0, NumPtr div 2 - 1, 2):
      ptrs[i] = alc.malloc(alc.ctx, 16)
      check not ptrs[i].isNil
      fill(ptrs[i], 16, 0)
    for i in 0..<(NumPtr div 2):
      alc.free(alc.ctx, ptrs[i])

    ptrs[0] = alc.malloc(alc.ctx, 64)
    ptrs[0] = alc.realloc(alc.ctx, ptrs[0], 64, 128)
    check not ptrs[0].isNil
    alc.free(alc.ctx, ptrs[0])

  test "pool allocator read":
    for n in [1, 2, 3, 8, 32, 128, 1000]:
      let json = makeArrayJson(n)
      var buf = newSeq[byte](system.int(yyjson_read_max_memory_usage(json.len.csize_t,
                                                                     YYJSON_READ_NOFLAG)))
      var alc: YyJsonAlc
      check yyjson_alc_pool_init(addr alc, buf.bufPtr, buf.len.csize_t)

      let doc = yyjson_read_opts(json.cstring, json.len.csize_t,
                                 YYJSON_READ_NOFLAG, cast[system.pointer](addr alc), nil)
      check not doc.isNil
      check yyjson_get_len(yyjson_doc_get_root(doc)) == n.csize_t
      yyjson_doc_free(doc)

      let padded = makeArrayJson(n, padded = true)
      let dataLen = padded.len - PaddingSize
      buf = newSeq[byte](system.int(yyjson_read_max_memory_usage(dataLen.csize_t,
                                                                 YYJSON_READ_INSITU)))
      check yyjson_alc_pool_init(addr alc, buf.bufPtr, buf.len.csize_t)

      let insituDoc = yyjson_read_opts(padded.cstring, dataLen.csize_t,
                                       YYJSON_READ_INSITU, cast[system.pointer](addr alc), nil)
      check not insituDoc.isNil
      check yyjson_get_len(yyjson_doc_get_root(insituDoc)) == n.csize_t
      yyjson_doc_free(insituDoc)

  test "dynamic allocator functions":
    var alc = yyjson_alc_dyn_new()
    check not alc.isNil
    check alc.malloc(alc.ctx, csize_t.high).isNil
    yyjson_alc_dyn_free(alc)
    yyjson_alc_dyn_free(nil)

    alc = yyjson_alc_dyn_new()
    check not alc.isNil
    var p = alc.malloc(alc.ctx, 0x100)
    check not p.isNil
    fill(p, 0x100)
    alc.free(alc.ctx, p)
    yyjson_alc_dyn_free(alc)

    alc = yyjson_alc_dyn_new()
    check not alc.isNil
    for i in 0..<256:
      let size = (i * 97 mod 0x4000) + 1
      p = alc.malloc(alc.ctx, size.csize_t)
      check not p.isNil
      fill(p, size)
      p = alc.realloc(alc.ctx, p, size.csize_t, (size + 17).csize_t)
      check not p.isNil
      fill(p, size + 17)
      alc.free(alc.ctx, p)
    yyjson_alc_dyn_free(alc)
