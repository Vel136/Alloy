-- MIT License
--
-- Copyright (c) 2026 VeDevelopment
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

-- Alloy
-- A reusable hashing module for Roblox.
-- Provides fast, allocation-free hashing for Vector3, Vector2,
-- plain integers, and arbitrary multi-value tuples.
--
-- All output is a clean unsigned 32-bit integer [0, 2^32).

local Alloy = {}

-- ─── Internal constants ───────────────────────────────────────────────────────

local UINT32        = 2^32
local GOLDEN_RATIO  = 0x9e3779b9   -- 2^32 / φ; used in hash_combine
local MIX_C1       = 0x85ebca6b   -- MurmurHash3 fmix32 constants
local MIX_C2       = 0xc2b2ae35

-- ─── Private helpers ──────────────────────────────────────────────────────────

-- Safe 32×32→32 multiply.
-- Lua doubles have a 53-bit mantissa; a naive (a*b) % 2^32 silently
-- drops low bits when both operands are large. Splitting 'a' into two
-- 16-bit halves keeps every intermediate product under 2^48.
local function mul32(a: number, b: number): number
	local lo = a % 0x10000
	local hi = math.floor(a / 0x10000)
	return ((hi * b % 0x10000) * 0x10000 + lo * b) % UINT32
end

-- MurmurHash3 fmix32 finalizer.
-- Passes all SMHasher avalanche tests: every input bit flips ~50% of
-- output bits. Applied once after combining all input values.
local function fmix32(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, MIX_C1)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, MIX_C2)
	return bit32.bxor(h, bit32.rshift(h, 16))
end

-- boost::hash_combine — the canonical way to fold one value into a seed.
-- GOLDEN_RATIO shifts each combine step into a maximally different region
-- of the hash space, preventing collisions between (a,b) and (b,a).
local function combine(seed: number, v: number): number
	return bit32.bxor(
		seed,
		(v + GOLDEN_RATIO + bit32.lshift(seed, 6) + bit32.rshift(seed, 2)) % UINT32
	)
end

-- Normalise any Lua number to an unsigned 32-bit integer.
-- math.floor + % UINT32 safely handles negatives:
--   e.g. math.floor(-5) % UINT32 == 4294967291  ✓
-- Used by integer paths (hashInt, hashTuple, hashVector2, hashVector3).
local function toU32(n: number): number
	return math.floor(n) % UINT32
end

-- Round-then-normalise variant for float-scaled inputs.
-- After multiplying by a scale factor, IEEE 754 rounding errors push the
-- result just below the intended integer (e.g. 1.001 * 1000 → 1000.9999…).
-- math.floor would silently truncate that to 1000, colliding with 1.0.
-- math.round snaps to the nearest integer instead, preserving the intended
-- precision boundary.
-- Used by hashFloat, hashVector2f, hashVector3f.
local function toU32f(n: number): number
	return math.round(n) % UINT32
end

-- ─── Public API ───────────────────────────────────────────────────────────────

--- Hash a single integer or float (truncated to integer).
-- @param n  number
-- @return   uint32
function Alloy.hashInt(n: number): number
	return fmix32(toU32(n))
end

--- Hash a single float with sub-integer precision.
-- @param n      number
-- @param scale  number   Multiplier for decimal precision (default 1000 → 3dp)
-- @return       uint32
function Alloy.hashFloat(n: number, scale: number?): number
	return fmix32(toU32f(n * (scale or 1000)))
end

--- Hash a Vector2 (integer coords).
-- @param v  Vector2
-- @return   uint32
function Alloy.hashVector2(v: Vector2): number
	local h = combine(0, toU32(v.X))
	h = combine(h, toU32(v.Y))
	return fmix32(h)
end

--- Hash a Vector2 with sub-integer precision.
-- @param v      Vector2
-- @param scale  number   (default 1000)
-- @return       uint32
function Alloy.hashVector2f(v: Vector2, scale: number?): number
	local s = scale or 1000
	local h = combine(0, toU32f(v.X * s))
	h = combine(h, toU32f(v.Y * s))
	return fmix32(h)
end

--- Hash a Vector3 (integer coords).  Zero allocations.
-- @param v  Vector3
-- @return   uint32
function Alloy.hashVector3(v: Vector3): number
	local h = combine(0, toU32(v.X))
	h = combine(h, toU32(v.Y))
	h = combine(h, toU32(v.Z))
	return fmix32(h)
end

--- Hash a Vector3 with sub-integer precision.
-- @param v      Vector3
-- @param scale  number   (default 1000)
-- @return       uint32
function Alloy.hashVector3f(v: Vector3, scale: number?): number
	local s = scale or 1000
	local h = combine(0, toU32f(v.X * s))
	h = combine(h, toU32f(v.Y * s))
	h = combine(h, toU32f(v.Z * s))
	return fmix32(h)
end

--- Hash an arbitrary sequence of numbers (variadic).
-- Useful for custom composite keys: HashUtil.hashTuple(chunkX, chunkZ, layer)
-- @param ...  numbers
-- @return     uint32
function Alloy.hashTuple(...: number): number
	local h = 0
	for i = 1, select("#", ...) do
		h = combine(h, toU32(select(i, ...)))
	end
	return fmix32(h)
end

--- Combine two already-hashed values into one.
-- Lets you build incremental/layered keys:
--   local base = HashUtil.hashVector3(chunkOrigin)
--   local full = HashUtil.combineHashes(base, HashUtil.hashInt(layer))
-- @param a  uint32
-- @param b  uint32
-- @return   uint32
function Alloy.combineHashes(a: number, b: number): number
	return fmix32(combine(a, b))
end

--- Map a hash to a bucket index  [1, n]  (Lua-style 1-based).
-- @param hash     uint32
-- @param buckets  number   Total bucket count
-- @return         number   Bucket index
function Alloy.toBucket(hash: number, buckets: number): number
	return (hash % buckets) + 1
end

return Alloy