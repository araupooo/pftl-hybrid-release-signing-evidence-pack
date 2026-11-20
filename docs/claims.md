# Claim-to-Evidence Index

Every substantive claim in this pack traces to a runnable script and
its unedited output, or to a cited primary source. "Script" means the
script in `scripts/`; "log" means the unedited output in `outputs/`.

## Measurements (all from `scripts/bench_openssl.sh`, log `outputs/bench_openssl.log`)

| ID | Claim | Evidence |
|---|---|---|
| M-01 | ML-DSA signature sizes are 2,420 B (44), 3,309 B (65), 4,627 B (87), matching FIPS 204 exactly. | bench log, `signature bytes:` lines; raw keys in `work/bench_openssl/` |
| M-02 | SLH-DSA signature sizes match FIPS 205 exactly for all 12 sets: 128s 7,856 B; 128f 17,088 B; 192s 16,224 B; 192f 35,664 B; 256s 29,792 B; 256f 49,856 B (SHA2 = SHAKE sizes). | bench log, `signature bytes:` lines |
| M-03 | ML-DSA-65 in-process sign cost is 1,600 us, verify 291 us (OpenSSL 3.5.9, `openssl speed`, 2 s each). | bench log, `--- speed ML-DSA-65 ---` section: 625.0 sign/s, 3,440.0 verify/s |
| M-04 | SLH-DSA-SHA2-128s in-process sign cost is 547,500 us (547.5 ms), verify 526 us. | bench log, `--- speed SLH-DSA-SHA2-128s ---`: 1.8 sign/s, 1,902.5 verify/s |
| M-05 | SLH-DSA-SHA2-128f in-process sign cost is 25,769 us, verify 1,495 us. | bench log, `--- speed SLH-DSA-SHA2-128f ---`: 38.8 sign/s, 669.0 verify/s |
| M-06 | SLH-DSA "s"-variant signing is the slowest operation measured: explicit-loop medians 0.54 s (SHA2-128s) to 2.46 s (SHAKE-192s); all "s" medians are >= 0.54 s. | bench log summary table; `outputs/timings_SLH-DSA-*_sign.txt` (n=20 each) |
| M-07 | SLH-DSA verification is cheap for every set: explicit-loop medians 7.4–13.6 ms (spawn-dominated); in-process 0.53–1.50 ms for the two sets `speed` covers. | bench log summary table + speed sections |
| M-08 | Explicit-loop medians for fast algorithms (~7–11 ms) are dominated by ~7 ms process-spawn overhead; minima sit at ~6.4–8.3 ms for all fast algorithms. Use the in-process `speed` numbers for crypto comparison. | bench log; `outputs/timings_ML-DSA-65_sign.txt` min 8,344 us, `timings_Ed25519_sign.txt` min 6,418 us |
| M-09 | Hybrid (Ed25519 + ML-DSA-65) signature is 3,373 B (64 + 3,309); in-process sign ≈ 1,657 us, verify ≈ 424 us (sums of components). | `outputs/dual_sign_demo.log` (size accounting); bench log speed sections for the components |
| M-10 | SLH-DSA-128s signing (547.5 ms in-process) is ~330x the hybrid signing cost (~1.66 ms); SLH-DSA-128s verification (526 us) is ~1.8x the ML-DSA-65 verification cost (291 us). | M-03, M-04, M-09 (arithmetic on measured values) |
| M-11 | Zero failures in every measured operation (17 algorithms x 3 ops). | bench log, `failures=0` lines; `outputs/failures_<ALG>_<OP>.txt` |
| M-12 | OpenSSL 3.5.9 on this host provides ML-DSA-44/65/87, all 12 SLH-DSA sets, ML-KEM-512/768/1024, and Ed25519 in the default provider. | `outputs/env_probe.log`; bench log header |
| M-13 | Cross-stack: SLH-DSA-128s signing agrees across stacks (547.5 ms OpenSSL speed vs 692.7 ms liboqs, prior pack); ML-DSA signing does not (1,600 us OpenSSL speed vs ~140 us liboqs) — the toolchain changes the measured ML-DSA sign cost ~11x. Ordering is identical in both stacks. | bench log speed sections; prior pack https://github.com/araupooo/postfiat-release-signing-pqc-assessment (hybrid sign 139.669 us, SLH-DSA-128s sign 692,670.570 us) |

## Hybrid manifest demo (`scripts/dual_sign_demo.sh`, log `outputs/dual_sign_demo.log`)

| ID | Claim | Evidence |
|---|---|---|
| D-01 | A valid hybrid manifest (version 1.0.0, monotonic counter 42, three fixed-content artifacts with SHA-256 digests, hybrid metadata, signer fingerprints) is ACCEPTED when both signatures verify. | demo log, `VERDICT: ACCEPT`, `DEMO RESULT: PASS` |
| D-02 | Manifest is 1,013 B; hybrid signatures total 3,373 B; manifest + hybrid signatures 4,386 B. | demo log, size accounting section |
| D-03 | Artifact digests are deterministic across runs (fixed demo content): binary `f0e4d112…`, firmware `2c424921…`, notes `7f13fb06…` (full hashes in the manifest). | demo log; `outputs/dual_sign_demo/manifest.json` |
| D-04 | The demo artifacts are fixed-content placeholders, NOT real postfiatd binaries. | `scripts/manifest_lib.sh`, `build_artifacts()` |

## Downgrade simulation (`scripts/downgrade_sim.sh`, log `outputs/downgrade_sim.log`)

| ID | Claim | Evidence |
|---|---|---|
| S-01 | Control (valid manifest, counter 42, both signatures) → ACCEPT. | sim log, case A PASS |
| S-02 | Stale manifest (counter 41, valid signatures) → REJECT. A signature alone does not authorize a downgrade. | sim log, case B PASS |
| S-03 | Missing ML-DSA-65 signature (classical-only manifest) → REJECT. | sim log, case C PASS |
| S-04 | Missing Ed25519 signature (PQ-only manifest) → REJECT. | sim log, case D PASS |
| S-05 | Tampered artifact (digest mismatch, valid signatures) → REJECT. | sim log, case E PASS |
| S-06 | Swapped signatures (ML-DSA sig in the Ed25519 field) → REJECT. | sim log, case F PASS |
| S-07 | All 6 cases produce their expected verdict. | sim log, `DOWNGRADE SIMULATION RESULT: PASS (6/6)` |

## Key-compromise drill (`scripts/compromise_drill.sh`, log `outputs/compromise_drill.log`)

| ID | Claim | Evidence |
|---|---|---|
| K-01 | Release v1.0.0 (counter 42) signed with key set A is ACCEPTED before compromise. | drill log, step 1 PASS |
| K-02 | A revocation record naming set A's pubkey fingerprints can be published in the drill's format (`revocation-set-A.json`). | drill log, step 2 PASS |
| K-03 | Release v1.0.1 (counter 43) re-signed with fresh key set B. | drill log, step 3 PASS |
| K-04 | The compromised v1.0.0 manifest is REJECTED via the revocation record, even though its signatures are cryptographically valid. | drill log, step 4 PASS |
| K-05 | v1.0.1 is ACCEPTED with set B, and v1.0.0 signatures do NOT verify under set B pubkeys — rotation is real, not cosmetic. | drill log, step 5 PASS |
| K-06 | All 5 drill steps behave as expected. | drill log, `COMPROMISE DRILL RESULT: PASS (5/5)` |

## Composite probe (`scripts/composite_probe.sh`, log `outputs/composite_probe.log`)

| ID | Claim | Evidence |
|---|---|---|
| C-01 | Stock OpenSSL 3.5.9 lists no composite algorithms. | probe log, section 1 |
| C-02 | `genpkey` with RFC 10073 composite names (MLDSA65-Ed25519, id-MLDSA65-Ed25519-SHA512, MLDSA44-Ed25519) fails. | probe log, section 2 |
| C-03 | No oqsprovider is installed (default provider only). | probe log, section 3 |
| C-04 | RFC 10073 OIDs (verified live 20 Nov 2026, §8.2): id-MLDSA44-Ed25519-SHA512 = 1.3.6.1.5.5.7.6.39; id-MLDSA65-Ed25519-SHA512 = 1.3.6.1.5.5.7.6.48. No id-MLDSA87-Ed25519-SHA512 is registered. | RFC 10073 text, https://www.rfc-editor.org/rfc/rfc10073.txt §8.2 |
| C-05 | Composite ML-DSA is EUF-CMA only, not SUF-CMA; applications where SUF-CMA is critical SHOULD NOT use it. | RFC 10073 §9.2 (verified live 20 Nov 2026) |

## Standards and policy (cited, not measured)

| ID | Claim | Evidence |
|---|---|---|
| P-01 | NIST IR 8547 final (27 Oct 2026): quantum-vulnerable public-key algorithms deprecated after 2030, disallowed after 2035 at every key size; federal high-value assets: PQC KEX by 31 Dec 2030, PQC signatures by 31 Dec 2031. | https://csrc.nist.gov/pubs/ir/8547/final |
| P-02 | CNSA 2.0 does NOT approve SLH-DSA for firmware; its hash-based firmware choice is LMS/XMSS (SP 800-208). | NSA CNSA 2.0 v2.1 (Dec 2024); see SOURCES.md |
| P-03 | Sigstore will NOT do dual signatures: separate ML-DSA stack, own ML-DSA-signed TUF root, production public instance targeted mid-2027, opt-in at first; classical instance until turndown tentatively 2029–2030. | Sigstore blog, 2 Oct 2026, https://blog.sigstore.dev/pqc-sigstore/ |
| P-04 | A signature never stops rollback; only a monotonic counter + version check does. Four real cases: BootHole (CVE-2020-10713), Baton Drop/BlackX (CVE-2022-21894), CVE-2024-7344, Android OEM platform-key leak. | `docs/key-compromise-playbook.md` §1, with primary sources |
| P-05 | Patching ≠ revocation; expiry ≠ revocation (BlackX ran on fully patched machines; Windows Production PCA 2011 expired 19 Oct 2026 without blocking old binaries — only a DBX entry does). | `docs/key-compromise-playbook.md` §1–2; Kaspersky, 22 Oct 2026 |
| P-06 | No 2026 cryptanalytic break of ML-DSA or SLH-DSA; the 2026 CVEs are implementation/compiler/parsing bugs (CVE-2026-22705, CVE-2026-46344/44518, GHSA-r7wm). | `docs/key-compromise-playbook.md` §3; SOURCES.md |
| P-07 | postfiatd at 0085a1ff has no release-artifact signing, no published digests, and manual rollback with no counter. | `docs/postfiatd-release-gap.md`; `docs/RELEASE.md` at that commit |

## Reproduction

| ID | Claim | Evidence |
|---|---|---|
| R-01 | `bash scripts/run_all.sh` reproduces every measurement from a fresh clone without manual repair (OpenSSL 3.5.9 provisioned from the pinned tarball, SHA-256 verified). | `repro/fresh-clone-run.log`; `repro/REPRODUCTION.md` |
| R-02 | Sizes, digests, verdicts, and failure counts reproduce exactly; absolute timing values vary with machine/load (compare orders of magnitude); keys are random per run by design. | `repro/REPRODUCTION.md` |
