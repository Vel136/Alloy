# Alloy

Fast, allocation-free hashing for Roblox.

**[Documentation](https://vel136.github.io/Alloy-/)** · **[Creator Store](https://create.roblox.com/store/asset/75061255262995)**

Alloy is a pure Luau hashing module that maps integers, floats, Vector2s, Vector3s, and arbitrary number tuples to clean unsigned 32-bit integers in the range `[0, 2^32)`. Every function is zero-allocation and safe to call on hot paths.

---

## Install

Get Alloy from the **[Roblox Creator Store](https://create.roblox.com/store/asset/75061255262995)**, then drop `Alloy.lua` into `ReplicatedStorage` (or any shared module location) and require it:

```lua
local Alloy = require(ReplicatedStorage.Alloy)
```

No dependencies. No setup. One require.

---

## API

| Function | Input | Output |
|----------|-------|--------|
| `hashInt(n)` | integer (float truncated) | uint32 |
| `hashFloat(n, scale?)` | float, precision scale | uint32 |
| `hashVector2(v)` | Vector2 (integer coords) | uint32 |
| `hashVector2f(v, scale?)` | Vector2 (float coords) | uint32 |
| `hashVector3(v)` | Vector3 (integer coords) | uint32 |
| `hashVector3f(v, scale?)` | Vector3 (float coords) | uint32 |
| `hashTuple(...)` | variadic numbers | uint32 |
| `combineHashes(a, b)` | two uint32 hashes | uint32 |
| `toBucket(hash, buckets)` | hash + count | 1-based index |

`scale` defaults to `1000` (3 decimal places) for all float variants.

---

## Examples

**Spatial grid keyed by chunk coordinates:**
```lua
local grid = {}

local function getChunk(cx, cz)
    local key = Alloy.hashTuple(cx, cz)
    if not grid[key] then
        grid[key] = buildChunk(cx, cz)
    end
    return grid[key]
end
```

**Bucket dispatch:**
```lua
local BUCKET_COUNT = 64
local buckets = {}

local function insert(entity)
    local key    = Alloy.hashVector3(entity.Position)
    local bucket = Alloy.toBucket(key, BUCKET_COUNT)
    table.insert(buckets[bucket], entity)
end
```

**De-duplicating world-space hit positions:**
```lua
local seen = {}

local function onHit(hitResult)
    local h = Alloy.hashVector3f(hitResult.Position)
    if seen[h] then return end
    seen[h] = true
    spawnDecal(hitResult)
end
```

**Layered / incremental keys:**
```lua
-- Compute the chunk hash once, then combine with a per-layer hash
local base  = Alloy.hashVector3(chunkOrigin)
local full  = Alloy.combineHashes(base, Alloy.hashInt(layerIndex))
```

---

## How It Works

Alloy uses `boost::hash_combine` to fold values into a running seed, then finalises with the MurmurHash3 `fmix32` avalanche mixer. The finalizer passes all SMHasher avalanche tests — flipping any single input bit changes ~50% of output bits.

Lua doubles have a 53-bit mantissa. To avoid silent bit-loss on large operands, Alloy uses a split-multiply (`mul32`) that keeps every intermediate product under 2^48.

Float inputs (`hashFloat`, `hashVector2f`, `hashVector3f`) multiply by `scale` then use `math.round` instead of `math.floor` to avoid IEEE 754 rounding artifacts at precision boundaries.

---

## License

MIT — Copyright © 2026 VeDevelopment
