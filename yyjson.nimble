version       = "0.1.0"
author        = "Andrii Zahriadskyi"
description   = "Thin Nim bindings for yyjson with a small idiomatic high-level API"
license       = "MIT"
srcDir        = "src"

requires "nim >= 2.0.0"

task test, "Run tests":
  exec "nim c -r tests/t_basic.nim"
