version       = "1.0.1"
author        = "Andrii Zahriadskyi"
description   = "Thin Nim bindings for yyjson with a small idiomatic high-level API"
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests", "examples"]

requires "nim >= 2.0.0"

const
  testNimFlags = "--hint:XDeclaredButNotUsed:off -p:src "
  upstreamTests = [
    "compile_smoke",
    "allocator",
    "json_merge_patch",
    "json_patch",
    "json_val",
    "json_mut_val",
    "json_pointer",
    "json_io",
    "number",
    "string",
    "fixtures"
  ]

task test, "Run tests":
  exec "nim c -r " & testNimFlags & "--nimcache:/tmp/nim_yyjson_cache_basic" &
       " --out:/tmp/nim_yyjson_basic tests/t_basic.nim"

  for name in upstreamTests:
    let path = "tests/upstream/" & name & ".nim"
    let outFile = "/tmp/nim_yyjson_" & name
    let cacheDir = "/tmp/nim_yyjson_cache_" & name
    exec "nim c -r " & testNimFlags & "--nimcache:" & cacheDir &
         " --out:" & outFile & " " & path
