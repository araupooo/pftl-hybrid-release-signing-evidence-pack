# Hybrid Post-Quantum Release-Signing Evidence Pack for PFTL

Measured benchmarks, a runnable hybrid manifest signing demo, a
rejected downgrade simulation, and a primary-source key-compromise
playbook for PFTL/postfiatd release signing — comparing ML-DSA with
SLH-DSA on OpenSSL 3.5.9.

## Headline finding

Hybrid (Ed25519 + ML-DSA-65) signing costs ~1.66 ms in-process
against ~547.5 ms for SLH-DSA-SHA2-128s — about 330x faster — and a
hybrid signature is 3,373 B against 7,856 B for SLH-DSA-128s and
17,088 B for SLH-DSA-128f. Verification is cheap for both (~0.42 ms
hybrid vs ~0.53 ms SLH-DSA-128s). Recommendation: sign releases with
hybrid Ed25519 + ML-DSA-65 now; keep SLH-DSA-128s as the hash-based
fallback for commercial, non-NSS use only (CNSA 2.0 does not approve
SLH-DSA for firmware — its choice is LMS/XMSS, SP 800-208). See
`docs/findings.md` and `docs/scheme-comparison.md`.

## What this pack contains

- `scripts/run_all.sh` — reproduce every measurement from a fresh
  clone (provisions pinned OpenSSL 3.5.9, SHA-256 verified).
- `scripts/env_probe.sh` — environment facts + tool versions.
- `scripts/bench_openssl.sh` — ML-DSA-44/65/87, all 12 SLH-DSA sets,
  Ed25519, RSA-2048 benchmarks (explicit loops + `openssl speed`
  cross-check).
- `scripts/dual_sign_demo.sh` + `scripts/verify_manifest.sh` +
  `scripts/manifest_lib.sh` — hybrid manifest sign/verify demo
  (version, monotonic counter, digests, hybrid metadata, rollback
  protection).
- `scripts/downgrade_sim.sh` — rejected downgrade simulation, 6 cases.
- `scripts/compromise_drill.sh` — key-compromise and recovery drill,
  5 steps.
- `scripts/composite_probe.sh` — RFC 10073 composite ML-DSA support
  probe (stock OpenSSL 3.5.9: not available).
- `docs/scheme-comparison.md` — ML-DSA vs SLH-DSA tables, cross-stack
  check, recommendation.
- `docs/findings.md` — assessment narrative and what changed since the
  14 Nov 2026 pack.
- `docs/key-compromise-playbook.md` — six-step runbook from primary
  sources (BootHole, Baton Drop/BlackX, CVE-2024-7344, Android OEM
  keys; 2026 CVE layer).
- `docs/postfiatd-release-gap.md` — what the release process at
  postfiatd `0085a1ff` is missing (no signing, no digests, manual
  rollback) and how each pack artifact maps to it.
- `docs/claims.md` — claim-to-evidence index (every claim → script +
  unedited output, or cited source).
- `outputs/` — unedited logs + raw per-iteration timing files
  (51 timing files, 17 algorithms x 3 ops, 0 failures).
- `repro/` — fresh-clone reproduction run log + how to reproduce.
- `SOURCES.md` — pinned primary sources.
- `SHA256SUMS` — full SHA-256 for every file in the pack.

## How to reproduce

```bash
git clone https://github.com/araupooo/pftl-hybrid-release-signing-evidence-pack.git
cd pftl-hybrid-release-signing-evidence-pack
bash scripts/run_all.sh
```

Prerequisites: `cmake gcc make python3 git curl`
(`sudo apt-get install -y cmake gcc make python3 git curl`).
Expected wall time on a 4-vCPU VM: ~15–25 minutes on a fresh clone
(the OpenSSL build dominates); ~5 minutes when OpenSSL is already
built. See `repro/REPRODUCTION.md` for what reproduces exactly and
what varies.

## How to verify the results

```bash
bash scripts/run_all.sh   # ends with "ALL CHECKS PASSED" or fails loudly
grep -E "RESULT: (PASS|FAIL)" outputs/*.log
sha256sum -c SHA256SUMS
```

Keys are ephemeral test-only keys, generated fresh on every run and
never used to sign anything real. Demo artifacts are fixed-content
placeholders, not real postfiatd binaries. No postfiatd code was
changed by this pack.

## Prior work

Prior release-signing pack (14 Nov 2026):
https://github.com/araupooo/postfiat-release-signing-pqc-assessment
(liboqs 0.16.0 + PQClean drivers). This pack re-measures with
OpenSSL 3.5.9 native tooling across all 12 SLH-DSA sets and adds the
manifest demo, downgrade simulation, compromise drill, and the
post-14-Nov standards/CVE layer (RFC 10073/10082, IR 8547 final,
BlackX, 2026 CVEs).
