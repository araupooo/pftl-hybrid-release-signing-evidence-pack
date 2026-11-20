#!/usr/bin/env bash
# run_all.sh — reproduce every measurement in this pack from a fresh clone.
#
# What it provisions (network, pinned):
#   * OpenSSL 3.5.9 — tarball from openssl.org, SHA-256 verified
#     (603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a),
#     built to work/openssl-3.5.9-install (skipped if already built).
#   * System tools — must already be installed: cmake, gcc, make,
#     python3, git, curl. On Debian/Ubuntu:
#       sudo apt-get install -y cmake gcc make python3 git curl
#     This script checks for them and stops with the install command if
#     any are missing (it does not install packages itself).
#
# What it runs (in order, each log unedited into outputs/):
#   1. env_probe.sh        — environment facts + tool versions
#   2. bench_openssl.sh    — OpenSSL 3.5.9 ML-DSA / SLH-DSA / Ed25519 / RSA benchmarks
#   3. dual_sign_demo.sh   — hybrid manifest sign/verify demo (positive path)
#   4. downgrade_sim.sh    — rejected downgrade simulation (6 cases)
#   5. compromise_drill.sh — key-compromise and recovery drill (5 steps)
#   6. composite_probe.sh  — RFC 10073 composite ML-DSA support probe
#
# Notes: keys are random per run (by design); the fixed 32-byte message,
# the fixed demo artifacts, the iteration counts, and every expected size
# are fixed, so re-runs should reproduce the same sizes, ACCEPT/REJECT
# outcomes, and timing ranges (timing values vary with machine load —
# compare orders of magnitude, not exact microseconds).
# Expected wall time on a 4-vCPU VM: ~15-25 minutes (OpenSSL build dominates
# on a fresh clone; ~5 minutes when OpenSSL is already built).
#
# NOTE: scripts are invoked via `bash` (not `./`) on purpose: files
# uploaded through the GitHub web UI lose their executable bit, so a fresh
# clone would fail with exit 126 if run_all.sh called ./script.sh directly.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p work outputs
echo "=== run_all.sh ==="
echo "repo root: $ROOT"
echo "date_utc: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo

# --- 0. System tools ---
MISSING=""
for t in cmake gcc make python3 git curl; do
  command -v "$t" >/dev/null 2>&1 || MISSING="$MISSING $t"
done
if [ -n "$MISSING" ]; then
  echo "MISSING tools:$MISSING"
  echo "Install them first, e.g.:"
  echo "  sudo apt-get install -y cmake gcc make python3 git curl"
  exit 1
fi
echo "system tools present: cmake gcc make python3 git curl"
echo

# --- 1. OpenSSL 3.5.9 (pinned tarball, SHA-256 verified) ---
OSSL_INSTALL="$ROOT/work/openssl-3.5.9-install"
OSSL_TARBALL_SHA="603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a"
# NOTE: the version check must set LD_LIBRARY_PATH — the built binary links
# the install's own lib64; run bare it fails against the system libssl.so.3.
# Prefix match: `openssl version` prints "OpenSSL 3.5.9 29 Sep 2026 (Library:
# OpenSSL 3.5.9 29 Sep 2026)" here, not the bare version string.
_ossl_build=0
if [ -x "$OSSL_INSTALL/bin/openssl" ]; then
  _ossl_ver="$(LD_LIBRARY_PATH="$OSSL_INSTALL/lib64" "$OSSL_INSTALL/bin/openssl" version 2>/dev/null)"
  case "$_ossl_ver" in
    "OpenSSL 3.5.9 29 Sep 2026"*) echo "OpenSSL 3.5.9 already built at $OSSL_INSTALL — reusing.";;
    *) echo "OpenSSL at $OSSL_INSTALL is not 3.5.9 (got: $_ossl_ver) — rebuilding."; _ossl_build=1;;
  esac
else
  _ossl_build=1
fi
if [ "$_ossl_build" = 1 ]; then
  echo "Building OpenSSL 3.5.9 (this takes a few minutes)..."
  cd "$ROOT/work"
  [ -f openssl-3.5.9.tar.gz ] || curl -fsSL -o openssl-3.5.9.tar.gz https://www.openssl.org/source/openssl-3.5.9.tar.gz
  echo "$OSSL_TARBALL_SHA  openssl-3.5.9.tar.gz" | sha256sum -c - || { echo "OpenSSL tarball SHA-256 MISMATCH — aborting."; exit 1; }
  rm -rf openssl-3.5.9
  tar xzf openssl-3.5.9.tar.gz
  cd openssl-3.5.9
  ./Configure --prefix="$OSSL_INSTALL" --openssldir="$OSSL_INSTALL/ssl" > "$ROOT/work/openssl-3.5.9-configure.log" 2>&1
  make -j"$(nproc)" > "$ROOT/work/openssl-3.5.9-build.log" 2>&1 || { echo "OpenSSL build FAILED — see work/openssl-3.5.9-build.log"; exit 1; }
  make install_sw > "$ROOT/work/openssl-3.5.9-install.log" 2>&1 || { echo "OpenSSL install FAILED — see work/openssl-3.5.9-install.log"; exit 1; }
  cd "$ROOT"
  echo "OpenSSL 3.5.9 built: $(LD_LIBRARY_PATH="$OSSL_INSTALL/lib64" "$OSSL_INSTALL/bin/openssl" version)"
fi
echo

# --- 2. Run the measurement scripts in order ---
export OPENSSL="$OSSL_INSTALL/bin/openssl"
export LD_LIBRARY_PATH="$OSSL_INSTALL/lib64"
FAIL=0
run_step() { # run_step <script> <log-name>
  echo "### step: $1 -> outputs/$2"
  bash "scripts/$1" > "outputs/$2" 2>&1
  rc=$?
  echo "### step $1 exit code: $rc"
  tail -n 3 "outputs/$2"
  echo
  [ "$rc" -ne 0 ] && FAIL=1
  return "$rc"
}
run_step env_probe.sh env_probe.log
run_step bench_openssl.sh bench_openssl.log
run_step dual_sign_demo.sh dual_sign_demo.log
run_step downgrade_sim.sh downgrade_sim.log
run_step compromise_drill.sh compromise_drill.log
run_step composite_probe.sh composite_probe.log

# --- 3. Final checks ---
echo "### final checks"
EXPECTED="env_probe.log bench_openssl.log dual_sign_demo.log downgrade_sim.log compromise_drill.log composite_probe.log"
missing=""
for f in $EXPECTED; do [ -f "outputs/$f" ] || missing="$missing $f"; done
[ -n "$missing" ] && { echo "MISSING output logs:$missing"; FAIL=1; }
grep -q "DEMO RESULT: PASS" outputs/dual_sign_demo.log || { echo "CHECK FAILED: dual-sign demo did not pass"; FAIL=1; }
grep -q "DOWNGRADE SIMULATION RESULT: PASS" outputs/downgrade_sim.log || { echo "CHECK FAILED: downgrade simulation did not pass"; FAIL=1; }
grep -q "COMPROMISE DRILL RESULT: PASS" outputs/compromise_drill.log || { echo "CHECK FAILED: compromise drill did not pass"; FAIL=1; }
grep -q "COMPOSITE PROBE RESULT: PASS" outputs/composite_probe.log || { echo "CHECK FAILED: composite probe did not pass"; FAIL=1; }
n_timings=$(ls outputs/timings_*.txt 2>/dev/null | wc -l)
echo "timing files produced: $n_timings (expected 51: 17 algorithms x 3 ops)"
[ "$n_timings" -eq 51 ] || { echo "CHECK FAILED: expected 51 timing files, got $n_timings"; FAIL=1; }
if [ "$FAIL" -eq 0 ]; then echo "run_all.sh: ALL CHECKS PASSED"; else echo "run_all.sh: SOME CHECKS FAILED — see above"; exit 1; fi
echo "=== end of run_all.sh ==="
