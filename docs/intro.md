---
sidebar_position: 1
---

# Getting Started

Alloy is a single-file Luau module. Install it, require it, and start hashing.

---

## Installation

Get Alloy from the Roblox Creator Store:

**[Get Alloy on Creator Store](https://create.roblox.com/store/asset/75061255262995)**

Then drop `Alloy.lua` into `ReplicatedStorage` (or any shared module location) and require it:

```lua
local Alloy = require(ReplicatedStorage.Alloy)
```

No dependencies. No setup. One require.

---

## Your First Hash

```lua
local Alloy = require(ReplicatedStorage.Alloy)

-- Hash a pair of integers
local key = Alloy.hashTuple(chunkX, chunkZ)
print(key)  -- e.g. 2847361029 — always in [0, 2^32)
```

All output is an unsigned 32-bit integer in `[0, 2^32)`. Safe to use as a table key, compare directly, or pass to `toBucket`.

---

## Spatial Grid

The most common use-case: keying a grid by chunk or tile coordinates.

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

---

## Float Positions

For world-space floats use the `f` variants. They multiply by a `scale` factor (default `1000`) and round before hashing, so `1.001` and `1.002` produce different hashes.

```lua
-- De-duplicate impact positions within 1/1000 stud precision
local seen = {}

local function onHit(hitResult)
    local h = Alloy.hashVector3f(hitResult.Position)
    if seen[h] then return end
    seen[h] = true
    spawnDecal(hitResult)
end
```

---

## Bucket Dispatch

`toBucket` maps any hash to a 1-based index, suitable for fixed-size bucket tables:

```lua
local BUCKETS = 64
local buckets = {}
for i = 1, BUCKETS do buckets[i] = {} end

local function insert(entity)
    local key    = Alloy.hashVector3(entity.GridPosition)
    local bucket = Alloy.toBucket(key, BUCKETS)
    table.insert(buckets[bucket], entity)
end
```

---

## Incremental Keys

Combine pre-computed hashes rather than re-hashing from scratch:

```lua
local base  = Alloy.hashVector3(chunkOrigin)   -- computed once per chunk
local full  = Alloy.combineHashes(base, Alloy.hashInt(layerIndex))
```

---

## Quick Reference

| I want to… | Function |
|------------|----------|
| Hash a whole number | [`hashInt`](../api/Alloy#hashInt) |
| Hash a decimal number | [`hashFloat`](../api/Alloy#hashFloat) |
| Hash a Vector2 (integers) | [`hashVector2`](../api/Alloy#hashVector2) |
| Hash a Vector2 (floats) | [`hashVector2f`](../api/Alloy#hashVector2f) |
| Hash a Vector3 (integers) | [`hashVector3`](../api/Alloy#hashVector3) |
| Hash a world-space position | [`hashVector3f`](../api/Alloy#hashVector3f) |
| Hash a composite key | [`hashTuple`](../api/Alloy#hashTuple) |
| Combine two hashes | [`combineHashes`](../api/Alloy#combineHashes) |
| Map hash to a bucket index | [`toBucket`](../api/Alloy#toBucket) |
| See practical examples | [Use Cases](./guides/use-cases) |
