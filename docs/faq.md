---
sidebar_position: 4
---

# FAQ

Answers to the questions that come up most often.

---

## General

**What is Alloy?**

Alloy is a pure Luau hashing module for Roblox. It turns integers, floats, Vector2s,
Vector3s, and arbitrary number tuples into unsigned 32-bit integer hashes using
`boost::hash_combine` and the MurmurHash3 `fmix32` avalanche finalizer. It is
designed for use on hot paths — zero allocations, no dependencies.

---

**Is Alloy free?**

Yes. Alloy is released under the MIT License.

---

**What are the hashes good for?**

- Keying spatial grids and chunk maps by coordinate
- Bucket dispatch in fixed-size hash tables
- De-duplicating floating-point positions without equality comparisons
- Building composite keys from multiple values
- Set membership checks for integer or vector data

---

**Can I use Alloy on the server and the client?**

Yes. Alloy has no RunService dependency and works identically in any Lua environment.
Require it on the server, the client, or in a ModuleScript shared between both.

---

## Hashing

**What does `hashInt` do with a negative number?**

`math.floor(n) % 2^32` correctly normalises negatives to the uint32 range.
`math.floor(-5) % 2^32 == 4294967291` — not zero, not an error.

---

**Why does `hashFloat` use `math.round` instead of `math.floor`?**

IEEE 754 rounding means `1.001 * 1000` often evaluates to `1000.9999…` rather than
exactly `1001`. `math.floor` would truncate that to `1000`, creating a false collision
with the hash of `1.0`. `math.round` snaps to the nearest integer, preserving the
intended precision boundary.

---

**What scale should I use for `hashFloat` / `hashVector3f`?**

| Scale | Precision |
|-------|-----------|
| `10` | 1 decimal place (nearest 0.1) |
| `100` | 2 decimal places (nearest 0.01) |
| `1000` | 3 decimal places — **default** |
| `10000` | 4 decimal places |

Choose based on how finely you need to distinguish values. Two inputs that round to
the same scaled integer will produce the same hash by design.

---

**Does order matter in `hashTuple`?**

Yes. `hashTuple(1, 2)` and `hashTuple(2, 1)` produce different hashes. The
`hash_combine` step uses a directional rotation that is not commutative.

---

**Can I use `hashVector3` on non-integer positions?**

Yes, but the components will be floor-truncated first. If you need sub-integer
precision, use `hashVector3f` instead.

---

**Is there a risk of collision?**

All hash functions have a theoretical collision probability of `1 / 2^32` for any two
distinct inputs (about 1 in 4 billion). For typical Roblox game data — chunk grids,
player IDs, hit positions — collisions are negligibly rare in practice.

If you need a collision-free mapping, use a proper bijection rather than a hash.

---

**Why is there no `hashString`?**

Alloy is designed for numeric inputs. Roblox provides `string.byte` and `string.len`
if you need to derive an integer from a string, which you can then pass to
`hashTuple` or `hashInt`.

---

## Performance

**Is Alloy safe to call every frame?**

Yes. Every function is zero-allocation. There are no intermediate table or string
constructions — only arithmetic and `bit32` operations.

---

**When should I use `hashVector3` vs `hashTuple(v.X, v.Y, v.Z)`?**

They are equivalent in output. `hashVector3` is marginally more readable and
avoids the variadic select overhead of `hashTuple`. Prefer `hashVector3` when you
already have a Vector3 value; prefer `hashTuple` when you have the components as
separate variables.

---

**When should I use `combineHashes` vs `hashTuple`?**

Use `combineHashes(a, b)` when one of the hashes (`a`) is already computed and
stored — for example, a chunk base hash cached in a table. This avoids recomputing
the first component.

Use `hashTuple` when hashing all components fresh from raw numbers.

---

## Buckets

**What bucket count gives the best distribution?**

Primes and powers of two both give good distribution with `toBucket`. The returned
index is always in `[1, n]`, compatible with Lua tables.

---

**Is `toBucket` biased?**

Slightly, in the same way that `n % k` is biased when `k` doesn't divide `2^32`.
For typical bucket counts (64, 128, 256, 512) the bias is below 1% and is not
meaningful in practice.
