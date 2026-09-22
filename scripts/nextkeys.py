#!/usr/bin/env python3
"""Print the storage key for session.nextKeys(<account hex>).

Pure-Python twox (xxHash64) so it runs on a stock Ubuntu with no pip installs.
Usage: nextkeys.py 0x<32-byte account hex>
"""
import sys

P1, P2, P3, P4, P5 = (11400714785074694791, 14029467366897019727,
                      1609587929392839161, 9650029242287828579,
                      2870177450012600261)
M = (1 << 64) - 1


def _rotl(x, r):
    return ((x << r) | (x >> (64 - r))) & M


def _round(acc, lane):
    acc = (acc + lane * P2) & M
    return (_rotl(acc, 31) * P1) & M


def _merge(acc, val):
    acc ^= _round(0, val)
    return (acc * P1 + P4) & M


def xxh64(data, seed=0):
    n, i = len(data), 0
    if n >= 32:
        v1, v2 = (seed + P1 + P2) & M, (seed + P2) & M
        v3, v4 = seed, (seed - P1) & M
        while i + 32 <= n:
            v1 = _round(v1, int.from_bytes(data[i:i + 8], "little"))
            v2 = _round(v2, int.from_bytes(data[i + 8:i + 16], "little"))
            v3 = _round(v3, int.from_bytes(data[i + 16:i + 24], "little"))
            v4 = _round(v4, int.from_bytes(data[i + 24:i + 32], "little"))
            i += 32
        h = (_rotl(v1, 1) + _rotl(v2, 7) + _rotl(v3, 12) + _rotl(v4, 18)) & M
        for v in (v1, v2, v3, v4):
            h = _merge(h, v)
    else:
        h = (seed + P5) & M
    h = (h + n) & M
    while i + 8 <= n:
        h ^= _round(0, int.from_bytes(data[i:i + 8], "little"))
        h = (_rotl(h, 27) * P1 + P4) & M
        i += 8
    if i + 4 <= n:
        h ^= (int.from_bytes(data[i:i + 4], "little") * P1) & M
        h = (_rotl(h, 23) * P2 + P3) & M
        i += 4
    while i < n:
        h ^= (data[i] * P5) & M
        h = (_rotl(h, 11) * P1) & M
        i += 1
    h ^= h >> 33
    h = (h * P2) & M
    h ^= h >> 29
    h = (h * P3) & M
    h ^= h >> 32
    return h


def twox128(s):
    b = s.encode()
    return (xxh64(b, 0).to_bytes(8, "little") + xxh64(b, 1).to_bytes(8, "little")).hex()


def twox64concat(b):
    return xxh64(b, 0).to_bytes(8, "little").hex() + b.hex()


if __name__ == "__main__":
    acct = bytes.fromhex(sys.argv[1].removeprefix("0x"))
    print("0x" + twox128("Session") + twox128("NextKeys") + twox64concat(acct))
