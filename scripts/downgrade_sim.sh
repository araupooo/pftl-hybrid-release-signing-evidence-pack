#!/usr/bin/env bash
# downgrade_sim.sh — rejected downgrade simulation.
# Six cases, each run through scripts/verify_manifest.sh against a fixed
# installed counter of 42. Expected verdicts are asserted; the script
# exits 0 only if every case produces its expected verdict.
#   A control: valid manifest, counter 42, both signatures -> ACCEPT
#   B stale manifest: counter 41, valid signatures -> REJECT (rollback)
#   C missing ML-DSA-65 signature -> REJECT
#   D missing Ed25519 signature -> REJECT
#   E tampered artifact (digest mismatch), valid signatures -> REJECT
#   F swapped signatures (ML-DSA sig in the Ed25519 field) -> REJECT
# Keys are ephemeral test-only keys, generated fresh on every run.
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OSSL="$W/work/openssl-3.5.9-install"
export LD_LIBRARY_PATH="$OSSL/lib64"
export OPENSSL="$OSSL/bin/openssl"
# shellcheck source=manifest_lib.sh
. "$W/scripts/manifest_lib.sh"
BASE="$W/work/downgrade_sim"
rm -rf "$BASE"; mkdir -p "$BASE"
PASS=0; FAIL=0
echo "=== REJECTED DOWNGRADE SIMULATION ==="
echo "date_utc: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "openssl: $($OPENSSL version)"
echo "installed counter (simulated deployed release): 42"
echo

run_case() { # run_case <id> <dir> <expected ACCEPT|REJECT> <description>
  local id="$1" dir="$2" expected="$3" desc="$4"
  echo "--- case $id: $desc (expected: $expected) ---"
  bash "$W/scripts/verify_manifest.sh" "$dir" 42 "$dir/keys" > "$BASE/case-$id-verify.log" 2>&1
  local rc=$?
  local got="REJECT"; [ "$rc" -eq 0 ] && got="ACCEPT"
  grep "VERDICT" "$BASE/case-$id-verify.log"
  if [ "$got" = "$expected" ]; then echo "case $id: PASS (got $got)"; PASS=$((PASS+1));
  else echo "case $id: FAIL (expected $expected, got $got)"; FAIL=$((FAIL+1)); fi
  echo
}

# Case A — control: valid current manifest.
mkdir -p "$BASE/A/keys"
build_artifacts "$BASE/A"; gen_keys "$BASE/A/keys"
write_manifest "$BASE/A" "1.0.0" 42; sign_manifest "$BASE/A"
run_case A "$BASE/A" ACCEPT "control: valid manifest, counter 42, both signatures present"

# Case B — stale manifest: counter 41 with VALID signatures (signed when
# 41 was current). A signature alone must not authorize a downgrade.
mkdir -p "$BASE/B/keys"
build_artifacts "$BASE/B"; gen_keys "$BASE/B/keys"
write_manifest "$BASE/B" "0.9.0" 41; sign_manifest "$BASE/B"
run_case B "$BASE/B" REJECT "stale manifest: counter 41 < installed 42, signatures valid"

# Case C — current manifest, ML-DSA-65 signature removed (classical-only).
mkdir -p "$BASE/C/keys"
build_artifacts "$BASE/C"; gen_keys "$BASE/C/keys"
write_manifest "$BASE/C" "1.0.0" 42; sign_manifest "$BASE/C"
python3 - "$BASE/C" <<'PYEOF'
import sys, json
d = sys.argv[1]
s = json.load(open(f"{d}/signatures.json"))
del s["ml-dsa-65"]
open(f"{d}/signatures.json", "w").write(json.dumps(s, indent=2, sort_keys=True) + "\n")
print("removed ml-dsa-65 signature from signatures.json")
PYEOF
run_case C "$BASE/C" REJECT "missing ML-DSA-65 signature (classical-only manifest)"

# Case D — current manifest, Ed25519 signature removed (PQ-only).
mkdir -p "$BASE/D/keys"
build_artifacts "$BASE/D"; gen_keys "$BASE/D/keys"
write_manifest "$BASE/D" "1.0.0" 42; sign_manifest "$BASE/D"
python3 - "$BASE/D" <<'PYEOF'
import sys, json
d = sys.argv[1]
s = json.load(open(f"{d}/signatures.json"))
del s["ed25519"]
open(f"{d}/signatures.json", "w").write(json.dumps(s, indent=2, sort_keys=True) + "\n")
print("removed ed25519 signature from signatures.json")
PYEOF
run_case D "$BASE/D" REJECT "missing Ed25519 signature (PQ-only manifest)"

# Case E — artifact tampered after signing (digest mismatch).
mkdir -p "$BASE/E/keys"
build_artifacts "$BASE/E"; gen_keys "$BASE/E/keys"
write_manifest "$BASE/E" "1.0.0" 42; sign_manifest "$BASE/E"
printf 'TAMPERED' >> "$BASE/E/postfiatd-firmware-1.0.0.bin"
echo "appended TAMPERED bytes to postfiatd-firmware-1.0.0.bin after signing"
run_case E "$BASE/E" REJECT "tampered artifact: digest mismatch, signatures valid"

# Case F — signatures swapped between fields.
mkdir -p "$BASE/F/keys"
build_artifacts "$BASE/F"; gen_keys "$BASE/F/keys"
write_manifest "$BASE/F" "1.0.0" 42; sign_manifest "$BASE/F"
python3 - "$BASE/F" <<'PYEOF'
import sys, json
d = sys.argv[1]
s = json.load(open(f"{d}/signatures.json"))
s["ed25519"], s["ml-dsa-65"] = s["ml-dsa-65"], s["ed25519"]
open(f"{d}/signatures.json", "w").write(json.dumps(s, indent=2, sort_keys=True) + "\n")
print("swapped ed25519 and ml-dsa-65 signature fields")
PYEOF
run_case F "$BASE/F" REJECT "swapped signatures (ML-DSA sig in Ed25519 field)"

echo "=== DOWNGRADE SIMULATION SUMMARY ==="
echo "passed: $PASS / 6, failed: $FAIL / 6"
if [ "$FAIL" -eq 0 ]; then echo "DOWNGRADE SIMULATION RESULT: PASS (all 6 cases produced their expected verdict)"; exit 0;
else echo "DOWNGRADE SIMULATION RESULT: FAIL ($FAIL case(s) wrong)"; exit 1; fi
echo "=== end of downgrade_sim.sh ==="
