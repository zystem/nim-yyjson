# yyjson

Thin Nim bindings for [yyjson](https://github.com/ibireme/yyjson), with a
small idiomatic wrapper for fast DOM-style JSON parsing, navigation, mutation,
and writing.

This package is not a drop-in replacement for `std/json`. It is meant for code
that wants yyjson's speed and memory profile without writing C-style Nim FFI at
every call site.

## Status

`yyjson` is usable as a 1.0.x package. The public API focuses on:

- parsing JSON from strings and files
- object and array access
- typed value access for strings, numbers, booleans, nulls, raw numbers
- zero-copy `cstring` access when you want it
- JSON Pointer get/set/add/replace/remove helpers
- JSON Patch and JSON Merge Patch support
- JSON writing to strings and files
- mutable JSON document construction and editing
- ARC/ORC-friendly ownership

The wrapper intentionally does not expose every low-level yyjson C helper as a
public Nim API. The lower-level `yyjson/private` module exists for the wrapper
and tests, but it is not the package's stable user-facing contract.

## Install

After the package is published to Nimble:

```bash
nimble install yyjson
```

From a local checkout:

```bash
nimble install
```

Then:

```nim
import yyjson
```

No system yyjson library is required. The package vendors `yyjson.c` and
`yyjson.h` and compiles yyjson automatically.

## Ownership

`JsonDoc` and `JsonMutDoc` own yyjson documents. They are move-only handles.
Keep them in `var` variables and call `close()` exactly once, usually with
`defer`:

```nim
proc loadName() =
  var doc = readJson("""{"name":"redis"}""")
  defer:
    doc.close()

  echo doc.root()["name"].str()
```

Values such as `JsonVal` and `JsonMutVal` borrow from their owning document.
Do not use them after the document has been closed.

## Quick Start

```nim
import yyjson

proc main() =
  var doc = readJson("""{"name":"redis","tags":["7.4","latest"],"enabled":true}""")
  defer:
    doc.close()

  let root = doc.root()

  echo root["name"].str()
  echo root["enabled"].bool()

  for tag in root["tags"].items:
    echo tag.str()

when isMainModule:
  main()
```

## Object Access

```nim
let root = doc.root()

if root.hasKey("name"):
  echo root["name"].str()

if "name" in root:
  echo root.getStr("name")

for key, value in root.pairs:
  echo key, " = ", value.kind()
```

Missing keys and out-of-range indexes return nil values:

```nim
if root["missing"].isNil:
  echo "not found"
```

## Typed Values

```nim
echo root["name"].str()
echo root["enabled"].bool()
echo root["count"].int()
echo root["count"].uint64()
echo root["ratio"].float()
```

String access methods:

- `cstr()` returns a zero-copy `cstring`
- `str()` copies to a Nim `string`
- `getCStr(key)` returns a zero-copy field value
- `getStr(key)` copies a field value

Zero-copy pointers are valid only while the owning document is alive.

## JSON Pointer

```nim
let value = doc.root().pointer("/metadata/name")
if not value.isNil:
  echo value.str()
```

Strict pointer helpers raise `JsonPointerError` with yyjson's error code and
position:

```nim
try:
  discard doc.root().pointerStrict("/missing/value")
except JsonPointerError as e:
  echo e.code, " at ", e.pos
```

## Write JSON

```nim
let compact = doc.writeJson()
let pretty = doc.writeJson(YYJSON_WRITE_PRETTY_TWO_SPACES)

writeJsonFile("out.json", doc)
writeJsonFile("tags.json", doc.root()["tags"])
```

Useful write flags include:

- `YYJSON_WRITE_PRETTY`
- `YYJSON_WRITE_PRETTY_TWO_SPACES`
- `YYJSON_WRITE_NEWLINE_AT_END`
- `YYJSON_WRITE_ESCAPE_UNICODE`
- `YYJSON_WRITE_ESCAPE_SLASHES`
- `YYJSON_WRITE_ALLOW_INF_AND_NAN`
- `YYJSON_WRITE_INF_AND_NAN_AS_NULL`

## Mutable JSON

```nim
proc buildJson() =
  var mutDoc = newJsonMutDoc()
  defer:
    mutDoc.close()

  let root = mutDoc.newObject()
  let tags = mutDoc.newArray()

  tags.add(mutDoc.newString("7.4"))
  tags.add(mutDoc.newString("latest"))

  root.add("name", mutDoc.newString("redis"))
  root.add("enabled", mutDoc.newBool(true))
  root.add("tags", tags)

  mutDoc.setRoot(root)

  echo mutDoc.writeJson()
```

Mutable arrays and objects support add, replace, remove, clear, indexing,
iteration, and JSON Pointer mutation helpers.

## Errors

Parsing, writing, and strict pointer operations raise package-specific
exceptions:

- `JsonReadError`
- `JsonWriteError`
- `JsonPointerError`

These exceptions expose yyjson's error code and a human-readable reason.

```nim
try:
  discard readJson("[1,]")
except JsonReadError as e:
  echo e.code, " at byte ", e.pos, ": ", e.reason
```

## Examples

```bash
nim c -r -p:src examples/parse.nim
nim c -r -p:src examples/harbor.nim -- vulnerabilities.json
```

The `harbor` example scans a Harbor vulnerabilities JSON export without
building a `std/json.JsonNode` tree.

## Tests

```bash
nimble test
```

The test suite contains focused Nim API tests plus upstream-inspired yyjson
tests and fixtures under `tests/upstream` and `tests/data/yyjson`.

The fixture data is copied from yyjson's upstream `test/data` corpus. The tests
cover behavior that matters to this Nim package: parsing flags, writing flags,
errors, strings, numbers, allocators, JSON Pointer, JSON Patch, JSON Merge
Patch, mutable DOM operations, and selected low-level FFI boundaries.

The suite does not try to port every C-only upstream test. Internal tag/subtype
checks, stack-allocated C value tests, and helpers that are not part of the
public Nim API are intentionally left outside the 1.0.x scope.

## Vendored yyjson

The package vendors:

```text
src/yyjson/vendor/yyjson.c
src/yyjson/vendor/yyjson.h
```

`src/yyjson/private.nim` compiles the vendored `yyjson.c` automatically. If the
vendored yyjson version is updated, run `nimble test` before publishing a new
package version.

## Why not `std/json`?

`std/json` is convenient and universal, but it builds a generic `JsonNode` tree.
That is not ideal when documents are large and only selected fields are needed.

`yyjson` is intended for cases like exporters, crawlers, scanners, API
gateways, and CLI tools where:

- JSON payloads are large
- only selected fields are needed
- memory pressure matters
- zero-copy string access is useful

## Memory Profile Note

On one real Harbor vulnerabilities JSON file of about 10 MiB, peak RSS was:

| Parser | Peak RSS |
|---|---:|
| `std/json.parseJson` | ~82 MiB |
| `std/parsejson` token parser | ~34 MiB |
| `gemmaJSON` | ~38 MiB |
| yyjson C API | ~16 MiB |

These numbers are illustrative, not a benchmark guarantee. They depend on the
compiler, allocator, OS, yyjson version, and input shape.

## Publishing Notes

For the initial Nimble release, the package is intentionally conservative:

- public API first
- upstream fixture coverage for behavior that affects Nim users
- private FFI bindings only where needed by the wrapper or tests
- deeper low-level C API parity can be added in later versions

## License

MIT for the Nim wrapper. Vendored yyjson keeps its upstream license.
