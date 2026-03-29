-- MIT License
--
-- Copyright (c) 2026 VeDevelopment

--[=[
	@class Alloy

	Fast, allocation-free hashing for Roblox.

	Alloy maps integers, floats, Vector2s, Vector3s, and arbitrary number tuples
	to clean unsigned 32-bit integers in the range `[0, 2^32)`. Every function is
	zero-allocation and safe to call on hot paths.

	**Algorithm.** Alloy uses `boost::hash_combine` to fold input values into a
	running seed, then finalises with the MurmurHash3 `fmix32` avalanche mixer.
	The finalizer passes all SMHasher avalanche tests — flipping any single input
	bit changes ~50% of output bits.

	**Precision.** Lua doubles have a 53-bit mantissa. Raw multiplication silently
	drops low bits when both operands are large. Alloy uses a split-multiply
	(`mul32`) that keeps every intermediate product under 2^48, preserving
	correctness across the full 32-bit output range.

	**Float inputs.** `hashFloat`, `hashVector2f`, and `hashVector3f` multiply by
	a `scale` factor (default `1000`) before rounding. `math.round` is used instead
	of `math.floor` to avoid IEEE 754 rounding artifacts at precision boundaries —
	`1.001 * 1000` rounds to `1001`, not `1000`.

	```lua
	local Alloy = require(ReplicatedStorage.Alloy)

	-- Hash a 2D chunk coordinate pair for a spatial grid
	local key = Alloy.hashTuple(chunkX, chunkZ)

	-- Map the hash to a 1-based bucket index
	local bucket = Alloy.toBucket(key, 256)

	-- Hash a world-space float position with 3dp precision
	local posHash = Alloy.hashVector3f(part.Position)
	```
]=]
local Alloy = {}

-- ─── Integer ──────────────────────────────────────────────────────────────────

--[=[
	@function hashInt
	@within Alloy

	Hashes a single integer (or float truncated to integer).

	Internally applies `fmix32` to the floor-truncated, uint32-normalised input.
	Suitable as a standalone integer hash or as a building block for composite keys
	via [Alloy.combineHashes].

	```lua
	local h = Alloy.hashInt(42)
	local h2 = Alloy.hashInt(-7)  -- negatives are normalised correctly
	```

	@param n number -- The value to hash. Floats are floor-truncated before hashing.
	@return number -- Unsigned 32-bit integer in `[0, 2^32)`.
]=]
function Alloy.hashInt(n: number): number end

-- ─── Float ────────────────────────────────────────────────────────────────────

--[=[
	@function hashFloat
	@within Alloy

	Hashes a single float with sub-integer precision.

	The value is multiplied by `scale` and rounded to the nearest integer before
	hashing. The default scale of `1000` preserves 3 decimal places — `1.001` and
	`1.002` produce different hashes.

	```lua
	-- Default: 3 decimal places
	local h = Alloy.hashFloat(3.14159)

	-- 4 decimal places
	local h2 = Alloy.hashFloat(3.14159, 10000)

	-- Nearest 0.5 stud
	local h3 = Alloy.hashFloat(distance, 2)
	```

	:::caution
	Two floats that round to the same scaled integer produce the same hash. Choose
	`scale` to match the precision granularity your use-case requires.
	:::

	@param n number -- The float to hash.
	@param scale number? -- Precision multiplier applied before rounding. Default: `1000`.
	@return number -- Unsigned 32-bit integer in `[0, 2^32)`.
]=]
function Alloy.hashFloat(n: number, scale: number?): number end

-- ─── Vector2 ──────────────────────────────────────────────────────────────────

--[=[
	@function hashVector2
	@within Alloy

	Hashes a Vector2 with integer coordinates.

	X and Y are floor-truncated and folded into a seed using `hash_combine`, then
	finalised with `fmix32`. Use this for tile positions, pixel coordinates, or any
	grid where components are already whole numbers.

	```lua
	local tileHash = Alloy.hashVector2(Vector2.new(tileX, tileY))
	local seen = {}
	seen[tileHash] = true
	```

	@param v Vector2 -- The vector to hash. Components are floor-truncated.
	@return number -- Unsigned 32-bit integer in `[0, 2^32)`.
]=]
function Alloy.hashVector2(v: Vector2): number end

--[=[
	@function hashVector2f
	@within Alloy

	Hashes a Vector2 with sub-integer precision.

	Each component is multiplied by `scale` and rounded before hashing. Use this
	for 2D world-space floats where you need stable hashes for fractional values.

	```lua
	local h  = Alloy.hashVector2f(position2D)        -- 3 decimal places
	local h2 = Alloy.hashVector2f(position2D, 100)   -- 2 decimal places
	```

	@param v Vector2 -- The vector to hash.
	@param scale number? -- Precision multiplier applied per component. Default: `1000`.
	@return number -- Unsigned 32-bit integer in `[0, 2^32)`.
]=]
function Alloy.hashVector2f(v: Vector2, scale: number?): number end

-- ─── Vector3 ──────────────────────────────────────────────────────────────────

--[=[
	@function hashVector3
	@within Alloy

	Hashes a Vector3 with integer coordinates. Zero allocations.

	X, Y, and Z are floor-truncated and folded sequentially into a seed using
	`hash_combine`, then finalised with `fmix32`. The most common use-case is
	hashing voxel positions or 3D chunk coordinates where components are whole
	numbers.

	```lua
	local chunkKey = Alloy.hashVector3(Vector3.new(cx, cy, cz))
	local chunkMap = {}
	chunkMap[chunkKey] = generateChunk(cx, cy, cz)
	```

	@param v Vector3 -- The vector to hash. Components are floor-truncated.
	@return number -- Unsigned 32-bit integer in `[0, 2^32)`.
]=]
function Alloy.hashVector3(v: Vector3): number end

--[=[
	@function hashVector3f
	@within Alloy

	Hashes a Vector3 with sub-integer precision.

	Each component is multiplied by `scale` and rounded before hashing. Useful for
	de-duplicating world-space hit positions, caching impact points, or keying any
	table by a floating-point position.

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

	:::caution
	Two positions that round to the same scaled integer triple produce the same
	hash. Increase `scale` for finer precision, but be aware that very large scale
	factors narrow the precision band — a `scale` of `1_000_000` on coordinates
	beyond ±4000 studs can overflow into hash collisions.
	:::

	@param v Vector3 -- The vector to hash.
	@param scale number? -- Precision multiplier applied per component. Default: `1000`.
	@return number -- Unsigned 32-bit integer in `[0, 2^32)`.
]=]
function Alloy.hashVector3f(v: Vector3, scale: number?): number end

-- ─── Tuple ────────────────────────────────────────────────────────────────────

--[=[
	@function hashTuple
	@within Alloy

	Hashes an arbitrary variadic sequence of numbers.

	Values are folded sequentially using `hash_combine` and finalised with `fmix32`.
	Order is significant — `hashTuple(1, 2)` and `hashTuple(2, 1)` produce different
	hashes. Suitable for composite keys of any arity.

	```lua
	-- 2D chunk + vertical layer
	local key = Alloy.hashTuple(chunkX, chunkZ, layer)

	-- Player + weapon slot composite key
	local key = Alloy.hashTuple(playerId, slotIndex)
	```

	@param ... number -- The numbers to hash, in order.
	@return number -- Unsigned 32-bit integer in `[0, 2^32)`.
]=]
function Alloy.hashTuple(...: number): number end

-- ─── Combine ──────────────────────────────────────────────────────────────────

--[=[
	@function combineHashes
	@within Alloy

	Combines two already-hashed uint32 values into a single hash.

	Useful for building layered or incremental keys without re-hashing from
	scratch. The result is passed through `fmix32` after combining, so the output
	has full avalanche mixing.

	```lua
	-- Hash the chunk origin once, then specialise per layer on demand
	local base  = Alloy.hashVector3(chunkOrigin)
	local full  = Alloy.combineHashes(base, Alloy.hashInt(layerIndex))

	-- Build a composite key from two independent hashes
	local playerHash = Alloy.hashInt(player.UserId)
	local zoneHash   = Alloy.hashInt(zoneId)
	local sessionKey = Alloy.combineHashes(playerHash, zoneHash)
	```

	@param a number -- First uint32 hash value.
	@param b number -- Second uint32 hash value.
	@return number -- Combined unsigned 32-bit integer in `[0, 2^32)`.
]=]
function Alloy.combineHashes(a: number, b: number): number end

-- ─── Bucket ───────────────────────────────────────────────────────────────────

--[=[
	@function toBucket
	@within Alloy

	Maps a hash to a 1-based bucket index in the range `[1, buckets]`.

	Uses modulo distribution. For best uniformity choose a prime or power-of-two
	bucket count. The return value is always a valid Lua table index.

	```lua
	local BUCKETS = 64
	local table   = {}
	for i = 1, BUCKETS do table[i] = {} end

	local function insert(entity)
	    local key    = Alloy.hashVector3(entity.GridPosition)
	    local bucket = Alloy.toBucket(key, BUCKETS)
	    table.insert(table[bucket], entity)
	end
	```

	@param hash number -- A uint32 hash value produced by any Alloy hash function.
	@param buckets number -- Total bucket count. Must be a positive integer.
	@return number -- Bucket index in `[1, buckets]`.
]=]
function Alloy.toBucket(hash: number, buckets: number): number end

return Alloy
