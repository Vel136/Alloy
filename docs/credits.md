---
sidebar_position: 5
---

# Credits

Alloy is built and maintained by **VeDevelopment**.

---

## Author

Alloy was designed and written by the VeDevelopment team. The algorithm — split-safe
32-bit multiply, `boost::hash_combine` combining, MurmurHash3 `fmix32` finalizer, and
`math.round`-based float normalisation — is original Luau implementation work.

**Find us:**

- [Discord Server](https://discord.gg/XMYMRKcd3g)
- [Direct Message](https://discord.com/users/897026279243669504)
- [Instagram](https://www.instagram.com/vedevelopment/)
- [X / Twitter](https://x.com/vedevelopment_)
- [TikTok](https://www.tiktok.com/@vedevelopment)

---

## Algorithm References

Alloy draws on well-established hashing techniques:

**`boost::hash_combine`** — the canonical folding step used to combine multiple
values into a single seed. The golden ratio constant (`0x9e3779b9 ≈ 2^32 / φ`) shifts
each combine step into a maximally different region of the hash space, preventing
collisions between `(a, b)` and `(b, a)`.

**MurmurHash3 `fmix32`** — the finalizer from Austin Appleby's MurmurHash3.
Passes all SMHasher avalanche tests. Every input bit influences approximately 50% of
output bits after finalisation.

---

## License

Alloy is released under the **MIT License**.

```
MIT License
Copyright (c) 2026 VeDevelopment

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
