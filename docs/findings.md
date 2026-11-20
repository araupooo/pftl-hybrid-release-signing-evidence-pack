# Findings — Hybrid Post-Quantum Release Signing for PFTL

## Headline

The hybrid scheme wins on every measured axis on this host, and the
win is biggest exactly where release signing hurts: **signing**.
Hybrid (Ed25519 + ML-DSA-65) signing costs ~1.66 ms in-process
against ~547.5 ms for SLH-DSA-SHA2-128s — about 330x faster — and a
hybrid signature is 3,373 B against 7,856 B for SLH-DSA-128s and
17,088 B for SLH-DSA-128f. Verification is cheap for both (~0.42 ms
hybrid vs ~0.53 ms SLH-DSA-128s), so verification cost does not
decide the choice; signing cost and signature size do.

## What was measured (new in this pack)

- **17 algorithms, 3 operations each, 0 failures**, on OpenSSL 3.5.9
  native tooling: ML-DSA-44/65/87, all 12 SLH-DSA sets (SHA2 + SHAKE),
  Ed25519, RSA-2048. Full table in `docs/scheme-comparison.md` §2–3;
  raw timings in `outputs/timings_*.txt`.
- **A runnable hybrid manifest demo**: version, monotonic counter,
  artifact digests, hybrid metadata, signer fingerprints, dual
  signatures — verified ACCEPT (`outputs/dual_sign_demo.log`).
- **A rejected downgrade simulation, 6/6 cases** as expected:
  control accepts; stale manifest, missing ML-DSA signature, missing
  Ed25519 signature, tampered artifact, and swapped signatures all
  reject (`outputs/downgrade_sim.log`).
- **A key-compromise drill, 5/5 steps**: revocation rejects the old
  release even though its signatures are valid; rotation to fresh
  keys is real, not cosmetic (`outputs/compromise_drill.log`).
- **A composite probe**: RFC 10073 composite ML-DSA is not runnable
  in stock OpenSSL 3.5.9 — dual signatures are the implementable-today
  shape (`outputs/composite_probe.log`).

## What changed since the prior pack (14 Nov 2026)

1. **The hybrid standard now exists as published RFCs.** RFC 10073
   (Composite ML-DSA for X.509) and RFC 10082 (Composite ML-DSA in
   CMS), both Nov 2026, Standards Track. The prior pack cited drafts;
   this pack cites the RFCs and verifies the OIDs live (RFC 10073 §8.2).
2. **The migration deadline is now final NIST policy.** IR 8547 final
   (27 Oct 2026): deprecation after 2030, disallowance after 2035 at
   every key size.
3. **The SLH-DSA fallback is re-scoped.** CNSA 2.0 does not approve
   SLH-DSA for firmware; LMS/XMSS (SP 800-208) is the NSS firmware
   choice. The prior pack's "SLH-DSA as fallback" is now explicitly
   commercial-only.
4. **The 2026 CVE layer is in.** No scheme break; implementation,
   compiler, and parsing bugs only (CVE-2026-22705, CVE-2026-46344 /
   CVE-2026-44518, GHSA-r7wm). The signer needs verify-after-sign,
   fault detection, and a constant-time-audited binary.
5. **Sigstore will not do dual signatures** (blog, 2 Oct 2026): a
   separate ML-DSA stack, production instance targeted mid-2027. A
   project wanting dual signatures today must do it itself — which is
   what this pack demonstrates.
6. **The toolchain finding:** OpenSSL 3.5.9's ML-DSA signing measures
   ~11x slower than raw liboqs (1,600 us vs ~140 us in-process),
   while SLH-DSA signing agrees across stacks (~0.55 s vs ~0.69 s).
   Quote the stack with the number; the ordering is identical either
   way.

## Recommendation (unchanged in direction, amended in scope)

**Sign releases with hybrid Ed25519 + ML-DSA-65 now** (dual
independent signatures, both required, fail-closed). Keep
**SLH-DSA-128s as the hash-based fallback for commercial, non-NSS
use only**, with the signer-hardening requirements in
`docs/key-compromise-playbook.md` §3. Track composite ML-DSA
(RFC 10073/10082) as the standards-tracked future and SP 800-230
(draft) as the future SLH-DSA firmware set; deploy neither until the
toolchain and the standard are final.

For postfiatd specifically: the release process at commit `0085a1ff`
has no signing, no digests, and manual rollback with no counter
(`docs/postfiatd-release-gap.md`). The manifest in this pack is the
missing integrity layer: add a signed manifest with a monotonic
counter to the GitHub Release / Docker image pair, and verify it on
the operator side before deploying. The demo shows the shape; the
downgrade simulation shows what it stops; the playbook shows what to
do when a key is lost.

## What this pack does not claim

- The demo artifacts are fixed-content placeholders, not real
  postfiatd binaries. No postfiatd code was changed.
- Absolute microseconds are stack- and host-dependent; the ratios and
  the ordering are the portable claims.
- Bouncy Castle 1.84 as the only interop-verified composite
  implementation is cited, not run (no Java runtime in this
  environment).
- No postfiatd release-signing key has been compromised; the
  playbook and drill are preparedness, not incident response.
