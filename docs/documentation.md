---
sidebar_position: 2
sidebar_label: "Overview"
---

# Alloy

Fast, allocation-free hashing for Roblox.

Alloy is a pure Luau hashing module that maps integers, floats, Vector2s, Vector3s,
and arbitrary number tuples to clean unsigned 32-bit integers. Every function is
zero-allocation and safe to call on hot paths.

---

## One File. One Require.

Drop `Alloy.lua` into `ReplicatedStorage` and require it from any script.

```lua
local Alloy = require(ReplicatedStorage.Alloy)
```

---

## Hash Anything

```lua
-- Integer
local h1 = Alloy.hashInt(42)

-- Float with 3 decimal places of precision
local h2 = Alloy.hashFloat(3.14159)

-- Vector3 (integer coords — most common for voxel/chunk grids)
local h3 = Alloy.hashVector3(Vector3.new(cx, cy, cz))

-- Vector3 (float coords — world-space positions)
local h4 = Alloy.hashVector3f(part.Position)

-- Composite key from multiple values
local h5 = Alloy.hashTuple(chunkX, chunkZ, layer)
```

All output is a uint32 in `[0, 2^32)`.

---

## Spatial Grids

Alloy's primary use-case. Hash 2D or 3D coordinates to a single integer key and use
it as a table index:

```lua
local chunkMap = {}

local function getOrCreate(cx, cz)
    local key = Alloy.hashTuple(cx, cz)
    if not chunkMap[key] then
        chunkMap[key] = generateChunk(cx, cz)
    end
    return chunkMap[key]
end
```

For 3D chunk grids (voxel worlds), add the Y component:

```lua
local key = Alloy.hashVector3(Vector3.new(cx, cy, cz))
```

---

## Bucket Tables

`toBucket` maps any hash to a 1-based Lua index for fixed-size bucket arrays:

```lua
local BUCKET_COUNT = 128
local buckets = {}
for i = 1, BUCKET_COUNT do buckets[i] = {} end

local function insert(entity)
    local key    = Alloy.hashInt(entity.Id)
    local bucket = Alloy.toBucket(key, BUCKET_COUNT)
    table.insert(buckets[bucket], entity)
end
```

Use a prime or power-of-two bucket count for best distribution uniformity.

---

## De-duplicating Positions

Hash world-space float positions to detect duplicates without floating-point equality:

```lua
local seen = {}

local function onHit(result)
    local h = Alloy.hashVector3f(result.Position)
    if seen[h] then return end
    seen[h] = true
    applyEffect(result)
end
```

The default scale of `1000` means two positions must differ by less than 0.001 studs
to produce the same hash. Adjust `scale` to your precision requirements.

---

## Incremental Keys

Compute a base hash once and specialise it cheaply without re-hashing:

```lua
local base = Alloy.hashVector3(chunkOrigin)

local function layerKey(layer)
    return Alloy.combineHashes(base, Alloy.hashInt(layer))
end
```

`combineHashes` passes the result through the full `fmix32` avalanche mixer, so the
output has the same quality as a fresh hash.

---

## How It Works

**Combining.** `boost::hash_combine` folds each value into a running seed using the
golden ratio (`0x9e3779b9`). The rotation ensures `(a, b)` and `(b, a)` produce
different seeds — order matters.

**Finalising.** The MurmurHash3 `fmix32` finalizer is applied once after all values
are folded in. It passes all SMHasher avalanche tests: every input bit influences
~50% of output bits.

**Safe multiply.** Lua doubles have a 53-bit mantissa. `a * b % 2^32` silently drops
low bits when both operands are large. Alloy splits `a` into two 16-bit halves,
keeping every intermediate product under 2^48.

**Float rounding.** `math.round` instead of `math.floor` prevents IEEE 754 rounding
artifacts at precision boundaries (e.g. `1.001 * 1000 = 1000.9999…` floors to
`1000`, colliding with `1.0`; `math.round` snaps it to `1001` correctly).

---

## API Surface

| Function | Input | Notes |
|----------|-------|-------|
| `hashInt(n)` | integer | Float is floor-truncated |
| `hashFloat(n, scale?)` | float | scale default `1000` |
| `hashVector2(v)` | Vector2 | Integer coords, no alloc |
| `hashVector2f(v, scale?)` | Vector2 | Float coords |
| `hashVector3(v)` | Vector3 | Integer coords, no alloc |
| `hashVector3f(v, scale?)` | Vector3 | Float coords |
| `hashTuple(...)` | variadic numbers | Order-sensitive |
| `combineHashes(a, b)` | two uint32s | Passes through fmix32 |
| `toBucket(hash, n)` | hash + count | Returns `[1, n]` |
