# Reproduction

This directory records the fresh-clone reproduction run of the pack:
the pack was copied to a clean directory (no `work/`, no `outputs/`,
no staged state) and `bash scripts/run_all.sh` was executed there.
The captured console log is `repro/fresh-clone-run.log`.

## How to reproduce (any machine)

Prerequisites (must already be installed; the script checks and stops
with the install command if any are missing):

```bash
sudo apt-get install -y cmake gcc make python3 git curl
```

Then:

```bash
git clone https://github.com/araupooo/pftl-hybrid-release-signing-evidence-pack.git
cd pftl-hybrid-release-signing-evidence-pack
bash scripts/run_all.sh
```

What happens:

1. `run_all.sh` downloads the pinned OpenSSL 3.5.9 tarball from
   openssl.org, verifies its SHA-256
   (`603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a`),
   builds it to `work/openssl-3.5.9-install`, and reuses it on later
   runs. Expected wall time on a 4-vCPU VM: ~15–25 minutes on a fresh
   clone (the OpenSSL build dominates); ~5 minutes when OpenSSL is
   already built.
2. It runs, in order: `env_probe.sh`, `bench_openssl.sh`,
   `dual_sign_demo.sh`, `downgrade_sim.sh`, `compromise_drill.sh`,
   `composite_probe.sh`, writing unedited logs to `outputs/`.
3. It asserts: all six logs exist; the demo passes; the downgrade
   simulation passes 6/6; the compromise drill passes 5/5; the
   composite probe passes; 51 timing files exist (17 algorithms x 3 ops).

## What reproduces exactly, and what varies

- **Exact:** signature sizes (ML-DSA-44 2,420 B; ML-DSA-65 3,309 B;
  ML-DSA-87 4,627 B; SLH-DSA 128s 7,856 B; 128f 17,088 B; 192s
  16,224 B; 192f 35,664 B; 256s 29,792 B; 256f 49,856 B; Ed25519 64 B),
  artifact digests (fixed demo content), ACCEPT/REJECT verdicts,
  failure counts (0 everywhere).
- **Varies with machine/load:** absolute timing values (microseconds).
  Compare orders of magnitude and ratios, not exact microseconds —
  e.g. SLH-DSA-128s signing is ~100x slower than ML-DSA-65 signing on
  any host, and hybrid verification is ~3–4x faster than
  SLH-DSA-128s verification.
- **Random per run (by design):** key material. Keys are generated
  fresh on every run and are test-only; signatures and key fingerprints
  therefore differ run to run, while sizes and verdicts do not.

## This run

- Fresh-clone run log: `repro/fresh-clone-run.log`
- (Filled in after the run: host, date, wall time, result.)
