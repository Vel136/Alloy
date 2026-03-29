---
sidebar_position: 1
---

# Use Cases

Practical patterns for the most common Alloy use-cases.

---

## Spatial Grids

The most frequent use-case. Store world data keyed by chunk or tile coordinate.

### 2D Chunk Map

```lua
local Alloy = require(ReplicatedStorage.Alloy)

local chunks = {}

local function getChunk(cx, cz)
    local key = Alloy.hashTuple(cx, cz)
    return chunks[key]
end

local function setChunk(cx, cz, data)
    local key = Alloy.hashTuple(cx, cz)
    chunks[key] = data
end
```

### 3D Voxel Map

```lua
local voxels = {}

local function getVoxel(x, y, z)
    local key = Alloy.hashVector3(Vector3.new(x, y, z))
    return voxels[key]
end
```

`hashVector3` floor-truncates components, so passing `Vector3.new(1.9, 0, 0)` is
equivalent to `Vector3.new(1, 0, 0)`. If your coordinates are always integers,
`hashVector3` is the most readable option.

### Layered Grid (2D + Depth)

Hash the XZ chunk once, then combine with the layer hash on demand:

```lua
local chunkBase = {}

local function getChunkBaseHash(cx, cz)
    local key = Alloy.hashTuple(cx, cz)
    if not chunkBase[key] then
        chunkBase[key] = Alloy.hashTuple(cx, cz)
    end
    return chunkBase[key]
end

local function getLayerKey(cx, cz, layer)
    return Alloy.combineHashes(getChunkBaseHash(cx, cz), Alloy.hashInt(layer))
end
```

---

## Bucket Tables

Fixed-size bucket tables offer O(1) insert and O(bucket_size) lookup without the
overhead of a fully dynamic hash map.

```lua
local Alloy = require(ReplicatedStorage.Alloy)

local BUCKET_COUNT = 128
local buckets = table.create(BUCKET_COUNT)
for i = 1, BUCKET_COUNT do
    buckets[i] = {}
end

local function insert(entity)
    local key    = Alloy.hashInt(entity.Id)
    local bucket = Alloy.toBucket(key, BUCKET_COUNT)
    table.insert(buckets[bucket], entity)
end

local function find(id)
    local key    = Alloy.hashInt(id)
    local bucket = Alloy.toBucket(key, BUCKET_COUNT)
    for _, entity in buckets[bucket] do
        if entity.Id == id then
            return entity
        end
    end
end
```

Use a power-of-two or prime bucket count. 64, 128, 256, and 512 all work well.

---

## De-duplicating Float Positions

Floating-point equality (`a == b`) is unreliable for world-space positions that went
through arithmetic. Hashing with a fixed scale gives a stable grouping.

```lua
local Alloy = require(ReplicatedStorage.Alloy)

-- Track which positions already have a decal, within 1/1000 stud precision
local decalPositions = {}

local function trySpawnDecal(hitResult)
    local h = Alloy.hashVector3f(hitResult.Position)
    if decalPositions[h] then return end
    decalPositions[h] = true
    spawnDecal(hitResult.Position, hitResult.Normal)
end
```

To coarsen the grouping (snap positions to the nearest 0.5 stud), reduce the scale:

```lua
local h = Alloy.hashVector3f(position, 2)  -- nearest 0.5 stud
```

---

## Composite Keys

Build keys from multiple independent values without allocating a string.

### Player + Zone Session Key

```lua
local sessionMap = {}

local function getSession(player, zoneId)
    local key = Alloy.hashTuple(player.UserId, zoneId)
    return sessionMap[key]
end
```

### Weapon + Ammo Type Key

```lua
local statCache = {}

local function getStats(weaponId, ammoType)
    local key = Alloy.hashTuple(weaponId, ammoType)
    if not statCache[key] then
        statCache[key] = computeStats(weaponId, ammoType)
    end
    return statCache[key]
end
```

---

## Set Membership

Check membership for integer or vector data without a linear scan.

```lua
local Alloy = require(ReplicatedStorage.Alloy)

-- Build a set of blocked tile positions at startup
local blockedTiles = {}
for _, tile in blockedTileList do
    blockedTiles[Alloy.hashVector2(tile)] = true
end

-- O(1) lookup
local function isBlocked(tilePos)
    return blockedTiles[Alloy.hashVector2(tilePos)] == true
end
```

---

## Incremental / Hierarchical Keys

When you compute the same base hash many times (e.g. once per chunk per frame),
cache it and extend with `combineHashes`:

```lua
local chunkHashes = {}

-- Called once per chunk when it loads
local function registerChunk(cx, cz)
    local key = Alloy.hashTuple(cx, cz)
    chunkHashes[key] = Alloy.hashTuple(cx, cz)
end

-- Called per entity per frame — no full re-hash
local function getEntityKey(cx, cz, entityId)
    local chunkKey = chunkHashes[Alloy.hashTuple(cx, cz)]
    return Alloy.combineHashes(chunkKey, Alloy.hashInt(entityId))
end
```

`combineHashes` runs through `fmix32` after the combine step, so the output has the
same avalanche quality as any other Alloy hash.
