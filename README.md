# yyjson.nim

Thin Nim bindings for [yyjson](https://github.com/ibireme/yyjson).

This package is intentionally not a replacement for `std/json`. It is a small wrapper for cases where
JSON performance and memory usage matter.

## Status

Initial usable wrapper:

- parse JSON from a Nim `string`
- parse JSON from a file
- access object fields
- iterate arrays
- iterate objects
- read string/int/float/bool/null values
- JSON Pointer access
- zero-copy `cstring` access for JSON strings
- ARC/ORC compatible

Mutable JSON and JSON writing are not implemented yet.

## Vendoring yyjson

This package expects these files:

```text
vendor/yyjson.c
vendor/yyjson.h
```

The wrapper compiles `vendor/yyjson.c` automatically:

```nim
import yyjson
```

No separate system library is required.

## Install locally

From this directory:

```bash
nimble install
```

## Basic usage

```nim
import yyjson

let doc = readJson("""{"name":"redis","tags":["7.4","latest"]}""")
defer:
  doc.close()

let root = doc.root()

echo root["name"].str()
for tag in root["tags"].items:
  echo tag.str()
```

## Object iteration

```nim
for key, value in doc.root().pairs:
  echo key, " = ", value.kind()
```

## JSON Pointer

```nim
let value = doc.root().pointer("/metadata/name")
if not value.isNil:
  echo value.str()
```

## Zero-copy string access

```nim
let p: cstring = doc.root()["name"].cstr()
```

The returned pointer is valid only while the owning `JsonDoc` is alive.

## Harbor-style example

```nim
import yyjson

let doc = readJsonFile("vulnerabilities.json")
defer:
  doc.close()

let root = doc.root()

for _, report in root.pairs:
  let vulns = report["vulnerabilities"]
  for v in vulns.items:
    echo v.getStr("id"), " ", v.getStr("package"), " ", v.getStr("severity")
```

## Build an example

```bash
nim c -r examples/parse.nim
```

## Notes

The API intentionally avoids converting to `JsonNode`. Doing so would lose the memory advantage.

String access methods:

- `cstr()` returns a zero-copy `cstring`
- `str()` copies to a Nim `string`
- `getCStr(key)` returns zero-copy field value
- `getStr(key)` copies field value

## Tested memory profile

On a real Harbor vulnerabilities JSON file of about 10 MiB:

| Parser | Peak RSS |
|---|---:|
| `std/json.parseJson` | ~82 MiB |
| `std/parsejson` token parser | ~34 MiB |
| `gemmaJSON` | ~38 MiB |
| yyjson C API | ~16 MiB |

Numbers depend on compiler, allocator, OS, and yyjson version.
