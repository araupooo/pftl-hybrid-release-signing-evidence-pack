# ML-DSA vs SLH-DSA for Release Signing — Scheme Comparison

**Measured on:** this pack's host (see `outputs/env_probe.log` for
machine/CPU/library details), OpenSSL 3.5.9 (29 Sep 2026), fixed
32-byte message, `scripts/bench_openssl.sh`. Raw per-iteration timings
in `outputs/timings_<ALG>_<OP>.txt`; unedited log in
`outputs/bench_openssl.log`.

**Two measurement methods, both reported.** The explicit-loop method
times each `openssl` process invocation with the nanosecond clock, so
every fast-algorithm number includes ~7 ms of process-spawn overhead
(the minima in the raw files sit at ~6.4–8.3 ms for all fast
algorithms). The `openssl speed` cross-check runs in-process and gives
the true crypto cost. Use the speed numbers for crypto comparison; use
the explicit-loop medians for scripting/CI cost estimates. Both are
printed in full below — neither is hidden.

## 1. Reference sizes (FIPS 204 / FIPS 205) — verified by measurement

| Set | Category | Public key | Secret key (expanded) | Signature |
|---|---|---|---|---|
| ML-DSA-44 | 2 | 1,312 B | 2,560 B | 2,420 B |
| ML-DSA-65 | 3 | 1,952 B | 4,032 B | 3,309 B |
| ML-DSA-87 | 5 | 2,592 B | 4,896 B | 4,627 B |

| Set (SHA2 = SHAKE) | Category | Public key | Secret key | Signature |
|---|---|---|---|---|
| 128s | 1 | 32 B | 64 B | 7,856 B |
| 128f | 1 | 32 B | 64 B | 17,088 B |
| 192s | 3 | 48 B | 96 B | 16,224 B |
| 192f | 3 | 48 B | 96 B | 35,664 B |
| 256s | 5 | 64 B | 128 B | 29,792 B |
| 256f | 5 | 64 B | 128 B | 49,856 B |

Measured signature bytes on this host match the FIPS tables exactly
for all 17 algorithms (see §2). ML-DSA private keys may be stored as
their 32-byte seed; the expanded form is derived from it (RFC 9881 /
RFC 9964, Oct 2025). For firmware: store the 32 B seed in the
HSM/secure element, never the 4 KB expanded key, unless the verifier
needs fast keygen.

## 2. Measured sizes and explicit-loop medians (OpenSSL 3.5.9)

| Algorithm | Sig bytes | Pubkey DER bytes | Keygen median (us) | Sign median (us) | Verify median (us) |
|---|---:|---:|---:|---:|---:|
| ML-DSA-44 | 2420 | 1334 | 8,072.0 (n=50) | 9,275.5 (n=200) | 6,951.5 (n=200) |
| ML-DSA-65 | 3309 | 1974 | 9,008.0 (n=50) | 11,473.0 (n=200) | 8,461.0 (n=200) |
| ML-DSA-87 | 4627 | 2614 | 8,961.0 (n=50) | 10,696.5 (n=200) | 7,207.5 (n=200) |
| Ed25519 | 64 | 44 | 7,437.5 (n=50) | 7,058.5 (n=200) | 6,993.0 (n=200) |
| RSA-2048 | 256 | 294 | 86,407.5 (n=10) | 8,878.0 (n=200) | 6,971.0 (n=200) |
| SLH-DSA-SHA2-128s | 7856 | 50 | 78,196.5 (n=50) | 541,496.5 (n=20) | 7,400.0 (n=100) |
| SLH-DSA-SHA2-128f | 17088 | 50 | 8,733.5 (n=50) | 35,566.5 (n=50) | 8,461.0 (n=100) |
| SLH-DSA-SHA2-192s | 16224 | 66 | 109,826.0 (n=50) | 1,039,005.5 (n=20) | 8,668.5 (n=100) |
| SLH-DSA-SHA2-192f | 35664 | 66 | 9,904.0 (n=50) | 57,170.5 (n=50) | 9,296.5 (n=100) |
| SLH-DSA-SHA2-256s | 29792 | 82 | 76,237.5 (n=50) | 957,700.0 (n=20) | 8,990.5 (n=100) |
| SLH-DSA-SHA2-256f | 49856 | 82 | 13,466.0 (n=50) | 103,275.0 (n=50) | 10,086.5 (n=100) |
| SLH-DSA-SHAKE-128s | 7856 | 50 | 192,232.0 (n=50) | 1,402,546.0 (n=20) | 9,487.5 (n=100) |
| SLH-DSA-SHAKE-128f | 17088 | 50 | 11,106.0 (n=50) | 79,402.5 (n=50) | 11,870.0 (n=100) |
| SLH-DSA-SHAKE-192s | 16224 | 66 | 277,944.5 (n=50) | 2,459,259.5 (n=20) | 9,904.0 (n=100) |
| SLH-DSA-SHAKE-192f | 35664 | 66 | 12,559.5 (n=50) | 141,086.0 (n=50) | 13,489.0 (n=100) |
| SLH-DSA-SHAKE-256s | 29792 | 82 | 186,909.5 (n=50) | 2,152,672.5 (n=20) | 10,156.5 (n=100) |
| SLH-DSA-SHAKE-256f | 49856 | 82 | 19,968.0 (n=50) | 235,720.5 (n=50) | 13,635.0 (n=100) |

Failures: 0 in every operation (see `outputs/failures_<ALG>_<OP>.txt`).
Read the table with the spawn-overhead caveat: the fast-algorithm
medians (~7–11 ms) are dominated by the ~7 ms per-invocation spawn
cost, not by crypto. The SLH-DSA "s"-variant signing medians
(0.54–2.46 s) are real crypto cost — spawn overhead is negligible
there. Verification medians are likewise spawn-dominated for every
algorithm; the in-process verify costs are in §3.

## 3. In-process crypto cost (`openssl speed`, 2 s each)

| Algorithm | Keygen | Sign | Verify | Sign/s | Verify/s |
|---|---|---|---|---|---|
| ML-DSA-44 | 175 us | 1,039 us | 189 us | 962.7 | 5,277.5 |
| ML-DSA-65 | 318 us | 1,600 us | 291 us | 625.0 | 3,440.0 |
| ML-DSA-87 | 597 us | 2,519 us | 634 us | 397.0 | 1,577.5 |
| Ed25519 | — | ~57 us | ~133 us | 17,621.0 | 7,543.5 |
| RSA-2048 | 80,400 us | 500 us | 29 us | 1,999.5 | 34,965.5 |
| SLH-DSA-SHA2-128s | 99,048 us | 547,500 us | 526 us | 1.8 | 1,902.5 |
| SLH-DSA-SHA2-128f | 1,085 us | 25,769 us | 1,495 us | 38.8 | 669.0 |

Hybrid (Ed25519 + ML-DSA-65, dual independent signatures) in-process
cost, summing components: sign ≈ 1,657 us, verify ≈ 424 us,
signature 3,373 B (64 + 3,309). Composite MLDSA65-Ed25519-SHA512
(RFC 10073) is the same 3,373 B signature with a 1,984 B public key
(RFC 10073 Appendix A) — but composite is not runnable in stock
OpenSSL 3.5.9 (see `outputs/composite_probe.log`).

Ratios (in-process): SLH-DSA-SHA2-128s signing (547.5 ms) is ~330x
the hybrid signing cost (~1.66 ms) and ~340x the ML-DSA-65 signing
cost (1.60 ms). SLH-DSA-128s verification (526 us) is ~1.8x the
ML-DSA-65 verification cost (291 us) — verification is cheap for both;
signing is where SLH-DSA pays. The slowest measured signing is
SLH-DSA-SHAKE-192s at ~2.46 s per signature (explicit loop).

## 4. Cross-stack check (prior pack, 14 Nov 2026)

The prior pack measured with liboqs 0.16.0 / PQClean C drivers
(in-process, no spawn overhead): hybrid sign 139.669 us, hybrid
verify 190.366 us, SLH-DSA-SHA2-128s sign 692,670.570 us,
SLH-DSA-128s verify 710.776 us. Independent liboqs 0.16.0 benchmarks
cite hybrid sign 143.8 us, verify 103.8 us.

Comparison with this pack's OpenSSL 3.5.9 numbers:

- **SLH-DSA-128s signing agrees across stacks:** 547.5 ms (OpenSSL
  speed) vs 692.7 ms (liboqs) — same order of magnitude, ~20% apart.
  Signing cost is dominated by hashing and is stack-independent.
- **ML-DSA signing does NOT agree:** 1,600 us (OpenSSL speed) vs
  ~140 us (liboqs) — ~11x apart. OpenSSL's EVP/provider dispatch path
  is slower than raw liboqs for ML-DSA. The toolchain choice changes
  the measured ML-DSA sign cost by an order of magnitude.
- **Verification agrees in order of magnitude:** hybrid verify
  190.4 us (liboqs) vs ~424 us (OpenSSL speed, summed components) —
  ~2.2x apart.
- **Ordering is identical in both stacks:** hybrid beats SLH-DSA-128s
  on signing by 2–3 orders of magnitude and on signature size by ~2.3x
  (3,373 B vs 7,856 B), while verification is within ~2x.

Lesson: quote the stack with the number. Absolute microseconds are
stack-dependent; the ratios and the ordering are not.

## 5. What `s` vs `f` really trades

`s` = fewer, taller XMSS layers → smaller signature, many more hash
calls to sign. `f` = more, shorter layers → larger signature, far
fewer hashes. Verification recomputes one path in both, so verify cost
differs only modestly. Measured: 128s signs in ~0.54 s vs 128f in
~0.036 s (SHA2), while 128s verifies in ~0.53 ms vs 128f in ~1.50 ms
(in-process). Choose `s` when the signature is stored/transmitted many
times; `f` when the signer is the bottleneck. A glitched hash during
SLH-DSA signing can leak a WOTS+ signature on a wrong value and enable
forgery — same verify-after-sign rule as ML-DSA (FIPS 205 §5–§9).

## 6. Recommendation

**Sign releases with hybrid Ed25519 + ML-DSA-65 now** (dual
independent signatures, both required, fail-closed — the Android
APK v3.2 model). Keep **SLH-DSA-128s as the hash-based fallback for
commercial, non-NSS use** — with three amendments to the prior pack's
recommendation:

1. **Scope the SLH-DSA fallback as commercial-only.** CNSA 2.0 does
   NOT approve SLH-DSA for firmware; its hash-based firmware choice
   is LMS/XMSS (SP 800-208). A design that says "ML-DSA now, SLH-DSA
   fallback if the HSM lags" is non-compliant for NSS — the fallback
   for NSS is a different HSM/module, not a different algorithm family.
2. **Add a physical-security requirement on the signer**
   (verify-after-sign, fault detection, constant-time-audited shipped
   binary). The 2024–2026 literature shows hedged mode alone does not
   cover fault/side-channel attacks (Zhao et al. ePrint 2026/056;
   CVE-2026-22705; GHSA-r7wm).
3. **Track NIST SP 800-230** (draft, Apr 2026) as the future SLH-DSA
   firmware set (3,856 B signatures, 2^24-signature cap, minutes-long
   signing) but do not deploy draft sets.

**Composite ML-DSA (RFC 10073/10082) is the standards-tracked
future, not the deploy-today shape:** composite is one key, one
signature, atomic, both components must verify (fail-closed), EUF-CMA
only, not SUF-CMA (RFC 10073 §9.2). The RFC's own default is
MLDSA65-ECDSA-P256, with MLDSA65-Ed25519 recommended specifically
where SUF-CMA is required. Stock OpenSSL 3.5.9 cannot generate or use
composite keys (`outputs/composite_probe.log`); only Bouncy Castle
1.84 has been verified by independent interop testing. Until a
composite-capable toolchain ships, dual signatures are the
implementable-today shape.

**Firmware rule (embedded/MCU evidence):** sign off-device, verify
on-device — always. SLH-DSA signing on a bare Cortex-M4 is not a
design option; ML-DSA signing tail latency on RP2040 reaches p99
~584 ms / max 1,157 ms. (arXiv:2606.15744, arXiv:2603.19340, 2026.)

## 7. Deadlines (why now)

NIST IR 8547 final (27 Oct 2026): quantum-vulnerable public-key
algorithms deprecated after 2030 and disallowed after 2035 **at every
key size**. Federal high-value assets: PQC key exchange by 31 Dec 2030,
PQC signatures by 31 Dec 2031 (EO 14412 / OMB M-26-15, June 2026).
The migration window is the rest of this decade, not the next one.
